with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Ada.Text_IO;
with Interfaces;

package body Lang.VM.IR is

   package Line_Vectors is new Ada.Containers.Vectors (Positive, Unbounded_String);

   function Trim (S : String) return String is separate;

   function Parse_Reg (S : String) return Natural is separate;


   function Unescape_IR (S : String) return String is separate;

   procedure Parse_Op_Objects (Instr : in out Ir_Instr; OpTok : String; Rest : String) is separate;
   procedure Parse_Op_Processes (Instr : in out Ir_Instr; OpTok : String; Rest : String) is separate;
   procedure Parse_Op_Calls (Instr : in out Ir_Instr; OpTok : String; Rest : String) is separate;
   procedure Parse_Op_Control (Instr : in out Ir_Instr; OpTok : String; Rest : String) is separate;
   procedure Parse_Op_Arithmetic (Instr : in out Ir_Instr; OpTok : String; Rest : String) is separate;
   procedure Parse_Op_Values (Instr : in out Ir_Instr; OpTok : String; Rest : String) is separate;
   function Parse (Text : String) return Ir_Module is separate;

   function Image (M : Ir_Module) return String is separate;

end Lang.VM.IR;