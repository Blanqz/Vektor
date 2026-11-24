separate (Lang.VM.IR)
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
         Parse_Op_Values (Instr, OpTok, Rest);
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