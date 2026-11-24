separate (Lang.VM.Machine)
   function Checked_Mul (A, B : Interfaces.Integer_64) return Interfaces.Integer_64 is
      R : constant Interfaces.Integer_64 := To_I64 (To_U64 (A) * To_U64 (B));
   begin
      if (A = -1 and then B = Interfaces.Integer_64'First)
        or else (B = -1 and then A = Interfaces.Integer_64'First)
        or else (A /= 0 and then R / A /= B)
      then
         raise Constraint_Error with "integer overflow in multiply";
      end if;
      return R;
   end Checked_Mul;