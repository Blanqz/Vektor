separate (Lang.VM.Machine)
   procedure Run (M : in out Machine; Entry_Name : String; Thread_Count : Natural := 1) is
      Main_Pid : Natural;
      Actual_Threads : constant Natural := Natural'Max (1, Thread_Count);
   begin
      Ensure_Compiled (M);
      Spawn_Process (M, Entry_Name, Main_Pid);

      M.Thread_Count := Actual_Threads;
      M.Threads.Clear;
      for I in 1 .. Actual_Threads loop
         declare
            TI : Thread_Info := (Run_Queue => Natural_Vectors.Empty_Vector, Current => 0);
         begin
            M.Threads.Append (TI);
         end;
      end loop;

      M.Processes (1).Assigned_Thread := 1;
      M.Threads (1).Run_Queue.Append (1);

      Scheduler_Loop : loop
         declare
            N : constant Natural := Natural (M.Processes.Length);
            Found : Boolean := False;
            Target_Thread : Natural := 0;
            Target_Idx : Natural := 0;
         begin
            exit Scheduler_Loop when N = 0;

            for Idx in 1 .. N loop
               declare
                  Q : constant Process_Access := M.Processes (Idx);
               begin
                  if Q.Status = Proc_Blocked and then Q.Blocked_Until > 0
                    and then M.Clock >= Q.Blocked_Until
                  then
                     Q.Status := Proc_Runnable;
                     Q.Recv_Timed_Out := True;
                  end if;
               end;
            end loop;

            for T in 1 .. Actual_Threads loop
               declare
                  Q : Natural_Vectors.Vector := M.Threads (T).Run_Queue;
               begin
                  for Offset in 1 .. Natural (Q.Length) loop
                     declare
                        Idx : constant Natural := (M.Threads (T).Current + Offset - 1) mod Natural (Q.Length) + 1;
                        Proc : constant Process_Access := M.Processes (Q (Idx));
                     begin
                        if Proc.Status = Proc_Runnable and then Proc.Assigned_Thread = T then
                           Target_Thread := T;
                           Target_Idx := Q (Idx);
                           Found := True;
                           exit;
                        end if;
                     end;
                  end loop;
               end;
               if Found then
                  exit;
               end if;
            end loop;

            if not Found then
               for T in 1 .. Actual_Threads loop
                  for Other_T in 1 .. Actual_Threads loop
                     if Other_T /= T and then not M.Threads (Other_T).Run_Queue.Is_Empty then
                        -- Steal first runnable process
                        declare
                           Q : Natural_Vectors.Vector := M.Threads (Other_T).Run_Queue;
                        begin
                           for Offset in 1 .. Natural (Q.Length) loop
                              declare
                                 Idx : constant Natural := Offset;
                                 Proc : constant Process_Access := M.Processes (Q (Idx));
                              begin
                                 if Proc.Status = Proc_Runnable then
                                    -- Steal this process
                                    Proc.Assigned_Thread := T;
                                    M.Threads (T).Run_Queue.Append (Q (Idx));
                                    M.Threads (Other_T).Run_Queue.Delete (Idx);
                                    Target_Thread := T;
                                    Target_Idx := Q (Idx);
                                    Found := True;
                                    exit;
                                 end if;
                              end;
                           end loop;
                        end;
                        if Found then
                           exit;
                        end if;
                     end if;
                  end loop;
                  if Found then
                     exit;
                  end if;
               end loop;
            end if;

            exit Scheduler_Loop when not Found;

            M.Current := Target_Idx;
            declare
               P : constant Process_Access := M.Processes (Target_Idx);
            begin
               if not M.Threads (Target_Thread).Run_Queue.Contains (Target_Idx) then
                  M.Threads (Target_Thread).Run_Queue.Append (Target_Idx);
               end if;
               Run_Slice (M, P);
            end;
         end;
      end loop Scheduler_Loop;
   end Run;