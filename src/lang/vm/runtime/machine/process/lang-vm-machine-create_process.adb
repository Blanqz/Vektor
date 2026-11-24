separate (Lang.VM.Machine)
   procedure Create_Process (M : in out Machine; CI : Natural; New_Pid : out Natural) is
      P    : constant Process_Access := new Process;
      Base : Natural;
   begin
      New_Pid := M.Next_Pid;
      M.Next_Pid := M.Next_Pid + 1;
      P.Id := New_Pid;
      P.Frames := new Frame_Array (1 .. 16);
      P.Stack := new Value_Array (1 .. 256);
      P.Mail := new Value_Array (1 .. 8);
      P.Large_Buffers := new Large_Buffer_Array;
      Allocator.Init_Heap (M, P);
      if CI > 0 then
         Push_Frame (M, P, CI, M.Prog.Funcs (CI).Frame_Size, False, 0, Base);
      end if;
      M.Processes.Append (P);
      while Natural (M.Pid_To_Idx.Length) < New_Pid loop
         M.Pid_To_Idx.Append (0);
      end loop;
      M.Pid_To_Idx (New_Pid) := Natural (M.Processes.Length);
   end Create_Process;