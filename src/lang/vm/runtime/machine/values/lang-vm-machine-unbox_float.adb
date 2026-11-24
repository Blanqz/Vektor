separate (Lang.VM.Machine)
   function Unbox_Float (P : Process_Access; W : TW) return Long_Float is
      B : constant Natural := Box_Slot (P, W);
      function Cast is new Ada.Unchecked_Conversion (Interfaces.Unsigned_64, Long_Float);
   begin
      if B = 0 then
         return 0.0;
      end if;
      return Cast (Box_At (P, B).Value);
   end Unbox_Float;