separate (Lang.VM.IR)
procedure Parse_Op_Arithmetic (Instr : in out Ir_Instr; OpTok : String; Rest : String) is
begin
                                    if OpTok = "add.int" or OpTok = "sub.int" or OpTok = "mul.int" or OpTok = "div.int" or OpTok = "mod.int" then
                                       if OpTok = "add.int" then Instr.Op := Op_Add_Int;
                                       elsif OpTok = "sub.int" then Instr.Op := Op_Sub_Int;
                                       elsif OpTok = "mul.int" then Instr.Op := Op_Mul_Int;
                                       elsif OpTok = "div.int" then Instr.Op := Op_Div_Int;
                                       else Instr.Op := Op_Mod_Int;
                                       end if;
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
                                          Instr.Has_Dest := True;
                                          Instr.Dest := Parse_Reg (Rest (Rest'First .. C1 - 1));
                                          Instr.Has_Src1 := True;
                                          Instr.Src1 := Parse_Reg (Rest (C1 + 1 .. C2 - 1));
                                          Instr.Has_Src2 := True;
                                          Instr.Src2 := Parse_Reg (Rest (C2 + 1 .. Rest'Last));
                                       end;
                                    elsif OpTok = "add.float" or OpTok = "sub.float" or OpTok = "mul.float" or OpTok = "div.float" then
                                       if OpTok = "add.float" then Instr.Op := Op_Add_Float;
                                       elsif OpTok = "sub.float" then Instr.Op := Op_Sub_Float;
                                       elsif OpTok = "mul.float" then Instr.Op := Op_Mul_Float;
                                       else Instr.Op := Op_Div_Float;
                                       end if;
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
                                          Instr.Has_Dest := True;
                                          Instr.Dest := Parse_Reg (Rest (Rest'First .. C1 - 1));
                                          Instr.Has_Src1 := True;
                                          Instr.Src1 := Parse_Reg (Rest (C1 + 1 .. C2 - 1));
                                          Instr.Has_Src2 := True;
                                          Instr.Src2 := Parse_Reg (Rest (C2 + 1 .. Rest'Last));
                                       end;
                                    elsif OpTok = "icmp" then
                                       Instr.Op := Op_Icmp;
                                       declare
                                          C1, C2, C3 : Natural := 0;
                                          Nc : Natural := 0;
                                       begin
                                          for K in Rest'Range loop
                                             if Rest (K) = ',' then
                                                Nc := Nc + 1;
                                                if Nc = 1 then C1 := K; elsif Nc = 2 then C2 := K; elsif Nc = 3 then C3 := K; end if;
                                             end if;
                                          end loop;
                                          Instr.Has_Dest := True;
                                          Instr.Dest := Parse_Reg (Rest (Rest'First .. C1 - 1));
                                          Instr.Has_Src1 := True;
                                          Instr.Src1 := Parse_Reg (Rest (C1 + 1 .. C2 - 1));
                                          Instr.Has_Src2 := True;
                                          Instr.Src2 := Parse_Reg (Rest (C2 + 1 .. C3 - 1));
                                          declare
                                             CT : constant String := Trim (Rest (C3 + 1 .. Rest'Last));
                                          begin
                                             if CT = "eq" then Instr.Cmp := Cmp_Eq;
                                             elsif CT = "ne" then Instr.Cmp := Cmp_Ne;
                                             elsif CT = "lt" then Instr.Cmp := Cmp_Lt;
                                             elsif CT = "le" then Instr.Cmp := Cmp_Le;
                                             elsif CT = "gt" then Instr.Cmp := Cmp_Gt;
                                             else Instr.Cmp := Cmp_Ge;
                                             end if;
                                          end;
                                       end;
                                    else
                                       Parse_Op_Control (Instr, OpTok, Rest);
                                    end if;
end Parse_Op_Arithmetic;