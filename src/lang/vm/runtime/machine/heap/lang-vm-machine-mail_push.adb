separate (Lang.VM.Machine)
   procedure Mail_Push (P : Process_Access; W : TW) is
      Cap : constant Natural := P.Mail.all'Length;
   begin
      if P.Mail_Count = Cap then
         declare
            Bigger : constant Value_Array_Access := new Value_Array (1 .. 2 * Cap);
         begin
            for I in 0 .. P.Mail_Count - 1 loop
               Bigger (I + 1) := P.Mail (((P.Mail_Head + I) mod Cap) + 1);
            end loop;
            Free_Values (P.Mail);
            P.Mail := Bigger;
            P.Mail_Head := 0;
         end;
      end if;
      P.Mail (((P.Mail_Head + P.Mail_Count) mod P.Mail.all'Length) + 1) := W;
      P.Mail_Count := P.Mail_Count + 1;
   end Mail_Push;