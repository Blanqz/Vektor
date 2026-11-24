separate (Lang.VM.Machine)
   procedure Ensure_Compiled (M : in out Machine) is
      N : Natural;
   begin
      if M.Compiled then
         return;
      end if;
      M.Prog := VC.Compile (M.Modu);
      for I in 1 .. Natural (M.Modu.Funcs.Length) loop
         M.Func_Names.Insert (To_String (M.Modu.Funcs (I).Name), I);
      end loop;
      M.Compiled := True;
   end Ensure_Compiled;