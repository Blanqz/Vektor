separate (Lang.VM.Machine)
   procedure Run_Slice_Objects (M : in out Machine; P : Process_Access; D : in out Natural; Fr : in out Frame; Fn : in out VC.Func_Code; Base : in out Natural; S : in out Value_Array_Access; Pc : in out Natural; Ins : VC.Code_Instr) is
   begin
      case Ins.Op is
                     when Op_New =>
                        declare
                           Slot : constant Natural := Allocator.Alloc_Obj (M, P);
                           N    : constant Natural := Ins.Args_Count;
                           F    : constant Value_Array_Access := new Value_Array (1 .. N);
                        begin
                           for I in 1 .. N loop
                              F (I) := S (Base + M.Prog.Args (Ins.Args_First + I - 1));
                           end loop;
                           Obj_At (P, Slot).Fields := F;
                           Obj_At (P, Slot).Count := N;
                           Obj_At (P, Slot).Drop := M.Prog.Drops (Ins.Str);
                           Obj_At (P, Slot).Type_Name := M.Prog.Strings (Ins.Str);
                           S (Base + Ins.Dest) := Obj_Ptr (Slot);
                        end;

                     when Op_FieldGet =>
                        declare
                           O : constant Natural := Obj_Slot (P, S (Base + Ins.Src1));
                        begin
                           if O > 0 and then Ins.Field_Index < Obj_At (P, O).Count then
                              S (Base + Ins.Dest) := Obj_At (P, O).Fields (Ins.Field_Index + 1);
                           end if;
                        end;

                     when Op_FieldSet =>
                        declare
                           O : constant Natural := Obj_Slot (P, S (Base + Ins.Src1));
                        begin
                           if O > 0 and then Ins.Field_Index < Obj_At (P, O).Count then
                              Obj_At (P, O).Fields (Ins.Field_Index + 1) := S (Base + Ins.Src2);
                           end if;
                        end;

                     when Op_RefNew =>
                        declare
                           Slot : constant Natural := Allocator.Alloc_Obj (M, P);
                           F    : constant Value_Array_Access := new Value_Array (1 .. 1);
                        begin
                           if Ins.Has_Src1 then
                              F (1) := S (Base + Ins.Src1);
                           else
                              F (1) := Zero;
                           end if;
                           Obj_At (P, Slot).Fields := F;
                           Obj_At (P, Slot).Count := 1;
                           S (Base + Ins.Dest) := Obj_Ptr (Slot);
                        end;

                     when Op_RefGet =>
                        declare
                           O : constant Natural := Obj_Slot (P, S (Base + Ins.Src1));
                        begin
                           if O > 0 and then Obj_At (P, O).Count >= 1 then
                              S (Base + Ins.Dest) := Obj_At (P, O).Fields (1);
                           end if;
                        end;

                     when Op_RefSet =>
                        declare
                           O : constant Natural := Obj_Slot (P, S (Base + Ins.Src1));
                        begin
                           if O > 0 and then Obj_At (P, O).Count >= 1 then
                              Obj_At (P, O).Fields (1) := S (Base + Ins.Src2);
                           end if;
                        end;

                     when Op_DynNew =>
                        declare
                           Slot : constant Natural := Allocator.Alloc_Obj (M, P);
                           F    : constant Value_Array_Access := new Value_Array (1 .. 2);
                        begin
                           F (1) := S (Base + Ins.Src1);
                           F (2) := S (Base + Ins.Src2);
                           Obj_At (P, Slot).Fields := F;
                           Obj_At (P, Slot).Count := 2;
                           S (Base + Ins.Dest) := Obj_Ptr (Slot);
                        end;

                     when Op_Drop =>
                        declare
                           V  : TW := S (Base + Ins.Src1);
                           O0 : constant Natural := Obj_Slot (P, V);
                           O  : Natural := O0;
                           DropFn : Natural := 0;
                        begin
                           if O0 > 0 and then Obj_At (P, O0).Count = 2
                             and then Is_Small_Int (Obj_At (P, O0).Fields (2))
                           then
                              declare
                                 VIdx : constant Natural := Natural (Unbox_Small_Int (Obj_At (P, O0).Fields (2)));
                                 Data : constant TW := Obj_At (P, O0).Fields (1);
                              begin
                                 if VIdx >= 1 and then VIdx <= P.VT_Cap
                                   and then VT_At (P, VIdx).In_Use
                                 then
                                    O := Obj_Slot (P, Data);
                                    if O > 0 then
                                       V := Data;
                                    end if;
                                 end if;
                              end;
                           end if;
                           if O > 0 then
                              DropFn := Obj_At (P, O).Drop;
                              if DropFn = 0 then
                                 declare
                                    TypeName : constant String := To_String (Obj_At (P, O).Type_Name);
                                    Cand1    : constant String := TypeName & ".drop";
                                 begin
                                    if M.Func_Names.Contains (Cand1) then
                                       DropFn := M.Func_Names.Element (Cand1);
                                    elsif M.Func_Names.Contains ("drop") then
                                       DropFn := M.Func_Names.Element ("drop");
                                    end if;
                                 end;
                              end if;
                           end if;
                           if DropFn in 1 .. M.Prog.Funcs.all'Length then
                              P.Frames (D).Pc := Pc;
                              declare
                                 Extent   : constant Natural :=
                                   Natural'Max (M.Prog.Funcs (DropFn).Frame_Size, 1);
                                 New_Base : Natural;
                              begin
                                 Push_Frame (M, P, DropFn, Extent, False, 0, New_Base);
                                 P.Stack (New_Base) := V;
                              end;
                              D := P.Depth;
                              if D > 0 then
                                 Fr := P.Frames (D);
                                 Fn := M.Prog.Funcs (Fr.Func);
                                 Base := Fr.Base;
                                 S := P.Stack;
                                 Pc := Fr.Pc;
                              end if;
                           end if;
                        end;

                     when Op_VTableNew =>
                        declare
                           Slot    : Natural := Allocator.Alloc_VT (M, P);
                           Methods : constant VC.Natural_Array_Access :=
                             new VC.Natural_Array (1 .. Ins.Args_Count);
                        begin
                           for I in 1 .. Ins.Args_Count loop
                              Methods (I) := M.Prog.Args (Ins.Args_First + I - 1);
                           end loop;
                           VT_At (P, Slot).Methods := Methods;
                           S (Base + Ins.Dest) := Make_Small_Int (Integer_64 (Slot));
                        end;

         when others => null;
      end case;
   end Run_Slice_Objects;