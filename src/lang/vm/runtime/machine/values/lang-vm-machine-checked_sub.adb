separate (Lang.VM.Machine)
   function Checked_Sub (A, B : Interfaces.Integer_64) return Interfaces.Integer_64 is
      R : constant Interfaces.Integer_64 := To_I64 (To_U64 (A) - To_U64 (B));
   begin
      if (B < 0 and then R < A) or else (B > 0 and then R > A) then
         raise Constraint_Error with "integer overflow in subtract";
      end if;
      return R;
   end Checked_Sub;