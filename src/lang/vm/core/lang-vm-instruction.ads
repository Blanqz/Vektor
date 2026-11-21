with Interfaces;
use Interfaces;
with Lang.VM.Opcode;

package Lang.VM.Instruction is

   type Instruction is new Interfaces.Unsigned_32;
   for Instruction'Size use 32;

   function Encode (Op : Lang.VM.Opcode.Opcode; R1, R2, R3 : Unsigned_8) return Instruction;
   function Opcode_Of (I : Instruction) return Lang.VM.Opcode.Opcode;
   function Reg1 (I : Instruction) return Unsigned_8;
   function Reg2 (I : Instruction) return Unsigned_8;
   function Reg3 (I : Instruction) return Unsigned_8;

end Lang.VM.Instruction;