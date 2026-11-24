separate (Lang.VM.Machine)
   function Make_Float (M : in out Machine; P : Process_Access; Value : Long_Float) return TW is
      Slot : constant Natural := Allocator.Alloc_Box (M, P);
      function Cast is new Ada.Unchecked_Conversion (Long_Float, Interfaces.Unsigned_64);
   begin
      Box_At (P, Slot).Header := Lang.VM.Box_Header.Make (Lang.VM.Box_Header.Kind_Float64);
      Box_At (P, Slot).Value := Cast (Value);
      return Box_Ptr (Slot);
   end Make_Float;