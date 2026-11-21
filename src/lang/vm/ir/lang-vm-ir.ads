with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Interfaces;

package Lang.VM.IR is

   type Ir_Op is
     (Op_Const_Int, Op_Const_Float, Op_Const_Bool, Op_Const_Str, Op_Const_None,
      Op_Move, Op_Add_Int, Op_Sub_Int, Op_Mul_Int, Op_Div_Int, Op_Mod_Int,
      Op_Add_Float, Op_Sub_Float, Op_Mul_Float, Op_Div_Float,
      Op_Icmp, Op_Br, Op_Jmp, Op_Label, Op_Call, Op_Ret, Op_Safepoint, Op_Phi,
      Op_Spawn, Op_Send, Op_Receive, Op_Self, Op_Drop, Op_FfiCall,
      Op_New, Op_FieldGet, Op_FieldSet, Op_RefNew, Op_RefGet, Op_RefSet,
      Op_VTableNew, Op_DynNew, Op_DynCall,
      Op_FuncRef, Op_Call_Indirect);

   type Cmp_Op is (Cmp_Eq, Cmp_Ne, Cmp_Lt, Cmp_Le, Cmp_Gt, Cmp_Ge);

   package Natural_Vectors is new Ada.Containers.Vectors (Positive, Natural);

   type Ir_Instr is record
      Op       : Ir_Op;
      Has_Dest : Boolean := False;
      Dest     : Natural := 0;
      Has_Src1 : Boolean := False;
      Src1     : Natural := 0;
      Has_Src2 : Boolean := False;
      Src2     : Natural := 0;
      Imm_Int  : Interfaces.Integer_64 := 0;
      Imm_Float: Long_Float := 0.0;
      Imm_Bool : Boolean := False;
      Imm_Str  : Unbounded_String;
      Cmp      : Cmp_Op := Cmp_Eq;
      Label    : Unbounded_String;
      Func_Name: Unbounded_String;
      Args     : Natural_Vectors.Vector;
      Spawn_Func    : Unbounded_String;
      New_Type      : Unbounded_String;
      Field_Index   : Natural := 0;
      Method_Index  : Natural := 0;
      Send_Target   : Natural := 0;
      Has_Send_Target : Boolean := False;
      Send_Msg      : Natural := 0;
      Has_Send_Msg  : Boolean := False;
      Recv_Dest     : Natural := 0;
      Has_Recv_Dest : Boolean := False;
      Recv_Timeout  : Natural := 0;
      Recv_Pattern  : Natural := 0;
      Recv_Guard    : Natural := 0;
   end record;

   package Ir_Instr_Vectors is new Ada.Containers.Vectors (Positive, Ir_Instr);

   type Ir_Param is record
      Name : Unbounded_String;
      Typ  : Unbounded_String;
   end record;
   package Ir_Param_Vectors is new Ada.Containers.Vectors (Positive, Ir_Param);

   type Ir_Func is record
      Name       : Unbounded_String;
      Params     : Ir_Param_Vectors.Vector;
      Ret_Type   : Unbounded_String;
      Regs       : Natural := 0;
      Instrs     : Ir_Instr_Vectors.Vector;
      Owned_Mask : Interfaces.Unsigned_32 := 0;
      Flags      : Natural := 0;
   end record;

   package Ir_Func_Vectors is new Ada.Containers.Vectors (Positive, Ir_Func);

   type Ir_Module is record
      Version : Natural := 1;
      Funcs   : Ir_Func_Vectors.Vector;
   end record;

   Parse_Error : exception;

   function Parse (Text : String) return Ir_Module;

   function Image (M : Ir_Module) return String;

end Lang.VM.IR;