package Lang.VM.Opcode is

   type Opcode is
     (Op_Const, Op_Move, Op_Add_Int, Op_Sub_Int, Op_Mul_Int, Op_Div_Int, Op_Mod_Int,
      Op_Icmp, Op_Br, Op_Jmp, Op_Label, Op_Call, Op_Ret, Op_Safepoint);
   for Opcode use
     (Op_Const => 0, Op_Move => 1, Op_Add_Int => 2, Op_Sub_Int => 3, Op_Mul_Int => 4,
      Op_Div_Int => 5, Op_Mod_Int => 6, Op_Icmp => 7, Op_Br => 8, Op_Jmp => 9,
      Op_Label => 10, Op_Call => 11, Op_Ret => 12, Op_Safepoint => 13);
   for Opcode'Size use 8;

end Lang.VM.Opcode;