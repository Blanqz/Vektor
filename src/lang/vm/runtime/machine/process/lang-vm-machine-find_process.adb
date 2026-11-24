separate (Lang.VM.Machine)
   function Find_Process (M : Machine; Pid : Natural) return Process_Access is
   begin
      if Pid >= 1 and then Pid <= Natural (M.Pid_To_Idx.Length) then
         declare
            Idx : constant Natural := M.Pid_To_Idx (Pid);
         begin
            if Idx >= 1 and then Idx <= Natural (M.Processes.Length) then
               return M.Processes (Idx);
            end if;
         end;
      end if;
      return null;
   end Find_Process;