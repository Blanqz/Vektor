with System;
with Interfaces.C;
with Interfaces.C.Strings;
with Ada.Unchecked_Conversion;
with System.Storage_Elements;

package body Runtime is
   use Interfaces.C;
   use Interfaces.C.Strings;
   use type System.Address;

   procedure C_Exit (Status : int);
   pragma Import (C, C_Exit, "exit");
   use System.Storage_Elements;
   function Malloc (Size : size_t) return System.Address;
   pragma Import (C, Malloc, "malloc");

   function To_Chars_Ptr is new Ada.Unchecked_Conversion (System.Address, chars_ptr);
   function To_Address is new Ada.Unchecked_Conversion (chars_ptr, System.Address);
   type Char_Access is access all Character;
   function To_Char_Access is new Ada.Unchecked_Conversion (System.Address, Char_Access);

   type Char_Array is array (size_t range <>) of Character;
   type Char_Array_Access is access all Char_Array;
   function To_Char_Array is new Ada.Unchecked_Conversion (chars_ptr, Char_Array_Access);

   function Make_C_String (S : String) return chars_ptr is
      P : constant chars_ptr := To_Chars_Ptr (Malloc (size_t (S'Length + 1)));
      A : constant Char_Array_Access := To_Char_Array (P);
   begin
      for I in S'Range loop
         A (size_t (I - S'First)) := S (I);
      end loop;
      A (size_t (S'Length)) := ASCII.NUL;
      return P;
   end Make_C_String;

   function Strlen (S : chars_ptr) return size_t;
   pragma Import (C, Strlen, "strlen");

   procedure Strcpy (Dest : chars_ptr; Src : chars_ptr);
   pragma Import (C, Strcpy, "strcpy");

   procedure Strcat (Dest : chars_ptr; Src : chars_ptr);
   pragma Import (C, Strcat, "strcat");

   function Puts (S : chars_ptr) return int;
   pragma Import (C, Puts, "puts");

   function Snprintf (Buf : chars_ptr; Size : size_t; Fmt : chars_ptr; Val : long_long) return int;
   pragma Import (C, Snprintf, "snprintf");

   type Obj_Array is array (Long_Long_Integer range <>) of long_long;
   type Obj_Array_Access is access all Obj_Array;
   function To_Obj_Access is new Ada.Unchecked_Conversion (System.Address, Obj_Array_Access);

   procedure Vect_Puts (S : in chars_ptr) is
   begin
      if S /= Null_Ptr then
         declare
            Dummy : int := Puts (S);
            pragma Unreferenced (Dummy);
         begin
            null;
         end;
      end if;
   end Vect_Puts;


   procedure Poke (A : System.Address; Off : size_t; C : Character) is
      P : constant Char_Access := To_Char_Access (A + Storage_Offset (Off));
   begin
      P.all := C;
   end Poke;

   function Peek (A : System.Address; Off : size_t) return Character is
      P : constant Char_Access := To_Char_Access (A + Storage_Offset (Off));
   begin
      return P.all;
   end Peek;

   function Vect_Int_To_String (X : in long_long) return chars_ptr is
      Buf : constant chars_ptr := To_Chars_Ptr (Malloc (64));
      Addr : constant System.Address := To_Address (Buf);
      V : long_long := X;
      Neg : Boolean := False;
      Pos : size_t := 0;
      Tmp : Character;
   begin
      if X < 0 then
         Neg := True;
         V := -X;
      end if;
      if V = 0 then
         Poke (Addr, 0, '0');
         Pos := 1;
      else
         while V > 0 loop
            Poke (Addr, Pos, Character'Val (Character'Pos ('0') + Natural (V rem 10)));
            Pos := Pos + 1;
            V := V / 10;
         end loop;
      end if;
      if Neg then
         Poke (Addr, Pos, '-');
         Pos := Pos + 1;
      end if;
      for I in 0 .. (Pos / 2) - 1 loop
         Tmp := Peek (Addr, size_t (I));
         Poke (Addr, size_t (I), Peek (Addr, Pos - size_t (I) - 1));
         Poke (Addr, Pos - size_t (I) - 1, Tmp);
      end loop;
      Poke (Addr, Pos, ASCII.NUL);
      return Buf;
   end Vect_Int_To_String;

   function Vect_Len (S : in chars_ptr) return long_long is
   begin
      if S = Null_Ptr then
         return 0;
      end if;
      return long_long (Strlen (S));
   end Vect_Len;

   function Vect_Str_From_C (S : in chars_ptr) return chars_ptr is
   begin
      return S;
   end Vect_Str_From_C;

   function Vect_Concat (A, B : in chars_ptr) return chars_ptr is
      La : constant size_t := (if A = Null_Ptr then 0 else Strlen (A));
      Lb : constant size_t := (if B = Null_Ptr then 0 else Strlen (B));
      R  : constant chars_ptr := To_Chars_Ptr (Malloc (La + Lb + 1));
   begin
      if A /= Null_Ptr then
         Strcpy (R, A);
      else
         declare
            Empty : chars_ptr := To_Chars_Ptr (Malloc (1));
         begin
            Poke (To_Address (R), 0, ASCII.NUL);
         end;
      end if;
      if B /= Null_Ptr then
         Strcat (R, B);
      end if;
      return R;
   end Vect_Concat;

   function Vect_Obj_New (N : in long_long) return System.Address is
   begin
      if N <= 0 then
         return System.Null_Address;
      end if;
      return Malloc (size_t (N) * size_t (Long_Long_Integer'Size / 8));
   end Vect_Obj_New;

   procedure Vect_Obj_Set (Obj : in System.Address; Index : in long_long; Val : in long_long) is
      type LL_Access is access all long_long;
      function To_LL_Access is new Ada.Unchecked_Conversion (System.Address, LL_Access);
   begin
      if Obj /= System.Null_Address then
         declare
            Ptr : System.Address := Obj + Storage_Offset (Index * 8);
            Acc : constant LL_Access := To_LL_Access (Ptr);
         begin
            Acc.all := Val;
         end;
      end if;
   end Vect_Obj_Set;

   function Vect_Obj_Get (Obj : in System.Address; Index : in long_long) return long_long is
      type LL_Access is access all long_long;
      function To_LL_Access is new Ada.Unchecked_Conversion (System.Address, LL_Access);
   begin
      if Obj = System.Null_Address then
         return 0;
      end if;
      declare
         Ptr : System.Address := Obj + Storage_Offset (Index * 8);
         Acc : constant LL_Access := To_LL_Access (Ptr);
      begin
         return Acc.all;
      end;
   end Vect_Obj_Get;

   function Vect_Ffi_Address (Name : in chars_ptr) return System.Address is
      pragma Unreferenced (Name);
   begin
      return System.Null_Address;
   end Vect_Ffi_Address;
   procedure Vect_Trap is
      Msg : constant chars_ptr := To_Chars_Ptr (Malloc (24));
      Dummy : int;
      pragma Unreferenced (Dummy);
   begin
      Poke (To_Address (Msg), 0, 'p');
      Poke (To_Address (Msg), 1, 'a');
      Poke (To_Address (Msg), 2, 'n');
      Poke (To_Address (Msg), 3, 'i');
      Poke (To_Address (Msg), 4, 'c');
      Poke (To_Address (Msg), 5, ':');
      Poke (To_Address (Msg), 6, ' ');
      Poke (To_Address (Msg), 7, 'p');
      Poke (To_Address (Msg), 8, 'r');
      Poke (To_Address (Msg), 9, 'o');
      Poke (To_Address (Msg), 10, 'c');
      Poke (To_Address (Msg), 11, 'e');
      Poke (To_Address (Msg), 12, 's');
      Poke (To_Address (Msg), 13, 's');
      Poke (To_Address (Msg), 14, ' ');
      Poke (To_Address (Msg), 15, 'a');
      Poke (To_Address (Msg), 16, 'b');
      Poke (To_Address (Msg), 17, 'o');
      Poke (To_Address (Msg), 18, 'r');
      Poke (To_Address (Msg), 19, 't');
      Poke (To_Address (Msg), 20, 'e');
      Poke (To_Address (Msg), 21, 'd');
      Poke (To_Address (Msg), 22, ASCII.NUL);
      Dummy := Puts (Msg);
      C_Exit (1);
   end Vect_Trap;

   function Vect_Call_Indirect (Closure : in System.Address) return System.Address is
      pragma Unreferenced (Closure);
   begin
      return System.Null_Address;
   end Vect_Call_Indirect;
   procedure Vect_GC_Collect is
   begin
      null;
   end Vect_GC_Collect;

end Runtime;
