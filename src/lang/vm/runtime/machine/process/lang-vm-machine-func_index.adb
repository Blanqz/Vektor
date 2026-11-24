separate (Lang.VM.Machine)
   function Func_Index (M : Machine; Name : String) return Natural is
   begin
      if M.Func_Names.Contains (Name) then
         return M.Func_Names.Element (Name);
      end if;
      return 0;
   end Func_Index;