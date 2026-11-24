separate (Lang.VM.Machine)
   procedure Spawn_Process (M : in out Machine; Func_Name : String; New_Pid : out Natural) is
   begin
      Ensure_Compiled (M);
      Create_Process (M, Func_Index (M, Func_Name), New_Pid);
   end Spawn_Process;