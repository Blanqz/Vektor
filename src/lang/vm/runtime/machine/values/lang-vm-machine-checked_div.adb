separate (Lang.VM.Machine)
   function Checked_Div (A, B : Interfaces.Integer_64) return Interfaces.Integer_64 is
   begin
      if B = 0 then
         raise Constraint_Error with "division by zero";
      end if;
      if B = -1 and then A = Interfaces.Integer_64'First then
         raise Constraint_Error with "integer overflow in divide";
      end if;
      return A / B;
   end Checked_Div;