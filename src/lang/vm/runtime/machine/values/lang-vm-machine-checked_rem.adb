separate (Lang.VM.Machine)
   function Checked_Rem (A, B : Interfaces.Integer_64) return Interfaces.Integer_64 is
   begin
      if B = 0 then
         raise Constraint_Error with "modulus by zero";
      end if;
      if B = -1 then
         return 0;   --  avoids the idiv trap on First rem -1
      end if;
      return A rem B;
   end Checked_Rem;