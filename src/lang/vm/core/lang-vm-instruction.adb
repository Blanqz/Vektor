with Interfaces;
with Lang.VM.Opcode;

package body Lang.VM.Instruction is

   use Interfaces;
   use Lang.VM.Opcode;

   function Encode (Op : Lang.VM.Opcode.Opcode; R1, R2, R3 : Unsigned_8) return Instruction is
   begin
      return Instruction (Unsigned_32 (Lang.VM.Opcode.Opcode'Pos (Op)) or
                          (Shift_Left (Unsigned_32 (R1), 8)) or
                          (Shift_Left (Unsigned_32 (R2), 16)) or
                          (Shift_Left (Unsigned_32 (R3), 24)));
   end Encode;

   function Opcode_Of (I : Instruction) return Lang.VM.Opcode.Opcode is
   begin
      return Lang.VM.Opcode.Opcode'Val (Unsigned_32 (I) and 16#FF#);
   end Opcode_Of;

   function Reg1 (I : Instruction) return Unsigned_8 is
   begin
      return Unsigned_8 (Shift_Right (Unsigned_32 (I), 8) and 16#FF#);
   end Reg1;

   function Reg2 (I : Instruction) return Unsigned_8 is
   begin
      return Unsigned_8 (Shift_Right (Unsigned_32 (I), 16) and 16#FF#);
   end Reg2;

   function Reg3 (I : Instruction) return Unsigned_8 is
   begin
      return Unsigned_8 (Shift_Right (Unsigned_32 (I), 24) and 16#FF#);
   end Reg3;

end Lang.VM.Instruction;