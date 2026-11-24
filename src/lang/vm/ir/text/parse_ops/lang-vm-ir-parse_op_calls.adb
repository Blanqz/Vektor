separate (Lang.VM.IR)
procedure Parse_Op_Calls (Instr : in out Ir_Instr; OpTok : String; Rest : String) is
begin
                                    if OpTok = "call" then
                                       Instr.Op := Op_Call;
                                       declare
                                          Comma : Natural := 0;
                                       begin
                                          for K in Rest'Range loop
                                             if Rest (K) = ',' then Comma := K; exit; end if;
                                          end loop;
                                          if Comma > 0 then
                                             Instr.Has_Dest := True;
                                             Instr.Dest := Parse_Reg (Rest (Rest'First .. Comma - 1));
                                             declare
                                                After : constant String := Trim (Rest (Comma + 1 .. Rest'Last));
                                                Sp : Natural := 0;
                                             begin
                                                for K in After'Range loop
                                                   if After (K) = ',' then Sp := K; exit; end if;
                                                end loop;
                                                if After'Length > 0 and then After (After'First) = '%' then
                                                   Instr.Op := Op_Call_Indirect;
                                                   Instr.Has_Src1 := True;
                                                   if Sp = 0 then
                                                      Instr.Src1 := Parse_Reg (After);
                                                   else
                                                      Instr.Src1 := Parse_Reg (After (After'First .. Sp - 1));
                                                      declare
                                                         Args_Str : constant String := Trim (After (Sp + 1 .. After'Last));
                                                         Start : Natural := Args_Str'First;
                                                      begin
                                                         for K in Args_Str'Range loop
                                                            if K = Args_Str'Last or else Args_Str (K + 1) = ',' then
                                                               Instr.Args.Append (Parse_Reg (Trim (Args_Str (Start .. K))));
                                                               Start := K + 2;
                                                            end if;
                                                         end loop;
                                                      end;
                                                   end if;
                                                elsif Sp = 0 then
                                                   Instr.Func_Name := To_Unbounded_String (Trim (After));
                                                else
                                                   Instr.Func_Name := To_Unbounded_String (Trim (After (After'First .. Sp - 1)));
                                                   declare
                                                      Args_Str : constant String := Trim (After (Sp + 1 .. After'Last));
                                                      Start : Natural := Args_Str'First;
                                                   begin
                                                      for K in Args_Str'Range loop
                                                         if K = Args_Str'Last or else Args_Str (K + 1) = ',' then
                                                            Instr.Args.Append (Parse_Reg (Trim (Args_Str (Start .. K))));
                                                            Start := K + 2;
                                                         end if;
                                                      end loop;
                                                   end;
                                                end if;
                                             end;
                                          end if;
                                       end;
                                    elsif OpTok = "ffi.call" then
                                       Instr.Op := Op_FfiCall;
                                       declare
                                          Comma : Natural := 0;
                                       begin
                                          for K in Rest'Range loop
                                             if Rest (K) = ',' then Comma := K; exit; end if;
                                          end loop;
                                          if Comma > 0 then
                                             Instr.Has_Dest := True;
                                             Instr.Dest := Parse_Reg (Rest (Rest'First .. Comma - 1));
                                             declare
                                                After : constant String := Trim (Rest (Comma + 1 .. Rest'Last));
                                                Sp : Natural := 0;
                                             begin
                                                for K in After'Range loop
                                                   if After (K) = ',' then Sp := K; exit; end if;
                                                end loop;
                                                if Sp = 0 then
                                                   Instr.Func_Name := To_Unbounded_String ( (if After'Length > 0 and then After (After'First) = '"' and then After (After'Last) = '"' then After (After'First+1 .. After'Last-1) else After) );
                                                else
                                                   Instr.Func_Name := To_Unbounded_String ( (if Sp > After'First and then After (After'First) = '"' and then After (Sp-1) = '"' then After (After'First+1 .. Sp-2) else After (After'First .. Sp-1)) );
                                                   declare
                                                      Args_Str : constant String := Trim (After (Sp + 1 .. After'Last));
                                                      Start : Natural := Args_Str'First;
                                                   begin
                                                      for K in Args_Str'Range loop
                                                         if K = Args_Str'Last or else Args_Str (K + 1) = ',' then
                                                            Instr.Args.Append (Parse_Reg (Trim (Args_Str (Start .. K))));
                                                            Start := K + 2;
                                                         end if;
                                                      end loop;
                                                   end;
                                                end if;
                                             end;
                                          end if;
                                       end;
                                    elsif OpTok = "dyn.call" then
            Instr.Op := Op_DynCall;
            declare
               Comma1 : Natural := 0;
               Comma2 : Natural := 0;
            begin
               for K in Rest'Range loop
                  if Rest (K) = ',' then
                     if Comma1 = 0 then
                        Comma1 := K;
                     elsif Comma2 = 0 then
                        Comma2 := K;
                        exit;
                     end if;
                  end if;
               end loop;
               Instr.Has_Dest := True;
               Instr.Dest := Parse_Reg (Rest (Rest'First .. Comma1 - 1));
               Instr.Has_Src1 := True;
               Instr.Src1 := Parse_Reg (Rest (Comma1 + 1 .. Comma2 - 1));
               declare
                  After : constant String := Trim (Rest (Comma2 + 1 .. Rest'Last));
                  Start : Natural := After'First;
                  Index_Read : Boolean := False;
               begin
                  for K in After'Range loop
                     if K = After'Last or else After (K + 1) = ',' then
                        if Index_Read then
                           Instr.Args.Append (Parse_Reg (Trim (After (Start .. K))));
                        else
                           Instr.Method_Index := Natural'Value (Trim (After (Start .. K)));
                           Index_Read := True;
                        end if;
                        Start := K + 2;
                     end if;
                  end loop;
               end;
            end;
                                    elsif OpTok = "call.indirect" or OpTok = "call_indirect" then
                                       Instr.Op := Op_Call_Indirect;
                                       declare
                                          Comma : Natural := 0;
                                       begin
                                          for K in Rest'Range loop
                                             if Rest (K) = ',' then Comma := K; exit; end if;
                                          end loop;
                                          if Comma > 0 then
                                             Instr.Has_Dest := True;
                                             Instr.Dest := Parse_Reg (Rest (Rest'First .. Comma - 1));
                                             declare
                                                After : constant String := Trim (Rest (Comma + 1 .. Rest'Last));
                                                Sp : Natural := 0;
                                             begin
                                                for K in After'Range loop
                                                   if After (K) = ',' then Sp := K; exit; end if;
                                                end loop;
                                                if Sp = 0 then
                                                   Instr.Has_Src1 := True;
                                                   Instr.Src1 := Parse_Reg (After);
                                                else
                                                   Instr.Has_Src1 := True;
                                                   Instr.Src1 := Parse_Reg (After (After'First .. Sp - 1));
                                                   declare
                                                      Args_Str : constant String := Trim (After (Sp + 1 .. After'Last));
                                                      Start : Natural := Args_Str'First;
                                                   begin
                                                      for K in Args_Str'Range loop
                                                         if K = Args_Str'Last or else Args_Str (K + 1) = ',' then
                                                            Instr.Args.Append (Parse_Reg (Trim (Args_Str (Start .. K))));
                                                            Start := K + 2;
                                                         end if;
                                                      end loop;
                                                   end;
                                                end if;
                                             end;
                                          end if;
                                       end;

                                    else
                                       Parse_Op_Processes (Instr, OpTok, Rest);
                                    end if;
end Parse_Op_Calls;