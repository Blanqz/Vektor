separate (Lang.VM.Machine)
   function Mail_Pop (P : Process_Access) return TW is
      W : constant TW := P.Mail (P.Mail_Head + 1);
   begin
      P.Mail_Head := P.Mail_Head + 1;
      if P.Mail_Head >= P.Mail.all'Length then
         P.Mail_Head := 0;
      end if;
      P.Mail_Count := P.Mail_Count - 1;
      if P.Mail_Count > 0 and then P.Mail.all'Length > 8
        and then P.Mail_Count * 4 <= P.Mail.all'Length
      then
         declare
            New_Cap : constant Natural := Natural'Max (8, 2 * P.Mail_Count);
            Smaller : constant Value_Array_Access := new Value_Array (1 .. New_Cap);
         begin
            for I in 0 .. P.Mail_Count - 1 loop
               Smaller (I + 1) := P.Mail (((P.Mail_Head + I) mod P.Mail.all'Length) + 1);
            end loop;
            Free_Values (P.Mail);
            P.Mail := Smaller;
            P.Mail_Head := 0;
         end;
      end if;
      return W;
   end Mail_Pop;