separate (Lang.VM.Machine)
   procedure Run_Slice_Values (M : in out Machine; P : Process_Access; D : in out Natural; Fr : in out Frame; Fn : in out VC.Func_Code; Base : in out Natural; S : in out Value_Array_Access; Pc : in out Natural; Ins : VC.Code_Instr) is
   begin
      case Ins.Op is
                     when Op_Const_Int =>
                        S (Base + Ins.Dest) := Make_Int (M, P, Ins.Imm_Int);

                     when Op_Const_None =>
                        S (Base + Ins.Dest) := Make_None;

                     when Op_Const_Bool =>
                        S (Base + Ins.Dest) := Make_Bool (Ins.Imm_Bool);

                     when Op_Const_Float =>
                        S (Base + Ins.Dest) := Make_Float (M, P, Ins.Imm_Float);

                     when Op_Const_Str =>
                        declare
                           Slot : constant Natural := Allocator.Alloc_Str (M, P);
                        begin
                           Str_At (P, Slot).Chars := M.Prog.Strings (Ins.Str);
                           Str_At (P, Slot).Pinned := True;
                           Allocator.Promote_To_Large (P, Slot);
                           S (Base + Ins.Dest) := Str_Ptr (Slot);
                        end;

                     when Op_Move =>
                        S (Base + Ins.Dest) := S (Base + Ins.Src1);

                     when Op_FuncRef =>
                        declare
                           Slot   : constant Natural := Allocator.Alloc_Obj (M, P);
                           Count  : constant Natural := 1 + Ins.Args_Count;
                           F      : Value_Array_Access := new Value_Array (1 .. Count);
                        begin
                           Obj_At (P, Slot).Type_Name := To_Unbounded_String ("Closure");
                           Obj_At (P, Slot).Count := Count;
                           F (1) := Make_Small_Int (Integer_64 (Ins.Callee));
                           for A in 1 .. Ins.Args_Count loop
                              F (A + 1) := P.Stack (Base + M.Prog.Args (Ins.Args_First + A - 1));
                           end loop;
                           Obj_At (P, Slot).Fields := F;
                           S (Base + Ins.Dest) := Obj_Ptr (Slot);
                        end;

         when others => null;
      end case;
   end Run_Slice_Values;