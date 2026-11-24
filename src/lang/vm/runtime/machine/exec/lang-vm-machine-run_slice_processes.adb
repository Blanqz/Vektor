separate (Lang.VM.Machine)
   procedure Run_Slice_Processes (M : in out Machine; P : Process_Access; D : in out Natural; Fr : in out Frame; Fn : in out VC.Func_Code; Base : in out Natural; S : in out Value_Array_Access; Pc : in out Natural; Ins : VC.Code_Instr) is
   begin
      case Ins.Op is
                     when Op_Spawn =>
                        declare
                           NewPid : Natural;
                           T      : Natural := 1;
                        begin
                           Create_Process (M, Ins.Callee, NewPid);
                           for I in 2 .. M.Thread_Count loop
                              if Natural (M.Threads (I).Run_Queue.Length) < Natural (M.Threads (T).Run_Queue.Length) then
                                 T := I;
                              end if;
                           end loop;
                           M.Processes (NewPid).Assigned_Thread := T;
                           M.Threads (T).Run_Queue.Append (NewPid);
                           S (Base + Ins.Dest) := Make_Pid (Unsigned_64 (NewPid));
                        end;

                     when Op_Send =>
                        declare
                           Target : constant Process_Access :=
                             Find_Process (M, Natural (Unbox_Pid (S (Base + Ins.Src1))));
                        begin
                           if Target /= null then
                              Mail_Push (Target, Deep_Copy (M, P, Target, S (Base + Ins.Src2)));
                              if Target.Status = Proc_Blocked then
                                 Target.Status := Proc_Runnable;
                              end if;
                           end if;
                        end;

                     when Op_Receive =>
                        declare
                           Found_Match : Boolean := False;
                        begin
                           if P.Mail_Count > 0 and then (Ins.Recv_Pattern > 0 or Ins.Recv_Guard > 0) then
                              for I in 0 .. P.Mail_Count - 1 loop
                                 declare
                                    Msg : constant TW := P.Mail (((P.Mail_Head + I) mod P.Mail.all'Length) + 1);
                                    Pattern_Match : Boolean := True;
                                    Guard_Match : Boolean := True;
                                 begin
                                    if Ins.Recv_Pattern > 0 then
                                       Pattern_Match := (Msg = P.Stack (Base + Ins.Recv_Pattern));
                                    end if;
                                    if Ins.Recv_Guard > 0 then
                                       Guard_Match := Unbox_Bool (P.Stack (Base + Ins.Recv_Guard));
                                    end if;
                                    if Pattern_Match and then Guard_Match then
                                       Found_Match := True;
                                       exit;
                                    end if;
                                 end;
                              end loop;
                           elsif P.Mail_Count > 0 then
                              Found_Match := True;
                           end if;
                           if Found_Match then
                              S (Base + Ins.Dest) := Mail_Pop (P);
                              P.Blocked_Until := 0;
                              P.Recv_Timed_Out := False;
                           elsif Ins.Recv_Timeout = 0 then
                              if P.Blocked_Until = 0 then
                                 P.Blocked_Until := Natural'Last;
                              end if;
                              Pc := Pc - 1;
                              P.Status := Proc_Blocked;
                           elsif P.Recv_Timed_Out then
                              S (Base + Ins.Dest) := Make_None;
                              P.Blocked_Until := 0;
                              P.Recv_Timed_Out := False;
                           elsif P.Blocked_Until = 0 then
                              P.Blocked_Until := M.Clock + Ins.Recv_Timeout;
                              Pc := Pc - 1;
                              P.Status := Proc_Blocked;
                           elsif M.Clock >= P.Blocked_Until then
                              S (Base + Ins.Dest) := Make_None;
                              P.Blocked_Until := 0;
                              P.Recv_Timed_Out := False;
                           else
                              Pc := Pc - 1;
                              P.Status := Proc_Blocked;
                           end if;
                        end;

                     when Op_Self =>
                        S (Base + Ins.Dest) := Make_Pid (Unsigned_64 (P.Id));

         when others => null;
      end case;
   end Run_Slice_Processes;