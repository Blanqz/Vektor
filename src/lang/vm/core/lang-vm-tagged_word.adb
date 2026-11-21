with Interfaces;
with Ada.Unchecked_Conversion;
use Interfaces;

package body Lang.VM.Tagged_Word is

   function To_Raw (Word : Tagged_Word) return Interfaces.Unsigned_64 is
   begin
      return Interfaces.Unsigned_64 (Word);
   end To_Raw;

   function Tag_Of (Word : Tagged_Word) return Tag is
   begin
      return Tag (To_Raw (Word) and 16#7#);
   end Tag_Of;

   function Is_Heap_Pointer (Word : Tagged_Word) return Boolean is
   begin
      return Tag_Of (Word) = Tag_Heap;
   end Is_Heap_Pointer;

   function Is_Small_Int (Word : Tagged_Word) return Boolean is
   begin
      return Tag_Of (Word) = Tag_Int;
   end Is_Small_Int;

   function Is_Immediate (Word : Tagged_Word) return Boolean is
   begin
      return Tag_Of (Word) = Tag_Imm;
   end Is_Immediate;

   function Is_Box (Word : Tagged_Word) return Boolean is
   begin
      return Tag_Of (Word) = Tag_Box;
   end Is_Box;

   function Make_Heap_Ptr (Addr : Interfaces.Unsigned_64) return Tagged_Word is
   begin
      return Tagged_Word (Addr or Unsigned_64 (Tag_Heap));
   end Make_Heap_Ptr;

   function Make_Small_Int (Value : Interfaces.Integer_64) return Tagged_Word is
      function Cast is new Ada.Unchecked_Conversion (Interfaces.Integer_64, Interfaces.Unsigned_64);
      Raw : constant Interfaces.Unsigned_64 := Cast (Value);
   begin
      if Value < -2 ** 60 or else Value > 2 ** 60 - 1 then
         raise Constraint_Error with "value outside small-int range";
      end if;
      return Tagged_Word (Shift_Left (Raw, 3) or Unsigned_64 (Tag_Int));
   end Make_Small_Int;

   function Make_Box_Ptr (Addr : Interfaces.Unsigned_64) return Tagged_Word is
   begin
      return Tagged_Word (Addr or Unsigned_64 (Tag_Box));
   end Make_Box_Ptr;

   function Make_Bool (Value : Boolean) return Tagged_Word is
   begin
      if Value then
         return Tagged_Word (Shift_Left (Unsigned_64 (1), 3) or Unsigned_64 (Tag_Imm));
      else
         return Tagged_Word (Unsigned_64 (Tag_Imm));
      end if;
   end Make_Bool;

   function Make_None return Tagged_Word is
   begin
      return None_Value;
   end Make_None;

   function Make_Unit return Tagged_Word is
   begin
      return Unit_Value;
   end Make_Unit;

   function Make_Char (Value : Wide_Wide_Character) return Tagged_Word is
   begin
      return Tagged_Word (Shift_Left (Unsigned_64 (Wide_Wide_Character'Pos (Value)), 3) or Unsigned_64 (2));
   end Make_Char;

   function Make_Pid (Value : Interfaces.Unsigned_64) return Tagged_Word is
   begin
      return Tagged_Word (Shift_Left (Value, 3) or Unsigned_64 (2));
   end Make_Pid;

   function Unbox_Small_Int (Word : Tagged_Word) return Interfaces.Integer_64 is
      function Cast is new Ada.Unchecked_Conversion (Interfaces.Unsigned_64, Interfaces.Integer_64);
      Shifted : constant Interfaces.Unsigned_64 :=
        Shift_Right_Arithmetic (To_Raw (Word), 3);
   begin
      return Cast (Shifted);
   end Unbox_Small_Int;

   function Unbox_Heap_Ptr (Word : Tagged_Word) return Interfaces.Unsigned_64 is
   begin
      return To_Raw (Word) and (not 16#7#);
   end Unbox_Heap_Ptr;

   function Unbox_Box_Ptr (Word : Tagged_Word) return Interfaces.Unsigned_64 is
   begin
      return To_Raw (Word) and (not 16#7#);
   end Unbox_Box_Ptr;

   function Unbox_Bool (Word : Tagged_Word) return Boolean is
   begin
      return Shift_Right (To_Raw (Word), 3) = Unsigned_64 (1);
   end Unbox_Bool;
   function Unbox_Pid (Word : Tagged_Word) return Interfaces.Unsigned_64 is
   begin
      return Shift_Right (To_Raw (Word), 3);
   end Unbox_Pid;

end Lang.VM.Tagged_Word;