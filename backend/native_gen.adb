with Ada.Text_IO; use Ada.Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Ada.Command_Line;
with Interfaces; use Interfaces;
with Lang.VM.IR; use Lang.VM.IR;
with Ada.Unchecked_Conversion;
with Native_Helpers; use Native_Helpers;
with Native_Builtins; use Native_Builtins;

procedure Native_Gen is
   F : File_Type;
   Text : Unbounded_String := To_Unbounded_String ("");
   Line : String (1 .. 4096);
   Last : Natural;
   M : Ir_Module;
   Out_F : File_Type;
   Data_Section : Unbounded_String := To_Unbounded_String ("");
   Str_Counter : Natural := 0;
   Trap_Counter : Natural := 0;
   Phys : array (0 .. 1024) of Integer := (others => -1);
   Crosses_Call : array (0 .. 1024) of Boolean := (others => False);
   Last_Use_Map : array (0 .. 1024) of Natural := (others => 0);




   function Operand (R : Natural) return String is
   begin
      if R <= 1024 then
         case Phys (R) is
            when 0 => return "rbx";
            when 1 => return "r12";
            when 2 => return "r13";
            when 3 => return "r14";
            when 4 => return "r10";
            when 5 => return "r11";
            when 6 => return "rsi";
            when 7 => return "rdi";
            when others => null;
         end case;
      end if;
      return "[rbp-" & Integer'Image (R * 8 + 8) & "]";
   end Operand;
