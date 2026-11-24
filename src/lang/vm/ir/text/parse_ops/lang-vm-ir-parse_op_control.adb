separate (Lang.VM.IR)
procedure Parse_Op_Control (Instr : in out Ir_Instr; OpTok : String; Rest : String) is
begin
                                    if OpTok = "br" then
                                       Instr.Op := Op_Br;
                                       declare
                                          C1, C2 : Natural := 0;
                                          Nc : Natural := 0;
                                       begin
                                          for K in Rest'Range loop
                                             if Rest (K) = ',' then
                                                Nc := Nc + 1;
                                                if Nc = 1 then C1 := K; elsif Nc = 2 then C2 := K; end if;
                                             end if;
                                          end loop;
                                          Instr.Has_Src1 := True;
                                          Instr.Src1 := Parse_Reg (Rest (Rest'First .. C1 - 1));
                                          Instr.Label := To_Unbounded_String (Trim (Rest (C1 + 1 .. C2 - 1)));
                                          Instr.Imm_Str := To_Unbounded_String (Trim (Rest (C2 + 1 .. Rest'Last)));
                                       end;
                                    elsif OpTok = "jmp" then
                                       Instr.Op := Op_Jmp;
                                       Instr.Label := To_Unbounded_String (Trim (Rest));
                                    elsif OpTok = "label" then
                                       Instr.Op := Op_Label;
                                       declare
                                          S : constant String := Trim (Rest);
                                       begin
                                          if S'Length > 0 and then S (S'Last) = ':' then
                                             Instr.Label := To_Unbounded_String (S (S'First .. S'Last - 1));
                                          else
                                             Instr.Label := To_Unbounded_String (S);
                                          end if;
                                       end;
                                    elsif OpTok = "ret" then
                                       Instr.Op := Op_Ret;
                                       if Rest'Length > 0 then
                                          Instr.Has_Src1 := True;
                                          Instr.Src1 := Parse_Reg (Rest);
                                       end if;
                                    elsif OpTok = "safepoint" then
                                       Instr.Op := Op_Safepoint;


                                    else
                                       Parse_Op_Calls (Instr, OpTok, Rest);
                                    end if;
end Parse_Op_Control;