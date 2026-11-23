with Ada.Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Characters.Handling;
with Ada.Real_Time;
with Ada.Numerics.Long_Elementary_Functions;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;           use Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Ada.Unchecked_Conversion;
with System.Storage_Elements;
with Interfaces;            use Interfaces;
with Lang.VM.IR;            use Lang.VM.IR;
with Lang.VM.Code;
with Lang.VM.Tagged_Word;
with Lang.VM.Box_Header; use Lang.VM.Box_Header;
with Lang.VM.Platform;
with System;
with Interfaces.C;
with Interfaces.C.Strings;

with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Directories;
with Ada.Environment_Variables;
with GNAT.Sockets;
with Ada.Long_Float_Text_IO;
with Ada.Text_IO;

package body Lang.VM.Machine is

   function Format_Decimal (V : Long_Float) return String is
      Buf : String (1 .. 400);
   begin
      Ada.Long_Float_Text_IO.Put (Buf, V, Aft => 12, Exp => 0);
      declare
         S : constant String := Ada.Strings.Fixed.Trim (Buf, Ada.Strings.Both);
         Last : Natural := S'Last;
      begin
         if S'Length = 0 then
            return "0.0";
         end if;
         if (for some C of S => C = '.') then
            while Last > S'First + 1 and then S (Last) = '0' and then S (Last - 1) /= '.' loop
               Last := Last - 1;
            end loop;
         end if;
         return S (S'First .. Last);
      end;
   exception
      when Ada.Text_IO.Layout_Error | Constraint_Error =>
         return Ada.Strings.Fixed.Trim (Long_Float'Image (V), Ada.Strings.Both);
   end Format_Decimal;

   use Lang.VM.Tagged_Word;

   --  Reference point for Clock.monotonic_ms, taken when the VM is elaborated.
   Mono_Epoch : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;

   function Index_Text (I : Integer_64) return String is
     (Ada.Strings.Fixed.Trim (Integer_64'Image (I), Ada.Strings.Left));

   --  Ends the whole program the way the language's process throw does: exit status 1.
   procedure C_Exit (Code : Interfaces.C.int);
   pragma Import (C, C_Exit, "exit");

   --  UTF-8 bytes of one Unicode code point; empty when the value is not a code point.
   function Utf8_Of (CP : Integer_64) return String is
      function Ch (N : Integer_64) return Character is (Character'Val (Integer (N)));
   begin
      if CP < 0 or else CP > 16#10FFFF# then
         return "";
      elsif CP < 16#80# then
         return (1 => Ch (CP));
      elsif CP < 16#800# then
         return (Ch (16#C0# + CP / 64), Ch (16#80# + CP mod 64));
      elsif CP < 16#10000# then
         return (Ch (16#E0# + CP / 4096), Ch (16#80# + (CP / 64) mod 64), Ch (16#80# + CP mod 64));
      else
         return (Ch (16#F0# + CP / 262144), Ch (16#80# + (CP / 4096) mod 64),
                 Ch (16#80# + (CP / 64) mod 64), Ch (16#80# + CP mod 64));
      end if;
   end Utf8_Of;

   use type VC.Builtin_Id;
   use VC;
   use System;
   use Interfaces.C;
   use Interfaces.C.Strings;

   Zero : constant TW := Make_Small_Int (0);

   procedure Free_Values is new Ada.Unchecked_Deallocation (Value_Array, Value_Array_Access);
   procedure Free_Natural_Array is new Ada.Unchecked_Deallocation (VC.Natural_Array, VC.Natural_Array_Access);
   procedure Free_Frames is new Ada.Unchecked_Deallocation (Frame_Array, Frame_Array_Access);
   procedure Free_Index is new Ada.Unchecked_Deallocation (Index_Array, Index_Array_Access);
   procedure Free_Str_Pool is new Ada.Unchecked_Deallocation (Str_Pool_Array, Str_Pool_Access);
   procedure Free_Obj_Pool is new Ada.Unchecked_Deallocation (Obj_Pool_Array, Obj_Pool_Access);
   procedure Free_VT_Pool is new Ada.Unchecked_Deallocation (VTable_Pool_Array, VTable_Pool_Access);
   procedure Free_Box_Pool is new Ada.Unchecked_Deallocation (Box_Pool_Array, Box_Pool_Access);

   function Str_Ptr (Slot : Natural) return TW is
     (Make_Heap_Ptr (Unsigned_64 (Slot) * 16));

   function Obj_Ptr (Slot : Natural) return TW is
     (Make_Heap_Ptr (Unsigned_64 (Slot) * 16 + 8));

   function Box_Ptr (Slot : Natural) return TW is
     (Make_Box_Ptr (Unsigned_64 (Slot) * 8));

   function Str_Slot (P : Process_Access; W : TW) return Natural is
   begin
      if Is_Heap_Pointer (W) then
         declare
            Addr : constant Unsigned_64 := Unbox_Heap_Ptr (W);
         begin
            if Addr mod 16 = 0 then
               declare
                  Idx : constant Unsigned_64 := Addr / 16;
               begin
                  if Idx >= 1 and then Idx <= Unsigned_64 (P.Str_Cap)
                    and then P.String_Pool (Natural (Idx)).In_Use
                  then
                     return Natural (Idx);
                  end if;
               end;
            end if;
         end;
      end if;
      return 0;
   end Str_Slot;

   function Obj_Slot (P : Process_Access; W : TW) return Natural is
   begin
      if Is_Heap_Pointer (W) then
         declare
            Addr : constant Unsigned_64 := Unbox_Heap_Ptr (W);
         begin
            if Addr mod 16 = 8 then
               declare
                  Idx : constant Unsigned_64 := Addr / 16;
               begin
                  if Idx >= 1 and then Idx <= Unsigned_64 (P.Obj_Cap)
                    and then P.Object_Pool (Natural (Idx)).In_Use
                  then
                     return Natural (Idx);
                  end if;
               end;
            end if;
         end;
      end if;
      return 0;
   end Obj_Slot;

   function Box_Slot (P : Process_Access; W : TW) return Natural is
   begin
      if Is_Box (W) then
         declare
            Idx : constant Unsigned_64 := Unbox_Box_Ptr (W) / 8;
         begin
            if Idx >= 1 and then Idx <= Unsigned_64 (P.Box_Cap)
              and then P.Box_Pool (Natural (Idx)).In_Use
            then
               return Natural (Idx);
            end if;
         end;
      end if;
      return 0;
   end Box_Slot;

   function Chars_Of (P : Process_Access; W : TW) return Unbounded_String is
      S : constant Natural := Str_Slot (P, W);
   begin
      if S > 0 then
         if P.String_Pool (S).Large and then P.String_Pool (S).Buf_Id > 0 then
            return P.Large_Buffers (P.String_Pool (S).Buf_Id).Data;
         end if;
         return P.String_Pool (S).Chars;
      end if;
      return Null_Unbounded_String;
   end Chars_Of;

   procedure Verify_Roots (M : in out Machine) is
   begin
      for I in 1 .. Natural (M.Processes.Length) loop
         declare
            P : constant Process_Access := M.Processes (I);
         begin
            for F in 1 .. P.Depth loop
               if P.Frames (F).Base < 1 or else P.Frames (F).Base + P.Frames (F).Reg_Count > P.Stack.all'Length then
                  Put_Line ("verify: bad frame layout in process" & Natural'Image (P.Id));
               end if;
               if P.Frames (F).Func > Natural (M.Prog.Funcs'Length) then
                  Put_Line ("verify: bad function id in process" & Natural'Image (P.Id));
               end if;
            end loop;
            if P.Mail_Head + P.Mail_Count > P.Mail.all'Length then
               Put_Line ("verify: bad mailbox in process" & Natural'Image (P.Id));
            end if;
         end;
      end loop;
   end Verify_Roots;

   procedure Collect (M : in out Machine) is
   begin
      M.GC_Generation := M.GC_Generation + 1;
      M.Major_GC := (M.GC_Generation mod 10 = 0);
      for PI in 1 .. Natural (M.Processes.Length) loop
         declare
            P : constant Process_Access := M.Processes (PI);
            Work : Index_Array_Access := new Index_Array (1 .. P.Obj_Cap);
            Top  : Natural := 0;

            procedure Mark_Pinned is
            begin
               for I in 1 .. P.Obj_Cap loop
                  if P.Object_Pool (I).In_Use and then P.Object_Pool (I).Pinned and then not P.Object_Pool (I).Marked then
                     P.Object_Pool (I).Marked := True;
                     Top := Top + 1;
                     Work (Top) := I;
                  end if;
               end loop;
               for I in 1 .. P.Str_Cap loop
                  if P.String_Pool (I).In_Use and then P.String_Pool (I).Pinned then
                     P.String_Pool (I).Marked := True;
                  end if;
               end loop;
            end Mark_Pinned;

            procedure Mark (W : TW) is
               S : Natural;
            begin
               if not Is_Heap_Pointer (W) then
                  return;
               end if;
               S := Str_Slot (P, W);
               if S > 0 then
                  P.String_Pool (S).Marked := True;
               else
                  S := Obj_Slot (P, W);
               if S > 0 then
                  if not P.Object_Pool (S).Marked then
                     P.Object_Pool (S).Marked := True;
                     Top := Top + 1;
                     Work (Top) := S;
                  end if;
               else
                  S := Box_Slot (P, W);
                  if S > 0 then
                     P.Box_Pool (S).Marked := True;
                  end if;
               end if;
               end if;
            end Mark;
         begin
            Mark_Pinned;
            Mark (P.Result);
            if P.Status /= Proc_Dead then
               for F in 1 .. P.Depth loop
                  for I in 0 .. P.Frames (F).Reg_Count - 1 loop
                     Mark (P.Stack (P.Frames (F).Base + I));
                  end loop;
               end loop;
               for I in 0 .. P.Mail_Count - 1 loop
                  Mark (P.Mail (((P.Mail_Head + I) mod P.Mail.all'Length) + 1));
               end loop;
            end if;

            while Top > 0 loop
               declare
                  S : constant Natural := Work (Top);
               begin
                  Top := Top - 1;
                  for I in 1 .. P.Object_Pool (S).Count loop
                     Mark (P.Object_Pool (S).Fields (I));
                  end loop;
                  if P.Object_Pool (S).Count >= 2 then
                     declare
                        VIdx : constant Natural := Natural (Unbox_Small_Int (P.Object_Pool (S).Fields (2)));
                     begin
                        if VIdx >= 1 and then VIdx <= P.VT_Cap and then P.VTable_Pool (VIdx).In_Use then
                           P.VTable_Pool (VIdx).Marked := True;
                        end if;
                     end;
                  end if;
               end;
            end loop;

            for I in 1 .. P.Str_Cap loop
               if P.String_Pool (I).In_Use and then not P.String_Pool (I).Pinned and then not P.String_Pool (I).Marked then
                  if M.Major_GC or else P.String_Pool (I).Gen >= M.GC_Generation - 1 then
                     if P.String_Pool (I).Large and then P.String_Pool (I).Buf_Id > 0 then
                        Release_Large_Buffer (P, P.String_Pool (I).Buf_Id);
                     end if;
                     P.String_Pool (I).In_Use := False;
                     P.String_Pool (I).Chars := Null_Unbounded_String;
                     P.String_Pool (I).Large := False;
                     P.String_Pool (I).Buf_Id := 0;
                  end if;
               end if;
               P.String_Pool (I).Marked := False;
            end loop;

            for I in 1 .. P.Obj_Cap loop
               if P.Object_Pool (I).In_Use and then not P.Object_Pool (I).Marked then
                  if M.Major_GC or else P.Object_Pool (I).Gen >= M.GC_Generation - 1 then
                     P.Object_Pool (I).In_Use := False;
                     P.Object_Pool (I).Count := 0;
                     P.Object_Pool (I).Type_Name := To_Unbounded_String ("");
                     Free_Values (P.Object_Pool (I).Fields);
                     P.Object_Pool (I).Fields := null;
                  end if;
               end if;
               P.Object_Pool (I).Marked := False;
            end loop;

            P.Str_Free_Top := 0;
            for I in reverse 1 .. P.Str_Cap loop
               if not P.String_Pool (I).In_Use then
                  P.Str_Free_Top := P.Str_Free_Top + 1;
                  P.Str_Free (P.Str_Free_Top) := I;
               end if;
            end loop;

            P.Obj_Free_Top := 0;
            for I in reverse 1 .. P.Obj_Cap loop
               if not P.Object_Pool (I).In_Use then
                  P.Obj_Free_Top := P.Obj_Free_Top + 1;
                  P.Obj_Free (P.Obj_Free_Top) := I;
               end if;
            end loop;

            for I in 1 .. P.VT_Cap loop
               if P.VTable_Pool (I).In_Use and then not P.VTable_Pool (I).Marked then
                  if M.Major_GC then
                     P.VTable_Pool (I).In_Use := False;
                     Free_Natural_Array (P.VTable_Pool (I).Methods);
                     P.VTable_Pool (I).Methods := null;
                  end if;
               end if;
               P.VTable_Pool (I).Marked := False;
            end loop;

            P.VT_Free_Top := 0;
            for I in reverse 1 .. P.VT_Cap loop
               if not P.VTable_Pool (I).In_Use then
                  P.VT_Free_Top := P.VT_Free_Top + 1;
                  P.VT_Free (P.VT_Free_Top) := I;
               end if;
            end loop;
            for I in 1 .. P.Box_Cap loop
               if P.Box_Pool (I).In_Use and then not P.Box_Pool (I).Marked then
                  if M.Major_GC or else P.Box_Pool (I).Gen >= M.GC_Generation - 1 then
                     P.Box_Pool (I).In_Use := False;
                     P.Box_Pool (I).Value := 0;
                  end if;
               end if;
               P.Box_Pool (I).Marked := False;
            end loop;

            P.Box_Free_Top := 0;
            for I in reverse 1 .. P.Box_Cap loop
               if not P.Box_Pool (I).In_Use then
                  P.Box_Free_Top := P.Box_Free_Top + 1;
                  P.Box_Free (P.Box_Free_Top) := I;
               end if;
            end loop;
            if M.Major_GC then
               Compact_Strings (M, P);
            end if;
            Free_Index (Work);
         end;
      end loop;
      M.Allocations_Since_GC := 0;
   end Collect;

    procedure Maybe_GC_At_Safepoint (M : in out Machine; P : Process_Access) is
    begin
       if M.GC_Safepoint_Pending then
          Collect (M);
          M.GC_Safepoint_Pending := False;
       elsif M.GC_Stress_Interval > 0 and then M.Allocations_Since_GC >= M.GC_Stress_Interval then
          Collect (M);
       end if;
    end Maybe_GC_At_Safepoint;

   procedure Run_Process_Drops (M : in out Machine; P : Process_Access) is
   begin
      for F in 1 .. P.Depth loop
         if P.Frames (F).Owned_Mask /= 0 then
            for I in 0 .. P.Frames (F).Reg_Count - 1 loop
               if (P.Frames (F).Owned_Mask and (Interfaces.Unsigned_32 (2) ** Natural (I))) /= 0 then
                  declare
                     V : constant TW := P.Stack (P.Frames (F).Base + I);
                     O : constant Natural := Obj_Slot (P, V);
                  begin
                     if O > 0 then
                        declare
                           DropFn : Natural := P.Object_Pool (O).Drop;
                           TypeName : constant String := To_String (P.Object_Pool (O).Type_Name);
                        begin
                           if DropFn = 0 then
                              declare
                                 Cand1 : constant String := TypeName & ".drop";
                              begin
                                 if M.Func_Names.Contains (Cand1) then
                                    DropFn := M.Func_Names.Element (Cand1);
                                 elsif M.Func_Names.Contains ("drop") then
                                    DropFn := M.Func_Names.Element ("drop");
                                 end if;
                              end;
                           end if;
                           -- Drop dispatch is handled by Op_Drop at runtime;
                           -- here we just mark the value for collection
                           null;
                        end;
                     end if;
                  end;
               end if;
            end loop;
         end if;
      end loop;
   end Run_Process_Drops;

   procedure Compact_Strings (M : in out Machine; P : Process_Access) is
      Map : Index_Array_Access := new Index_Array'(1 .. P.Str_Cap => 0);
      New_Top : Natural := 0;
      function Update_Str_Ref (W : TW) return TW is
         S : Natural;
      begin
         S := Str_Slot (P, W);
         if S > 0 and then Map (S) > 0 then
            return Str_Ptr (Map (S));
         end if;
         return W;
      end Update_Str_Ref;
   begin
      for I in 1 .. P.Str_Cap loop
         if P.String_Pool (I).In_Use then
            New_Top := New_Top + 1;
            Map (I) := New_Top;
         else
            Map (I) := 0;
         end if;
      end loop;
      if New_Top = 0 then
         return;
      end if;
      declare
         Already_Compact : Boolean := True;
      begin
         for I in 1 .. P.Str_Cap loop
            if P.String_Pool (I).In_Use and then Map (I) /= I then
               Already_Compact := False;
               exit;
            end if;
         end loop;
         if Already_Compact then
            return;
         end if;
      end;
      for I in 1 .. P.Str_Cap loop
         if Map (I) > 0 and then Map (I) /= I then
            P.String_Pool (Map (I)) := P.String_Pool (I);
            P.String_Pool (I).In_Use := False;
            P.String_Pool (I).Chars := Null_Unbounded_String;
         end if;
      end loop;
      for F in 1 .. P.Depth loop
         for I in 0 .. P.Frames (F).Reg_Count - 1 loop
            P.Stack (P.Frames (F).Base + I) := Update_Str_Ref (P.Stack (P.Frames (F).Base + I));
         end loop;
      end loop;
      for I in 0 .. P.Mail_Count - 1 loop
         declare
            Idx : constant Natural := ((P.Mail_Head + I) mod P.Mail.all'Length) + 1;
         begin
            P.Mail (Idx) := Update_Str_Ref (P.Mail (Idx));
         end;
      end loop;
      for O in 1 .. P.Obj_Cap loop
         if P.Object_Pool (O).In_Use and then P.Object_Pool (O).Fields /= null then
            for I in 1 .. P.Object_Pool (O).Count loop
               P.Object_Pool (O).Fields (I) := Update_Str_Ref (P.Object_Pool (O).Fields (I));
            end loop;
         end if;
      end loop;
      P.Result := Update_Str_Ref (P.Result);
      P.Str_Free_Top := 0;
      for I in reverse 1 .. P.Str_Cap loop
         if not P.String_Pool (I).In_Use then
            P.Str_Free_Top := P.Str_Free_Top + 1;
            P.Str_Free (P.Str_Free_Top) := I;
         end if;
      end loop;
      Free_Index (Map);
   end Compact_Strings;

   procedure Resize_Free (Free : in out Index_Array_Access; Top : Natural; New_Cap : Natural) is
      Fresh : constant Index_Array_Access := new Index_Array (1 .. New_Cap);
   begin
      if Free /= null then
         for I in 1 .. Top loop
            Fresh (I) := Free (I);
         end loop;
         Free_Index (Free);
      end if;
      Free := Fresh;
   end Resize_Free;

   procedure Grow_Str (P : Process_Access) is
      Old_Cap : constant Natural := P.Str_Cap;
      New_Cap : constant Natural := 2 * Old_Cap;
      Fresh   : constant Str_Pool_Access := new Str_Pool_Array (1 .. New_Cap);
   begin
      for I in 1 .. Old_Cap loop
         Fresh (I) := P.String_Pool (I);
      end loop;
      Free_Str_Pool (P.String_Pool);
      P.String_Pool := Fresh;
      P.Str_Cap := New_Cap;
      Resize_Free (P.Str_Free, P.Str_Free_Top, New_Cap);
      for I in reverse Old_Cap + 1 .. New_Cap loop
         P.Str_Free_Top := P.Str_Free_Top + 1;
         P.Str_Free (P.Str_Free_Top) := I;
      end loop;
   end Grow_Str;

   procedure Grow_Obj (P : Process_Access) is
      Old_Cap : constant Natural := P.Obj_Cap;
      New_Cap : constant Natural := 2 * Old_Cap;
      Fresh   : constant Obj_Pool_Access := new Obj_Pool_Array (1 .. New_Cap);
   begin
      for I in 1 .. Old_Cap loop
         Fresh (I) := P.Object_Pool (I);
      end loop;
      Free_Obj_Pool (P.Object_Pool);
      P.Object_Pool := Fresh;
      P.Obj_Cap := New_Cap;
      Resize_Free (P.Obj_Free, P.Obj_Free_Top, New_Cap);
      for I in reverse Old_Cap + 1 .. New_Cap loop
         P.Obj_Free_Top := P.Obj_Free_Top + 1;
         P.Obj_Free (P.Obj_Free_Top) := I;
      end loop;
   end Grow_Obj;

   procedure Grow_VT (P : Process_Access) is
      Old_Cap : constant Natural := P.VT_Cap;
      New_Cap : constant Natural := 2 * Old_Cap;
      Fresh   : constant VTable_Pool_Access := new VTable_Pool_Array (1 .. New_Cap);
   begin
      for I in 1 .. Old_Cap loop
         Fresh (I) := P.VTable_Pool (I);
      end loop;
      Free_VT_Pool (P.VTable_Pool);
      P.VTable_Pool := Fresh;
      P.VT_Cap := New_Cap;
      Resize_Free (P.VT_Free, P.VT_Free_Top, New_Cap);
      for I in reverse Old_Cap + 1 .. New_Cap loop
         P.VT_Free_Top := P.VT_Free_Top + 1;
         P.VT_Free (P.VT_Free_Top) := I;
      end loop;
   end Grow_VT;

   procedure Grow_Box (P : Process_Access) is
      Old_Cap : constant Natural := P.Box_Cap;
      New_Cap : constant Natural := 2 * Old_Cap;
      Fresh   : constant Box_Pool_Access := new Box_Pool_Array (1 .. New_Cap);
   begin
      for I in 1 .. Old_Cap loop
         Fresh (I) := P.Box_Pool (I);
      end loop;
      Free_Box_Pool (P.Box_Pool);
      P.Box_Pool := Fresh;
      P.Box_Cap := New_Cap;
      Resize_Free (P.Box_Free, P.Box_Free_Top, New_Cap);
      for I in reverse Old_Cap + 1 .. New_Cap loop
         P.Box_Free_Top := P.Box_Free_Top + 1;
         P.Box_Free (P.Box_Free_Top) := I;
      end loop;
   end Grow_Box;

   procedure Init_Heap (P : Process_Access) is
   begin
      P.String_Pool := new Str_Pool_Array (1 .. Pool_Size);
      P.Str_Cap := Pool_Size;
      P.Object_Pool := new Obj_Pool_Array (1 .. Object_Pool_Size);
      P.Obj_Cap := Object_Pool_Size;
      P.VTable_Pool := new VTable_Pool_Array (1 .. VTable_Pool_Size);
      P.VT_Cap := VTable_Pool_Size;
      P.Box_Pool := new Box_Pool_Array (1 .. Box_Pool_Size);
      P.Box_Cap := Box_Pool_Size;
      P.Str_Free := new Index_Array (1 .. Pool_Size);
      P.Obj_Free := new Index_Array (1 .. Object_Pool_Size);
      P.VT_Free := new Index_Array (1 .. VTable_Pool_Size);
      P.Box_Free := new Index_Array (1 .. Box_Pool_Size);
      for I in reverse 1 .. Pool_Size loop
         P.Str_Free_Top := P.Str_Free_Top + 1;
         P.Str_Free (P.Str_Free_Top) := I;
      end loop;
      for I in reverse 1 .. Object_Pool_Size loop
         P.Obj_Free_Top := P.Obj_Free_Top + 1;
         P.Obj_Free (P.Obj_Free_Top) := I;
      end loop;
      for I in reverse 1 .. VTable_Pool_Size loop
         P.VT_Free_Top := P.VT_Free_Top + 1;
         P.VT_Free (P.VT_Free_Top) := I;
      end loop;
      for I in reverse 1 .. Box_Pool_Size loop
         P.Box_Free_Top := P.Box_Free_Top + 1;
         P.Box_Free (P.Box_Free_Top) := I;
      end loop;
   end Init_Heap;

   function Alloc_Str (M : in out Machine; P : Process_Access) return Natural is
      S : Natural;
   begin
      if P.Str_Free_Top = 0 then
         Collect (M);
      end if;
      if P.Str_Free_Top = 0 then
         Grow_Str (P);
      end if;
      S := P.Str_Free (P.Str_Free_Top);
      P.Str_Free_Top := P.Str_Free_Top - 1;
      P.String_Pool (S).Chars := To_Unbounded_String ("");
      P.String_Pool (S).In_Use := True;
      P.String_Pool (S).Marked := False;
      P.String_Pool (S).Pinned := False;
      P.String_Pool (S).Large := False;
      P.String_Pool (S).Buf_Id := 0;
      P.String_Pool (S).Gen := M.GC_Generation;
      M.Allocations_Since_GC := M.Allocations_Since_GC + 1;
      if M.GC_Stress_Interval > 0 and then M.Allocations_Since_GC >= M.GC_Stress_Interval then
         Collect (M);
      end if;
      return S;
   end Alloc_Str;

   function Alloc_Large_Buffer (P : Process_Access) return Natural is
   begin
      for I in 1 .. 64 loop
         if not P.Large_Buffers (I).In_Use then
            P.Large_Buffers (I).In_Use := True;
            P.Large_Buffers (I).RefCnt := 1;
            P.Large_Buffers (I).Data := To_Unbounded_String ("");
            return I;
         end if;
      end loop;
      return 0;
   end Alloc_Large_Buffer;

   procedure Retain_Large_Buffer (P : Process_Access; Id : Natural) is
   begin
      if Id >= 1 and then Id <= 64 and then P.Large_Buffers (Id).In_Use then
         P.Large_Buffers (Id).RefCnt := P.Large_Buffers (Id).RefCnt + 1;
      end if;
   end Retain_Large_Buffer;

   procedure Release_Large_Buffer (P : Process_Access; Id : Natural) is
   begin
      if Id >= 1 and then Id <= 64 and then P.Large_Buffers (Id).In_Use then
         if P.Large_Buffers (Id).RefCnt > 0 then
            P.Large_Buffers (Id).RefCnt := P.Large_Buffers (Id).RefCnt - 1;
         end if;
         if P.Large_Buffers (Id).RefCnt = 0 then
            P.Large_Buffers (Id).In_Use := False;
            P.Large_Buffers (Id).Data := To_Unbounded_String ("");
         end if;
      end if;
   end Release_Large_Buffer;

   procedure Promote_To_Large (P : Process_Access; Slot : Natural) is
      L : Natural;
      Buf_Id : Natural;
   begin
      if P.String_Pool (Slot).Large then
         return;
      end if;
      L := Length (P.String_Pool (Slot).Chars);
      if L < Large_Buffer_Threshold then
         return;
      end if;
      Buf_Id := Alloc_Large_Buffer (P);
      if Buf_Id = 0 then
         return;
      end if;
      P.Large_Buffers (Buf_Id).Data := P.String_Pool (Slot).Chars;
      P.String_Pool (Slot).Large := True;
      P.String_Pool (Slot).Buf_Id := Buf_Id;
      P.String_Pool (Slot).Chars := To_Unbounded_String ("");
   end Promote_To_Large;

   function Alloc_Obj (M : in out Machine; P : Process_Access) return Natural is
      S : Natural;
   begin
      if P.Obj_Free_Top = 0 then
         Collect (M);
      end if;
      if P.Obj_Free_Top = 0 then
         Grow_Obj (P);
      end if;
      S := P.Obj_Free (P.Obj_Free_Top);
      P.Obj_Free_Top := P.Obj_Free_Top - 1;
      P.Object_Pool (S).Type_Name := To_Unbounded_String ("");
      P.Object_Pool (S).Drop := 0;
      P.Object_Pool (S).Count := 0;
      P.Object_Pool (S).Fields := null;
      P.Object_Pool (S).In_Use := True;
      P.Object_Pool (S).Marked := False;
      P.Object_Pool (S).Pinned := False;
      P.Object_Pool (S).Gen := M.GC_Generation;
      M.Allocations_Since_GC := M.Allocations_Since_GC + 1;
      if M.GC_Stress_Interval > 0 and then M.Allocations_Since_GC >= M.GC_Stress_Interval then
         Collect (M);
      end if;
      return S;
   end Alloc_Obj;

   function Alloc_VT (M : in out Machine; P : Process_Access) return Natural is
      S : Natural;
   begin
      --  Collect rebuilds the free list from scratch, so it's not refilled here.
      if P.VT_Free_Top = 0 then
         Collect (M);
         for I in 1 .. P.VT_Cap loop
            if not P.VTable_Pool (I).In_Use then
               P.VT_Free_Top := P.VT_Free_Top + 1;
               P.VT_Free (P.VT_Free_Top) := I;
            end if;
         end loop;
      end if;
      if P.VT_Free_Top = 0 then
         Collect (M);
         for I in 1 .. P.VT_Cap loop
            if not P.VTable_Pool (I).In_Use then
               P.VT_Free_Top := P.VT_Free_Top + 1;
               P.VT_Free (P.VT_Free_Top) := I;
            end if;
         end loop;
      end if;
      if P.VT_Free_Top = 0 then
         Grow_VT (P);
      end if;
      S := P.VT_Free (P.VT_Free_Top);
      P.VT_Free_Top := P.VT_Free_Top - 1;
      P.VTable_Pool (S).Methods := null;
      P.VTable_Pool (S).In_Use := True;
      P.VTable_Pool (S).Marked := False;
      M.Allocations_Since_GC := M.Allocations_Since_GC + 1;
      if M.GC_Stress_Interval > 0 and then M.Allocations_Since_GC >= M.GC_Stress_Interval then
         Collect (M);
      end if;
      return S;
   end Alloc_VT;

   function Alloc_Box (M : in out Machine; P : Process_Access) return Natural is
      S : Natural;
   begin
      --  Collect rebuilds the free list from scratch, so it's not refilled here.
      if P.Box_Free_Top = 0 then
         Collect (M);
         for I in 1 .. P.Box_Cap loop
            if not P.Box_Pool (I).In_Use then
               P.Box_Free_Top := P.Box_Free_Top + 1;
               P.Box_Free (P.Box_Free_Top) := I;
            end if;
         end loop;
      end if;
      if P.Box_Free_Top = 0 then
         Collect (M);
         for I in 1 .. P.Box_Cap loop
            if not P.Box_Pool (I).In_Use then
               P.Box_Free_Top := P.Box_Free_Top + 1;
               P.Box_Free (P.Box_Free_Top) := I;
            end if;
         end loop;
      end if;
      if P.Box_Free_Top = 0 then
         Grow_Box (P);
      end if;
      S := P.Box_Free (P.Box_Free_Top);
      P.Box_Free_Top := P.Box_Free_Top - 1;
      P.Box_Pool (S).Header := Lang.VM.Box_Header.Make (Lang.VM.Box_Header.Kind_Float64);
      P.Box_Pool (S).Value := 0;
      P.Box_Pool (S).In_Use := True;
      P.Box_Pool (S).Marked := False;
      P.Box_Pool (S).Gen := M.GC_Generation;
      M.Allocations_Since_GC := M.Allocations_Since_GC + 1;
      if M.GC_Stress_Interval > 0 and then M.Allocations_Since_GC >= M.GC_Stress_Interval then
         Collect (M);
      end if;
      return S;
   end Alloc_Box;

   function Make_Float (M : in out Machine; P : Process_Access; Value : Long_Float) return TW is
      Slot : constant Natural := Alloc_Box (M, P);
      function Cast is new Ada.Unchecked_Conversion (Long_Float, Interfaces.Unsigned_64);
   begin
      P.Box_Pool (Slot).Header := Lang.VM.Box_Header.Make (Lang.VM.Box_Header.Kind_Float64);
      P.Box_Pool (Slot).Value := Cast (Value);
      return Box_Ptr (Slot);
   end Make_Float;

   function Unbox_Float (P : Process_Access; W : TW) return Long_Float is
      B : constant Natural := Box_Slot (P, W);
      function Cast is new Ada.Unchecked_Conversion (Interfaces.Unsigned_64, Long_Float);
   begin
      if B = 0 then
         return 0.0;
      end if;
      return Cast (P.Box_Pool (B).Value);
   end Unbox_Float;



   function Make_Int (M : in out Machine; P : Process_Access; Value : Interfaces.Integer_64) return TW is
      Slot : Natural;
      function Cast is new Ada.Unchecked_Conversion (Interfaces.Integer_64, Interfaces.Unsigned_64);
   begin
      if Value >= -2 ** 60 and then Value <= 2 ** 60 - 1 then
         return Make_Small_Int (Value);
      end if;
      Slot := Alloc_Box (M, P);
      P.Box_Pool (Slot).Header := Lang.VM.Box_Header.Make (Lang.VM.Box_Header.Kind_Int64);
      P.Box_Pool (Slot).Value := Cast (Value);
      return Box_Ptr (Slot);
   end Make_Int;

   function Unbox_Int (P : Process_Access; W : TW) return Interfaces.Integer_64 is
      B : constant Natural := Box_Slot (P, W);
      function Cast is new Ada.Unchecked_Conversion (Interfaces.Unsigned_64, Interfaces.Integer_64);
   begin
      if Is_Small_Int (W) then
         return Unbox_Small_Int (W);
      end if;
      if B > 0 and then Lang.VM.Box_Header.Kind_Of (P.Box_Pool (B).Header) = Lang.VM.Box_Header.Kind_Int64 then
         return Cast (P.Box_Pool (B).Value);
      end if;
      return 0;
   end Unbox_Int;

   function Is_Int_Box (P : Process_Access; W : TW) return Boolean is
      B : constant Natural := Box_Slot (P, W);
   begin
      return B > 0 and then Lang.VM.Box_Header.Kind_Of (P.Box_Pool (B).Header) = Lang.VM.Box_Header.Kind_Int64;
   end Is_Int_Box;

   function Is_Float_Box (P : Process_Access; W : TW) return Boolean is
      B : constant Natural := Box_Slot (P, W);
   begin
      return B > 0 and then Lang.VM.Box_Header.Kind_Of (P.Box_Pool (B).Header) = Lang.VM.Box_Header.Kind_Float64;
   end Is_Float_Box;

   function Is_Int_Like (P : Process_Access; W : TW) return Boolean is
   begin
      return Is_Small_Int (W) or else Is_Int_Box (P, W);
   end Is_Int_Like;

   function To_U64 is new Ada.Unchecked_Conversion (Interfaces.Integer_64, Interfaces.Unsigned_64);
   function To_I64 is new Ada.Unchecked_Conversion (Interfaces.Unsigned_64, Interfaces.Integer_64);

   -- wrapping is done on the modular rype, so nothing depends on runtime overflow checks
   function Checked_Add (A, B : Interfaces.Integer_64) return Interfaces.Integer_64 is
      R : constant Interfaces.Integer_64 := To_I64 (To_U64 (A) + To_U64 (B));
   begin
      if (B > 0 and then R < A) or else (B < 0 and then R > A) then
         raise Constraint_Error with "integer overflow in add";
      end if;
      return R;
   end Checked_Add;

   function Checked_Sub (A, B : Interfaces.Integer_64) return Interfaces.Integer_64 is
      R : constant Interfaces.Integer_64 := To_I64 (To_U64 (A) - To_U64 (B));
   begin
      if (B < 0 and then R < A) or else (B > 0 and then R > A) then
         raise Constraint_Error with "integer overflow in subtract";
      end if;
      return R;
   end Checked_Sub;

   function Checked_Mul (A, B : Interfaces.Integer_64) return Interfaces.Integer_64 is
      R : constant Interfaces.Integer_64 := To_I64 (To_U64 (A) * To_U64 (B));
   begin
      if (A = -1 and then B = Interfaces.Integer_64'First)
        or else (B = -1 and then A = Interfaces.Integer_64'First)
        or else (A /= 0 and then R / A /= B)
      then
         raise Constraint_Error with "integer overflow in multiply";
      end if;
      return R;
   end Checked_Mul;

   function Checked_Div (A, B : Interfaces.Integer_64) return Interfaces.Integer_64 is
   begin
      if B = 0 then
         raise Constraint_Error with "division by zero";
      end if;
      if B = -1 and then A = Interfaces.Integer_64'First then
         raise Constraint_Error with "integer overflow in divide";
      end if;
      return A / B;
   end Checked_Div;

   function Checked_Rem (A, B : Interfaces.Integer_64) return Interfaces.Integer_64 is
   begin
      if B = 0 then
         raise Constraint_Error with "modulus by zero";
      end if;
      if B = -1 then
         return 0;   --  avoids the idiv trap on First rem -1
      end if;
      return A rem B;
   end Checked_Rem;

   function Deep_Copy (M : in out Machine; SrcP, DstP : Process_Access; W : TW) return TW is
      S  : Natural;
      O  : Natural;
      Slot : Natural;
      VIdx : Natural;
      DSlot : Natural;
   begin
      DstP.Deep_Copy_In_Progress := True;
      begin
         if not Is_Heap_Pointer (W) then
            DstP.Deep_Copy_In_Progress := False;
            return W;
         end if;
      S := Str_Slot (SrcP, W);
      if S > 0 then
         Slot := Alloc_Str (M, DstP);
         DstP.String_Pool (Slot).Chars := SrcP.String_Pool (S).Chars;
         DstP.String_Pool (Slot).Pinned := SrcP.String_Pool (S).Pinned;
         return Str_Ptr (Slot);
      end if;
      O := Obj_Slot (SrcP, W);
      if O > 0 then
         declare
            SrcObj : Obj_Entry renames SrcP.Object_Pool (O);
            Count  : constant Natural := SrcObj.Count;
            F      : Value_Array_Access := null;
         begin
            Slot := Alloc_Obj (M, DstP);
            DstP.Object_Pool (Slot).Pinned := True;
            DstP.Object_Pool (Slot).Type_Name := SrcObj.Type_Name;
            DstP.Object_Pool (Slot).Drop := SrcObj.Drop;
            DstP.Object_Pool (Slot).Count := Count;
            if Count > 0 then
               F := new Value_Array (1 .. Count);
               DstP.Object_Pool (Slot).Fields := F;
               for I in 1 .. Count loop
                  F (I) := Deep_Copy (M, SrcP, DstP, SrcObj.Fields (I));
               end loop;
               if Count >= 2 and then Is_Small_Int (SrcObj.Fields (2)) then
                  VIdx := Natural (Unbox_Small_Int (SrcObj.Fields (2)));
                  if VIdx >= 1 and then VIdx <= SrcP.VT_Cap and then SrcP.VTable_Pool (VIdx).In_Use then
                     DSlot := Alloc_VT (M, DstP);
                     if SrcP.VTable_Pool (VIdx).Methods /= null then
                        declare
                           N : constant Natural := SrcP.VTable_Pool (VIdx).Methods.all'Length;
                           MArr : VC.Natural_Array_Access := new VC.Natural_Array (1 .. N);
                        begin
                           MArr (1 .. N) := SrcP.VTable_Pool (VIdx).Methods (1 .. N);
                           DstP.VTable_Pool (DSlot).Methods := MArr;
                        end;
                     end if;
                     F (2) := Make_Small_Int (Integer_64 (DSlot));
                  end if;
               end if;
            end if;
            DstP.Object_Pool (Slot).Pinned := False;
            return Obj_Ptr (Slot);
         end;
      end if;
      declare
         B : constant Natural := Box_Slot (SrcP, W);
      begin
         if B > 0 then
            declare
               Slot : constant Natural := Alloc_Box (M, DstP);
            begin
               DstP.Box_Pool (Slot).Header := SrcP.Box_Pool (B).Header;
               DstP.Box_Pool (Slot).Value := SrcP.Box_Pool (B).Value;
               return Box_Ptr (Slot);
            end;
         end if;
      end;  -- declare box
      end;  -- inner begin
      DstP.Deep_Copy_In_Progress := False;
      return W;
   end Deep_Copy;

   procedure Mail_Push (P : Process_Access; W : TW) is
      Cap : constant Natural := P.Mail.all'Length;
   begin
      if P.Mail_Count = Cap then
         declare
            Bigger : constant Value_Array_Access := new Value_Array (1 .. 2 * Cap);
         begin
            for I in 0 .. P.Mail_Count - 1 loop
               Bigger (I + 1) := P.Mail (((P.Mail_Head + I) mod Cap) + 1);
            end loop;
            Free_Values (P.Mail);
            P.Mail := Bigger;
            P.Mail_Head := 0;
         end;
      end if;
      P.Mail (((P.Mail_Head + P.Mail_Count) mod P.Mail.all'Length) + 1) := W;
      P.Mail_Count := P.Mail_Count + 1;
   end Mail_Push;

   function Mail_Pop (P : Process_Access) return TW is
      W : constant TW := P.Mail (P.Mail_Head + 1);
   begin
      P.Mail_Head := P.Mail_Head + 1;
      if P.Mail_Head >= P.Mail.all'Length then
         P.Mail_Head := 0;
      end if;
      P.Mail_Count := P.Mail_Count - 1;
      if P.Mail_Count > 0 and then P.Mail.all'Length > 8
        and then P.Mail_Count * 4 <= P.Mail.all'Length
      then
         declare
            New_Cap : constant Natural := Natural'Max (8, 2 * P.Mail_Count);
            Smaller : constant Value_Array_Access := new Value_Array (1 .. New_Cap);
         begin
            for I in 0 .. P.Mail_Count - 1 loop
               Smaller (I + 1) := P.Mail (((P.Mail_Head + I) mod P.Mail.all'Length) + 1);
            end loop;
            Free_Values (P.Mail);
            P.Mail := Smaller;
            P.Mail_Head := 0;
         end;
      end if;
      return W;
   end Mail_Pop;

   procedure Push_Frame (M       : in out Machine;
                         P        : Process_Access;
                         Fn_Index : Natural;
                         Extent   : Natural;
                         Has_Ret  : Boolean;
                         Ret_Dest : Natural;
                         Base     : out Natural) is
   begin
      if P.Depth = P.Frames.all'Length then
         declare
            Old_Len : constant Natural := P.Frames.all'Length;
            Bigger  : constant Frame_Array_Access := new Frame_Array (1 .. 2 * Old_Len);
         begin
            Bigger (1 .. P.Depth) := P.Frames (1 .. P.Depth);
            Free_Frames (P.Frames);
            P.Frames := Bigger;
         end;
      end if;

      Base := P.Sp;
      if Base + Extent - 1 > P.Stack.all'Length then
         declare
            Old_Len  : constant Natural := P.Stack.all'Length;
            New_Size : constant Natural := Natural'Max (2 * Old_Len, Base + Extent - 1);
            Bigger   : constant Value_Array_Access := new Value_Array (1 .. New_Size);
         begin
            Bigger (1 .. Old_Len) := P.Stack.all;
            Free_Values (P.Stack);
            P.Stack := Bigger;
         end;
      end if;

      for I in Base .. Base + Extent - 1 loop
         P.Stack (I) := Zero;
      end loop;

      P.Depth := P.Depth + 1;
      P.Frames (P.Depth) := (Func      => Fn_Index,
                             Pc        => 1,
                             Base      => Base,
                             Reg_Count => Extent,
                             Ret_Dest  => Ret_Dest,
                             Has_Ret   => Has_Ret,
                             Owned_Mask => M.Prog.Funcs (Fn_Index).Owned_Mask);
      P.Sp := Base + Extent;
   end Push_Frame;
   function Func_Index (M : Machine; Name : String) return Natural is
   begin
      if M.Func_Names.Contains (Name) then
         return M.Func_Names.Element (Name);
      end if;
      return 0;
   end Func_Index;

   function Find_Process (M : Machine; Pid : Natural) return Process_Access is
   begin
      if Pid >= 1 and then Pid <= Natural (M.Pid_To_Idx.Length) then
         declare
            Idx : constant Natural := M.Pid_To_Idx (Pid);
         begin
            if Idx >= 1 and then Idx <= Natural (M.Processes.Length) then
               return M.Processes (Idx);
            end if;
         end;
      end if;
      return null;
   end Find_Process;

   procedure Ensure_Compiled (M : in out Machine) is
      N : Natural;
   begin
      if M.Compiled then
         return;
      end if;
      M.Prog := VC.Compile (M.Modu);
      for I in 1 .. Natural (M.Modu.Funcs.Length) loop
         M.Func_Names.Insert (To_String (M.Modu.Funcs (I).Name), I);
      end loop;
      M.Compiled := True;
   end Ensure_Compiled;

   procedure Create_Process (M : in out Machine; CI : Natural; New_Pid : out Natural) is
      P    : constant Process_Access := new Process;
      Base : Natural;
   begin
      New_Pid := M.Next_Pid;
      M.Next_Pid := M.Next_Pid + 1;
      P.Id := New_Pid;
      P.Frames := new Frame_Array (1 .. 16);
      P.Stack := new Value_Array (1 .. 256);
      P.Mail := new Value_Array (1 .. 8);
      P.Large_Buffers := new Large_Buffer_Array;
      Init_Heap (P);
      if CI > 0 then
         Push_Frame (M, P, CI, M.Prog.Funcs (CI).Frame_Size, False, 0, Base);
      end if;
      M.Processes.Append (P);
      while Natural (M.Pid_To_Idx.Length) < New_Pid loop
         M.Pid_To_Idx.Append (0);
      end loop;
      M.Pid_To_Idx (New_Pid) := Natural (M.Processes.Length);
   end Create_Process;

   procedure Spawn_Process (M : in out Machine; Func_Name : String; New_Pid : out Natural) is
   begin
      Ensure_Compiled (M);
      Create_Process (M, Func_Index (M, Func_Name), New_Pid);
   end Spawn_Process;

   function Last_Result (M : Machine) return TW is
   begin
      if M.Processes.Is_Empty then
         return Make_Small_Int (0);
      end if;
      return M.Processes.First_Element.Result;
   end Last_Result;
   function Ffi_Address (Name : String) return System.Address is
   begin
      return Lang.VM.Platform.Resolve_Symbol (Name);
   end Ffi_Address;

   procedure Run_Builtin (M    : in out Machine;
                          P    : Process_Access;
                          Base : Natural;
                          Ins  : VC.Code_Instr) is
      function Arg (I : Positive) return TW is
      begin
         return P.Stack (Base + M.Prog.Args (Ins.Args_First + I - 1));
      end Arg;

      procedure Set_Dest (W : TW) is
      begin
         P.Stack (Base + Ins.Dest) := W;
      end Set_Dest;
   begin
      case Ins.Builtin is
         when VC.Bi_Puts =>
            if Ins.Args_Count >= 1 then
               declare
                  V : constant TW := Arg (1);
               begin
                  if Is_Heap_Pointer (V) then
                     Put_Line (To_String (Chars_Of (P, V)));
                  elsif V = Make_None then
                     Put_Line ("none");
                  elsif V = Make_None then
                     Put_Line ("none");
                  else
                     Put_Line (Integer'Image (Integer (Unbox_Small_Int (V))));
                  end if;
               end;
            end if;
            if Ins.Has_Dest then
               Set_Dest (Zero);
            end if;

         when VC.Bi_Concat =>
            if Ins.Args_Count >= 2 then
               declare
                  A    : constant Unbounded_String := Chars_Of (P, Arg (1));
                  B    : constant Unbounded_String := Chars_Of (P, Arg (2));
                  Slot : constant Natural := Alloc_Str (M, P);
               begin
                  P.String_Pool (Slot).Chars := A & B;
                  Promote_To_Large (P, Slot);
                  if Ins.Has_Dest then
                     Set_Dest (Str_Ptr (Slot));
                  end if;
               end;
            end if;

         when VC.Bi_Len =>
            if Ins.Args_Count >= 1 then
               declare
                  S : constant Natural := Str_Slot (P, Arg (1));
                  L : constant Natural := (if S > 0 then Length (P.String_Pool (S).Chars) else 0);
               begin
                  if Ins.Has_Dest then
                     Set_Dest (Make_Small_Int (Integer_64 (L)));
                  end if;
               end;
            end if;

         when VC.Bi_Int_To_String =>
            if Ins.Args_Count >= 1 then
               declare
                  Img  : constant String :=
                    (if Arg (1) = Make_None then "none"
                     else Ada.Strings.Fixed.Trim (Integer_64'Image (Unbox_Small_Int (Arg (1))),
                                                  Ada.Strings.Left));
                  Slot : constant Natural := Alloc_Str (M, P);
               begin
                  P.String_Pool (Slot).Chars := To_Unbounded_String (Img);
                  Promote_To_Large (P, Slot);
                  if Ins.Has_Dest then
                     Set_Dest (Str_Ptr (Slot));
                  end if;
               end;
            end if;

         when VC.Bi_List_Append =>
            if Ins.Args_Count >= 2 then
               declare
                  L : constant TW := Arg (1);
                  V : constant TW := Arg (2);
                  O : constant Natural := Obj_Slot (P, L);
               begin
                  if O > 0 then
                     declare
                        Old_Count : constant Natural := P.Object_Pool (O).Count;
                        Cap       : constant Natural :=
                          (if P.Object_Pool (O).Fields = null then 0 else P.Object_Pool (O).Fields.all'Length);
                     begin
                        if Old_Count >= Cap then
                           declare
                              New_Cap : constant Natural := Natural'Max (4, 2 * Old_Count);
                              F       : constant Value_Array_Access := new Value_Array (1 .. New_Cap);
                           begin
                              if Old_Count > 0 then
                                 F (1 .. Old_Count) := P.Object_Pool (O).Fields (1 .. Old_Count);
                              end if;
                              if P.Object_Pool (O).Fields /= null then
                                 Free_Values (P.Object_Pool (O).Fields);
                              end if;
                              P.Object_Pool (O).Fields := F;
                           end;
                        end if;
                        P.Object_Pool (O).Fields (Old_Count + 1) := V;
                        P.Object_Pool (O).Count := Old_Count + 1;
                        if Ins.Has_Dest then
                           Set_Dest (L);
                        end if;
                     end;
                  end if;
               end;
            end if;

         when VC.Bi_List_Pop =>
            if Ins.Args_Count >= 1 then
               declare
                  L : constant TW := Arg (1);
                  O : constant Natural := Obj_Slot (P, L);
               begin
                  if O > 0 and then P.Object_Pool (O).Count > 0 then
                     declare
                        N : constant Natural := P.Object_Pool (O).Count;
                        V : constant TW := P.Object_Pool (O).Fields (N);
                     begin
                        P.Object_Pool (O).Fields (N) := Make_None;
                        P.Object_Pool (O).Count := N - 1;
                        if Ins.Has_Dest then
                           Set_Dest (V);
                        end if;
                     end;
                  elsif Ins.Has_Dest then
                     Set_Dest (Make_None);
                  end if;
               end;
            end if;

         when VC.Bi_List_Set =>
            if Ins.Args_Count >= 3 then
               declare
                  L : constant TW := Arg (1);
                  I : constant Integer_64 := Unbox_Small_Int (Arg (2));
                  V : constant TW := Arg (3);
                  O : constant Natural := Obj_Slot (P, L);
               begin
                  if O > 0 and then I >= 0 and then I < Integer_64 (P.Object_Pool (O).Count) then
                     P.Object_Pool (O).Fields (Natural (I) + 1) := V;
                  else
                     raise Constraint_Error with "list index " & Index_Text (I) & " out of range";
                  end if;
                  if Ins.Has_Dest then
                     Set_Dest (Make_Unit);
                  end if;
               end;
            end if;

         when VC.Bi_List_Get =>
            if Ins.Args_Count >= 2 then
               declare
                  L : constant TW := Arg (1);
                  I : constant Integer_64 := Unbox_Small_Int (Arg (2));
                  O : constant Natural := Obj_Slot (P, L);
               begin
                  if O > 0 and then I >= 0 and then I < Integer_64 (P.Object_Pool (O).Count) then
                     if Ins.Has_Dest then
                        Set_Dest (P.Object_Pool (O).Fields (Natural (I) + 1));
                     end if;
                  else
                     raise Constraint_Error with "list index " & Index_Text (I) & " out of range";
                  end if;
               end;
            end if;

         when VC.Bi_List_Len =>
            if Ins.Args_Count >= 1 then
               declare
                  L : constant TW := Arg (1);
                  O : constant Natural := Obj_Slot (P, L);
                  Len : constant Integer_64 := (if O > 0 then Integer_64 (P.Object_Pool (O).Count) else 0);
               begin
                  if Ins.Has_Dest then
                     Set_Dest (Make_Small_Int (Len));
                  end if;
               end;
            end if;

         when VC.Bi_String_Get =>
            if Ins.Args_Count >= 2 then
               declare
                  S : constant Natural := Str_Slot (P, Arg (1));
                  I : constant Integer_64 := Unbox_Small_Int (Arg (2));
                  L : constant Natural := (if S > 0 then Length (P.String_Pool (S).Chars) else 0);
               begin
                  if S > 0 and then I >= 0 and then I < Integer_64 (L) then
                     if Ins.Has_Dest then
                        Set_Dest (Make_Small_Int (Integer_64 (Character'Pos (Element (P.String_Pool (S).Chars, Natural (I) + 1)))));
                     end if;
                  else
                     raise Constraint_Error with "text index " & Index_Text (I) & " out of range";
                  end if;
               end;
            end if;

         when VC.Bi_String_Slice =>
            if Ins.Args_Count >= 3 then
               declare
                  S : constant Natural := Str_Slot (P, Arg (1));
                  Start : constant Integer_64 := Unbox_Small_Int (Arg (2));
                  Finish : constant Integer_64 := Unbox_Small_Int (Arg (3));
                  Src : constant Unbounded_String := (if S > 0 then P.String_Pool (S).Chars else To_Unbounded_String (""));
                  L : constant Natural := Length (Src);
                  Lo : constant Natural := Natural'Min (L, Natural'Max (0, Integer (Start)));
                  Hi : constant Natural := Natural'Min (L, Natural'Max (Lo, Integer (Finish)));
                  Slot : constant Natural := Alloc_Str (M, P);
               begin
                  P.String_Pool (Slot).Chars := Unbounded_Slice (Src, Lo + 1, Hi);
                  Promote_To_Large (P, Slot);
                  if Ins.Has_Dest then
                     Set_Dest (Str_Ptr (Slot));
                  end if;
               end;
            end if;

         when VC.Bi_Read_Line =>
            declare
               Line : String := Get_Line;
               Slot : constant Natural := Alloc_Str (M, P);
            begin
               P.String_Pool (Slot).Chars := To_Unbounded_String (Line);
               if Ins.Has_Dest then
                  Set_Dest (Str_Ptr (Slot));
               end if;
            end;

         when VC.Bi_Read_Int =>
            declare
               Line : constant String := Get_Line;
               Val  : Integer_64;
            begin
               Val := Integer_64'Value (Ada.Strings.Fixed.Trim (Line, Ada.Strings.Both));
               if Ins.Has_Dest then
                  Set_Dest (Make_Small_Int (Val));
               end if;
            exception
               when others =>
                  if Ins.Has_Dest then
                     Set_Dest (Zero);
                  end if;
            end;

         when VC.Bi_Bit_And =>
            declare
               A : constant Interfaces.Integer_64 := Unbox_Int (P, Arg (1));
               B : constant Interfaces.Integer_64 := Unbox_Int (P, Arg (2));
            begin
               if Ins.Has_Dest then
                  Set_Dest (Make_Int (M, P, Interfaces.Integer_64 (Interfaces.Unsigned_64 (A) and Interfaces.Unsigned_64 (B))));
               end if;
            end;
         when VC.Bi_Bit_Or =>
            declare
               A : constant Interfaces.Integer_64 := Unbox_Int (P, Arg (1));
               B : constant Interfaces.Integer_64 := Unbox_Int (P, Arg (2));
            begin
               if Ins.Has_Dest then
                  Set_Dest (Make_Int (M, P, Interfaces.Integer_64 (Interfaces.Unsigned_64 (A) or Interfaces.Unsigned_64 (B))));
               end if;
            end;
         when VC.Bi_Bit_Xor =>
            declare
               A : constant Interfaces.Integer_64 := Unbox_Int (P, Arg (1));
               B : constant Interfaces.Integer_64 := Unbox_Int (P, Arg (2));
            begin
               if Ins.Has_Dest then
                  Set_Dest (Make_Int (M, P, Interfaces.Integer_64 (Interfaces.Unsigned_64 (A) xor Interfaces.Unsigned_64 (B))));
               end if;
            end;
         when VC.Bi_Bit_Not =>
            declare
               A : constant Interfaces.Integer_64 := Unbox_Int (P, Arg (1));
            begin
               if Ins.Has_Dest then
                  Set_Dest (Make_Int (M, P, Interfaces.Integer_64 (not Interfaces.Unsigned_64 (A))));
               end if;
            end;
         when VC.Bi_Bit_Shl =>
            declare
               A : constant Interfaces.Integer_64 := Unbox_Int (P, Arg (1));
               B : constant Natural := Natural (Unbox_Int (P, Arg (2)));
            begin
               if Ins.Has_Dest then
                  if B >= 64 then
                     Set_Dest (Make_Int (M, P, 0));
                  else
                     Set_Dest (Make_Int (M, P, Interfaces.Integer_64 (Interfaces.Shift_Left (Interfaces.Unsigned_64 (A), B))));
                  end if;
               end if;
            end;
         when VC.Bi_Float_From_Int =>
            if Ins.Args_Count >= 1 then
               Set_Dest (Make_Float (M, P, Long_Float (Unbox_Int (P, Arg (1)))));
            end if;

         when VC.Bi_Read_File =>
            declare
               Name    : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               Content : Unbounded_String := To_Unbounded_String ("");
               SF      : Ada.Streams.Stream_IO.File_Type;
               Slot    : Natural;
            begin
               begin
                  Ada.Streams.Stream_IO.Open (SF, Ada.Streams.Stream_IO.In_File, Name);
                  declare
                     Size : constant Natural := Natural (Ada.Streams.Stream_IO.Size (SF));
                     Buf  : Ada.Streams.Stream_Element_Array
                              (1 .. Ada.Streams.Stream_Element_Offset (Size));
                     Last : Ada.Streams.Stream_Element_Offset;
                  begin
                     Ada.Streams.Stream_IO.Read (SF, Buf, Last);
                     for I in 1 .. Last loop
                        Append (Content, Character'Val (Integer (Buf (I))));
                     end loop;
                  end;
                  Ada.Streams.Stream_IO.Close (SF);
               exception
                  when others =>
                     Put_Line (Standard_Error, "cannot read file: " & Name);
               end;
               Slot := Alloc_Str (M, P);
               P.String_Pool (Slot).Chars := Content;
               Promote_To_Large (P, Slot);
               if Ins.Has_Dest then
                  Set_Dest (Str_Ptr (Slot));
               end if;
            end;

         when VC.Bi_Err_Puts =>
            if Ins.Args_Count >= 1 then
               declare
                  V   : constant TW := Arg (1);
                  Msg : constant String :=
                    (if Is_Heap_Pointer (V) then To_String (Chars_Of (P, V))
                     elsif V = Make_None then "none"
                     elsif V = Make_None then "none"
                     else Integer'Image (Integer (Unbox_Small_Int (V))));
               begin
                  Flush (Standard_Output);
                  Put_Line (Standard_Error, Msg);
                  Flush (Standard_Error);
               end;
            end if;
            if Ins.Has_Dest then
               Set_Dest (Zero);
            end if;

         when VC.Bi_Float_To_String =>
            if Ins.Args_Count >= 1 then
               declare
                  Img  : constant String :=
                    (if Arg (1) = Make_None then "none"
                     else Format_Decimal (Unbox_Float (P, Arg (1))));
                  Slot : constant Natural := Alloc_Str (M, P);
               begin
                  P.String_Pool (Slot).Chars := To_Unbounded_String (Img);
                  Promote_To_Large (P, Slot);
                  if Ins.Has_Dest then
                     Set_Dest (Str_Ptr (Slot));
                  end if;
               end;
            end if;

         when VC.Bi_Bit_Shr =>
            declare
               A : constant Interfaces.Integer_64 := Unbox_Int (P, Arg (1));
               B : constant Natural := Natural (Unbox_Int (P, Arg (2)));
            begin
               if Ins.Has_Dest then
                  if B >= 64 then
                     Set_Dest (Make_Int (M, P, 0));
                  else
                     Set_Dest (Make_Int (M, P, Interfaces.Integer_64 (Interfaces.Shift_Right_Arithmetic (Interfaces.Unsigned_64 (A), B))));
                  end if;
               end if;
            end;
         when VC.Bi_Text_Hash =>
            if Ins.Args_Count >= 1 then
               declare
                  S : constant Natural := Str_Slot (P, Arg (1));
                  H : Integer_64 := 7;
               begin
                  if S > 0 then
                     for I in 1 .. Length (P.String_Pool (S).Chars) loop
                        H := (H * 31 + Integer_64 (Character'Pos (Element (P.String_Pool (S).Chars, I))))
                             mod 1_000_000_007;
                     end loop;
                  end if;
                  if Ins.Has_Dest then
                     Set_Dest (Make_Small_Int (H));
                  end if;
               end;
            end if;

         when VC.Bi_String_Compare =>
            if Ins.Args_Count >= 2 then
               declare
                  A : constant String := To_String (Chars_Of (P, Arg (1)));
                  B : constant String := To_String (Chars_Of (P, Arg (2)));
                  R : Integer_64 := 0;
               begin
                  if A < B then
                     R := -1;
                  elsif A > B then
                     R := 1;
                  end if;
                  if Ins.Has_Dest then
                     Set_Dest (Make_Small_Int (R));
                  end if;
               end;
            end if;

         when VC.Bi_String_From_Code =>
            if Ins.Args_Count >= 1 then
               declare
                  N    : constant Integer_64 := Unbox_Int (P, Arg (1));
                  Img  : constant String :=
                    (if N >= 0 and then N <= 255 then (1 => Character'Val (Integer (N))) else "");
                  Slot : constant Natural := Alloc_Str (M, P);
               begin
                  P.String_Pool (Slot).Chars := To_Unbounded_String (Img);
                  Promote_To_Large (P, Slot);
                  if Ins.Has_Dest then
                     Set_Dest (Str_Ptr (Slot));
                  end if;
               end;
            end if;

         when VC.Bi_String_Upper | VC.Bi_String_Lower =>
            if Ins.Args_Count >= 1 then
               declare
                  Src  : constant String := To_String (Chars_Of (P, Arg (1)));
                  Img  : String := Src;
                  Slot : constant Natural := Alloc_Str (M, P);
               begin
                  for I in Img'Range loop
                     if Ins.Builtin = VC.Bi_String_Upper then
                        Img (I) := Ada.Characters.Handling.To_Upper (Img (I));
                     else
                        Img (I) := Ada.Characters.Handling.To_Lower (Img (I));
                     end if;
                  end loop;
                  P.String_Pool (Slot).Chars := To_Unbounded_String (Img);
                  Promote_To_Large (P, Slot);
                  if Ins.Has_Dest then
                     Set_Dest (Str_Ptr (Slot));
                  end if;
               end;
            end if;

         when VC.Bi_Float_Parse =>
            declare
               Src : constant String :=
                 Ada.Strings.Fixed.Trim (To_String (Chars_Of (P, Arg (1))), Ada.Strings.Both);
               V   : Long_Float;
            begin
               V := Long_Float'Value (Src);
               if Ins.Has_Dest then
                  Set_Dest (Make_Float (M, P, V));
               end if;
            exception
               when others =>
                  if Ins.Has_Dest then
                     Set_Dest (Make_Float (M, P, 0.0));
                  end if;
            end;

         when VC.Bi_Float_Sqrt | VC.Bi_Float_Exp | VC.Bi_Float_Ln | VC.Bi_Float_Sin |
              VC.Bi_Float_Cos | VC.Bi_Float_Tan | VC.Bi_Float_Atan | VC.Bi_Float_Floor |
              VC.Bi_Float_Ceil | VC.Bi_Float_Round | VC.Bi_Float_Trunc =>
            if Ins.Args_Count >= 1 then
               declare
                  X : constant Long_Float := Unbox_Float (P, Arg (1));
                  R : Long_Float;
               begin
                  case Ins.Builtin is
                     when VC.Bi_Float_Sqrt  => R := Ada.Numerics.Long_Elementary_Functions.Sqrt (X);
                     when VC.Bi_Float_Exp   => R := Ada.Numerics.Long_Elementary_Functions.Exp (X);
                     when VC.Bi_Float_Ln    => R := Ada.Numerics.Long_Elementary_Functions.Log (X);
                     when VC.Bi_Float_Sin   => R := Ada.Numerics.Long_Elementary_Functions.Sin (X);
                     when VC.Bi_Float_Cos   => R := Ada.Numerics.Long_Elementary_Functions.Cos (X);
                     when VC.Bi_Float_Tan   => R := Ada.Numerics.Long_Elementary_Functions.Tan (X);
                     when VC.Bi_Float_Atan  => R := Ada.Numerics.Long_Elementary_Functions.Arctan (X);
                     when VC.Bi_Float_Floor => R := Long_Float'Floor (X);
                     when VC.Bi_Float_Ceil  => R := Long_Float'Ceiling (X);
                     when VC.Bi_Float_Round =>
                        R := Long_Float'Rounding (X);
                     when others            => R := Long_Float'Truncation (X);
                  end case;
                  if Ins.Has_Dest then
                     Set_Dest (Make_Float (M, P, R));
                  end if;
               exception
                  when others =>
                     if Ins.Has_Dest then
                        Set_Dest (Make_Float (M, P, 0.0));
                     end if;
               end;
            end if;

         when VC.Bi_Float_Pow | VC.Bi_Float_Atan2 =>
            if Ins.Args_Count >= 2 then
               declare
                  X : constant Long_Float := Unbox_Float (P, Arg (1));
                  Y : constant Long_Float := Unbox_Float (P, Arg (2));
                  R : Long_Float;
               begin
                  if Ins.Builtin = VC.Bi_Float_Pow then
                     R := Ada.Numerics.Long_Elementary_Functions."**" (X, Y);
                  else
                     R := Ada.Numerics.Long_Elementary_Functions.Arctan (Y, X);
                  end if;
                  if Ins.Has_Dest then
                     Set_Dest (Make_Float (M, P, R));
                  end if;
               exception
                  when others =>
                     if Ins.Has_Dest then
                        Set_Dest (Make_Float (M, P, 0.0));
                     end if;
               end;
            end if;

         when VC.Bi_Float_To_Int =>
            if Ins.Args_Count >= 1 then
               declare
                  X : constant Long_Float := Unbox_Float (P, Arg (1));
               begin
                  if Ins.Has_Dest then
                     Set_Dest (Make_Small_Int (Integer_64 (Long_Float'Truncation (X))));
                  end if;
               exception
                  when others =>
                     if Ins.Has_Dest then
                        Set_Dest (Zero);
                     end if;
               end;
            end if;

         

         when VC.Bi_Clock_Mono_Ms =>
            if Ins.Has_Dest then
               declare
                  Span : constant Ada.Real_Time.Time_Span :=
                    Ada.Real_Time."-" (Ada.Real_Time.Clock, Mono_Epoch);
               begin
                  Set_Dest (Make_Small_Int (Integer_64 (
                    Long_Float (Ada.Real_Time.To_Duration (Span)) * 1000.0)));
               end;
            end if;

         when VC.Bi_Clock_Sleep_Ms =>
            declare
               Ms : constant Integer_64 := Unbox_Int (P, Arg (1));
            begin
               if Ms > 0 then
                  delay Duration (Long_Float (Ms) / 1000.0);
               end if;
               if Ins.Has_Dest then
                  Set_Dest (Make_Unit);
               end if;
            end;

         when VC.Bi_Char_To_Text =>
            if Ins.Args_Count >= 1 then
               declare
                  Slot : constant Natural := Alloc_Str (M, P);
               begin
                  P.String_Pool (Slot).Chars :=
                    To_Unbounded_String (Utf8_Of (Unbox_Int (P, Arg (1))));
                  Promote_To_Large (P, Slot);
                  if Ins.Has_Dest then
                     Set_Dest (Str_Ptr (Slot));
                  end if;
               end;
            end if;

         when VC.Bi_Char_Code | VC.Bi_Char_From_Code =>
            if Ins.Args_Count >= 1 then
               if Ins.Has_Dest then
                  Set_Dest (Make_Small_Int (Unbox_Int (P, Arg (1))));
               end if;
            end if;

         when VC.Bi_Os_Write_File =>
            declare
               Path : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               Content : constant String :=
                 (if Ins.Args_Count >= 2 then To_String (Chars_Of (P, Arg (2))) else "");
               SF : Ada.Streams.Stream_IO.File_Type;
               Ok  : Boolean := True;
            begin
               begin
                  Ada.Streams.Stream_IO.Create (SF, Ada.Streams.Stream_IO.Out_File, Path);
                  if Content'Length > 0 then
                     declare
                        Buf : Ada.Streams.Stream_Element_Array (1 .. Content'Length);
                     begin
                        for I in Content'Range loop
                           Buf (Ada.Streams.Stream_Element_Offset (I - Content'First + 1)) := Ada.Streams.Stream_Element (Character'Pos (Content (I)));
                        end loop;
                        Ada.Streams.Stream_IO.Write (SF, Buf);
                     end;
                  end if;
                  Ada.Streams.Stream_IO.Close (SF);
               exception
                  when others =>
                     Ok := False;
                     Put_Line (Standard_Error, "cannot write file: " & Path);
               end;
               if Ins.Has_Dest then
                  Set_Dest (Make_Bool (Ok));
               end if;
            end;

         when VC.Bi_Os_File_Exists =>
            declare
               Path : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               Ok : Boolean := False;
            begin
               Ok := Ada.Directories.Exists (Path);
               if Ins.Has_Dest then
                  Set_Dest (Make_Bool (Ok));
               end if;
            end;

         when VC.Bi_Os_List_Dir =>
            declare
               Path : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else ".");
               Content : Unbounded_String := To_Unbounded_String ("");
               First : Boolean := True;
               Iter : Ada.Directories.Search_Type;
               E : Ada.Directories.Directory_Entry_Type;
            begin
               begin
                  Ada.Directories.Start_Search (Iter, Path, "");
                  while Ada.Directories.More_Entries (Iter) loop
                     Ada.Directories.Get_Next_Entry (Iter, E);
                     declare
                        Nm : constant String := Ada.Directories.Simple_Name (E);
                     begin
                        if Nm /= "." and then Nm /= ".." then
                           if not First then Append (Content, Character'Val (10)); end if;
                           First := False;
                           Append (Content, Nm);
                        end if;
                     end;
                  end loop;
                  Ada.Directories.End_Search (Iter);
               exception
                  when others =>
                     Put_Line (Standard_Error, "cannot list dir: " & Path);
               end;
               declare
                  Slot : constant Natural := Alloc_Str (M, P);
               begin
                  P.String_Pool (Slot).Chars := Content;
                  Promote_To_Large (P, Slot);
                  if Ins.Has_Dest then
                     Set_Dest (Str_Ptr (Slot));
                  end if;
               end;
            end;

         when VC.Bi_Os_Get_Env =>
            declare
               Name : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               Val  : Unbounded_String := To_Unbounded_String ("");
            begin
               begin
                  Val := To_Unbounded_String (Ada.Environment_Variables.Value (Name));
               exception
                  when others =>
                     Val := To_Unbounded_String ("");
               end;
               declare
                  Slot : constant Natural := Alloc_Str (M, P);
               begin
                  P.String_Pool (Slot).Chars := Val;
                  Promote_To_Large (P, Slot);
                  if Ins.Has_Dest then
                     Set_Dest (Str_Ptr (Slot));
                  end if;
               end;
            end;

         when VC.Bi_Os_Cwd =>
            declare
               Cwd  : constant String := Ada.Directories.Current_Directory;
               Slot : constant Natural := Alloc_Str (M, P);
            begin
               P.String_Pool (Slot).Chars := To_Unbounded_String (Cwd);
               Promote_To_Large (P, Slot);
               if Ins.Has_Dest then
                  Set_Dest (Str_Ptr (Slot));
               end if;
            end;

         when VC.Bi_Os_Remove_File =>
            declare
               Path : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               Ok : Boolean := True;
            begin
               begin
                  Ada.Directories.Delete_File (Path);
               exception
                  when others =>
                     Ok := False;
               end;
               if Ins.Has_Dest then
                  Set_Dest (Make_Bool (Ok));
               end if;
            end;

         when VC.Bi_Os_Make_Dir =>
            declare
               Path : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               Ok : Boolean := True;
            begin
               begin
                  Ada.Directories.Create_Directory (Path);
               exception
                  when others =>
                     Ok := False;
               end;
               if Ins.Has_Dest then
                  Set_Dest (Make_Bool (Ok));
               end if;
            end;

         when VC.Bi_Process_Spawn =>
            declare
               Name : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               NewPid : Natural;
               T      : Natural := 1;
            begin
               Spawn_Process (M, Name, NewPid);
               for I in 2 .. M.Thread_Count loop
                  if Natural (M.Threads (I).Run_Queue.Length) < Natural (M.Threads (T).Run_Queue.Length) then
                     T := I;
                  end if;
               end loop;
               M.Processes (NewPid).Assigned_Thread := T;
               M.Threads (T).Run_Queue.Append (NewPid);
               if Ins.Has_Dest then
                  Set_Dest (Make_Small_Int (Integer_64 (NewPid)));
               end if;
            end;

         when VC.Bi_Process_Send =>
            declare
               Target : constant Process_Access :=
                 (if Ins.Args_Count >= 1 then Find_Process (M, Natural (Unbox_Int (P, Arg (1)))) else null);
            begin
               if Target /= null and then Ins.Args_Count >= 2 then
                  Mail_Push (Target, Deep_Copy (M, P, Target, Arg (2)));
                  if Target.Status = Proc_Blocked then
                     Target.Status := Proc_Runnable;
                  end if;
               end if;
               if Ins.Has_Dest then
                  Set_Dest (Make_Bool (Target /= null));
               end if;
            end;

         when VC.Bi_Process_Receive =>
            begin
               if P.Mail_Count > 0 then
                  if Ins.Has_Dest then
                     Set_Dest (Mail_Pop (P));
                  end if;
               else
                  if P.Depth > 0 then
                     P.Frames (P.Depth).Pc := P.Frames (P.Depth).Pc - 1;
                  end if;
                  P.Status := Proc_Blocked;
                  if P.Blocked_Until = 0 then
                     P.Blocked_Until := Natural'Last;
                  end if;
               end if;
            end;

         when VC.Bi_Process_Try_Receive =>
            begin
               if P.Mail_Count > 0 then
                  if Ins.Has_Dest then
                     Set_Dest (Mail_Pop (P));
                  end if;
               else
                  if Ins.Has_Dest then
                     Set_Dest (Make_None);
                  end if;
               end if;
            end;

         when VC.Bi_Process_Mail_Count =>
            if Ins.Has_Dest then
               Set_Dest (Make_Small_Int (Integer_64 (P.Mail_Count)));
            end if;

         when VC.Bi_Net_Connect =>
            declare
               Host : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "localhost");
               Port : constant Integer :=
                 (if Ins.Args_Count >= 2 then Integer (Unbox_Int (P, Arg (2))) else 0);
               Sock : GNAT.Sockets.Socket_Type;
               Addr : GNAT.Sockets.Sock_Addr_Type;
               Ok   : Boolean := True;
               H    : Natural := 0;
            begin
               begin
                  GNAT.Sockets.Create_Socket (Sock);
                  Addr.Addr := GNAT.Sockets.Inet_Addr (Host);
                  Addr.Port := GNAT.Sockets.Port_Type (Port);
                  GNAT.Sockets.Connect_Socket (Sock, Addr);
                  M.Net_Sockets.Append (new GNAT.Sockets.Socket_Type'(Sock));
                  M.Net_Active.Append (True);
                  H := Natural (M.Net_Sockets.Length);
               exception
                  when others =>
                     Ok := False;
                     begin GNAT.Sockets.Close_Socket (Sock); exception when others => null; end;
               end;
               if Ins.Has_Dest then
                  if Ok then Set_Dest (Make_Small_Int (Integer_64 (H)));
                  else Set_Dest (Make_Small_Int (0)); end if;
               end if;
            end;

         when VC.Bi_Net_Send =>
            declare
               H    : constant Integer :=
                 (if Ins.Args_Count >= 1 then Integer (Unbox_Int (P, Arg (1))) else 0);
               Data : constant String :=
                 (if Ins.Args_Count >= 2 then To_String (Chars_Of (P, Arg (2))) else "");
               Last : Ada.Streams.Stream_Element_Offset;
               Buf  : Ada.Streams.Stream_Element_Array (1 .. Data'Length);
               Sock : GNAT.Sockets.Socket_Type;
               Ok   : Boolean := False;
            begin
               if H >= 1 and then H <= Natural (M.Net_Sockets.Length) and then M.Net_Active (H) then
                  Sock := M.Net_Sockets (H).all;
                  for I in Data'Range loop
                     Buf (Ada.Streams.Stream_Element_Offset (I - Data'First + 1)) := Ada.Streams.Stream_Element (Character'Pos (Data (I)));
                  end loop;
                  begin
                     GNAT.Sockets.Send_Socket (Sock, Buf, Last);
                     Ok := True;
                  exception
                     when others => Ok := False;
                  end;
               end if;
               if Ins.Has_Dest then
                  if Ok then Set_Dest (Make_Small_Int (Integer_64 (Last)));
                  else Set_Dest (Make_Small_Int (-1)); end if;
               end if;
            end;

         when VC.Bi_Net_Recv =>
            declare
               H       : constant Integer :=
                 (if Ins.Args_Count >= 1 then Integer (Unbox_Int (P, Arg (1))) else 0);
               Sock    : GNAT.Sockets.Socket_Type;
               Buf     : Ada.Streams.Stream_Element_Array (1 .. 4096);
               Last    : Ada.Streams.Stream_Element_Offset;
               Content : Unbounded_String := To_Unbounded_String ("");
            begin
               if H >= 1 and then H <= Natural (M.Net_Sockets.Length) and then M.Net_Active (H) then
                  Sock := M.Net_Sockets (H).all;
                  begin
                     GNAT.Sockets.Receive_Socket (Sock, Buf, Last);
                     for I in 1 .. Last loop
                        Append (Content, Character'Val (Integer (Buf (I))));
                     end loop;
                  exception
                     when others => null;
                  end;
               end if;
               declare
                  Slot : constant Natural := Alloc_Str (M, P);
               begin
                  P.String_Pool (Slot).Chars := Content;
                  Promote_To_Large (P, Slot);
                  if Ins.Has_Dest then
                     Set_Dest (Str_Ptr (Slot));
                  end if;
               end;
            end;

         when VC.Bi_Net_Close =>
            declare
               H : constant Integer :=
                 (if Ins.Args_Count >= 1 then Integer (Unbox_Int (P, Arg (1))) else 0);
            begin
               if H >= 1 and then H <= Natural (M.Net_Sockets.Length) and then M.Net_Active (H) then
                  begin
                     GNAT.Sockets.Close_Socket (M.Net_Sockets (H).all);
                  exception
                     when others => null;
                  end;
                  M.Net_Active (H) := False;
               end if;
               if Ins.Has_Dest then
                  Set_Dest (Make_Bool (True));
               end if;
            end;

         when VC.Bi_Net_Listen =>
            declare
               Port : constant Integer :=
                 (if Ins.Args_Count >= 1 then Integer (Unbox_Int (P, Arg (1))) else 0);
               Sock : GNAT.Sockets.Socket_Type;
               Addr : GNAT.Sockets.Sock_Addr_Type;
               Ok   : Boolean := True;
               H    : Natural := 0;
            begin
               begin
                  GNAT.Sockets.Create_Socket (Sock, GNAT.Sockets.Family_Inet, GNAT.Sockets.Socket_Stream);
                  Addr.Addr := GNAT.Sockets.Any_Inet_Addr;
                  Addr.Port := GNAT.Sockets.Port_Type (Port);
                  GNAT.Sockets.Bind_Socket (Sock, Addr);
                  GNAT.Sockets.Listen_Socket (Sock);
                  M.Net_Sockets.Append (new GNAT.Sockets.Socket_Type'(Sock));
                  M.Net_Active.Append (True);
                  H := Natural (M.Net_Sockets.Length);
               exception
                  when others =>
                     Ok := False;
                     begin GNAT.Sockets.Close_Socket (Sock); exception when others => null; end;
               end;
               if Ins.Has_Dest then
                  if Ok then Set_Dest (Make_Small_Int (Integer_64 (H)));
                  else Set_Dest (Make_Small_Int (0)); end if;
               end if;
            end;

         when VC.Bi_Net_Accept =>
            declare
               H        : constant Integer :=
                 (if Ins.Args_Count >= 1 then Integer (Unbox_Int (P, Arg (1))) else 0);
               Listener : GNAT.Sockets.Socket_Type;
               Client   : GNAT.Sockets.Socket_Type;
               Addr     : GNAT.Sockets.Sock_Addr_Type;
               Ok       : Boolean := True;
               NH       : Natural := 0;
            begin
               if H >= 1 and then H <= Natural (M.Net_Sockets.Length) and then M.Net_Active (H) then
                  Listener := M.Net_Sockets (H).all;
                  begin
                     GNAT.Sockets.Accept_Socket (Listener, Client, Addr);
                     M.Net_Sockets.Append (new GNAT.Sockets.Socket_Type'(Client));
                     M.Net_Active.Append (True);
                     NH := Natural (M.Net_Sockets.Length);
                  exception
                     when others => Ok := False;
                  end;
               else
                  Ok := False;
               end if;
               if Ins.Has_Dest then
                  if Ok then Set_Dest (Make_Small_Int (Integer_64 (NH)));
                  else Set_Dest (Make_Small_Int (0)); end if;
               end if;
            end;

         when VC.Bi_None =>
            null;


      end case;
   end Run_Builtin;
   procedure Run_Slice (M : in out Machine; P : Process_Access) is
      D    : Natural;
      Fr   : Frame;
      Fn   : VC.Func_Code;
      Base : Natural;
      S    : Value_Array_Access;
      Pc   : Natural;
   begin
      begin
         if P.Depth = 0 then
            P.Status := Proc_Dead;
            return;
         end if;
         D    := P.Depth;
         Fr   := P.Frames (D);
         Fn   := M.Prog.Funcs (Fr.Func);
         Base := Fr.Base;
         S    := P.Stack;
         Pc   := Fr.Pc;

         while P.Status = Proc_Runnable and then P.Reductions > 0 and then P.Depth > 0 loop
            P.Reductions := P.Reductions - 1;

            if Pc > Fn.Code.all'Length then
               P.Sp := Base;
               P.Depth := D - 1;
               if P.Depth = 0 then
                  P.Status := Proc_Dead;
               else
                  D := P.Depth;
                  Fr := P.Frames (D);
                  Fn := M.Prog.Funcs (Fr.Func);
                  Base := Fr.Base;
                  S := P.Stack;
                  Pc := Fr.Pc;
               end if;
            else
               declare
                  Ins : VC.Code_Instr renames Fn.Code.all (Pc);
               begin
                  Pc := Pc + 1;

                  case Ins.Op is
                     when Op_Const_Int =>
                        S (Base + Ins.Dest) := Make_Int (M, P, Ins.Imm_Int);

                     when Op_Const_None =>
                        S (Base + Ins.Dest) := Make_None;

                     when Op_Const_Bool =>
                        S (Base + Ins.Dest) := Make_Bool (Ins.Imm_Bool);

                     when Op_Const_Float =>
                        S (Base + Ins.Dest) := Make_Float (M, P, Ins.Imm_Float);

                     when Op_Const_Str =>
                        declare
                           Slot : constant Natural := Alloc_Str (M, P);
                        begin
                           P.String_Pool (Slot).Chars := M.Prog.Strings (Ins.Str);
                           P.String_Pool (Slot).Pinned := True;
                           Promote_To_Large (P, Slot);
                           S (Base + Ins.Dest) := Str_Ptr (Slot);
                        end;

                     when Op_Move =>
                        S (Base + Ins.Dest) := S (Base + Ins.Src1);

                     when Op_FuncRef =>
                        declare
                           Slot   : constant Natural := Alloc_Obj (M, P);
                           Count  : constant Natural := 1 + Ins.Args_Count;
                           F      : Value_Array_Access := new Value_Array (1 .. Count);
                        begin
                           P.Object_Pool (Slot).Type_Name := To_Unbounded_String ("Closure");
                           P.Object_Pool (Slot).Count := Count;
                           F (1) := Make_Small_Int (Integer_64 (Ins.Callee));
                           for A in 1 .. Ins.Args_Count loop
                              F (A + 1) := P.Stack (Base + M.Prog.Args (Ins.Args_First + A - 1));
                           end loop;
                           P.Object_Pool (Slot).Fields := F;
                           S (Base + Ins.Dest) := Obj_Ptr (Slot);
                        end;

                     when Op_Add_Int =>
                        S (Base + Ins.Dest) := Make_Int (M, P,
                          Checked_Add (Unbox_Int (P, S (Base + Ins.Src1)),
                                       Unbox_Int (P, S (Base + Ins.Src2))));

                     when Op_Sub_Int =>
                        S (Base + Ins.Dest) := Make_Int (M, P,
                          Checked_Sub (Unbox_Int (P, S (Base + Ins.Src1)),
                                       Unbox_Int (P, S (Base + Ins.Src2))));

                     when Op_Mul_Int =>
                        S (Base + Ins.Dest) := Make_Int (M, P,
                          Checked_Mul (Unbox_Int (P, S (Base + Ins.Src1)),
                                       Unbox_Int (P, S (Base + Ins.Src2))));

                     when Op_Add_Float =>
                        S (Base + Ins.Dest) := Make_Float (M, P,
                          Unbox_Float (P, S (Base + Ins.Src1)) +
                          Unbox_Float (P, S (Base + Ins.Src2)));

                     when Op_Sub_Float =>
                        S (Base + Ins.Dest) := Make_Float (M, P,
                          Unbox_Float (P, S (Base + Ins.Src1)) -
                          Unbox_Float (P, S (Base + Ins.Src2)));

                     when Op_Mul_Float =>
                        S (Base + Ins.Dest) := Make_Float (M, P,
                          Unbox_Float (P, S (Base + Ins.Src1)) *
                          Unbox_Float (P, S (Base + Ins.Src2)));

                     when Op_Div_Float =>
                        declare
                           Dv : constant Long_Float := Unbox_Float (P, S (Base + Ins.Src2));
                        begin
                           if Dv = 0.0 then
                              raise Constraint_Error with "division by zero";
                           end if;
                           S (Base + Ins.Dest) := Make_Float (M, P,
                             Unbox_Float (P, S (Base + Ins.Src1)) / Dv);
                        end;

                     when Op_Div_Int =>
                        S (Base + Ins.Dest) := Make_Int (M, P,
                          Checked_Div (Unbox_Int (P, S (Base + Ins.Src1)),
                                       Unbox_Int (P, S (Base + Ins.Src2))));

                     when Op_Mod_Int =>
                        S (Base + Ins.Dest) := Make_Int (M, P,
                          Checked_Rem (Unbox_Int (P, S (Base + Ins.Src1)),
                                       Unbox_Int (P, S (Base + Ins.Src2))));

                     when Op_Icmp =>
                        --  Integers (small or boxed) compare by value. Anything
                        --  else (none, bool, pointers) compares by raw word, so
                        --  none == none holds and none never equals an integer.
                        declare
                           WA : constant TW := S (Base + Ins.Src1);
                           WB : constant TW := S (Base + Ins.Src2);
                           R  : Boolean := False;
                        begin
                           if Is_Int_Like (P, WA) and then Is_Int_Like (P, WB) then
                              declare
                                 A : constant Integer_64 := Unbox_Int (P, WA);
                                 B : constant Integer_64 := Unbox_Int (P, WB);
                              begin
                                 case Ins.Cmp is
                                    when Cmp_Eq => R := A = B;
                                    when Cmp_Ne => R := A /= B;
                                    when Cmp_Lt => R := A < B;
                                    when Cmp_Le => R := A <= B;
                                    when Cmp_Gt => R := A > B;
                                    when Cmp_Ge => R := A >= B;
                                 end case;
                              end;
                           elsif Is_Float_Box (P, WA) and then Is_Float_Box (P, WB) then
                              declare
                                 A : constant Long_Float := Unbox_Float (P, WA);
                                 B : constant Long_Float := Unbox_Float (P, WB);
                              begin
                                 case Ins.Cmp is
                                    when Cmp_Eq => R := A = B;
                                    when Cmp_Ne => R := A /= B;
                                    when Cmp_Lt => R := A < B;
                                    when Cmp_Le => R := A <= B;
                                    when Cmp_Gt => R := A > B;
                                    when Cmp_Ge => R := A >= B;
                                 end case;
                              end;
                           elsif Str_Slot (P, WA) > 0 and then Str_Slot (P, WB) > 0
                             and then (Ins.Cmp = Cmp_Eq or else Ins.Cmp = Cmp_Ne)
                           then
                              declare
                                 Same : constant Boolean :=
                                   To_String (P.String_Pool (Str_Slot (P, WA)).Chars)
                                   = To_String (P.String_Pool (Str_Slot (P, WB)).Chars);
                              begin
                                 R := (Same and then Ins.Cmp = Cmp_Eq)
                                   or else (not Same and then Ins.Cmp = Cmp_Ne);
                              end;
                           else
                              case Ins.Cmp is
                                 when Cmp_Eq => R := To_Raw (WA) = To_Raw (WB);
                                 when Cmp_Ne => R := To_Raw (WA) /= To_Raw (WB);
                                 when others => R := False;
                              end case;
                           end if;
                           S (Base + Ins.Dest) := Make_Bool (R);
                        end;

                     when Op_Br =>
                        if Unbox_Bool (S (Base + Ins.Src1)) then
                           Pc := Ins.Target;
                        else
                           Pc := Ins.Target_F;
                        end if;

                     when Op_Jmp =>
                        Pc := Ins.Target;

                     when Op_Call =>
                        P.Frames (D).Pc := Pc;
                        if Ins.Builtin /= VC.Bi_None then
                           Run_Builtin (M, P, Base, Ins);
                        else
                           declare
                              Callee   : constant Natural := Ins.Callee;
                              Extent   : constant Natural :=
                                Natural'Max (M.Prog.Funcs (Callee).Frame_Size, Ins.Args_Count);
                              New_Base : Natural;
                           begin
                              P.Frames (D).Pc := Pc;
                              Push_Frame (M, P, Callee, Extent, Ins.Has_Dest, Ins.Dest, New_Base);
                              for A in 1 .. Ins.Args_Count loop
                                 P.Stack (New_Base + A - 1) :=
                                   P.Stack (Base + M.Prog.Args (Ins.Args_First + A - 1));
                              end loop;
                           end;
                        end if;
                        D := P.Depth;
                        if D > 0 then
                           Fr := P.Frames (D);
                           Fn := M.Prog.Funcs (Fr.Func);
                           Base := Fr.Base;
                           S := P.Stack;
                           Pc := Fr.Pc;
                        end if;

                     when Op_Ret =>
                        declare
                           RetVal : constant TW :=
                             (if Ins.Has_Src1 then S (Base + Ins.Src1) else Zero);
                        begin
                           P.Sp := Base;
                           P.Depth := D - 1;
                           if P.Depth = 0 then
                              Run_Process_Drops (M, P);
                              P.Result := RetVal;
                              P.Status := Proc_Dead;
                           elsif Fr.Has_Ret then
                              P.Stack (P.Frames (P.Depth).Base + Fr.Ret_Dest) := RetVal;
                           end if;
                        end;
                        if P.Depth > 0 then
                           D := P.Depth;
                           Fr := P.Frames (D);
                           Fn := M.Prog.Funcs (Fr.Func);
                           Base := Fr.Base;
                           S := P.Stack;
                           Pc := Fr.Pc;
                        end if;
                     when Op_Call_Indirect =>
                        P.Frames (D).Pc := Pc;
                        declare
                           W        : constant TW := S (Base + Ins.Src1);
                           O        : constant Natural := Obj_Slot (P, W);
                           Callee   : Natural := 0;
                           Captures : Natural := 0;
                           Extent   : Natural;
                           New_Base : Natural;
                        begin
                           if O > 0 and then P.Object_Pool (O).Count >= 1
                             and then Is_Small_Int (P.Object_Pool (O).Fields (1))
                           then
                              Callee := Natural (Unbox_Small_Int (P.Object_Pool (O).Fields (1)));
                              Captures := P.Object_Pool (O).Count - 1;
                           end if;
                           if Callee = 0 then
                              Put_Line ("invalid closure O=" & Natural'Image (O) & " count=" & Natural'Image ((if O>0 then P.Object_Pool (O).Count else 0)));
                              raise Constraint_Error with "invalid closure";
                           end if;
                           Extent := Natural'Max (M.Prog.Funcs (Callee).Frame_Size, Captures + Ins.Args_Count);
                           Push_Frame (M, P, Callee, Extent, Ins.Has_Dest, Ins.Dest, New_Base);
                           for C in 1 .. Captures loop
                              P.Stack (New_Base + C - 1) := P.Object_Pool (O).Fields (C + 1);
                           end loop;
                           for A in 1 .. Ins.Args_Count loop
                              P.Stack (New_Base + Captures + A - 1) :=
                                P.Stack (Base + M.Prog.Args (Ins.Args_First + A - 1));
                           end loop;
                        end;
                        D := P.Depth;
                        if D > 0 then
                           Fr := P.Frames (D);
                           Fn := M.Prog.Funcs (Fr.Func);
                           Base := Fr.Base;
                           S := P.Stack;
                           Pc := Fr.Pc;
                        end if;

                     when Op_Spawn =>
                        declare
                           NewPid : Natural;
                           T      : Natural := 1;
                        begin
                           Create_Process (M, Ins.Callee, NewPid);
                           for I in 2 .. M.Thread_Count loop
                              if Natural (M.Threads (I).Run_Queue.Length) < Natural (M.Threads (T).Run_Queue.Length) then
                                 T := I;
                              end if;
                           end loop;
                           M.Processes (NewPid).Assigned_Thread := T;
                           M.Threads (T).Run_Queue.Append (NewPid);
                           S (Base + Ins.Dest) := Make_Pid (Unsigned_64 (NewPid));
                        end;

                     when Op_Send =>
                        declare
                           Target : constant Process_Access :=
                             Find_Process (M, Natural (Unbox_Pid (S (Base + Ins.Src1))));
                        begin
                           if Target /= null then
                              Mail_Push (Target, Deep_Copy (M, P, Target, S (Base + Ins.Src2)));
                              if Target.Status = Proc_Blocked then
                                 Target.Status := Proc_Runnable;
                              end if;
                           end if;
                        end;

                     when Op_Receive =>
                        declare
                           Found_Match : Boolean := False;
                        begin
                           if P.Mail_Count > 0 and then (Ins.Recv_Pattern > 0 or Ins.Recv_Guard > 0) then
                              for I in 0 .. P.Mail_Count - 1 loop
                                 declare
                                    Msg : constant TW := P.Mail (((P.Mail_Head + I) mod P.Mail.all'Length) + 1);
                                    Pattern_Match : Boolean := True;
                                    Guard_Match : Boolean := True;
                                 begin
                                    if Ins.Recv_Pattern > 0 then
                                       Pattern_Match := (Msg = P.Stack (Base + Ins.Recv_Pattern));
                                    end if;
                                    if Ins.Recv_Guard > 0 then
                                       Guard_Match := Unbox_Bool (P.Stack (Base + Ins.Recv_Guard));
                                    end if;
                                    if Pattern_Match and then Guard_Match then
                                       Found_Match := True;
                                       exit;
                                    end if;
                                 end;
                              end loop;
                           elsif P.Mail_Count > 0 then
                              Found_Match := True;
                           end if;
                           if Found_Match then
                              S (Base + Ins.Dest) := Mail_Pop (P);
                              P.Blocked_Until := 0;
                              P.Recv_Timed_Out := False;
                           elsif Ins.Recv_Timeout = 0 then
                              if P.Blocked_Until = 0 then
                                 P.Blocked_Until := Natural'Last;
                              end if;
                              Pc := Pc - 1;
                              P.Status := Proc_Blocked;
                           elsif P.Recv_Timed_Out then
                              S (Base + Ins.Dest) := Make_None;
                              P.Blocked_Until := 0;
                              P.Recv_Timed_Out := False;
                           elsif P.Blocked_Until = 0 then
                              P.Blocked_Until := M.Clock + Ins.Recv_Timeout;
                              Pc := Pc - 1;
                              P.Status := Proc_Blocked;
                           elsif M.Clock >= P.Blocked_Until then
                              S (Base + Ins.Dest) := Make_None;
                              P.Blocked_Until := 0;
                              P.Recv_Timed_Out := False;
                           else
                              Pc := Pc - 1;
                              P.Status := Proc_Blocked;
                           end if;
                        end;

                     when Op_Self =>
                        S (Base + Ins.Dest) := Make_Pid (Unsigned_64 (P.Id));

                     when Op_New =>
                        declare
                           Slot : constant Natural := Alloc_Obj (M, P);
                           N    : constant Natural := Ins.Args_Count;
                           F    : constant Value_Array_Access := new Value_Array (1 .. N);
                        begin
                           for I in 1 .. N loop
                              F (I) := S (Base + M.Prog.Args (Ins.Args_First + I - 1));
                           end loop;
                           P.Object_Pool (Slot).Fields := F;
                           P.Object_Pool (Slot).Count := N;
                           P.Object_Pool (Slot).Drop := M.Prog.Drops (Ins.Str);
                           P.Object_Pool (Slot).Type_Name := M.Prog.Strings (Ins.Str);
                           S (Base + Ins.Dest) := Obj_Ptr (Slot);
                        end;

                     when Op_FieldGet =>
                        declare
                           O : constant Natural := Obj_Slot (P, S (Base + Ins.Src1));
                        begin
                           if O > 0 and then Ins.Field_Index < P.Object_Pool (O).Count then
                              S (Base + Ins.Dest) := P.Object_Pool (O).Fields (Ins.Field_Index + 1);
                           end if;
                        end;

                     when Op_FieldSet =>
                        declare
                           O : constant Natural := Obj_Slot (P, S (Base + Ins.Src1));
                        begin
                           if O > 0 and then Ins.Field_Index < P.Object_Pool (O).Count then
                              P.Object_Pool (O).Fields (Ins.Field_Index + 1) := S (Base + Ins.Src2);
                           end if;
                        end;

                     when Op_RefNew =>
                        declare
                           Slot : constant Natural := Alloc_Obj (M, P);
                           F    : constant Value_Array_Access := new Value_Array (1 .. 1);
                        begin
                           if Ins.Has_Src1 then
                              F (1) := S (Base + Ins.Src1);
                           else
                              F (1) := Zero;
                           end if;
                           P.Object_Pool (Slot).Fields := F;
                           P.Object_Pool (Slot).Count := 1;
                           S (Base + Ins.Dest) := Obj_Ptr (Slot);
                        end;

                     when Op_RefGet =>
                        declare
                           O : constant Natural := Obj_Slot (P, S (Base + Ins.Src1));
                        begin
                           if O > 0 and then P.Object_Pool (O).Count >= 1 then
                              S (Base + Ins.Dest) := P.Object_Pool (O).Fields (1);
                           end if;
                        end;

                     when Op_RefSet =>
                        declare
                           O : constant Natural := Obj_Slot (P, S (Base + Ins.Src1));
                        begin
                           if O > 0 and then P.Object_Pool (O).Count >= 1 then
                              P.Object_Pool (O).Fields (1) := S (Base + Ins.Src2);
                           end if;
                        end;

                     when Op_DynNew =>
                        declare
                           Slot : constant Natural := Alloc_Obj (M, P);
                           F    : constant Value_Array_Access := new Value_Array (1 .. 2);
                        begin
                           F (1) := S (Base + Ins.Src1);
                           F (2) := S (Base + Ins.Src2);
                           P.Object_Pool (Slot).Fields := F;
                           P.Object_Pool (Slot).Count := 2;
                           S (Base + Ins.Dest) := Obj_Ptr (Slot);
                        end;

                     when Op_DynCall =>
                        declare
                           O     : constant Natural := Obj_Slot (P, S (Base + Ins.Src1));
                           Self  : TW := Zero;
                           VIdx  : Natural := 0;
                           Func  : Natural := 0;
                        begin
                           if O > 0 then
                              if P.Object_Pool (O).Count >= 1 then
                                 Self := P.Object_Pool (O).Fields (1);
                              end if;
                              if P.Object_Pool (O).Count >= 2 then
                                 VIdx := Natural (Unbox_Small_Int (P.Object_Pool (O).Fields (2)));
                              end if;
                           end if;

                           if VIdx in 1 .. P.VT_Cap and then P.VTable_Pool (VIdx).In_Use
                             and then Ins.Method_Index < P.VTable_Pool (VIdx).Methods.all'Length
                           then
                              Func := P.VTable_Pool (VIdx).Methods (Ins.Method_Index + 1);
                           end if;

                           if Func in 1 .. M.Prog.Funcs.all'Length then
                              P.Frames (D).Pc := Pc;
                              declare
                                 Extent   : constant Natural :=
                                   Natural'Max (M.Prog.Funcs (Func).Frame_Size, Ins.Args_Count + 1);
                                 New_Base : Natural;
                              begin
                                 Push_Frame (M, P, Func, Extent, Ins.Has_Dest, Ins.Dest, New_Base);
                                 P.Stack (New_Base) := Self;
                                 for A in 1 .. Ins.Args_Count loop
                                    P.Stack (New_Base + A) :=
                                      P.Stack (Base + M.Prog.Args (Ins.Args_First + A - 1));
                                 end loop;
                              end;
                           end if;
                        end;
                        if P.Depth > D then
                           D := P.Depth;
                           Fr := P.Frames (D);
                           Fn := M.Prog.Funcs (Fr.Func);
                           Base := Fr.Base;
                           S := P.Stack;
                           Pc := Fr.Pc;
                        end if;

                     when Op_Drop =>
                        declare
                           V  : TW := S (Base + Ins.Src1);
                           O0 : constant Natural := Obj_Slot (P, V);
                           O  : Natural := O0;
                           DropFn : Natural := 0;
                        begin
                           if O0 > 0 and then P.Object_Pool (O0).Count = 2
                             and then Is_Small_Int (P.Object_Pool (O0).Fields (2))
                           then
                              declare
                                 VIdx : constant Natural := Natural (Unbox_Small_Int (P.Object_Pool (O0).Fields (2)));
                                 Data : constant TW := P.Object_Pool (O0).Fields (1);
                              begin
                                 if VIdx >= 1 and then VIdx <= P.VT_Cap
                                   and then P.VTable_Pool (VIdx).In_Use
                                 then
                                    O := Obj_Slot (P, Data);
                                    if O > 0 then
                                       V := Data;
                                    end if;
                                 end if;
                              end;
                           end if;
                           if O > 0 then
                              DropFn := P.Object_Pool (O).Drop;
                              if DropFn = 0 then
                                 declare
                                    TypeName : constant String := To_String (P.Object_Pool (O).Type_Name);
                                    Cand1    : constant String := TypeName & ".drop";
                                 begin
                                    if M.Func_Names.Contains (Cand1) then
                                       DropFn := M.Func_Names.Element (Cand1);
                                    elsif M.Func_Names.Contains ("drop") then
                                       DropFn := M.Func_Names.Element ("drop");
                                    end if;
                                 end;
                              end if;
                           end if;
                           if DropFn in 1 .. M.Prog.Funcs.all'Length then
                              P.Frames (D).Pc := Pc;
                              declare
                                 Extent   : constant Natural :=
                                   Natural'Max (M.Prog.Funcs (DropFn).Frame_Size, 1);
                                 New_Base : Natural;
                              begin
                                 Push_Frame (M, P, DropFn, Extent, False, 0, New_Base);
                                 P.Stack (New_Base) := V;
                              end;
                              D := P.Depth;
                              if D > 0 then
                                 Fr := P.Frames (D);
                                 Fn := M.Prog.Funcs (Fr.Func);
                                 Base := Fr.Base;
                                 S := P.Stack;
                                 Pc := Fr.Pc;
                              end if;
                           end if;
                        end;

                     when Op_FfiCall =>
                        declare
                           type A0 is access function return Integer_64;
                           pragma Convention (C, A0);
                           type A1 is access function (A : Integer_64) return Integer_64;
                           pragma Convention (C, A1);
                           type A2 is access function (A, B : Integer_64) return Integer_64;
                           pragma Convention (C, A2);
                           FuncName : constant String := To_String (M.Prog.Strings (Ins.Str));
                           Addr     : constant System.Address := Ffi_Address (FuncName);
                           NArgs    : constant Natural := Natural (Ins.Args_Count);
                           R        : Integer_64 := 0;

                           function Cvt0 is new Ada.Unchecked_Conversion (System.Address, A0);
                           function Cvt1 is new Ada.Unchecked_Conversion (System.Address, A1);
                           function Cvt2 is new Ada.Unchecked_Conversion (System.Address, A2);

                           function To_Int (W : TW) return Integer_64 is
                           begin
                              if Is_Small_Int (W) then
                                 return Unbox_Small_Int (W);
                              end if;
                              return 0;
                           end To_Int;
                        begin
                           if FuncName = "puts" or FuncName = "IO.puts" then
                              if Ins.Args_Count >= 1 then
                                 declare
                                    V : constant TW := P.Stack (Base + M.Prog.Args (Ins.Args_First));
                                 begin
                                    if Is_Heap_Pointer (V) then
                                       Put_Line (To_String (Chars_Of (P, V)));
                                    else
                                       Put_Line (Integer'Image (Integer (Unbox_Small_Int (V))));
                                    end if;
                                 end;
                              end if;
                              R := 0;
                           elsif FuncName = "strlen" or FuncName = "String.len" or FuncName = "len" then
                              if Ins.Args_Count >= 1 then
                                 declare
                                    Sl : constant Natural := Str_Slot (P, P.Stack (Base + M.Prog.Args (Ins.Args_First)));
                                 begin
                                    if Sl > 0 then
                                       R := Integer_64 (Length (P.String_Pool (Sl).Chars));
                                    else
                                       R := 0;
                                    end if;
                                 end;
                              end if;
                           elsif FuncName = "sqrt" then
                              if Ins.Args_Count >= 1 then
                                 declare
                                    X : Integer_64 := Unbox_Small_Int (P.Stack (Base + M.Prog.Args (Ins.Args_First)));
                                    Rr : Integer_64 := X;
                                    Nr : Integer_64;
                                 begin
                                    if X <= 0 then
                                       R := 0;
                                    else
                                       loop
                                          Nr := (Rr + X / Rr) / 2;
                                          exit when Nr >= Rr;
                                          Rr := Nr;
                                       end loop;
                                       R := Rr;
                                    end if;
                                 end;
                              end if;
                           elsif FuncName = "getpid" then
                              R := Lang.VM.Platform.Current_Process_Id;
                           else
                              if Addr = System.Null_Address then
                                 Put_Line ("ffi: symbol not found " & FuncName);
                              else
                                 case NArgs is
                                    when 0 =>
                                       R := Cvt0 (Addr).all;
                                    when 1 =>
                                       R := Cvt1 (Addr).all (To_Int (P.Stack (Base + M.Prog.Args (Ins.Args_First))));
                                    when 2 =>
                                       R := Cvt2 (Addr).all
                                         (To_Int (P.Stack (Base + M.Prog.Args (Ins.Args_First))),
                                          To_Int (P.Stack (Base + M.Prog.Args (Ins.Args_First + 1))));
                                    when others =>
                                       Put_Line ("ffi: too many args");
                                 end case;
                              end if;
                           end if;
                           if Ins.Has_Dest then
                              S (Base + Ins.Dest) := Make_Int (M, P, R);
                           end if;
                        end;

                     when Op_VTableNew =>
                        declare
                           Slot    : Natural := Alloc_VT (M, P);
                           Methods : constant VC.Natural_Array_Access :=
                             new VC.Natural_Array (1 .. Ins.Args_Count);
                        begin
                           for I in 1 .. Ins.Args_Count loop
                              Methods (I) := M.Prog.Args (Ins.Args_First + I - 1);
                           end loop;
                           P.VTable_Pool (Slot).Methods := Methods;
                           S (Base + Ins.Dest) := Make_Small_Int (Integer_64 (Slot));
                        end;

                     when others =>
                        null;
                  end case;
                  if P.Depth > 0 then
                     P.Frames (P.Depth).Pc := Pc;
                  end if;
               end;
            end if;
         end loop;
      exception
         when E : others =>
            Put_Line ("panic: " & Ada.Exceptions.Exception_Message (E));
            Flush (Standard_Output);
            C_Exit (1);
      end;

      if P.Reductions = 0 then
         if M.Verify_Roots then
            Verify_Roots (M);
         end if;
         M.Clock := M.Clock + (2000 - P.Reductions);
         P.Reductions := 2000;
      else
         M.Clock := M.Clock + (2000 - P.Reductions);
      end if;
   end Run_Slice;

   procedure Run (M : in out Machine; Entry_Name : String; Thread_Count : Natural := 1) is
      Main_Pid : Natural;
      Actual_Threads : constant Natural := Natural'Max (1, Thread_Count);
   begin
      Ensure_Compiled (M);
      Spawn_Process (M, Entry_Name, Main_Pid);

      M.Thread_Count := Actual_Threads;
      M.Threads.Clear;
      for I in 1 .. Actual_Threads loop
         declare
            TI : Thread_Info := (Run_Queue => Natural_Vectors.Empty_Vector, Current => 0);
         begin
            M.Threads.Append (TI);
         end;
      end loop;

      M.Processes (1).Assigned_Thread := 1;
      M.Threads (1).Run_Queue.Append (1);

      Scheduler_Loop : loop
         declare
            N : constant Natural := Natural (M.Processes.Length);
            Found : Boolean := False;
            Target_Thread : Natural := 0;
            Target_Idx : Natural := 0;
         begin
            exit Scheduler_Loop when N = 0;

            for Idx in 1 .. N loop
               declare
                  Q : constant Process_Access := M.Processes (Idx);
               begin
                  if Q.Status = Proc_Blocked and then Q.Blocked_Until > 0
                    and then M.Clock >= Q.Blocked_Until
                  then
                     Q.Status := Proc_Runnable;
                     Q.Recv_Timed_Out := True;
                  end if;
               end;
            end loop;

            for T in 1 .. Actual_Threads loop
               declare
                  Q : Natural_Vectors.Vector := M.Threads (T).Run_Queue;
               begin
                  for Offset in 1 .. Natural (Q.Length) loop
                     declare
                        Idx : constant Natural := (M.Threads (T).Current + Offset - 1) mod Natural (Q.Length) + 1;
                        Proc : constant Process_Access := M.Processes (Q (Idx));
                     begin
                        if Proc.Status = Proc_Runnable and then Proc.Assigned_Thread = T then
                           Target_Thread := T;
                           Target_Idx := Q (Idx);
                           Found := True;
                           exit;
                        end if;
                     end;
                  end loop;
               end;
               if Found then
                  exit;
               end if;
            end loop;

            if not Found then
               for T in 1 .. Actual_Threads loop
                  for Other_T in 1 .. Actual_Threads loop
                     if Other_T /= T and then not M.Threads (Other_T).Run_Queue.Is_Empty then
                        -- Steal first runnable process
                        declare
                           Q : Natural_Vectors.Vector := M.Threads (Other_T).Run_Queue;
                        begin
                           for Offset in 1 .. Natural (Q.Length) loop
                              declare
                                 Idx : constant Natural := Offset;
                                 Proc : constant Process_Access := M.Processes (Q (Idx));
                              begin
                                 if Proc.Status = Proc_Runnable then
                                    -- Steal this process
                                    Proc.Assigned_Thread := T;
                                    M.Threads (T).Run_Queue.Append (Q (Idx));
                                    M.Threads (Other_T).Run_Queue.Delete (Idx);
                                    Target_Thread := T;
                                    Target_Idx := Q (Idx);
                                    Found := True;
                                    exit;
                                 end if;
                              end;
                           end loop;
                        end;
                        if Found then
                           exit;
                        end if;
                     end if;
                  end loop;
                  if Found then
                     exit;
                  end if;
               end loop;
            end if;

            exit Scheduler_Loop when not Found;

            M.Current := Target_Idx;
            declare
               P : constant Process_Access := M.Processes (Target_Idx);
            begin
               if not M.Threads (Target_Thread).Run_Queue.Contains (Target_Idx) then
                  M.Threads (Target_Thread).Run_Queue.Append (Target_Idx);
               end if;
               Run_Slice (M, P);
            end;
         end;
      end loop Scheduler_Loop;
   end Run;

end Lang.VM.Machine;