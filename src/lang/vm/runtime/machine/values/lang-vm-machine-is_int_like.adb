separate (Lang.VM.Machine)
   function Is_Int_Like (P : Process_Access; W : TW) return Boolean is
   begin
      return Is_Small_Int (W) or else Is_Int_Box (P, W);
   end Is_Int_Like;