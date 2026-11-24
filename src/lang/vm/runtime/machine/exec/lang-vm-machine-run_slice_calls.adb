separate (Lang.VM.Machine)
   procedure Run_Slice_Calls (M : in out Machine; P : Process_Access; D : in out Natural; Fr : in out Frame; Fn : in out VC.Func_Code; Base : in out Natural; S : in out Value_Array_Access; Pc : in out Natural; Ins : VC.Code_Instr) is
   begin
      case Ins.Op is
                     when Op_Call =>
                        P.Frames (D).Pc := Pc;
                        if Ins.Builtin /= VC.Bi_None then
                           Run_Builtin (M, P, Base, Ins);
                        else
                           declare
                              Callee   : constant Natural := Ins.Callee;
                              Extent   : constant Natural :=
                                Natural'Max (M.Prog.Funcs (Callee).Frame_Size, Ins.Args_Count);
                              New_Base : Natural;
                           begin
                              P.Frames (D).Pc := Pc;
                              Push_Frame (M, P, Callee, Extent, Ins.Has_Dest, Ins.Dest, New_Base);
                              for A in 1 .. Ins.Args_Count loop
                                 P.Stack (New_Base + A - 1) :=
                                   P.Stack (Base + M.Prog.Args (Ins.Args_First + A - 1));
                              end loop;
                           end;
                        end if;
                        D := P.Depth;
                        if D > 0 then
                           Fr := P.Frames (D);
                           Fn := M.Prog.Funcs (Fr.Func);
                           Base := Fr.Base;
                           S := P.Stack;
                           Pc := Fr.Pc;
                        end if;

                     when Op_Call_Indirect =>
                        P.Frames (D).Pc := Pc;
                        declare
                           W        : constant TW := S (Base + Ins.Src1);
                           O        : constant Natural := Obj_Slot (P, W);
                           Callee   : Natural := 0;
                           Captures : Natural := 0;
                           Extent   : Natural;
                           New_Base : Natural;
                        begin
                           if O > 0 and then Obj_At (P, O).Count >= 1
                             and then Is_Small_Int (Obj_At (P, O).Fields (1))
                           then
                              Callee := Natural (Unbox_Small_Int (Obj_At (P, O).Fields (1)));
                              Captures := Obj_At (P, O).Count - 1;
                           end if;
                           if Callee = 0 then
                              Put_Line ("invalid closure O=" & Natural'Image (O) & " count=" & Natural'Image ((if O>0 then Obj_At (P, O).Count else 0)));
                              raise Constraint_Error with "invalid closure";
                           end if;
                           Extent := Natural'Max (M.Prog.Funcs (Callee).Frame_Size, Captures + Ins.Args_Count);
                           Push_Frame (M, P, Callee, Extent, Ins.Has_Dest, Ins.Dest, New_Base);
                           for C in 1 .. Captures loop
                              P.Stack (New_Base + C - 1) := Obj_At (P, O).Fields (C + 1);
                           end loop;
                           for A in 1 .. Ins.Args_Count loop
                              P.Stack (New_Base + Captures + A - 1) :=
                                P.Stack (Base + M.Prog.Args (Ins.Args_First + A - 1));
                           end loop;
                        end;
                        D := P.Depth;
                        if D > 0 then
                           Fr := P.Frames (D);
                           Fn := M.Prog.Funcs (Fr.Func);
                           Base := Fr.Base;
                           S := P.Stack;
                           Pc := Fr.Pc;
                        end if;

                     when Op_DynCall =>
                        declare
                           O     : constant Natural := Obj_Slot (P, S (Base + Ins.Src1));
                           Self  : TW := Zero;
                           VIdx  : Natural := 0;
                           Func  : Natural := 0;
                        begin
                           if O > 0 then
                              if Obj_At (P, O).Count >= 1 then
                                 Self := Obj_At (P, O).Fields (1);
                              end if;
                              if Obj_At (P, O).Count >= 2 then
                                 VIdx := Natural (Unbox_Small_Int (Obj_At (P, O).Fields (2)));
                              end if;
                           end if;

                           if VIdx in 1 .. P.VT_Cap and then VT_At (P, VIdx).In_Use
                             and then Ins.Method_Index < VT_At (P, VIdx).Methods.all'Length
                           then
                              Func := VT_At (P, VIdx).Methods (Ins.Method_Index + 1);
                           end if;

                           if Func in 1 .. M.Prog.Funcs.all'Length then
                              P.Frames (D).Pc := Pc;
                              declare
                                 Extent   : constant Natural :=
                                   Natural'Max (M.Prog.Funcs (Func).Frame_Size, Ins.Args_Count + 1);
                                 New_Base : Natural;
                              begin
                                 Push_Frame (M, P, Func, Extent, Ins.Has_Dest, Ins.Dest, New_Base);
                                 P.Stack (New_Base) := Self;
                                 for A in 1 .. Ins.Args_Count loop
                                    P.Stack (New_Base + A) :=
                                      P.Stack (Base + M.Prog.Args (Ins.Args_First + A - 1));
                                 end loop;
                              end;
                           end if;
                        end;
                        if P.Depth > D then
                           D := P.Depth;
                           Fr := P.Frames (D);
                           Fn := M.Prog.Funcs (Fr.Func);
                           Base := Fr.Base;
                           S := P.Stack;
                           Pc := Fr.Pc;
                        end if;

                     when Op_FfiCall =>
                        declare
                           type A0 is access function return Integer_64;
                           pragma Convention (C, A0);
                           type A1 is access function (A : Integer_64) return Integer_64;
                           pragma Convention (C, A1);
                           type A2 is access function (A, B : Integer_64) return Integer_64;
                           pragma Convention (C, A2);
                           FuncName : constant String := To_String (M.Prog.Strings (Ins.Str));
                           Addr     : constant System.Address := Ffi_Address (FuncName);
                           NArgs    : constant Natural := Natural (Ins.Args_Count);
                           R        : Integer_64 := 0;

                           function Cvt0 is new Ada.Unchecked_Conversion (System.Address, A0);
                           function Cvt1 is new Ada.Unchecked_Conversion (System.Address, A1);
                           function Cvt2 is new Ada.Unchecked_Conversion (System.Address, A2);

                           function To_Int (W : TW) return Integer_64 is
                           begin
                              if Is_Small_Int (W) then
                                 return Unbox_Small_Int (W);
                              end if;
                              return 0;
                           end To_Int;
                        begin
                           if FuncName = "puts" or FuncName = "IO.puts" then
                              if Ins.Args_Count >= 1 then
                                 declare
                                    V : constant TW := P.Stack (Base + M.Prog.Args (Ins.Args_First));
                                 begin
                                    if Is_Heap_Pointer (V) then
                                       Put_Line (To_String (Chars_Of (P, V)));
                                    else
                                       Put_Line (Integer'Image (Integer (Unbox_Small_Int (V))));
                                    end if;
                                 end;
                              end if;
                              R := 0;
                           elsif FuncName = "strlen" or FuncName = "String.len" or FuncName = "len" then
                              if Ins.Args_Count >= 1 then
                                 declare
                                    Sl : constant Natural := Str_Slot (P, P.Stack (Base + M.Prog.Args (Ins.Args_First)));
                                 begin
                                    if Sl > 0 then
                                       R := Integer_64 (Length (Str_At (P, Sl).Chars));
                                    else
                                       R := 0;
                                    end if;
                                 end;
                              end if;
                           elsif FuncName = "sqrt" then
                              if Ins.Args_Count >= 1 then
                                 declare
                                    X : Integer_64 := Unbox_Small_Int (P.Stack (Base + M.Prog.Args (Ins.Args_First)));
                                    Rr : Integer_64 := X;
                                    Nr : Integer_64;
                                 begin
                                    if X <= 0 then
                                       R := 0;
                                    else
                                       loop
                                          Nr := (Rr + X / Rr) / 2;
                                          exit when Nr >= Rr;
                                          Rr := Nr;
                                       end loop;
                                       R := Rr;
                                    end if;
                                 end;
                              end if;
                           elsif FuncName = "getpid" then
                              R := Lang.VM.Platform.Current_Process_Id;
                           else
                              if Addr = System.Null_Address then
                                 Put_Line ("ffi: symbol not found " & FuncName);
                              else
                                 case NArgs is
                                    when 0 =>
                                       R := Cvt0 (Addr).all;
                                    when 1 =>
                                       R := Cvt1 (Addr).all (To_Int (P.Stack (Base + M.Prog.Args (Ins.Args_First))));
                                    when 2 =>
                                       R := Cvt2 (Addr).all
                                         (To_Int (P.Stack (Base + M.Prog.Args (Ins.Args_First))),
                                          To_Int (P.Stack (Base + M.Prog.Args (Ins.Args_First + 1))));
                                    when others =>
                                       Put_Line ("ffi: too many args");
                                 end case;
                              end if;
                           end if;
                           if Ins.Has_Dest then
                              S (Base + Ins.Dest) := Make_Int (M, P, R);
                           end if;
                        end;

         when others => null;
      end case;
   end Run_Slice_Calls;