separate (Lang.VM.IR)
procedure Parse_Op_Processes (Instr : in out Ir_Instr; OpTok : String; Rest : String) is
begin
                                    if OpTok = "spawn" then
                                       Instr.Op := Op_Spawn;
                                       declare
                                          Comma : Natural := 0;
                                       begin
                                          for K in Rest'Range loop
                                             if Rest (K) = ',' then Comma := K; exit; end if;
                                          end loop;
                                          if Comma > 0 then
                                             Instr.Has_Dest := True;
                                             Instr.Dest := Parse_Reg (Rest (Rest'First .. Comma - 1));
                                             Instr.Spawn_Func := To_Unbounded_String (Trim (Rest (Comma + 1 .. Rest'Last)));
                                          else
                                             Instr.Spawn_Func := To_Unbounded_String (Trim (Rest));
                                          end if;
                                       end;
                                    elsif OpTok = "send" then
                                       Instr.Op := Op_Send;
                                       declare
                                          Comma : Natural := 0;
                                       begin
                                          for K in Rest'Range loop
                                             if Rest (K) = ',' then Comma := K; exit; end if;
                                          end loop;
                                          Instr.Has_Send_Target := True;
                                          Instr.Send_Target := Parse_Reg (Rest (Rest'First .. Comma - 1));
                                          Instr.Has_Send_Msg := True;
                                          Instr.Send_Msg := Parse_Reg (Rest (Comma + 1 .. Rest'Last));
                                       end;
                                    elsif OpTok = "receive" then
                                       Instr.Op := Op_Receive;
                                       declare
                                          Parts : array (1 .. 4) of Unbounded_String := (others => To_Unbounded_String (""));
                                          NParts : Natural := 0;
                                          Start : Natural := Rest'First;
                                          Tmp : Natural;
                                       begin
                                          for K in Rest'Range loop
                                             if Rest (K) = ',' then
                                                NParts := NParts + 1;
                                                Parts (NParts) := To_Unbounded_String (Trim (Rest (Start .. K - 1)));
                                                Start := K + 1;
                                             end if;
                                          end loop;
                                          NParts := NParts + 1;
                                          Parts (NParts) := To_Unbounded_String (Trim (Rest (Start .. Rest'Last)));
                                          Instr.Has_Recv_Dest := True;
                                          Instr.Recv_Dest := Parse_Reg (To_String (Parts (1)));
                                          for PI in 2 .. NParts loop
                                             declare
                                                PStr : constant String := Trim (To_String (Parts (PI)));
                                             begin
                                                if PStr'Length > 2 and then PStr (PStr'First .. PStr'First + 1) = "%r" then
                                                   if Instr.Recv_Pattern = 0 and then PI = 2 then
                                                      Instr.Recv_Pattern := Parse_Reg (PStr);
                                                   elsif Instr.Recv_Guard = 0 then
                                                      Instr.Recv_Guard := Parse_Reg (PStr);
                                                   end if;
                                                else
                                                   begin
                                                      Instr.Recv_Timeout := Natural'Value (PStr);
                                                   exception
                                                      when others => null;
                                                   end;
                                                end if;
                                             end;
                                          end loop;
                                       end;
                                    elsif OpTok = "self" then
                                       Instr.Op := Op_Self;
                                       Instr.Has_Dest := True;
                                       Instr.Dest := Parse_Reg (Rest);
                                    else
                                       Parse_Op_Objects (Instr, OpTok, Rest);
                                    end if;
end Parse_Op_Processes;