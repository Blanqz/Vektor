separate (Lang.VM.Machine)
   procedure Run_Builtin_Processes (M    : in out Machine;
                          P    : Process_Access;
                          Base : Natural;
                          Ins  : VC.Code_Instr) is
      function Arg (I : Positive) return TW is
      begin
         return P.Stack (Base + M.Prog.Args (Ins.Args_First + I - 1));
      end Arg;

      procedure Set_Dest (W : TW) is
      begin
         P.Stack (Base + Ins.Dest) := W;
      end Set_Dest;
begin
      case Ins.Builtin is
         when VC.Bi_Process_Spawn =>
            declare
               Name : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               NewPid : Natural;
               T      : Natural := 1;
            begin
               Spawn_Process (M, Name, NewPid);
               for I in 2 .. M.Thread_Count loop
                  if Natural (M.Threads (I).Run_Queue.Length) < Natural (M.Threads (T).Run_Queue.Length) then
                     T := I;
                  end if;
               end loop;
               M.Processes (NewPid).Assigned_Thread := T;
               M.Threads (T).Run_Queue.Append (NewPid);
               if Ins.Has_Dest then
                  Set_Dest (Make_Small_Int (Integer_64 (NewPid)));
               end if;
            end;

         when VC.Bi_Process_Send =>
            declare
               Target : constant Process_Access :=
                 (if Ins.Args_Count >= 1 then Find_Process (M, Natural (Unbox_Int (P, Arg (1)))) else null);
            begin
               if Target /= null and then Ins.Args_Count >= 2 then
                  Mail_Push (Target, Deep_Copy (M, P, Target, Arg (2)));
                  if Target.Status = Proc_Blocked then
                     Target.Status := Proc_Runnable;
                  end if;
               end if;
               if Ins.Has_Dest then
                  Set_Dest (Make_Bool (Target /= null));
               end if;
            end;

         when VC.Bi_Process_Receive =>
            begin
               if P.Mail_Count > 0 then
                  if Ins.Has_Dest then
                     Set_Dest (Mail_Pop (P));
                  end if;
               else
                  if P.Depth > 0 then
                     P.Frames (P.Depth).Pc := P.Frames (P.Depth).Pc - 1;
                  end if;
                  P.Status := Proc_Blocked;
                  if P.Blocked_Until = 0 then
                     P.Blocked_Until := Natural'Last;
                  end if;
               end if;
            end;

         when VC.Bi_Process_Try_Receive =>
            begin
               if P.Mail_Count > 0 then
                  if Ins.Has_Dest then
                     Set_Dest (Mail_Pop (P));
                  end if;
               else
                  if Ins.Has_Dest then
                     Set_Dest (Make_None);
                  end if;
               end if;
            end;

         when VC.Bi_Process_Mail_Count =>
            if Ins.Has_Dest then
               Set_Dest (Make_Small_Int (Integer_64 (P.Mail_Count)));
            end if;

         when others => null;
      end case;
end Run_Builtin_Processes;