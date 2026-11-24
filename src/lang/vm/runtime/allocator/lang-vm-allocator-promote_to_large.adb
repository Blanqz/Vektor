separate (Lang.VM.Allocator)
   procedure Promote_To_Large (P : Process_Access; Slot : Natural) is
      L : Natural;
      Buf_Id : Natural;
   begin
      if Str_At (P, Slot).Large then
         return;
      end if;
      L := Ada.Strings.Unbounded.Length (Str_At (P, Slot).Chars);
      if L < Large_Buffer_Threshold then
         return;
      end if;
      Buf_Id := Alloc_Large_Buffer (P);
      if Buf_Id = 0 then
         return;
      end if;
      P.Large_Buffers (Buf_Id).Data := Str_At (P, Slot).Chars;
      Str_At (P, Slot).Large := True;
      Str_At (P, Slot).Buf_Id := Buf_Id;
      Str_At (P, Slot).Chars := To_Unbounded_String ("");
   end Promote_To_Large;