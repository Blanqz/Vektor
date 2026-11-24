separate (Lang.VM.Machine)
   function Format_Decimal (V : Long_Float) return String is
      Buf : String (1 .. 400);
   begin
      Ada.Long_Float_Text_IO.Put (Buf, V, Aft => 12, Exp => 0);
      declare
         S : constant String := Ada.Strings.Fixed.Trim (Buf, Ada.Strings.Both);
         Last : Natural := S'Last;
      begin
         if S'Length = 0 then
            return "0.0";
         end if;
         if (for some C of S => C = '.') then
            while Last > S'First + 1 and then S (Last) = '0' and then S (Last - 1) /= '.' loop
               Last := Last - 1;
            end loop;
         end if;
         return S (S'First .. Last);
      end;
   exception
      when Ada.Text_IO.Layout_Error | Constraint_Error =>
         return Ada.Strings.Fixed.Trim (Long_Float'Image (V), Ada.Strings.Both);
   end Format_Decimal;