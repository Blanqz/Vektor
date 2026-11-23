with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Strings.Hash;

package body Lang.VM.Code is

   use Ada.Strings.Unbounded;

   package Name_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Natural,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   package Str_Vec is new Ada.Containers.Vectors (Positive, Unbounded_String);
   package Nat_Vec is new Ada.Containers.Vectors (Positive, Natural);

   function Builtin_Of (Name : String) return Builtin_Id is
   begin
      if Name = "IO.puts" or Name = "puts" then
         return Bi_Puts;
      elsif Name = "String.concat" or Name = "concat" then
         return Bi_Concat;
      elsif Name = "String.len" or Name = "len" then
         return Bi_Len;
      elsif Name = "Int.to_string" or Name = "to_string" then
         return Bi_Int_To_String;
      elsif Name = "List.append" or Name = "List_Append" then
         return Bi_List_Append;
      elsif Name = "List.get" or Name = "List_Get" then
         return Bi_List_Get;
      elsif Name = "List.len" or Name = "List_Len" or Name = "List.length" then
         return Bi_List_Len;
      elsif Name = "String.get" or Name = "String_Get" then
         return Bi_String_Get;
      elsif Name = "String.slice" or Name = "String_Slice" then
         return Bi_String_Slice;
      elsif Name = "IO.read_line" or Name = "read_line" then
         return Bi_Read_Line;
      elsif Name = "IO.read_int" or Name = "read_int" then
         return Bi_Read_Int;
      elsif Name = "Decimal.from_int" then
         return Bi_Float_From_Int;
      elsif Name = "Decimal.to_string" or Name = "Decimal_to_string" then
         return Bi_Float_To_String;
      elsif Name = "IO.eputs" or Name = "eputs" then
         return Bi_Err_Puts;
      elsif Name = "IO.read_file" or Name = "read_file" then
         return Bi_Read_File;
      elsif Name = "Bit.and" or Name = "Bit_and" or Name = "and" then
         return Bi_Bit_And;
      elsif Name = "Bit.or" or Name = "Bit_or" or Name = "or" then
         return Bi_Bit_Or;
      elsif Name = "Bit.xor" or Name = "Bit_xor" or Name = "xor" then
         return Bi_Bit_Xor;
      elsif Name = "Bit.not" or Name = "Bit_not" or Name = "not" then
         return Bi_Bit_Not;
      elsif Name = "Bit.shl" or Name = "Bit_shl" or Name = "shl" then
         return Bi_Bit_Shl;
      elsif Name = "Bit.shr" or Name = "Bit_shr" or Name = "shr" then
         return Bi_Bit_Shr;
      elsif Name = "String.hash" or Name = "Text.hash" then
         return Bi_Text_Hash;
      elsif Name = "List.pop" or Name = "List_Pop" then
         return Bi_List_Pop;
      elsif Name = "List.set" or Name = "List_Set" then
         return Bi_List_Set;
      else
         return Bi_None;
      end if;
   end Builtin_Of;

   procedure Check_Supported (Op : Ir_Op; Func_Name : String) is
   begin
      case Op is
         when Op_Phi =>
            raise Compile_Error with
              Ir_Op'Image (Op) & " is not implemented by the VM (in " & Func_Name & ")";
         when others =>
            null;
      end case;
   end Check_Supported;

   function Compile (M : Ir_Module) return Program is
      N       : constant Natural := Natural (M.Funcs.Length);
      Func_Ix : Name_Maps.Map;
      Strs    : Str_Vec.Vector;
      Pool    : Nat_Vec.Vector;
      Funcs   : constant Func_Array_Access := new Func_Array (1 .. N);
      Result  : Program;
   begin
      for I in 1 .. N loop
         declare
            S : constant String := To_String (M.Funcs (I).Name);
         begin
            if not Func_Ix.Contains (S) then
               Func_Ix.Insert (S, I);
            end if;
         end;
      end loop;

      for FI in 1 .. N loop
         declare
            Src    : constant Ir_Func := M.Funcs (FI);
            Labels : Name_Maps.Map;
            Live   : Natural := 0;
            Code   : Code_Access;

            function Resolve (Label : Unbounded_String) return Natural is
               L : constant String := To_String (Label);
            begin
               if not Labels.Contains (L) then
                  raise Compile_Error with
                    "unknown label " & L & " in " & To_String (Src.Name);
               end if;
               return Labels.Element (L);
            end Resolve;

            function Intern (S : Unbounded_String) return Natural is
            begin
               Str_Vec.Append (Strs, S);
               return Natural (Str_Vec.Length (Strs));
            end Intern;

            function Lookup (Name : Unbounded_String) return Natural is
               S : constant String := To_String (Name);
            begin
               if not Func_Ix.Contains (S) then
                  raise Compile_Error with "unknown function " & S;
               end if;
               return Func_Ix.Element (S);
            end Lookup;

            procedure Push_Args (Args : Natural_Vectors.Vector;
                                 First, Count : out Natural) is
            begin
               First := Natural (Nat_Vec.Length (Pool)) + 1;
               Count := Natural (Args.Length);
               for A of Args loop
                  Nat_Vec.Append (Pool, A);
               end loop;
            end Push_Args;

            function Translate (Ins : Ir_Instr) return Code_Instr is
               R : Code_Instr;
            begin
               R.Op           := Ins.Op;
               R.Has_Dest     := Ins.Has_Dest;
               R.Dest         := Ins.Dest;
               R.Has_Src1     := Ins.Has_Src1;
               R.Src1         := Ins.Src1;
               R.Has_Src2     := Ins.Has_Src2;
               R.Src2         := Ins.Src2;
               R.Imm_Int      := Ins.Imm_Int;
               R.Imm_Float    := Ins.Imm_Float;
               R.Imm_Bool     := Ins.Imm_Bool;
               R.Cmp          := Ins.Cmp;
               R.Field_Index  := Ins.Field_Index;
               R.Method_Index := Ins.Method_Index;

               case Ins.Op is
                  when Op_Const_Str =>
                     R.Str := Intern (Ins.Imm_Str);
                  when Op_Br =>
                     R.Target   := Resolve (Ins.Label);
                     R.Target_F := Resolve (Ins.Imm_Str);
                  when Op_Jmp =>
                     R.Target := Resolve (Ins.Label);
                  when Op_Call =>
                     R.Builtin := Builtin_Of (To_String (Ins.Func_Name));
                     if R.Builtin = Bi_None then
                        R.Callee := Lookup (Ins.Func_Name);
                     end if;
                     Push_Args (Ins.Args, R.Args_First, R.Args_Count);
                  when Op_Spawn =>
                     R.Callee := Lookup (Ins.Spawn_Func);
                  when Op_New =>
                     R.Str := Intern (Ins.New_Type);
                     Push_Args (Ins.Args, R.Args_First, R.Args_Count);
                  when Op_DynCall | Op_VTableNew =>
                     Push_Args (Ins.Args, R.Args_First, R.Args_Count);
                  when Op_FfiCall =>
                     R.Str := Intern (Ins.Func_Name);
                     Push_Args (Ins.Args, R.Args_First, R.Args_Count);
                  when Op_FuncRef =>
                     R.Callee := Lookup (Ins.Func_Name);
                     Push_Args (Ins.Args, R.Args_First, R.Args_Count);
                  when Op_Call_Indirect =>
                     R.Has_Src1 := True;
                     R.Src1 := Ins.Src1;
                     Push_Args (Ins.Args, R.Args_First, R.Args_Count);
                  when Op_Send =>
                     R.Has_Src1 := True;
                     R.Src1     := Ins.Send_Target;
                     R.Has_Src2 := True;
                     R.Src2     := Ins.Send_Msg;
                  when Op_Receive =>
                     R.Has_Dest := True;
                     R.Dest     := Ins.Recv_Dest;
                     R.Recv_Timeout := Ins.Recv_Timeout;
                     R.Recv_Pattern := Ins.Recv_Pattern;
                     R.Recv_Guard   := Ins.Recv_Guard;
                  when others =>
                     null;
               end case;
               return R;
            end Translate;

         begin
            for Ins of Src.Instrs loop
               Check_Supported (Ins.Op, To_String (Src.Name));
               if Ins.Op = Op_Label then
                  Labels.Include (To_String (Ins.Label), Live + 1);
               elsif Ins.Op /= Op_Safepoint then
                  Live := Live + 1;
               end if;
            end loop;

            Code := new Code_Array (1 .. Live);
            declare
               J : Natural := 0;
            begin
               for Ins of Src.Instrs loop
                  if Ins.Op /= Op_Label and then Ins.Op /= Op_Safepoint then
                     J := J + 1;
                     Code (J) := Translate (Ins);
                  end if;
               end loop;
            end;

            declare
               Max_R : Natural := 0;
               K     : Natural;
            begin
               for C of Code.all loop
                  Max_R := Natural'Max (Max_R, Natural'Max (C.Dest, Natural'Max (C.Src1, C.Src2)));
                  for J in 1 .. C.Args_Count loop
                     K := C.Args_First + J - 1;
                     Max_R := Natural'Max (Max_R, Pool (K));
                  end loop;
               end loop;
               Funcs (FI) := (Code       => Code,
                              Frame_Size => Natural'Max (Max_R + 1, Natural (Src.Params.Length)),
                              Owned_Mask => Src.Owned_Mask,
                              Flags      => Src.Flags);
            end;
         end;
      end loop;

      Result.Funcs := Funcs;

      Result.Strings := new String_Array (1 .. Natural (Str_Vec.Length (Strs)));
      for I in 1 .. Natural (Str_Vec.Length (Strs)) loop
         Result.Strings (I) := Strs (I);
      end loop;

      Result.Args := new Natural_Array (1 .. Natural (Nat_Vec.Length (Pool)));
      for I in 1 .. Natural (Nat_Vec.Length (Pool)) loop
         Result.Args (I) := Pool (I);
      end loop;

      Result.Drops := new Natural_Array (1 .. Natural (Str_Vec.Length (Strs)));
      for I in 1 .. Natural (Str_Vec.Length (Strs)) loop
         declare
            S : constant String := To_String (Strs (I));
         begin
            if Func_Ix.Contains (S & ".drop") then
               Result.Drops (I) := Func_Ix.Element (S & ".drop");
            elsif Func_Ix.Contains ("drop") then
               Result.Drops (I) := Func_Ix.Element ("drop");
            else
               Result.Drops (I) := 0;
            end if;
         end;
      end loop;

      return Result;
   end Compile;

end Lang.VM.Code;
