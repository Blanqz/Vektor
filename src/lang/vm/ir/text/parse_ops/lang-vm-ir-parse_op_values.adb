separate (Lang.VM.IR)
procedure Parse_Op_Values (Instr : in out Ir_Instr; OpTok : String; Rest : String) is
begin
                                    if OpTok = "const.int" then
                                       Instr.Op := Op_Const_Int;
                                       declare
                                          Comma : Natural := 0;
                                       begin
                                          for K in Rest'Range loop
                                             if Rest (K) = ',' then Comma := K; exit; end if;
                                          end loop;
                                          Instr.Has_Dest := True;
                                          Instr.Dest := Parse_Reg (Rest (Rest'First .. Comma - 1));
                                          Instr.Imm_Int := Interfaces.Integer_64'Value (Trim (Rest (Comma + 1 .. Rest'Last)));
                                       end;
                                    elsif OpTok = "const.none" then
                                       Instr.Op := Op_Const_None;
                                       Instr.Has_Dest := True;
                                       Instr.Dest := Parse_Reg (Rest);
                                    elsif OpTok = "const.float" then
                                       Instr.Op := Op_Const_Float;
                                       declare
                                          Comma : Natural := 0;
                                       begin
                                          for K in Rest'Range loop
                                             if Rest (K) = ',' then Comma := K; exit; end if;
                                          end loop;
                                          Instr.Has_Dest := True;
                                          Instr.Dest := Parse_Reg (Rest (Rest'First .. Comma - 1));
                                          Instr.Imm_Float := Long_Float'Value (Trim (Rest (Comma + 1 .. Rest'Last)));
                                       end;
                                    elsif OpTok = "const.bool" then
                                       Instr.Op := Op_Const_Bool;
                                       declare
                                          Comma : Natural := 0;
                                       begin
                                          for K in Rest'Range loop
                                             if Rest (K) = ',' then Comma := K; exit; end if;
                                          end loop;
                                          Instr.Has_Dest := True;
                                          Instr.Dest := Parse_Reg (Rest (Rest'First .. Comma - 1));
                                          Instr.Imm_Bool := (Trim (Rest (Comma + 1 .. Rest'Last)) = "true");
                                       end;
                                    elsif OpTok = "const.str" then
                                       Instr.Op := Op_Const_Str;
                                       declare
                                          Comma : Natural := 0;
                                       begin
                                          for K in Rest'Range loop
                                             if Rest (K) = ',' then Comma := K; exit; end if;
                                          end loop;
                                          Instr.Has_Dest := True;
                                          Instr.Dest := Parse_Reg (Rest (Rest'First .. Comma - 1));
                                          declare
                                             S : constant String := Trim (Rest (Comma + 1 .. Rest'Last));
                                          begin
                                             if S'Length >= 2 and then S (S'First) = '"' and then S (S'Last) = '"' then
                                                Instr.Imm_Str := To_Unbounded_String (Unescape_IR (S (S'First + 1 .. S'Last - 1)));
                                             else
                                                Instr.Imm_Str := To_Unbounded_String (S);
                                             end if;
                                          end;
                                       end;
                                    elsif OpTok = "move" then
                                       Instr.Op := Op_Move;
                                       declare
                                          Comma : Natural := 0;
                                       begin
                                          for K in Rest'Range loop
                                             if Rest (K) = ',' then Comma := K; exit; end if;
                                          end loop;
                                          Instr.Has_Dest := True;
                                          Instr.Dest := Parse_Reg (Rest (Rest'First .. Comma - 1));
                                          Instr.Has_Src1 := True;
                                          Instr.Src1 := Parse_Reg (Rest (Comma + 1 .. Rest'Last));
                                       end;
         elsif OpTok = "func.ref" or OpTok = "closure.new" or OpTok = "func_ref" then
                                       Instr.Op := Op_FuncRef;
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

                                    else
                                       Parse_Op_Arithmetic (Instr, OpTok, Rest);
                                    end if;
end Parse_Op_Values;