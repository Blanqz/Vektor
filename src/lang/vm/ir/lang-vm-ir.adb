with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Ada.Text_IO;
with Interfaces;

package body Lang.VM.IR is

   package Line_Vectors is new Ada.Containers.Vectors (Positive, Unbounded_String);

   function Trim (S : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (S, Ada.Strings.Both);
   end Trim;

   function Parse_Reg (S : String) return Natural is
      T : constant String := Trim (S);
   begin
      if T'Length > 2 and then T (T'First .. T'First + 1) = "%r" then
         return Natural'Value (T (T'First + 2 .. T'Last));
      else
         return 0;
      end if;
   exception
      when others => return 0;
   end Parse_Reg;


   function Parse (Text : String) return Ir_Module is
      M : Ir_Module;
      Lines : Line_Vectors.Vector;
      NLines : Natural := 0;
      I : Natural := 1;
   begin
      declare
         Start : Natural := Text'First;
      begin
         for J in Text'Range loop
            if Text (J) = ASCII.LF then
               NLines := NLines + 1;
               Lines.Append (To_Unbounded_String (Text (Start .. J - 1)));
               Start := J + 1;
            end if;
         end loop;
         if Start <= Text'Last then
            NLines := NLines + 1;
            Lines.Append (To_Unbounded_String (Text (Start .. Text'Last)));
         end if;
      end;

      if NLines >= 1 then
         declare
            L : Unbounded_String := To_Unbounded_String ("");
         begin
            for I in 1 .. NLines loop
               declare
                  Cand : constant String := Trim (To_String (Lines (I)));
               begin
                  if Cand'Length >= 6 and then Cand (Cand'First .. Cand'First + 5) = "DECLS:" then
                     null;
                  else
                     L := To_Unbounded_String (Cand);
                     exit;
                  end if;
               end;
            end loop;
            if To_String (L) = "ir 1" or else To_String (L) = "ir 2" then
               M.Version := 2;
            else
               raise Parse_Error with "unsupported IR version: " & To_String (L);
            end if;
         end;
      end if;

      I := 2;
      while I <= NLines loop
         declare
            L : constant String := Trim (To_String (Lines (I)));
         begin
            if L'Length = 0 then
               I := I + 1;
            elsif L'Length >= 4 and then L (L'First .. L'First + 3) = "func" then
               declare
                  P1 : Natural := 0;
                  P2 : Natural := 0;
                  Arrow : Natural := 0;
                  Brace : Natural := 0;
                  Name : Unbounded_String;
                  Params_Str : String (1 .. 0) := (others => ' ');
               begin
                  for K in L'Range loop
                     if L (K) = '(' then P1 := K; exit; end if;
                  end loop;
                  for K in P1 .. L'Last loop
                     if L (K) = ')' then P2 := K; exit; end if;
                  end loop;
                  Name := To_Unbounded_String (Trim (L (L'First + 4 .. P1 - 1)));
                  for K in P2 .. L'Last loop
                     if K + 1 <= L'Last and then L (K) = '-' and then L (K + 1) = '>' then
                        Arrow := K; exit;
                     end if;
                  end loop;
                  declare
                     RetStr : constant String := Trim (L (Arrow + 2 .. L'Last));
                     RetCleanRaw : constant String := Trim (RetStr (RetStr'First .. (if RetStr'Last > 0 and then RetStr (RetStr'Last) = '{' then RetStr'Last - 1 else RetStr'Last)));
                     F : Ir_Func;
                     OwnedVal : Natural := 0;
                     FlagsVal : Natural := 0;
                     RetClean : String := RetCleanRaw;
                     Param_List : constant String := Trim (L (P1 + 1 .. P2 - 1));
                  begin
                     declare
                        OwnedPos : Natural := 0;
                     begin
                        -- Find 'owned' keyword
                        for K in RetClean'First .. RetClean'Last - 5 loop
                           if RetClean (K .. K + 5) = "owned " then
                              OwnedPos := K;
                              exit;
                           end if;
                        end loop;
                        if OwnedPos > 0 then
                           OwnedVal := Natural'Value (Trim (RetClean (OwnedPos + 6 .. RetClean'Last)));
                           RetClean := Trim (RetClean (RetClean'First .. OwnedPos - 1));
                        end if;
                        -- Find flags keyword
                        declare
                           FlagsPos : Natural := 0;
                        begin
                           for K in RetClean'First .. RetClean'Last - 5 loop
                              if RetClean (K .. K + 5) = "flags " then
                                 FlagsPos := K;
                                 exit;
                              end if;
                           end loop;
                           if FlagsPos > 0 then
                              FlagsVal := Natural'Value (Trim (RetClean (FlagsPos + 6 .. RetClean'Last)));
                              RetClean := Trim (RetClean (RetClean'First .. FlagsPos - 1));
                           end if;
                        end;
                     end;
                     F.Name := Name;
                     F.Ret_Type := To_Unbounded_String (RetClean);
                     F.Owned_Mask := Interfaces.Unsigned_32 (OwnedVal);
                     F.Flags := FlagsVal;
                     if Param_List'Length > 0 then
                        declare
                           Start : Natural := Param_List'First;
                        begin
                           for K in Param_List'Range loop
                              if K = Param_List'Last or else Param_List (K + 1) = ',' then
                                 declare
                                    Seg : constant String := Trim (Param_List (Start .. K));
                                    Colon : Natural := 0;
                                 begin
                                    for C in Seg'Range loop
                                       if Seg (C) = ':' then Colon := C; exit; end if;
                                    end loop;
                                    if Colon > 0 then
                                       declare
                                          P : Ir_Param;
                                       begin
                                          P.Name := To_Unbounded_String (Trim (Seg (Seg'First .. Colon - 1)));
                                          P.Typ  := To_Unbounded_String (Trim (Seg (Colon + 1 .. Seg'Last)));
                                          F.Params.Append (P);
                                       end;
                                    end if;
                                 end;
                                 Start := K + 2;
                              end if;
                           end loop;
                        end;
                     end if;
                     I := I + 1;
                     while I <= NLines loop
                        declare
                           BLine : constant String := Trim (To_String (Lines (I)));
                        begin
                           if BLine = "}" then
                              I := I + 1;
                              exit;
                           elsif BLine'Length = 0 then
                              I := I + 1;
                           else
                              declare
                                 Instr : Ir_Instr;
                                 FirstSpace : Natural := 0;
                              begin
                                 for K in BLine'Range loop
                                    if BLine (K) = ' ' then FirstSpace := K; exit; end if;
                                 end loop;
                                 declare
                                    OpTok : constant String := (if FirstSpace = 0 then BLine else BLine (BLine'First .. FirstSpace - 1));
                                    Rest  : constant String := (if FirstSpace = 0 then "" else Trim (BLine (FirstSpace + 1 .. BLine'Last)));
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
                                                Instr.Imm_Str := To_Unbounded_String (S (S'First + 1 .. S'Last - 1));
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
                                    elsif OpTok = "add.int" or OpTok = "sub.int" or OpTok = "mul.int" or OpTok = "div.int" or OpTok = "mod.int" then
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
                                    elsif OpTok = "br" then
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
                                    elsif OpTok = "call" then
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
                                    elsif OpTok = "ret" then
                                       Instr.Op := Op_Ret;
                                       if Rest'Length > 0 then
                                          Instr.Has_Src1 := True;
                                          Instr.Src1 := Parse_Reg (Rest);
                                       end if;
                                    elsif OpTok = "spawn" then
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
                                    elsif OpTok = "self" then
                                       Instr.Op := Op_Self;
                                       Instr.Has_Dest := True;
                                       Instr.Dest := Parse_Reg (Rest);
                                    elsif OpTok = "drop" then
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
                                    elsif OpTok = "dyn.call" then
                                       Instr.Op := Op_DynCall;
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
                                          Instr.Method_Index := Natural'Value (Trim (Rest (C2 + 1 .. Rest'Last)));
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

                                    elsif OpTok = "safepoint" then
                                       Instr.Op := Op_Safepoint;


                                    else
                                       raise Parse_Error with "unknown opcode: " & OpTok;
                                    end if;
                                 end;
                                 F.Instrs.Append (Instr);
                              end;
                              I := I + 1;
                           end if;
                        end;
                     end loop;
                     M.Funcs.Append (F);
                  end;
               end;
            else
               I := I + 1;
            end if;
         end;
      end loop;

      return M;
   end Parse;

   function Image (M : Ir_Module) return String is
      Result : Unbounded_String := To_Unbounded_String ("ir 2" & ASCII.LF);
   begin
      for F of M.Funcs loop
         Result := Result & "func " & F.Name & "(";
         for I in 1 .. Natural (F.Params.Length) loop
            if I > 1 then Result := Result & ", "; end if;
            Result := Result & F.Params (I).Name & " : " & F.Params (I).Typ;
         end loop;
         if Natural (F.Owned_Mask) /= 0 and then F.Flags /= 0 then
            Result := Result & ") -> " & F.Ret_Type & " owned " & Trim (Natural'Image (Natural (F.Owned_Mask))) & " flags " & Trim (Natural'Image (F.Flags)) & " {" & ASCII.LF;
         elsif Natural (F.Owned_Mask) /= 0 then
            Result := Result & ") -> " & F.Ret_Type & " owned " & Trim (Natural'Image (Natural (F.Owned_Mask))) & " {" & ASCII.LF;
         elsif F.Flags /= 0 then
            Result := Result & ") -> " & F.Ret_Type & " flags " & Trim (Natural'Image (F.Flags)) & " {" & ASCII.LF;
         else
            Result := Result & ") -> " & F.Ret_Type & " {" & ASCII.LF;
         end if;
         for Ins of F.Instrs loop
            Result := Result & "  ";
            case Ins.Op is
               when Op_Const_Int =>
                  Result := Result & "const.int   " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & Trim (Interfaces.Integer_64'Image (Ins.Imm_Int));
               when Op_Const_None =>
                  Result := Result & "const.none  " & "%r" & Trim (Natural'Image (Ins.Dest));
               when Op_Const_Float =>
                  Result := Result & "const.float " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & Long_Float'Image (Ins.Imm_Float);
               when Op_Const_Bool =>
                  Result := Result & "const.bool  " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & (if Ins.Imm_Bool then "true" else "false");
               when Op_Const_Str =>
                  Result := Result & "const.str   " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & '"' & Ins.Imm_Str & '"';
               when Op_Move =>
                  Result := Result & "move        " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & "%r" & Trim (Natural'Image (Ins.Src1));
               when Op_Add_Int =>
                  Result := Result & "add.int     " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & "%r" & Trim (Natural'Image (Ins.Src1)) & ", " & "%r" & Trim (Natural'Image (Ins.Src2));
               when Op_Sub_Int =>
                  Result := Result & "sub.int     " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & "%r" & Trim (Natural'Image (Ins.Src1)) & ", " & "%r" & Trim (Natural'Image (Ins.Src2));
               when Op_Mul_Int =>
                  Result := Result & "mul.int     " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & "%r" & Trim (Natural'Image (Ins.Src1)) & ", " & "%r" & Trim (Natural'Image (Ins.Src2));
               when Op_Div_Int =>
                  Result := Result & "div.int     " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & "%r" & Trim (Natural'Image (Ins.Src1)) & ", " & "%r" & Trim (Natural'Image (Ins.Src2));
               when Op_Mod_Int =>
                  Result := Result & "mod.int     " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & "%r" & Trim (Natural'Image (Ins.Src1)) & ", " & "%r" & Trim (Natural'Image (Ins.Src2));
               when Op_Add_Float =>
                  Result := Result & "add.float   " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & "%r" & Trim (Natural'Image (Ins.Src1)) & ", " & "%r" & Trim (Natural'Image (Ins.Src2));
               when Op_Sub_Float =>
                  Result := Result & "sub.float   " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & "%r" & Trim (Natural'Image (Ins.Src1)) & ", " & "%r" & Trim (Natural'Image (Ins.Src2));
               when Op_Mul_Float =>
                  Result := Result & "mul.float   " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & "%r" & Trim (Natural'Image (Ins.Src1)) & ", " & "%r" & Trim (Natural'Image (Ins.Src2));
               when Op_Div_Float =>
                  Result := Result & "div.float   " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & "%r" & Trim (Natural'Image (Ins.Src1)) & ", " & "%r" & Trim (Natural'Image (Ins.Src2));
               when Op_Icmp =>
                  Result := Result & "icmp        " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & "%r" & Trim (Natural'Image (Ins.Src1)) & ", " & "%r" & Trim (Natural'Image (Ins.Src2)) & ", " &
                     (case Ins.Cmp is
                        when Cmp_Eq => "eq", when Cmp_Ne => "ne", when Cmp_Lt => "lt",
                        when Cmp_Le => "le", when Cmp_Gt => "gt", when others => "ge");
               when Op_Br =>
                  Result := Result & "br          " & "%r" & Trim (Natural'Image (Ins.Src1)) & ", " & Ins.Label & ", " & Ins.Imm_Str;
               when Op_Jmp =>
                  Result := Result & "jmp         " & Ins.Label;
               when Op_Label =>
                  Result := Result & "label       " & Ins.Label & ":";
               when Op_Call =>
                  Result := Result & "call        " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & Ins.Func_Name;
                  for A of Ins.Args loop
                     Result := Result & ", " & "%r" & Trim (Natural'Image (A));
                  end loop;
               when Op_Ret =>
                  if Ins.Has_Src1 then
                     Result := Result & "ret         " & "%r" & Trim (Natural'Image (Ins.Src1));
                  else
                     Result := Result & "ret";
                  end if;
               when Op_Safepoint =>
                  Result := Result & "safepoint";
               when Op_Phi =>
                  Result := Result & "phi";
               when Op_Spawn =>
                  Result := Result & "spawn       " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & Ins.Spawn_Func;
               when Op_Send =>
                  Result := Result & "send        " & "%r" & Trim (Natural'Image (Ins.Send_Target)) & ", " & "%r" & Trim (Natural'Image (Ins.Send_Msg));
               when Op_Receive =>
                  Result := Result & "receive     " & "%r" & Trim (Natural'Image (Ins.Recv_Dest));
                  if Ins.Recv_Pattern > 0 then
                     Result := Result & ", %r" & Trim (Natural'Image (Ins.Recv_Pattern));
                  end if;
                  if Ins.Recv_Guard > 0 then
                     Result := Result & ", %r" & Trim (Natural'Image (Ins.Recv_Guard));
                  end if;
                  if Ins.Recv_Timeout > 0 then
                     Result := Result & ", " & Trim (Natural'Image (Ins.Recv_Timeout));
                  end if;
               when Op_Self =>
                  Result := Result & "self        " & "%r" & Trim (Natural'Image (Ins.Dest));
               when Op_Drop =>
                  Result := Result & "drop        " & "%r" & Trim (Natural'Image (Ins.Src1));
               when Op_FfiCall =>
                  Result := Result & "ffi.call    " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & Ins.Func_Name;
                  for J in 1 .. Natural (Ins.Args.Length) loop
                     Result := Result & ", %r" & Trim (Natural'Image (Ins.Args (J)));
                  end loop;
               when Op_New =>
                  Result := Result & "new         " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & Ins.New_Type;
               when Op_FieldGet =>
                  Result := Result & "field.get   " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & "%r" & Trim (Natural'Image (Ins.Src1)) & ", " & Trim (Natural'Image (Ins.Field_Index));
               when Op_FieldSet =>
                  Result := Result & "field.set   " & "%r" & Trim (Natural'Image (Ins.Src1)) & ", " & Trim (Natural'Image (Ins.Field_Index)) & ", " & "%r" & Trim (Natural'Image (Ins.Src2));
               when Op_RefNew =>
                  Result := Result & "ref.new     " & "%r" & Trim (Natural'Image (Ins.Dest));
               when Op_RefGet =>
                  Result := Result & "ref.get     " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & "%r" & Trim (Natural'Image (Ins.Src1));
               when Op_RefSet =>
                  Result := Result & "ref.set     " & "%r" & Trim (Natural'Image (Ins.Src1)) & ", " & "%r" & Trim (Natural'Image (Ins.Src2));
               when Op_VTableNew =>
                  Result := Result & "vtable.new  " & "%r" & Trim (Natural'Image (Ins.Dest));
                  for A of Ins.Args loop
                     Result := Result & ", " & Trim (Natural'Image (A));
                  end loop;
               when Op_DynNew =>
                  Result := Result & "dyn.new     " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & "%r" & Trim (Natural'Image (Ins.Src1)) & ", " & "%r" & Trim (Natural'Image (Ins.Src2));
               when Op_DynCall =>
                  Result := Result & "dyn.call    " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & "%r" & Trim (Natural'Image (Ins.Src1)) & ", " & Trim (Natural'Image (Ins.Method_Index));
               when Op_FuncRef =>
                  Result := Result & "func.ref    " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & Ins.Func_Name;
                  for A of Ins.Args loop
                     Result := Result & ", " & "%r" & Trim (Natural'Image (A));
                  end loop;
               when Op_Call_Indirect =>
                  Result := Result & "call.indirect " & "%r" & Trim (Natural'Image (Ins.Dest)) & ", " & "%r" & Trim (Natural'Image (Ins.Src1));
                  for A of Ins.Args loop
                     Result := Result & ", " & "%r" & Trim (Natural'Image (A));
                  end loop;
            end case;
            Result := Result & ASCII.LF;
         end loop;
         Result := Result & "}" & ASCII.LF;
      end loop;
      return To_String (Result);
   end Image;

end Lang.VM.IR;