begin
   if Ada.Command_Line.Argument_Count < 2 then
      Put_Line ("usage: native_gen <in.ir> <out.s>");
      return;
   end if;
   Open (F, In_File, Ada.Command_Line.Argument (1));
   while not End_Of_File (F) loop
      Get_Line (F, Line, Last);
      Text := Text & To_Unbounded_String (Line (1 .. Last)) & To_Unbounded_String ((1 => ASCII.LF));
   end loop;
   Close (F);
   M := Parse (To_String (Text));

   if False then -- disabled
   for FI in 1 .. Natural (M.Funcs.Length) loop
      declare
         Fn : Ir_Func renames M.Funcs (FI);
         Has_Branch : Boolean := False;
      begin
         for I in 1 .. Natural (Fn.Instrs.Length) loop
            if Fn.Instrs (I).Op = Op_Br or Fn.Instrs (I).Op = Op_Jmp then
               Has_Branch := True;
            end if;
         end loop;
         if not Has_Branch then
            declare
               Live : array (0 .. 1024) of Boolean := (others => False);
            begin
               for I in reverse 1 .. Natural (Fn.Instrs.Length) loop
                  declare
                     Ins : Ir_Instr := Fn.Instrs (I);
                     Is_Dead : Boolean := False;
                  begin
                     if Ins.Has_Dest and then Ins.Dest <= 1024 then
                        if not Live (Ins.Dest) then
                           case Ins.Op is
                              when Op_Call | Op_FfiCall | Op_Call_Indirect | Op_Spawn |
                                   Op_Send | Op_Receive | Op_Safepoint | Op_Label |
                                   Op_Ret | Op_Br | Op_Jmp =>
                                 null; -- keep side effecting
                              when others =>
                                 Is_Dead := True;
                           end case;
                        end if;
                        if Ins.Dest <= 1024 then
                           Live (Ins.Dest) := False;
                        end if;
                     end if;
                     if Is_Dead then
                        Ins.Op := Op_Label;
                        Ins.Label := To_Unbounded_String ("");
                        Fn.Instrs (I) := Ins;
                     else
                        if Ins.Has_Src1 and then Ins.Src1 <= 1024 then Live (Ins.Src1) := True; end if;
                        if Ins.Has_Src2 and then Ins.Src2 <= 1024 then Live (Ins.Src2) := True; end if;
                        for J in 1 .. Natural (Ins.Args.Length) loop
                           if Ins.Args (J) <= 1024 then Live (Ins.Args (J)) := True; end if;
                        end loop;
                     end if;
                  end;
               end loop;
            end;
         end if;
      end;
   end loop;
   end if;




   Create (Out_F, Out_File, Ada.Command_Line.Argument (2));
   Put_Line (Out_F, ".intel_syntax noprefix");
   Put_Line (Out_F, ".data");
   Put_Line (Out_F, ".globl vect_result");
   Put_Line (Out_F, "vect_result: .quad 0");
   Put_Line (Out_F, ".text");

   for FI in 1 .. Natural (M.Funcs.Length) loop
      declare
         Fn : Ir_Func renames M.Funcs (FI);
         FuncName : constant String := To_String (Fn.Name);
         Asm_Func : constant String := (if FuncName = "main" then "vect_main_impl" else Sanitize (FuncName));
         Trap_Label : constant String := ".Ltrap_" & Asm_Func;
         No_Overflow : constant Boolean := (Interfaces.Unsigned_32 (Fn.Flags) and Interfaces.Unsigned_32 (4)) /= 0;
         MaxReg : Natural := Natural (Fn.Params.Length);
         MaxArgs : Natural := Natural (Fn.Params.Length);
         FrameBytes : Natural;
      begin
         for I in 1 .. Natural (Fn.Instrs.Length) loop
            declare
               Ins : Ir_Instr renames Fn.Instrs (I);
            begin
               MaxReg := Natural'Max (MaxReg, Ins.Dest);
               MaxReg := Natural'Max (MaxReg, Ins.Src1);
               MaxReg := Natural'Max (MaxReg, Ins.Src2);
               MaxArgs := Natural'Max (MaxArgs, Natural (Ins.Args.Length));
               for J in 1 .. Natural (Ins.Args.Length) loop
                  MaxReg := Natural'Max (MaxReg, Ins.Args (J));
               end loop;
            end;
         end loop;
         if MaxReg = 0 then MaxReg := 1; end if;
         declare
            Stack_Reserve : Natural := 32;
         begin
            if MaxArgs > 4 then
               Stack_Reserve := Stack_Reserve + (MaxArgs - 4) * 8;
            end if;
            if Stack_Reserve mod 16 /= 0 then
               Stack_Reserve := Stack_Reserve + (16 - (Stack_Reserve mod 16));
            end if;
            FrameBytes := ((MaxReg + 2) * 8) + Stack_Reserve;
            if FrameBytes mod 16 /= 0 then
               FrameBytes := FrameBytes + (16 - (FrameBytes mod 16));
            end if;
         end;

         for R in 0 .. MaxReg loop
            Phys (R) := -1;
            Crosses_Call (R) := False;
         end loop;
         declare
            First : array (0 .. MaxReg) of Natural := (others => 0);
            Last_Use  : array (0 .. MaxReg) of Natural := (others => 0);
            Spill : array (0 .. MaxReg) of Boolean := (others => False);
            Order : array (0 .. MaxReg) of Natural := (others => 0);
            NRegs : Natural := 0;
            ActiveEnd : array (0 .. 7) of Natural := (others => 0);
            ActiveReg : array (0 .. 7) of Integer := (others => -1);

            procedure Touch (R, I : Natural) is
            begin
               if R > MaxReg then
                  return;
               end if;
               if First (R) = 0 then
                  First (R) := I;
               end if;
               Last_Use (R) := I;
            end Touch;
         begin
            for I in 1 .. Natural (Fn.Instrs.Length) loop
               declare
                  Ins : Ir_Instr renames Fn.Instrs (I);
               begin
                  Touch (Ins.Dest, I);
                  if Ins.Has_Src1 then Touch (Ins.Src1, I); end if;
                  if Ins.Has_Src2 then Touch (Ins.Src2, I); end if;
                  for J in 1 .. Natural (Ins.Args.Length) loop
                     Touch (Ins.Args (J), I);
                  end loop;
               end;
            end loop;

            declare
               Label_Index : array (1 .. Natural (Fn.Instrs.Length)) of Natural := (others => 0);
            begin
               null;
            end;

            for I in 1 .. Natural (Fn.Instrs.Length) loop
               declare
                  Ins : Ir_Instr renames Fn.Instrs (I);
                  Targets : array (1 .. 2) of Natural := (others => 0);
                  NT : Natural := 0;
               begin
                  if Ins.Op = Op_Label then
                     null;
                  end if;
                  if Ins.Op = Op_Br then
                     for J in 1 .. Natural (Fn.Instrs.Length) loop
                        if Fn.Instrs (J).Op = Op_Label then
                           if To_String (Fn.Instrs (J).Label) = To_String (Ins.Label) then
                              Targets (1) := J; NT := 1;
                           end if;
                           if To_String (Fn.Instrs (J).Label) = To_String (Ins.Imm_Str) then
                              Targets (2) := J; NT := 2;
                           end if;
                        end if;
                     end loop;
                  elsif Ins.Op = Op_Jmp then
                     for J in 1 .. Natural (Fn.Instrs.Length) loop
                        if Fn.Instrs (J).Op = Op_Label and then
                           To_String (Fn.Instrs (J).Label) = To_String (Ins.Label)
                        then
                           Targets (1) := J; NT := 1;
                        end if;
                     end loop;
                  end if;
                  for T in 1 .. NT loop
                     if Targets (T) > 0 and then Targets (T) < I then
                        for R in 1 .. MaxReg loop
                           if First (R) > 0 and then First (R) <= I and then Last_Use (R) >= Targets (T) then
                              Spill (R) := True;
                           end if;
                        end loop;
                     end if;
                  end loop;
               end;
            end loop;

            for I in 1 .. Natural (Fn.Instrs.Length) loop
               declare
                  Ins : Ir_Instr renames Fn.Instrs (I);
               begin
                  if Ins.Op = Op_Call or Ins.Op = Op_FfiCall or Ins.Op = Op_Call_Indirect or Ins.Op = Op_Spawn then
                     for R in 1 .. MaxReg loop
                        if First (R) > 0 and then First (R) <= I and then Last_Use (R) >= I then
                           Crosses_Call (R) := True;
                        end if;
                     end loop;
                  end if;
               end;
            end loop;

            for I in 1 .. Natural (Fn.Instrs.Length) loop
               declare
                  Ins : Ir_Instr renames Fn.Instrs (I);
               begin
                  if Ins.Op = Op_Call or Ins.Op = Op_FfiCall or Ins.Op = Op_Call_Indirect or Ins.Op = Op_Spawn then
                     for R in 1 .. MaxReg loop
                        if First (R) > 0 and then First (R) <= I and then Last_Use (R) >= I then
                           Crosses_Call (R) := True;
                        end if;
                     end loop;
                  end if;
               end;
            end loop;

            for R in 1 .. MaxReg loop
               Last_Use_Map (R) := Last_Use (R);
               if First (R) > 0 then
                  if Spill (R) then
                     Phys (R) := -1;
                  else
                     Order (NRegs) := R;
                     NRegs := NRegs + 1;
                  end if;
               end if;
            end loop;
            for I in 1 .. NRegs - 1 loop
               declare
                  Key : constant Natural := Order (I);
                  J   : Integer := I - 1;
               begin
                  while J >= 0 and then First (Order (J)) > First (Key) loop
                     Order (J + 1) := Order (J);
                     J := J - 1;
                  end loop;
                  Order (J + 1) := Key;
               end;
            end loop;

            for K in 0 .. NRegs - 1 loop
               declare
                  R : constant Natural := Order (K);
               begin
                  for P in 0 .. 7 loop
                     if ActiveReg (P) /= -1 and then ActiveEnd (P) < First (R) then
                        ActiveReg (P) := -1;
                     end if;
                  end loop;
                  declare
                     Found : Integer := -1;
                  begin
                     for P in 0 .. 7 loop
                        if (P = 4 or P = 5) and then Crosses_Call (R) then
                           null;
                        elsif ActiveReg (P) = -1 then
                           Found := P;
                           exit;
                        end if;
                     end loop;
                     -- always spill to avoid register reuse bugs
                     Phys (R) := -1;
                  end;
               end;
            end loop;
         end;

         for P in 0 .. Natural (Fn.Params.Length) - 1 loop
            Phys (P) := -1;
         end loop;

         Put_Line (Out_F, ".globl " & Asm_Func);
         Put_Line (Out_F, Asm_Func & ":");
         Put_Line (Out_F, "    push rbp");
         Put_Line (Out_F, "    push rbx");
         Put_Line (Out_F, "    push r12");
         Put_Line (Out_F, "    push r13");
         Put_Line (Out_F, "    push r14");
         Put_Line (Out_F, "    push rsi");
         Put_Line (Out_F, "    push rdi");
         Put_Line (Out_F, "    mov rbp, rsp");
         Put_Line (Out_F, "    sub rsp, " & Natural'Image (FrameBytes));

         for P in 1 .. Natural (Fn.Params.Length) loop
            if P = 1 then
               Put_Line (Out_F, "    mov [rbp-" & Natural'Image (P * 8) & "], rcx");
            elsif P = 2 then
               Put_Line (Out_F, "    mov [rbp-" & Natural'Image (P * 8) & "], rdx");
            elsif P = 3 then
               Put_Line (Out_F, "    mov [rbp-" & Natural'Image (P * 8) & "], r8");
            elsif P = 4 then
               Put_Line (Out_F, "    mov [rbp-" & Natural'Image (P * 8) & "], r9");
            else
               Put_Line (Out_F, "    mov rax, [rbp+" & Natural'Image (P * 8 + 56) & "]");
               Put_Line (Out_F, "    mov [rbp-" & Natural'Image (P * 8) & "], rax");
            end if;
         end loop;

         declare
            Skip_Next : Boolean := False;
         begin
         for I in 1 .. Natural (Fn.Instrs.Length) loop
            if Skip_Next then
               Skip_Next := False;
            else
            declare
               Ins : Ir_Instr renames Fn.Instrs (I);
               function Slot (R : Natural) return String is
               begin
                  return "[rbp-" & Integer'Image (R * 8 + 8) & "]";
               end Slot;
            begin
               if Ins.Op = Op_Icmp and then I < Natural (Fn.Instrs.Length)
                 and then Fn.Instrs.Element (I + 1).Op = Op_Br
                 and then Fn.Instrs.Element (I + 1).Src1 = Ins.Dest
                 and then Last_Use_Map (Ins.Dest) = I
               then
                  declare
                     Next_Ins : Ir_Instr renames Fn.Instrs (I + 1);
                  begin
                     if True then
                        Put_Line (Out_F, "    mov rax, " & Operand (Ins.Src1));
                        Put_Line (Out_F, "    cmp rax, " & Operand (Ins.Src2));
                        declare
                           Jcc : constant String :=
                             (case Ins.Cmp is
                                when Cmp_Eq => "je",
                                when Cmp_Ne => "jne",
                                when Cmp_Lt => "jl",
                                when Cmp_Le => "jle",
                                when Cmp_Gt => "jg",
                                when Cmp_Ge => "jge");
                        begin
                           Put_Line (Out_F, "    " & Jcc & " .L" & Asm_Func & "_" & To_String (Next_Ins.Label));
                        end;
                        Put_Line (Out_F, "    jmp .L" & Asm_Func & "_" & To_String (Next_Ins.Imm_Str));
                        Skip_Next := True;
                     end if;
                  end;
               end if;
               if not Skip_Next then
                  case Ins.Op is
                  when Op_Const_Int =>
                     Put_Line (Out_F, "    mov rax, " & Integer_64'Image (Ins.Imm_Int));
                     Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rax");

                  when Op_Const_None =>
                     --  The native backend doesnt have tagged values, so it can't represent none.
                     Put_Line (Standard_Error, "native_gen: const.none is not supported by the native backend (" & FuncName & ")");
                     Put_Line (Out_F, "    ud2");
                     Ada.Command_Line.Set_Exit_Status (1);

                  when Op_Const_Bool =>
                     Put_Line (Out_F, "    mov rax, " & (if Ins.Imm_Bool then "1" else "0"));
                     Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rax");

                  when Op_Const_Float =>
                     Put_Line (Out_F, "    mov rax, " & Unsigned_64'Image (Float_Bits (Ins.Imm_Float)));
                     Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rax");

                  when Op_Move =>
                     if Operand (Ins.Src1) /= Operand (Ins.Dest) then
                        Put_Line (Out_F, "    mov rax, " & Operand (Ins.Src1));
                        Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rax");
                     end if;

                  when Op_Add_Int =>
                     Trap_Counter := Trap_Counter + 1;
                     declare
                        Lb : constant String := ".LT" & Asm_Func & "_" & Ada.Strings.Fixed.Trim (Natural'Image (Trap_Counter), Ada.Strings.Both);
                        Ld : constant String := Lb & "d";
                     begin
                        if Operand (Ins.Dest) = Operand (Ins.Src1) then
                           if Operand (Ins.Src2)'Length > 0 and then Operand (Ins.Src2)(Operand (Ins.Src2)'First) = '[' then
                              Put_Line (Out_F, "    mov rax, " & Operand (Ins.Src2));
                              Put_Line (Out_F, "    add " & Operand (Ins.Dest) & ", rax");
                           else
                              Put_Line (Out_F, "    add " & Operand (Ins.Dest) & ", " & Operand (Ins.Src2));
                           end if;
                        else
                           Put_Line (Out_F, "    mov rax, " & Operand (Ins.Src1));
                           Put_Line (Out_F, "    add rax, " & Operand (Ins.Src2));
                           Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rax");
                        end if;
                        if not No_Overflow then
                           Put_Line (Out_F, "    jo " & Trap_Label);
                        end if;
                     end;

                  when Op_Sub_Int =>
                     Trap_Counter := Trap_Counter + 1;
                     declare
                        Lb : constant String := ".LT" & Asm_Func & "_" & Ada.Strings.Fixed.Trim (Natural'Image (Trap_Counter), Ada.Strings.Both);
                        Ld : constant String := Lb & "d";
                     begin
                        if Operand (Ins.Dest) = Operand (Ins.Src1) then
                           if Operand (Ins.Src2)'Length > 0 and then Operand (Ins.Src2)(Operand (Ins.Src2)'First) = '[' then
                              Put_Line (Out_F, "    mov rax, " & Operand (Ins.Src2));
                              Put_Line (Out_F, "    sub " & Operand (Ins.Dest) & ", rax");
                           else
                              Put_Line (Out_F, "    sub " & Operand (Ins.Dest) & ", " & Operand (Ins.Src2));
                           end if;
                        else
                           Put_Line (Out_F, "    mov rax, " & Operand (Ins.Src1));
                           Put_Line (Out_F, "    sub rax, " & Operand (Ins.Src2));
                           Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rax");
                        end if;
                        if not No_Overflow then
                           Put_Line (Out_F, "    jo " & Trap_Label);
                        end if;
                     end;

                  when Op_Mul_Int =>
                     Trap_Counter := Trap_Counter + 1;
                     declare
                        Lb : constant String := ".LT" & Asm_Func & "_" & Ada.Strings.Fixed.Trim (Natural'Image (Trap_Counter), Ada.Strings.Both);
                        Ld : constant String := Lb & "d";
                     begin
                        if Operand (Ins.Dest) = Operand (Ins.Src1)
                          and then (Operand (Ins.Dest)'Length = 0 or else Operand (Ins.Dest)(Operand (Ins.Dest)'First) /= '[')
                        then
                           if Operand (Ins.Src2)'Length > 0 and then Operand (Ins.Src2)(Operand (Ins.Src2)'First) = '[' then
                              Put_Line (Out_F, "    mov rax, " & Operand (Ins.Src2));
                              Put_Line (Out_F, "    imul " & Operand (Ins.Dest) & ", rax");
                           else
                              Put_Line (Out_F, "    imul " & Operand (Ins.Dest) & ", " & Operand (Ins.Src2));
                           end if;
                        else
                           Put_Line (Out_F, "    mov rax, " & Operand (Ins.Src1));
                           Put_Line (Out_F, "    imul rax, " & Operand (Ins.Src2));
                           Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rax");
                        end if;
                        if not No_Overflow then
                           Put_Line (Out_F, "    jo " & Trap_Label);
                        end if;
                     end;

                  when Op_Div_Int =>
                     Trap_Counter := Trap_Counter + 1;
                     declare
                        Lb : constant String := ".LT" & Asm_Func & "_" & Ada.Strings.Fixed.Trim (Natural'Image (Trap_Counter), Ada.Strings.Both);
                        Ld : constant String := Lb & "d";
                     begin
                        Put_Line (Out_F, "    mov rax, " & Operand (Ins.Src2));
                        Put_Line (Out_F, "    test rax, rax");
                        Put_Line (Out_F, "    je " & Trap_Label);
                        Put_Line (Out_F, "    mov rax, " & Operand (Ins.Src1));
                        Put_Line (Out_F, "    cqo");
                        Put_Line (Out_F, "    idiv " & Operand (Ins.Src2));
                        Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rax");
                     end;

                  when Op_Mod_Int =>
                     Trap_Counter := Trap_Counter + 1;
                     declare
                        Lb : constant String := ".LT" & Asm_Func & "_" & Ada.Strings.Fixed.Trim (Natural'Image (Trap_Counter), Ada.Strings.Both);
                        Ld : constant String := Lb & "d";
                     begin
                        Put_Line (Out_F, "    mov rax, " & Operand (Ins.Src2));
                        Put_Line (Out_F, "    test rax, rax");
                        Put_Line (Out_F, "    je " & Trap_Label);
                        Put_Line (Out_F, "    mov rax, " & Operand (Ins.Src1));
                        Put_Line (Out_F, "    cqo");
                        Put_Line (Out_F, "    idiv " & Operand (Ins.Src2));
                        Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rdx");
                     end;

                  when Op_Add_Float =>
                     Put_Line (Out_F, "    movq xmm0, " & Operand (Ins.Src1));
                     Put_Line (Out_F, "    addsd xmm0, " & Operand (Ins.Src2));
                     Put_Line (Out_F, "    movq " & Operand (Ins.Dest) & ", xmm0");

                  when Op_Sub_Float =>
                     Put_Line (Out_F, "    movq xmm0, " & Operand (Ins.Src1));
                     Put_Line (Out_F, "    subsd xmm0, " & Operand (Ins.Src2));
                     Put_Line (Out_F, "    movq " & Operand (Ins.Dest) & ", xmm0");

                  when Op_Mul_Float =>
                     Put_Line (Out_F, "    movq xmm0, " & Operand (Ins.Src1));
                     Put_Line (Out_F, "    mulsd xmm0, " & Operand (Ins.Src2));
                     Put_Line (Out_F, "    movq " & Operand (Ins.Dest) & ", xmm0");

                  when Op_Div_Float =>
                     Put_Line (Out_F, "    movq xmm0, " & Operand (Ins.Src1));
                     Put_Line (Out_F, "    divsd xmm0, " & Operand (Ins.Src2));
                     Put_Line (Out_F, "    movq " & Operand (Ins.Dest) & ", xmm0");

                  when Op_Icmp =>
                     Put_Line (Out_F, "    mov rax, " & Operand (Ins.Src1));
                     Put_Line (Out_F, "    cmp rax, " & Operand (Ins.Src2));
                     declare
                        SetIns : String :=
                          (case Ins.Cmp is
                             when Cmp_Eq => "    sete al",
                             when Cmp_Ne => "    setne al",
                             when Cmp_Lt => "    setl al",
                             when Cmp_Le => "    setle al",
                             when Cmp_Gt => "    setg al",
                             when Cmp_Ge => "    setge al");
                     begin
                        Put_Line (Out_F, SetIns);
                     end;
                     Put_Line (Out_F, "    movzx rax, al");
                     Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rax");

                  when Op_Br =>
                     Put_Line (Out_F, "    mov rax, " & Operand (Ins.Src1));
                     Put_Line (Out_F, "    test rax, rax");
                     Put_Line (Out_F, "    jne .L" & Asm_Func & "_" & To_String (Ins.Label));
                     Put_Line (Out_F, "    jmp .L" & Asm_Func & "_" & To_String (Ins.Imm_Str));

                  when Op_Jmp =>
                     Put_Line (Out_F, "    call vect_decrement_reduction");
                     Put_Line (Out_F, "    jmp .L" & Asm_Func & "_" & To_String (Ins.Label));

                  when Op_Label =>
                     if To_String (Ins.Label) = "" then
                        null;
                     else
                        Put_Line (Out_F, ".L" & Asm_Func & "_" & To_String (Ins.Label) & ":");
                     end if;

                  when Op_Call | Op_FfiCall =>
                     declare
                        Callee : constant String := To_String (Ins.Func_Name);
                        Target : Unbounded_String := To_Unbounded_String (Callee);
                     begin
                        Target := To_Unbounded_String (Map_Builtin (Callee));
                        if Natural (Ins.Args.Length) >= 1 then
                           Put_Line (Out_F, "    mov rcx, " & Operand (Ins.Args (1)));
                        end if;
                        if Natural (Ins.Args.Length) >= 2 then
                           Put_Line (Out_F, "    mov rdx, " & Operand (Ins.Args (2)));
                        end if;
                        if Natural (Ins.Args.Length) >= 3 then
                           Put_Line (Out_F, "    mov r8, " & Operand (Ins.Args (3)));
                        end if;
                        if Natural (Ins.Args.Length) >= 4 then
                           Put_Line (Out_F, "    mov r9, " & Operand (Ins.Args (4)));
                        end if;
                        for A in 5 .. Natural (Ins.Args.Length) loop
                           Put_Line (Out_F, "    mov rax, " & Operand (Ins.Args (A)));
                           Put_Line (Out_F, "    mov [rsp+" & Natural'Image (32 + (A - 5) * 8) & "], rax");
                        end loop;
                        Put_Line (Out_F, "    call " & To_String (Target));
                        Put_Line (Out_F, "    call vect_decrement_reduction");
                        if Ins.Has_Dest then
                           Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rax");
                        end if;
                     end;

                  when Op_Ret =>
                     if Ins.Has_Src1 then
                        Put_Line (Out_F, "    mov rax, " & Operand (Ins.Src1));
                     else
                        Put_Line (Out_F, "    xor rax, rax");
                     end if;
                     if Asm_Func = "vect_main_impl" then
                        Put_Line (Out_F, "    movabs r10, OFFSET vect_result");
                        Put_Line (Out_F, "    mov [r10], rax");
                     end if;
                     Put_Line (Out_F, "    mov rsp, rbp");
                     Put_Line (Out_F, "    pop rdi");
                     Put_Line (Out_F, "    pop rsi");
                     Put_Line (Out_F, "    pop r14");
                     Put_Line (Out_F, "    pop r13");
                     Put_Line (Out_F, "    pop r12");
                     Put_Line (Out_F, "    pop rbx");
                     Put_Line (Out_F, "    pop rbp");
                     Put_Line (Out_F, "    ret");

                  when Op_Const_Str =>
                     Str_Counter := Str_Counter + 1;
                     declare
                        Lbl : constant String := ".LS" & Ada.Strings.Fixed.Trim (Natural'Image (Str_Counter), Ada.Strings.Both);
                     begin
                        Data_Section := Data_Section & To_Unbounded_String (Lbl & ": .asciz """ & Escape_Asciz (To_String (Ins.Imm_Str)) & """") & To_Unbounded_String ((1 => ASCII.LF));
                        Put_Line (Out_F, "    lea rcx, [rip + " & Lbl & "]");
                                       Put_Line (Out_F, "    call vect_str_from_c");
                                       Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rax");
                     end;

                  when Op_New =>
                     Put_Line (Out_F, "    mov rcx, " & Ada.Strings.Fixed.Trim (Natural'Image (Natural (Ins.Args.Length)), Ada.Strings.Both));
                                 Put_Line (Out_F, "    call vect_obj_new");
                                 Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rax");
                     for A in 1 .. Natural (Ins.Args.Length) loop
                        Put_Line (Out_F, "    mov rcx, " & Operand (Ins.Dest));
                        Put_Line (Out_F, "    mov rdx, " & Natural'Image (A - 1));
                        Put_Line (Out_F, "    mov r8, " & Operand (Ins.Args (A)));
                                       Put_Line (Out_F, "    call vect_obj_set");
                                    end loop;

                  when Op_FieldGet =>
                     Put_Line (Out_F, "    mov rcx, " & Operand (Ins.Src1));
                     Put_Line (Out_F, "    mov rdx, " & Natural'Image (Ins.Field_Index));
                                 Put_Line (Out_F, "    call vect_obj_get");
                                 Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rax");

                  when Op_FieldSet =>
                     Put_Line (Out_F, "    mov rcx, " & Operand (Ins.Src1));
                     Put_Line (Out_F, "    mov rdx, " & Natural'Image (Ins.Field_Index));
                     Put_Line (Out_F, "    mov r8, " & Operand (Ins.Src2));
                                 Put_Line (Out_F, "    call vect_obj_set");
            
                  when Op_RefNew =>
                     Put_Line (Out_F, "    mov rcx, 1");
                                 Put_Line (Out_F, "    call vect_obj_new");
                                 Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rax");
                     if Ins.Has_Src1 then
                        Put_Line (Out_F, "    mov rcx, " & Operand (Ins.Dest));
                        Put_Line (Out_F, "    xor rdx, rdx");
                        Put_Line (Out_F, "    mov r8, " & Operand (Ins.Src1));
                                       Put_Line (Out_F, "    call vect_obj_set");
                                    end if;

                  when Op_RefGet =>
                     Put_Line (Out_F, "    mov rcx, " & Operand (Ins.Src1));
                     Put_Line (Out_F, "    xor rdx, rdx");
                                 Put_Line (Out_F, "    call vect_obj_get");
                                 Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rax");

                  when Op_RefSet =>
                     Put_Line (Out_F, "    mov rcx, " & Operand (Ins.Src1));
                     Put_Line (Out_F, "    xor rdx, rdx");
                     Put_Line (Out_F, "    mov r8, " & Operand (Ins.Src2));
                                 Put_Line (Out_F, "    call vect_obj_set");
            
                  when Op_Self =>
                     Put_Line (Out_F, "    xor rax, rax");
                     Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rax");

                  when Op_Spawn =>
                                 Put_Line (Out_F, "    movabs rcx, OFFSET " & Sanitize (To_String (Ins.Spawn_Func)));
                                 Put_Line (Out_F, "    call vect_process_spawn");
                                 Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rax");

                  when Op_Send =>
                     Put_Line (Out_F, "    mov rcx, " & Operand (Ins.Send_Target));
                     Put_Line (Out_F, "    mov rdx, " & Operand (Ins.Send_Msg));
                                 Put_Line (Out_F, "    call vect_send");
            
                  when Op_Receive =>
                                 Put_Line (Out_F, "    call vect_receive");
                                 Put_Line (Out_F, "    mov " & Operand (Ins.Recv_Dest) & ", rax");

                  when Op_Call_Indirect =>
                     Put_Line (Out_F, "    mov rcx, " & Operand (Ins.Src1));
                                 Put_Line (Out_F, "    call vect_call_indirect");
                                 Put_Line (Out_F, "    mov " & Operand (Ins.Dest) & ", rax");

                  when Op_Drop =>
                     null;

                  when others =>
                     null;
               end case;
               end if;
            end;
         end if;
         end loop;
         end;

         Put_Line (Out_F, "    mov rsp, rbp");
         Put_Line (Out_F, "    pop rdi");
         Put_Line (Out_F, "    pop rsi");
         Put_Line (Out_F, "    pop r14");
         Put_Line (Out_F, "    pop r13");
         Put_Line (Out_F, "    pop r12");
         Put_Line (Out_F, "    pop rbx");
         Put_Line (Out_F, "    pop rbp");
         Put_Line (Out_F, "    ret");
         Put_Line (Out_F, "");
         Put_Line (Out_F, Trap_Label & ":");
         Put_Line (Out_F, "    call vect_trap");
         Put_Line (Out_F, "    xor rax, rax");
         Put_Line (Out_F, "    mov rsp, rbp");
         Put_Line (Out_F, "    pop rdi");
         Put_Line (Out_F, "    pop rsi");
         Put_Line (Out_F, "    pop r14");
         Put_Line (Out_F, "    pop r13");
         Put_Line (Out_F, "    pop r12");
         Put_Line (Out_F, "    pop rbx");
         Put_Line (Out_F, "    pop rbp");
         Put_Line (Out_F, "    ret");
         Put_Line (Out_F, "");
      end;
   end loop;

   if Str_Counter > 0 then
      Put_Line (Out_F, ".section .rdata");
      Put_Line (Out_F, To_String (Data_Section));
   end if;

   Close (Out_F);
end Native_Gen;