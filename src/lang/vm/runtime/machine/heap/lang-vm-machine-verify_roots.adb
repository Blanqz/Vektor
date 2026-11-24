separate (Lang.VM.Machine)
   procedure Verify_Roots (M : in out Machine) is
   begin
      for I in 1 .. Natural (M.Processes.Length) loop
         declare
            P : constant Process_Access := M.Processes (I);
         begin
            for F in 1 .. P.Depth loop
               if P.Frames (F).Base < 1 or else P.Frames (F).Base + P.Frames (F).Reg_Count > P.Stack.all'Length then
                  Put_Line ("verify: bad frame layout in process" & Natural'Image (P.Id));
               end if;
               if P.Frames (F).Func > Natural (M.Prog.Funcs'Length) then
                  Put_Line ("verify: bad function id in process" & Natural'Image (P.Id));
               end if;
            end loop;
            if P.Mail_Head + P.Mail_Count > P.Mail.all'Length then
               Put_Line ("verify: bad mailbox in process" & Natural'Image (P.Id));
            end if;
         end;
      end loop;
   end Verify_Roots;