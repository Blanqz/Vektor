separate (Lang.VM.Machine)
   procedure Run_Builtin_Text (M    : in out Machine;
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
                  Slot : constant Natural := Allocator.Alloc_Str (M, P);
               begin
                  Str_At (P, Slot).Chars := A & B;
                  Allocator.Promote_To_Large (P, Slot);
                  if Ins.Has_Dest then
                     Set_Dest (Str_Ptr (Slot));
                  end if;
               end;
            end if;

         when VC.Bi_Len =>
            if Ins.Args_Count >= 1 then
               declare
                  S : constant Natural := Str_Slot (P, Arg (1));
                  L : constant Natural := (if S > 0 then Length (Str_At (P, S).Chars) else 0);
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
                  Slot : constant Natural := Allocator.Alloc_Str (M, P);
               begin
                  Str_At (P, Slot).Chars := To_Unbounded_String (Img);
                  Allocator.Promote_To_Large (P, Slot);
                  if Ins.Has_Dest then
                     Set_Dest (Str_Ptr (Slot));
                  end if;
               end;
            end if;

         when VC.Bi_String_Get =>
            if Ins.Args_Count >= 2 then
               declare
                  S : constant Natural := Str_Slot (P, Arg (1));
                  I : constant Integer_64 := Unbox_Small_Int (Arg (2));
                  L : constant Natural := (if S > 0 then Length (Str_At (P, S).Chars) else 0);
               begin
                  if S > 0 and then I >= 0 and then I < Integer_64 (L) then
                     if Ins.Has_Dest then
                        Set_Dest (Make_Small_Int (Integer_64 (Character'Pos (Element (Str_At (P, S).Chars, Natural (I) + 1)))));
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
                  Src : constant Unbounded_String := (if S > 0 then Str_At (P, S).Chars else To_Unbounded_String (""));
                  L : constant Natural := Length (Src);
                  Lo : constant Natural := Natural'Min (L, Natural'Max (0, Integer (Start)));
                  Hi : constant Natural := Natural'Min (L, Natural'Max (Lo, Integer (Finish)));
                  Slot : constant Natural := Allocator.Alloc_Str (M, P);
               begin
                  Str_At (P, Slot).Chars := Unbounded_Slice (Src, Lo + 1, Hi);
                  Allocator.Promote_To_Large (P, Slot);
                  if Ins.Has_Dest then
                     Set_Dest (Str_Ptr (Slot));
                  end if;
               end;
            end if;

         when VC.Bi_Float_To_String =>
            if Ins.Args_Count >= 1 then
               declare
                  Img  : constant String :=
                    (if Arg (1) = Make_None then "none"
                     else Format_Decimal (Unbox_Float (P, Arg (1))));
                  Slot : constant Natural := Allocator.Alloc_Str (M, P);
               begin
                  Str_At (P, Slot).Chars := To_Unbounded_String (Img);
                  Allocator.Promote_To_Large (P, Slot);
                  if Ins.Has_Dest then
                     Set_Dest (Str_Ptr (Slot));
                  end if;
               end;
            end if;

         when VC.Bi_Text_Hash =>
            if Ins.Args_Count >= 1 then
               declare
                  S : constant Natural := Str_Slot (P, Arg (1));
                  H : Integer_64 := 7;
               begin
                  if S > 0 then
                     for I in 1 .. Length (Str_At (P, S).Chars) loop
                        H := (H * 31 + Integer_64 (Character'Pos (Element (Str_At (P, S).Chars, I))))
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
                  Slot : constant Natural := Allocator.Alloc_Str (M, P);
               begin
                  Str_At (P, Slot).Chars := To_Unbounded_String (Img);
                  Allocator.Promote_To_Large (P, Slot);
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
                  Slot : constant Natural := Allocator.Alloc_Str (M, P);
               begin
                  for I in Img'Range loop
                     if Ins.Builtin = VC.Bi_String_Upper then
                        Img (I) := Ada.Characters.Handling.To_Upper (Img (I));
                     else
                        Img (I) := Ada.Characters.Handling.To_Lower (Img (I));
                     end if;
                  end loop;
                  Str_At (P, Slot).Chars := To_Unbounded_String (Img);
                  Allocator.Promote_To_Large (P, Slot);
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

         when VC.Bi_Char_To_Text =>
            if Ins.Args_Count >= 1 then
               declare
                  Slot : constant Natural := Allocator.Alloc_Str (M, P);
               begin
                  Str_At (P, Slot).Chars :=
                    To_Unbounded_String (Utf8_Of (Unbox_Int (P, Arg (1))));
                  Allocator.Promote_To_Large (P, Slot);
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

         when others => null;
      end case;
end Run_Builtin_Text;