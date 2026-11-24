separate (Lang.VM.Machine)
   procedure Run_Slice_Control (M : in out Machine; P : Process_Access; D : in out Natural; Fr : in out Frame; Fn : in out VC.Func_Code; Base : in out Natural; S : in out Value_Array_Access; Pc : in out Natural; Ins : VC.Code_Instr) is
   begin
      case Ins.Op is
                     when Op_Br =>
                        if Unbox_Bool (S (Base + Ins.Src1)) then
                           Pc := Ins.Target;
                        else
                           Pc := Ins.Target_F;
                        end if;

                     when Op_Jmp =>
                        Pc := Ins.Target;

                     when Op_Ret =>
                        declare
                           RetVal : constant TW :=
                             (if Ins.Has_Src1 then S (Base + Ins.Src1) else Zero);
                        begin
                           P.Sp := Base;
                           P.Depth := D - 1;
                           if P.Depth = 0 then
                              Allocator.Run_Process_Drops (M, P);
                              P.Result := RetVal;
                              P.Status := Proc_Dead;
                           elsif Fr.Has_Ret then
                              P.Stack (P.Frames (P.Depth).Base + Fr.Ret_Dest) := RetVal;
                           end if;
                        end;
                        if P.Depth > 0 then
                           D := P.Depth;
                           Fr := P.Frames (D);
                           Fn := M.Prog.Funcs (Fr.Func);
                           Base := Fr.Base;
                           S := P.Stack;
                           Pc := Fr.Pc;
                        end if;
         when others => null;
      end case;
   end Run_Slice_Control;