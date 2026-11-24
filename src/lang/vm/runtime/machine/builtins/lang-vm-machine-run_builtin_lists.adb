separate (Lang.VM.Machine)
   procedure Run_Builtin_Lists (M    : in out Machine;
                          P    : Process_Access;
                          Base : Natural;
                          Ins  : VC.Code_Instr) is
      function Arg (I : Positive) return TW is
      begin
         return P.Stack (Base + M.Prog.Args (Ins.Args_First + I - 1));
      end Arg;

      procedure Set_Dest (W : TW) is
      begin
         P.Stack (Base + Ins.Dest) := W;
      end Set_Dest;
begin
      case Ins.Builtin is
         when VC.Bi_List_Append =>
            if Ins.Args_Count >= 2 then
               declare
                  L : constant TW := Arg (1);
                  V : constant TW := Arg (2);
                  O : constant Natural := Obj_Slot (P, L);
               begin
                  if O > 0 then
                     declare
                        Old_Count : constant Natural := Obj_At (P, O).Count;
                        Cap       : constant Natural :=
                          (if Obj_At (P, O).Fields = null then 0 else Obj_At (P, O).Fields.all'Length);
                     begin
                        if Old_Count >= Cap then
                           declare
                              New_Cap : constant Natural := Natural'Max (4, 2 * Old_Count);
                              F       : constant Value_Array_Access := new Value_Array (1 .. New_Cap);
                           begin
                              if Old_Count > 0 then
                                 F (1 .. Old_Count) := Obj_At (P, O).Fields (1 .. Old_Count);
                              end if;
                              if Obj_At (P, O).Fields /= null then
                                 Free_Values (Obj_At (P, O).Fields);
                              end if;
                              Obj_At (P, O).Fields := F;
                           end;
                        end if;
                        Obj_At (P, O).Fields (Old_Count + 1) := V;
                        Obj_At (P, O).Count := Old_Count + 1;
                        if Ins.Has_Dest then
                           Set_Dest (L);
                        end if;
                     end;
                  end if;
               end;
            end if;

         when VC.Bi_List_Pop =>
            if Ins.Args_Count >= 1 then
               declare
                  L : constant TW := Arg (1);
                  O : constant Natural := Obj_Slot (P, L);
               begin
                  if O > 0 and then Obj_At (P, O).Count > 0 then
                     declare
                        N : constant Natural := Obj_At (P, O).Count;
                        V : constant TW := Obj_At (P, O).Fields (N);
                     begin
                        Obj_At (P, O).Fields (N) := Make_None;
                        Obj_At (P, O).Count := N - 1;
                        if Ins.Has_Dest then
                           Set_Dest (V);
                        end if;
                     end;
                  elsif Ins.Has_Dest then
                     Set_Dest (Make_None);
                  end if;
               end;
            end if;

         when VC.Bi_List_Set =>
            if Ins.Args_Count >= 3 then
               declare
                  L : constant TW := Arg (1);
                  I : constant Integer_64 := Unbox_Small_Int (Arg (2));
                  V : constant TW := Arg (3);
                  O : constant Natural := Obj_Slot (P, L);
               begin
                  if O > 0 and then I >= 0 and then I < Integer_64 (Obj_At (P, O).Count) then
                     Obj_At (P, O).Fields (Natural (I) + 1) := V;
                  else
                     raise Constraint_Error with "list index " & Index_Text (I) & " out of range";
                  end if;
                  if Ins.Has_Dest then
                     Set_Dest (Make_Unit);
                  end if;
               end;
            end if;

         when VC.Bi_List_Get =>
            if Ins.Args_Count >= 2 then
               declare
                  L : constant TW := Arg (1);
                  I : constant Integer_64 := Unbox_Small_Int (Arg (2));
                  O : constant Natural := Obj_Slot (P, L);
               begin
                  if O > 0 and then I >= 0 and then I < Integer_64 (Obj_At (P, O).Count) then
                     if Ins.Has_Dest then
                        Set_Dest (Obj_At (P, O).Fields (Natural (I) + 1));
                     end if;
                  else
                     raise Constraint_Error with "list index " & Index_Text (I) & " out of range";
                  end if;
               end;
            end if;

         when VC.Bi_List_Len =>
            if Ins.Args_Count >= 1 then
               declare
                  L : constant TW := Arg (1);
                  O : constant Natural := Obj_Slot (P, L);
                  Len : constant Integer_64 := (if O > 0 then Integer_64 (Obj_At (P, O).Count) else 0);
               begin
                  if Ins.Has_Dest then
                     Set_Dest (Make_Small_Int (Len));
                  end if;
               end;
            end if;

         when others => null;
      end case;
end Run_Builtin_Lists;