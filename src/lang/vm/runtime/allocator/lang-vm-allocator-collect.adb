separate (Lang.VM.Allocator)
   procedure Collect (M : in out Lang.VM.Machine.Machine) is
   begin
      M.GC_Generation := M.GC_Generation + 1;
      M.Major_GC := (M.GC_Generation mod 10 = 0);
      for PI in 1 .. Natural (M.Processes.Length) loop
         declare
            P : constant Process_Access := M.Processes (PI);
            Work : Index_Array_Access := new Index_Array (1 .. P.Obj_Cap);
            Top  : Natural := 0;

            procedure Mark_Pinned is
            begin
               for I in 1 .. P.Obj_Cap loop
                  if Obj_At (P, I).In_Use and then Obj_At (P, I).Pinned and then not Obj_At (P, I).Marked then
                     Obj_At (P, I).Marked := True;
                     Top := Top + 1;
                     Work (Top) := I;
                  end if;
               end loop;
               for I in 1 .. P.Str_Cap loop
                  if Str_At (P, I).In_Use and then Str_At (P, I).Pinned then
                     Str_At (P, I).Marked := True;
                  end if;
               end loop;
            end Mark_Pinned;

            procedure Mark (W : TW) is
               S : Natural;
            begin
               if not Is_Heap_Pointer (W) then
                  return;
               end if;
               S := Str_Slot (P, W);
               if S > 0 then
                  Str_At (P, S).Marked := True;
               else
                  S := Obj_Slot (P, W);
               if S > 0 then
                  if not Obj_At (P, S).Marked then
                     Obj_At (P, S).Marked := True;
                     Top := Top + 1;
                     Work (Top) := S;
                  end if;
               else
                  S := Box_Slot (P, W);
                  if S > 0 then
                     Box_At (P, S).Marked := True;
                  end if;
               end if;
               end if;
            end Mark;
         begin
            Mark_Pinned;
            Mark (P.Result);
            if P.Status /= Proc_Dead then
               for F in 1 .. P.Depth loop
                  for I in 0 .. P.Frames (F).Reg_Count - 1 loop
                     Mark (P.Stack (P.Frames (F).Base + I));
                  end loop;
               end loop;
               for I in 0 .. P.Mail_Count - 1 loop
                  Mark (P.Mail (((P.Mail_Head + I) mod P.Mail.all'Length) + 1));
               end loop;
            end if;

            while Top > 0 loop
               declare
                  S : constant Natural := Work (Top);
               begin
                  Top := Top - 1;
                  for I in 1 .. Obj_At (P, S).Count loop
                     Mark (Obj_At (P, S).Fields (I));
                  end loop;
                  if Obj_At (P, S).Count >= 2 then
                     declare
                        VIdx : constant Natural := Natural (Unbox_Small_Int (Obj_At (P, S).Fields (2)));
                     begin
                        if VIdx >= 1 and then VIdx <= P.VT_Cap and then VT_At (P, VIdx).In_Use then
                           VT_At (P, VIdx).Marked := True;
                        end if;
                     end;
                  end if;
               end;
            end loop;

            for I in 1 .. P.Str_Cap loop
               if Str_At (P, I).In_Use and then not Str_At (P, I).Pinned and then not Str_At (P, I).Marked then
                  if M.Major_GC or else Str_At (P, I).Gen >= M.GC_Generation - 1 then
                     if Str_At (P, I).Large and then Str_At (P, I).Buf_Id > 0 then
                        Release_Large_Buffer (P, Str_At (P, I).Buf_Id);
                     end if;
                     Str_At (P, I).In_Use := False;
                     Str_At (P, I).Chars := Null_Unbounded_String;
                     Str_At (P, I).Large := False;
                     Str_At (P, I).Buf_Id := 0;
                  end if;
               end if;
               Str_At (P, I).Marked := False;
            end loop;

            P.Str_Free_Top := 0;
            for I in reverse 1 .. P.Str_Cap loop
               if not Str_At (P, I).In_Use then
                  P.Str_Free_Top := P.Str_Free_Top + 1;
                  P.Str_Free (P.Str_Free_Top) := I;
               end if;
            end loop;

            for I in 1 .. P.Obj_Cap loop
               if Obj_At (P, I).In_Use and then not Obj_At (P, I).Marked then
                  if M.Major_GC or else Obj_At (P, I).Gen >= M.GC_Generation - 1 then
                     Obj_At (P, I).In_Use := False;
                     Obj_At (P, I).Count := 0;
                     Obj_At (P, I).Type_Name := To_Unbounded_String ("");
                     Free_Values (Obj_At (P, I).Fields);
                     Obj_At (P, I).Fields := null;
                  end if;
               end if;
               Obj_At (P, I).Marked := False;
            end loop;

            P.Str_Free_Top := 0;
            for I in reverse 1 .. P.Str_Cap loop
               if not Str_At (P, I).In_Use then
                  P.Str_Free_Top := P.Str_Free_Top + 1;
                  P.Str_Free (P.Str_Free_Top) := I;
               end if;
            end loop;

            P.Obj_Free_Top := 0;
            for I in reverse 1 .. P.Obj_Cap loop
               if not Obj_At (P, I).In_Use then
                  P.Obj_Free_Top := P.Obj_Free_Top + 1;
                  P.Obj_Free (P.Obj_Free_Top) := I;
               end if;
            end loop;

            for I in 1 .. P.VT_Cap loop
               if VT_At (P, I).In_Use and then not VT_At (P, I).Marked then
                  if M.Major_GC then
                     VT_At (P, I).In_Use := False;
                     Free_Natural_Array (VT_At (P, I).Methods);
                     VT_At (P, I).Methods := null;
                  end if;
               end if;
               VT_At (P, I).Marked := False;
            end loop;

            P.VT_Free_Top := 0;
            for I in reverse 1 .. P.VT_Cap loop
               if not VT_At (P, I).In_Use then
                  P.VT_Free_Top := P.VT_Free_Top + 1;
                  P.VT_Free (P.VT_Free_Top) := I;
               end if;
            end loop;
            for I in 1 .. P.Box_Cap loop
               if Box_At (P, I).In_Use and then not Box_At (P, I).Marked then
                  if M.Major_GC or else Box_At (P, I).Gen >= M.GC_Generation - 1 then
                     Box_At (P, I).In_Use := False;
                     Box_At (P, I).Value := 0;
                  end if;
               end if;
               Box_At (P, I).Marked := False;
            end loop;

            P.Box_Free_Top := 0;
            for I in reverse 1 .. P.Box_Cap loop
               if not Box_At (P, I).In_Use then
                  P.Box_Free_Top := P.Box_Free_Top + 1;
                  P.Box_Free (P.Box_Free_Top) := I;
               end if;
            end loop;
            if M.Major_GC then
               Compact_Strings (M, P);
            end if;
            null;
         end;
      end loop;
      M.Allocations_Since_GC := 0;
   end Collect;