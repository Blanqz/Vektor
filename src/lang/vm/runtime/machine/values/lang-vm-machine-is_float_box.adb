separate (Lang.VM.Machine)
   function Is_Float_Box (P : Process_Access; W : TW) return Boolean is
      B : constant Natural := Box_Slot (P, W);
   begin
      return B > 0 and then Lang.VM.Box_Header.Kind_Of (Box_At (P, B).Header) = Lang.VM.Box_Header.Kind_Float64;
   end Is_Float_Box;