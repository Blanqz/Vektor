separate (Lang.VM.Machine)
   function Ffi_Address (Name : String) return System.Address is
   begin
      return Lang.VM.Platform.Resolve_Symbol (Name);
   end Ffi_Address;