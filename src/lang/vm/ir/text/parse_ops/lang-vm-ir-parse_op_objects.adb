separate (Lang.VM.IR)
procedure Parse_Op_Objects (Instr : in out Ir_Instr; OpTok : String; Rest : String) is
begin
                                    if OpTok = "drop" then
                                       Instr.Op := Op_Drop;
                                       Instr.Has_Src1 := True;
                                       Instr.Src1 := Parse_Reg (Rest);
                                    elsif OpTok = "new" then
                                       Instr.Op := Op_New;
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
                                                   Instr.New_Type := To_Unbounded_String (Trim (After));
                                                else
                                                   Instr.New_Type := To_Unbounded_String (Trim (After (After'First .. Sp - 1)));
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
                                    elsif OpTok = "field.get" then
                                       Instr.Op := Op_FieldGet;
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
                                          Instr.Field_Index := Natural'Value (Trim (Rest (C2 + 1 .. Rest'Last)));
                                       end;
                                    elsif OpTok = "field.set" then
                                       Instr.Op := Op_FieldSet;
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
                                          Instr.Field_Index := Natural'Value (Trim (Rest (C1 + 1 .. C2 - 1)));
                                          Instr.Has_Src2 := True;
                                          Instr.Src2 := Parse_Reg (Rest (C2 + 1 .. Rest'Last));
                                       end;
                                    elsif OpTok = "ref.new" then
                                       Instr.Op := Op_RefNew;
                                       declare
                                          Comma : Natural := 0;
                                       begin
                                          for K in Rest'Range loop
                                             if Rest (K) = ',' then Comma := K; exit; end if;
                                          end loop;
                                          if Comma > 0 then
                                             Instr.Has_Dest := True;
                                             Instr.Dest := Parse_Reg (Rest (Rest'First .. Comma - 1));
                                             Instr.Has_Src1 := True;
                                             Instr.Src1 := Parse_Reg (Rest (Comma + 1 .. Rest'Last));
                                          else
                                             Instr.Has_Dest := True;
                                             Instr.Dest := Parse_Reg (Rest);
                                          end if;
                                       end;
                                    elsif OpTok = "ref.get" then
                                       Instr.Op := Op_RefGet;
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
                                    elsif OpTok = "ref.set" then
                                       Instr.Op := Op_RefSet;
                                       declare
                                          Comma : Natural := 0;
                                       begin
                                          for K in Rest'Range loop
                                             if Rest (K) = ',' then Comma := K; exit; end if;
                                          end loop;
                                          Instr.Has_Src1 := True;
                                          Instr.Src1 := Parse_Reg (Rest (Rest'First .. Comma - 1));
                                          Instr.Has_Src2 := True;
                                          Instr.Src2 := Parse_Reg (Rest (Comma + 1 .. Rest'Last));
                          
                                       end;
                                    elsif OpTok = "vtable.new" then
                                       Instr.Op := Op_VTableNew;
                                       declare
                                          C0 : Natural := 0;
                                       begin
                                          for K in Rest'Range loop
                                             if Rest (K) = ',' then C0 := K; exit; end if;
                                          end loop;
                                          Instr.Has_Dest := True;
                                          if C0 > 0 then
                                             Instr.Dest := Parse_Reg (Rest (Rest'First .. C0 - 1));
                                          else
                                             Instr.Dest := Parse_Reg (Rest);
                                          end if;
                                       end;
                                       declare
                                          Comma : Natural := 0;
                                          SegStart : Natural := 0;
                                       begin
                                          for K in Rest'Range loop
                                             if Rest (K) = ',' then Comma := K; exit; end if;
                                          end loop;
                                          if Comma > 0 then
                                             declare
                                                After : constant String := Trim (Rest (Comma + 1 .. Rest'Last));
                                                Start : Natural := After'First;
                                             begin
                                                for K in After'Range loop
                                                   if K = After'Last or else After (K + 1) = ',' then
                                                      Instr.Args.Append (Natural'Value (Trim (After (Start .. K))));
                                                      Start := K + 2;
                                                   end if;
                                                end loop;
                                             end;
                                          end if;
                                       end;
                                    elsif OpTok = "dyn.new" then
                                       Instr.Op := Op_DynNew;
                                       declare
                                          C1 : Natural := 0;
                                       begin
                                          for K in Rest'Range loop
                                             if Rest (K) = ',' then C1 := K; exit; end if;
                                          end loop;
                                          Instr.Has_Dest := True;
                                          Instr.Dest := Parse_Reg (Rest (Rest'First .. C1 - 1));
                                          declare
                                             After : constant String := Trim (Rest (C1 + 1 .. Rest'Last));
                                             C2 : Natural := 0;
                                          begin
                                             for K in After'Range loop
                                                if After (K) = ',' then C2 := K; exit; end if;
                                             end loop;
                                             if C2 > 0 then
                                                Instr.Has_Src1 := True;
                                                Instr.Src1 := Parse_Reg (After (After'First .. C2 - 1));
                                                Instr.Has_Src2 := True;
                                                Instr.Src2 := Parse_Reg (After (C2 + 1 .. After'Last));
                                             else
                                                Instr.Has_Src1 := True;
                                                Instr.Src1 := Parse_Reg (After);
                                             end if;
                                          end;
                                       end;
                                    else
                                       raise Parse_Error with "unknown opcode: " & OpTok;
                                    end if;
end Parse_Op_Objects;