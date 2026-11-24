separate (Lang.VM.Machine)
   function Last_Result (M : Machine) return TW is
   begin
      if M.Processes.Is_Empty then
         return Make_Small_Int (0);
      end if;
      return M.Processes.First_Element.Result;
   end Last_Result;