separate (Lang.VM.IR)
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