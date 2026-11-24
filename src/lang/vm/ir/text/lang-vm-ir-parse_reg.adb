separate (Lang.VM.IR)
   function Parse_Reg (S : String) return Natural is
      T : constant String := Trim (S);
   begin
      if T'Length > 2 and then T (T'First .. T'First + 1) = "%r" then
         return Natural'Value (T (T'First + 2 .. T'Last));
      else
         return 0;
      end if;
   exception
      when others => return 0;
   end Parse_Reg;