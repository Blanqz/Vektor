separate (Lang.VM.Machine)
   function Unbox_Int (P : Process_Access; W : TW) return Interfaces.Integer_64 is
      B : constant Natural := Box_Slot (P, W);
      function Cast is new Ada.Unchecked_Conversion (Interfaces.Unsigned_64, Interfaces.Integer_64);
   begin
      if Is_Small_Int (W) then
         return Unbox_Small_Int (W);
      end if;
      if B > 0 and then Lang.VM.Box_Header.Kind_Of (Box_At (P, B).Header) = Lang.VM.Box_Header.Kind_Int64 then
         return Cast (Box_At (P, B).Value);
      end if;
      return 0;
   end Unbox_Int;