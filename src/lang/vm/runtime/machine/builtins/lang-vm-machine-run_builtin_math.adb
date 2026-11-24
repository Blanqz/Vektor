separate (Lang.VM.Machine)
   procedure Run_Builtin_Math (M    : in out Machine;
                          P    : Process_Access;
                          Base : Natural;
                          Ins  : VC.Code_Instr) is
      function Arg (I : Positive) return TW is
      begin
         return P.Stack (Base + M.Prog.Args (Ins.Args_First + I - 1));
      end Arg;

      procedure Set_Dest (W : TW) is
      begin
         P.Stack (Base + Ins.Dest) := W;
      end Set_Dest;
begin
      case Ins.Builtin is
         when VC.Bi_Bit_And =>
            declare
               A : constant Interfaces.Integer_64 := Unbox_Int (P, Arg (1));
               B : constant Interfaces.Integer_64 := Unbox_Int (P, Arg (2));
            begin
               if Ins.Has_Dest then
                  Set_Dest (Make_Int (M, P, Interfaces.Integer_64 (Interfaces.Unsigned_64 (A) and Interfaces.Unsigned_64 (B))));
               end if;
            end;
         when VC.Bi_Bit_Or =>
            declare
               A : constant Interfaces.Integer_64 := Unbox_Int (P, Arg (1));
               B : constant Interfaces.Integer_64 := Unbox_Int (P, Arg (2));
            begin
               if Ins.Has_Dest then
                  Set_Dest (Make_Int (M, P, Interfaces.Integer_64 (Interfaces.Unsigned_64 (A) or Interfaces.Unsigned_64 (B))));
               end if;
            end;
         when VC.Bi_Bit_Xor =>
            declare
               A : constant Interfaces.Integer_64 := Unbox_Int (P, Arg (1));
               B : constant Interfaces.Integer_64 := Unbox_Int (P, Arg (2));
            begin
               if Ins.Has_Dest then
                  Set_Dest (Make_Int (M, P, Interfaces.Integer_64 (Interfaces.Unsigned_64 (A) xor Interfaces.Unsigned_64 (B))));
               end if;
            end;
         when VC.Bi_Bit_Not =>
            declare
               A : constant Interfaces.Integer_64 := Unbox_Int (P, Arg (1));
            begin
               if Ins.Has_Dest then
                  Set_Dest (Make_Int (M, P, Interfaces.Integer_64 (not Interfaces.Unsigned_64 (A))));
               end if;
            end;
         when VC.Bi_Bit_Shl =>
            declare
               A : constant Interfaces.Integer_64 := Unbox_Int (P, Arg (1));
               B : constant Natural := Natural (Unbox_Int (P, Arg (2)));
            begin
               if Ins.Has_Dest then
                  if B >= 64 then
                     Set_Dest (Make_Int (M, P, 0));
                  else
                     Set_Dest (Make_Int (M, P, Interfaces.Integer_64 (Interfaces.Shift_Left (Interfaces.Unsigned_64 (A), B))));
                  end if;
               end if;
            end;
         when VC.Bi_Float_From_Int =>
            if Ins.Args_Count >= 1 then
               Set_Dest (Make_Float (M, P, Long_Float (Unbox_Int (P, Arg (1)))));
            end if;

         when VC.Bi_Bit_Shr =>
            declare
               A : constant Interfaces.Integer_64 := Unbox_Int (P, Arg (1));
               B : constant Natural := Natural (Unbox_Int (P, Arg (2)));
            begin
               if Ins.Has_Dest then
                  if B >= 64 then
                     Set_Dest (Make_Int (M, P, 0));
                  else
                     Set_Dest (Make_Int (M, P, Interfaces.Integer_64 (Interfaces.Shift_Right_Arithmetic (Interfaces.Unsigned_64 (A), B))));
                  end if;
               end if;
            end;
         when VC.Bi_Float_Sqrt | VC.Bi_Float_Exp | VC.Bi_Float_Ln | VC.Bi_Float_Sin |
              VC.Bi_Float_Cos | VC.Bi_Float_Tan | VC.Bi_Float_Atan | VC.Bi_Float_Floor |
              VC.Bi_Float_Ceil | VC.Bi_Float_Round | VC.Bi_Float_Trunc =>
            if Ins.Args_Count >= 1 then
               declare
                  X : constant Long_Float := Unbox_Float (P, Arg (1));
                  R : Long_Float;
               begin
                  case Ins.Builtin is
                     when VC.Bi_Float_Sqrt  => R := Ada.Numerics.Long_Elementary_Functions.Sqrt (X);
                     when VC.Bi_Float_Exp   => R := Ada.Numerics.Long_Elementary_Functions.Exp (X);
                     when VC.Bi_Float_Ln    => R := Ada.Numerics.Long_Elementary_Functions.Log (X);
                     when VC.Bi_Float_Sin   => R := Ada.Numerics.Long_Elementary_Functions.Sin (X);
                     when VC.Bi_Float_Cos   => R := Ada.Numerics.Long_Elementary_Functions.Cos (X);
                     when VC.Bi_Float_Tan   => R := Ada.Numerics.Long_Elementary_Functions.Tan (X);
                     when VC.Bi_Float_Atan  => R := Ada.Numerics.Long_Elementary_Functions.Arctan (X);
                     when VC.Bi_Float_Floor => R := Long_Float'Floor (X);
                     when VC.Bi_Float_Ceil  => R := Long_Float'Ceiling (X);
                     when VC.Bi_Float_Round =>
                        R := Long_Float'Rounding (X);
                     when others            => R := Long_Float'Truncation (X);
                  end case;
                  if Ins.Has_Dest then
                     Set_Dest (Make_Float (M, P, R));
                  end if;
               exception
                  when others =>
                     if Ins.Has_Dest then
                        Set_Dest (Make_Float (M, P, 0.0));
                     end if;
               end;
            end if;

         when VC.Bi_Float_Pow | VC.Bi_Float_Atan2 =>
            if Ins.Args_Count >= 2 then
               declare
                  X : constant Long_Float := Unbox_Float (P, Arg (1));
                  Y : constant Long_Float := Unbox_Float (P, Arg (2));
                  R : Long_Float;
               begin
                  if Ins.Builtin = VC.Bi_Float_Pow then
                     R := Ada.Numerics.Long_Elementary_Functions."**" (X, Y);
                  else
                     R := Ada.Numerics.Long_Elementary_Functions.Arctan (Y, X);
                  end if;
                  if Ins.Has_Dest then
                     Set_Dest (Make_Float (M, P, R));
                  end if;
               exception
                  when others =>
                     if Ins.Has_Dest then
                        Set_Dest (Make_Float (M, P, 0.0));
                     end if;
               end;
            end if;

         when VC.Bi_Float_To_Int =>
            if Ins.Args_Count >= 1 then
               declare
                  X : constant Long_Float := Unbox_Float (P, Arg (1));
               begin
                  if Ins.Has_Dest then
                     Set_Dest (Make_Small_Int (Integer_64 (Long_Float'Truncation (X))));
                  end if;
               exception
                  when others =>
                     if Ins.Has_Dest then
                        Set_Dest (Zero);
                     end if;
               end;
            end if;

         

         when others => null;
      end case;
end Run_Builtin_Math;