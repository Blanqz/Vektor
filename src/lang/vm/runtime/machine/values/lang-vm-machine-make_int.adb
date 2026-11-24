separate (Lang.VM.Machine)
   function Make_Int (M : in out Machine; P : Process_Access; Value : Interfaces.Integer_64) return TW is
      Slot : Natural;
      function Cast is new Ada.Unchecked_Conversion (Interfaces.Integer_64, Interfaces.Unsigned_64);
   begin
      if Value >= -2 ** 60 and then Value <= 2 ** 60 - 1 then
         return Make_Small_Int (Value);
      end if;
      Slot := Allocator.Alloc_Box (M, P);
      Box_At (P, Slot).Header := Lang.VM.Box_Header.Make (Lang.VM.Box_Header.Kind_Int64);
      Box_At (P, Slot).Value := Cast (Value);
      return Box_Ptr (Slot);
   end Make_Int;