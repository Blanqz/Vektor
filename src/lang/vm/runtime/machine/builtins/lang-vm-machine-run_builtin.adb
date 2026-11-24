separate (Lang.VM.Machine)
   procedure Run_Builtin (M    : in out Machine;
                          P    : Process_Access;
                          Base : Natural;
                          Ins  : VC.Code_Instr) is
      function Arg (I : Positive) return TW is
      begin
         return P.Stack (Base + M.Prog.Args (Ins.Args_First + I - 1));
      end Arg;

      procedure Set_Dest (W : TW) is
      begin
         P.Stack (Base + Ins.Dest) := W;
      end Set_Dest;
   begin
      case Ins.Builtin is
         when VC.Bi_Puts =>
            Run_Builtin_Text (M, P, Base, Ins);
         when VC.Bi_Concat =>
            Run_Builtin_Text (M, P, Base, Ins);
         when VC.Bi_Len =>
            Run_Builtin_Text (M, P, Base, Ins);
         when VC.Bi_Int_To_String =>
            Run_Builtin_Text (M, P, Base, Ins);
         when VC.Bi_List_Append =>
            Run_Builtin_Lists (M, P, Base, Ins);
         when VC.Bi_List_Pop =>
            Run_Builtin_Lists (M, P, Base, Ins);
         when VC.Bi_List_Set =>
            Run_Builtin_Lists (M, P, Base, Ins);
         when VC.Bi_List_Get =>
            Run_Builtin_Lists (M, P, Base, Ins);
         when VC.Bi_List_Len =>
            Run_Builtin_Lists (M, P, Base, Ins);
         when VC.Bi_String_Get =>
            Run_Builtin_Text (M, P, Base, Ins);
         when VC.Bi_String_Slice =>
            Run_Builtin_Text (M, P, Base, Ins);
         when VC.Bi_Read_Line =>
            Run_Builtin_Console (M, P, Base, Ins);
         when VC.Bi_Read_Int =>
            Run_Builtin_Console (M, P, Base, Ins);
         when VC.Bi_Bit_And =>
            Run_Builtin_Math (M, P, Base, Ins);
         when VC.Bi_Bit_Or =>
            Run_Builtin_Math (M, P, Base, Ins);
         when VC.Bi_Bit_Xor =>
            Run_Builtin_Math (M, P, Base, Ins);
         when VC.Bi_Bit_Not =>
            Run_Builtin_Math (M, P, Base, Ins);
         when VC.Bi_Bit_Shl =>
            Run_Builtin_Math (M, P, Base, Ins);
         when VC.Bi_Float_From_Int =>
            Run_Builtin_Math (M, P, Base, Ins);
         when VC.Bi_Read_File =>
            Run_Builtin_Files (M, P, Base, Ins);
         when VC.Bi_Err_Puts =>
            Run_Builtin_Console (M, P, Base, Ins);
         when VC.Bi_Float_To_String =>
            Run_Builtin_Text (M, P, Base, Ins);
         when VC.Bi_Bit_Shr =>
            Run_Builtin_Math (M, P, Base, Ins);
         when VC.Bi_Text_Hash =>
            Run_Builtin_Text (M, P, Base, Ins);
         when VC.Bi_String_Compare =>
            Run_Builtin_Text (M, P, Base, Ins);
         when VC.Bi_String_From_Code =>
            Run_Builtin_Text (M, P, Base, Ins);
         when VC.Bi_String_Upper | VC.Bi_String_Lower =>
            Run_Builtin_Text (M, P, Base, Ins);
         when VC.Bi_Float_Parse =>
            Run_Builtin_Text (M, P, Base, Ins);
         when VC.Bi_Float_Sqrt | VC.Bi_Float_Exp | VC.Bi_Float_Ln | VC.Bi_Float_Sin |
              VC.Bi_Float_Cos | VC.Bi_Float_Tan | VC.Bi_Float_Atan | VC.Bi_Float_Floor |
              VC.Bi_Float_Ceil | VC.Bi_Float_Round | VC.Bi_Float_Trunc =>
            Run_Builtin_Math (M, P, Base, Ins);
         when VC.Bi_Float_Pow | VC.Bi_Float_Atan2 =>
            Run_Builtin_Math (M, P, Base, Ins);
         when VC.Bi_Float_To_Int =>
            Run_Builtin_Math (M, P, Base, Ins);
         when VC.Bi_Clock_Mono_Ms =>
            Run_Builtin_Console (M, P, Base, Ins);
         when VC.Bi_Clock_Sleep_Ms =>
            Run_Builtin_Console (M, P, Base, Ins);
         when VC.Bi_Char_To_Text =>
            Run_Builtin_Text (M, P, Base, Ins);
         when VC.Bi_Char_Code | VC.Bi_Char_From_Code =>
            Run_Builtin_Text (M, P, Base, Ins);
         when VC.Bi_Os_Write_File =>
            Run_Builtin_Files (M, P, Base, Ins);
         when VC.Bi_Os_File_Exists =>
            Run_Builtin_Files (M, P, Base, Ins);
         when VC.Bi_Os_List_Dir =>
            Run_Builtin_Files (M, P, Base, Ins);
         when VC.Bi_Os_Get_Env =>
            Run_Builtin_Files (M, P, Base, Ins);
         when VC.Bi_Os_Cwd =>
            Run_Builtin_Files (M, P, Base, Ins);
         when VC.Bi_Os_Remove_File =>
            Run_Builtin_Files (M, P, Base, Ins);
         when VC.Bi_Os_Make_Dir =>
            Run_Builtin_Files (M, P, Base, Ins);
         when VC.Bi_Process_Spawn =>
            Run_Builtin_Processes (M, P, Base, Ins);
         when VC.Bi_Process_Send =>
            Run_Builtin_Processes (M, P, Base, Ins);
         when VC.Bi_Process_Receive =>
            Run_Builtin_Processes (M, P, Base, Ins);
         when VC.Bi_Process_Try_Receive =>
            Run_Builtin_Processes (M, P, Base, Ins);
         when VC.Bi_Process_Mail_Count =>
            Run_Builtin_Processes (M, P, Base, Ins);
         when VC.Bi_Net_Connect =>
            Run_Builtin_Net (M, P, Base, Ins);
         when VC.Bi_Net_Send =>
            Run_Builtin_Net (M, P, Base, Ins);
         when VC.Bi_Net_Recv =>
            Run_Builtin_Net (M, P, Base, Ins);
         when VC.Bi_Net_Close =>
            Run_Builtin_Net (M, P, Base, Ins);
         when VC.Bi_Net_Listen =>
            Run_Builtin_Net (M, P, Base, Ins);
         when VC.Bi_Net_Accept =>
            Run_Builtin_Net (M, P, Base, Ins);
         when VC.Bi_Os_Append_File =>
            Run_Builtin_Files (M, P, Base, Ins);
         when VC.Bi_Os_Copy_File =>
            Run_Builtin_Files (M, P, Base, Ins);
         when VC.Bi_Os_Move_File =>
            Run_Builtin_Files (M, P, Base, Ins);
         when VC.Bi_Os_File_Size =>
            Run_Builtin_Files (M, P, Base, Ins);
         when VC.Bi_Os_Is_Dir =>
            Run_Builtin_Files (M, P, Base, Ins);
         when VC.Bi_None =>
            Run_Builtin_Console (M, P, Base, Ins);
      end case;
   end Run_Builtin;