with Ada.Strings.Unbounded;
with Interfaces;
with Lang.VM.IR; use Lang.VM.IR;

package Lang.VM.Code is

   Compile_Error : exception;

   type Builtin_Id is (Bi_None, Bi_Puts, Bi_Concat, Bi_Len, Bi_Int_To_String,
      Bi_List_Append, Bi_List_Get, Bi_List_Len,
      Bi_String_Get, Bi_String_Slice, Bi_Read_Line, Bi_Read_Int,
      Bi_Bit_And, Bi_Bit_Or, Bi_Bit_Xor, Bi_Bit_Not, Bi_Bit_Shl, Bi_Bit_Shr);

   type Code_Instr is record
      Op           : Ir_Op := Op_Label;
      Has_Dest     : Boolean := False;
      Has_Src1     : Boolean := False;
      Has_Src2     : Boolean := False;
      Dest         : Natural := 0;
      Src1         : Natural := 0;
      Src2         : Natural := 0;
      Imm_Int      : Interfaces.Integer_64 := 0;
      Imm_Float    : Long_Float := 0.0;
      Imm_Bool     : Boolean := False;
      Cmp          : Cmp_Op := Cmp_Eq;
      Str          : Natural := 0;
      Target       : Natural := 0;
      Target_F     : Natural := 0;
      Callee       : Natural := 0;
      Builtin      : Builtin_Id := Bi_None;
      Args_First   : Natural := 0;
      Args_Count   : Natural := 0;
      Field_Index  : Natural := 0;
      Method_Index : Natural := 0;
      Recv_Timeout : Natural := 0;
      Recv_Pattern : Natural := 0;
      Recv_Guard   : Natural := 0;
   end record;

   type Code_Array is array (Positive range <>) of Code_Instr;
   type Code_Access is access Code_Array;

   type Func_Code is record
      Code       : Code_Access := null;
      Frame_Size : Natural := 0;
      Owned_Mask : Interfaces.Unsigned_32 := 0;
   end record;

   type Func_Array is array (Positive range <>) of Func_Code;
   type Func_Array_Access is access Func_Array;

   type String_Array is array (Positive range <>) of Ada.Strings.Unbounded.Unbounded_String;
   type String_Array_Access is access String_Array;

   type Natural_Array is array (Positive range <>) of Natural;
   type Natural_Array_Access is access Natural_Array;

   type Program is record
      Funcs   : Func_Array_Access := null;
      Strings : String_Array_Access := null;
      Args    : Natural_Array_Access := null;
      Drops   : Natural_Array_Access := null;
   end record;

   function Compile (M : Ir_Module) return Program;

end Lang.VM.Code;
