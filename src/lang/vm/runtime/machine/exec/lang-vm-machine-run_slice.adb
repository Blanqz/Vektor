separate (Lang.VM.Machine)
   procedure Run_Slice (M : in out Machine; P : Process_Access) is
      D    : Natural;
      Fr   : Frame;
      Fn   : VC.Func_Code;
      Base : Natural;
      S    : Value_Array_Access;
      Pc   : Natural;
   begin
      begin
         if P.Depth = 0 then
            P.Status := Proc_Dead;
            return;
         end if;
         D    := P.Depth;
         Fr   := P.Frames (D);
         Fn   := M.Prog.Funcs (Fr.Func);
         Base := Fr.Base;
         S    := P.Stack;
         Pc   := Fr.Pc;

         while P.Status = Proc_Runnable and then P.Reductions > 0 and then P.Depth > 0 loop
            P.Reductions := P.Reductions - 1;

            if Pc > Fn.Code.all'Length then
               P.Sp := Base;
               P.Depth := D - 1;
               if P.Depth = 0 then
                  P.Status := Proc_Dead;
               else
                  D := P.Depth;
                  Fr := P.Frames (D);
                  Fn := M.Prog.Funcs (Fr.Func);
                  Base := Fr.Base;
                  S := P.Stack;
                  Pc := Fr.Pc;
               end if;
            else
               declare
                  Ins : VC.Code_Instr renames Fn.Code.all (Pc);
               begin
                  Pc := Pc + 1;

                  case Ins.Op is
                     when Op_Const_Int =>
            Run_Slice_Values (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Const_None =>
            Run_Slice_Values (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Const_Bool =>
            Run_Slice_Values (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Const_Float =>
            Run_Slice_Values (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Const_Str =>
            Run_Slice_Values (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Move =>
            Run_Slice_Values (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_FuncRef =>
            Run_Slice_Values (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Add_Int =>
            Run_Slice_Arithmetic (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Sub_Int =>
            Run_Slice_Arithmetic (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Mul_Int =>
            Run_Slice_Arithmetic (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Add_Float =>
            Run_Slice_Arithmetic (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Sub_Float =>
            Run_Slice_Arithmetic (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Mul_Float =>
            Run_Slice_Arithmetic (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Div_Float =>
            Run_Slice_Arithmetic (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Div_Int =>
            Run_Slice_Arithmetic (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Mod_Int =>
            Run_Slice_Arithmetic (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Icmp =>
            Run_Slice_Arithmetic (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Br =>
            Run_Slice_Control (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Jmp =>
            Run_Slice_Control (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Call =>
            Run_Slice_Calls (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Ret =>
            Run_Slice_Control (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Call_Indirect =>
            Run_Slice_Calls (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Spawn =>
            Run_Slice_Processes (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Send =>
            Run_Slice_Processes (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Receive =>
            Run_Slice_Processes (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Self =>
            Run_Slice_Processes (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_New =>
            Run_Slice_Objects (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_FieldGet =>
            Run_Slice_Objects (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_FieldSet =>
            Run_Slice_Objects (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_RefNew =>
            Run_Slice_Objects (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_RefGet =>
            Run_Slice_Objects (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_RefSet =>
            Run_Slice_Objects (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_DynNew =>
            Run_Slice_Objects (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_DynCall =>
            Run_Slice_Calls (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_Drop =>
            Run_Slice_Objects (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_FfiCall =>
            Run_Slice_Calls (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when Op_VTableNew =>
            Run_Slice_Objects (M, P, D, Fr, Fn, Base, S, Pc, Ins);
                     when others =>
            null;
                  end case;
                  if P.Depth > 0 then
                     P.Frames (P.Depth).Pc := Pc;
                  end if;
               end;
            end if;
         end loop;
      exception
         when E : others =>
            Put_Line ("panic: " & Ada.Exceptions.Exception_Message (E));
            Flush (Standard_Output);
            C_Exit (1);
      end;

      if P.Reductions = 0 then
         if M.Verify_Roots then
            Verify_Roots (M);
         end if;
         M.Clock := M.Clock + (2000 - P.Reductions);
         P.Reductions := 2000;
      else
         M.Clock := M.Clock + (2000 - P.Reductions);
      end if;
   end Run_Slice;