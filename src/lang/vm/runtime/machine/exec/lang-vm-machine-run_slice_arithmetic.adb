separate (Lang.VM.Machine)
   procedure Run_Slice_Arithmetic (M : in out Machine; P : Process_Access; D : in out Natural; Fr : in out Frame; Fn : in out VC.Func_Code; Base : in out Natural; S : in out Value_Array_Access; Pc : in out Natural; Ins : VC.Code_Instr) is
   begin
      case Ins.Op is
                     when Op_Add_Int =>
                        S (Base + Ins.Dest) := Make_Int (M, P,
                          Checked_Add (Unbox_Int (P, S (Base + Ins.Src1)),
                                       Unbox_Int (P, S (Base + Ins.Src2))));

                     when Op_Sub_Int =>
                        S (Base + Ins.Dest) := Make_Int (M, P,
                          Checked_Sub (Unbox_Int (P, S (Base + Ins.Src1)),
                                       Unbox_Int (P, S (Base + Ins.Src2))));

                     when Op_Mul_Int =>
                        S (Base + Ins.Dest) := Make_Int (M, P,
                          Checked_Mul (Unbox_Int (P, S (Base + Ins.Src1)),
                                       Unbox_Int (P, S (Base + Ins.Src2))));

                     when Op_Add_Float =>
                        S (Base + Ins.Dest) := Make_Float (M, P,
                          Unbox_Float (P, S (Base + Ins.Src1)) +
                          Unbox_Float (P, S (Base + Ins.Src2)));

                     when Op_Sub_Float =>
                        S (Base + Ins.Dest) := Make_Float (M, P,
                          Unbox_Float (P, S (Base + Ins.Src1)) -
                          Unbox_Float (P, S (Base + Ins.Src2)));

                     when Op_Mul_Float =>
                        S (Base + Ins.Dest) := Make_Float (M, P,
                          Unbox_Float (P, S (Base + Ins.Src1)) *
                          Unbox_Float (P, S (Base + Ins.Src2)));

                     when Op_Div_Float =>
                        declare
                           Dv : constant Long_Float := Unbox_Float (P, S (Base + Ins.Src2));
                        begin
                           if Dv = 0.0 then
                              raise Constraint_Error with "division by zero";
                           end if;
                           S (Base + Ins.Dest) := Make_Float (M, P,
                             Unbox_Float (P, S (Base + Ins.Src1)) / Dv);
                        end;

                     when Op_Div_Int =>
                        S (Base + Ins.Dest) := Make_Int (M, P,
                          Checked_Div (Unbox_Int (P, S (Base + Ins.Src1)),
                                       Unbox_Int (P, S (Base + Ins.Src2))));

                     when Op_Mod_Int =>
                        S (Base + Ins.Dest) := Make_Int (M, P,
                          Checked_Rem (Unbox_Int (P, S (Base + Ins.Src1)),
                                       Unbox_Int (P, S (Base + Ins.Src2))));

                     when Op_Icmp =>
                        --  Integers (small or boxed) compare by value. Anything
                        --  else (none, bool, pointers) compares by raw word, so
                        --  none == none holds and none never equals an integer.
                        declare
                           WA : constant TW := S (Base + Ins.Src1);
                           WB : constant TW := S (Base + Ins.Src2);
                           R  : Boolean := False;
                        begin
                           if Is_Int_Like (P, WA) and then Is_Int_Like (P, WB) then
                              declare
                                 A : constant Integer_64 := Unbox_Int (P, WA);
                                 B : constant Integer_64 := Unbox_Int (P, WB);
                              begin
                                 case Ins.Cmp is
                                    when Cmp_Eq => R := A = B;
                                    when Cmp_Ne => R := A /= B;
                                    when Cmp_Lt => R := A < B;
                                    when Cmp_Le => R := A <= B;
                                    when Cmp_Gt => R := A > B;
                                    when Cmp_Ge => R := A >= B;
                                 end case;
                              end;
                           elsif Is_Float_Box (P, WA) and then Is_Float_Box (P, WB) then
                              declare
                                 A : constant Long_Float := Unbox_Float (P, WA);
                                 B : constant Long_Float := Unbox_Float (P, WB);
                              begin
                                 case Ins.Cmp is
                                    when Cmp_Eq => R := A = B;
                                    when Cmp_Ne => R := A /= B;
                                    when Cmp_Lt => R := A < B;
                                    when Cmp_Le => R := A <= B;
                                    when Cmp_Gt => R := A > B;
                                    when Cmp_Ge => R := A >= B;
                                 end case;
                              end;
                           elsif Str_Slot (P, WA) > 0 and then Str_Slot (P, WB) > 0
                             and then (Ins.Cmp = Cmp_Eq or else Ins.Cmp = Cmp_Ne)
                           then
                              declare
                                 Same : constant Boolean :=
                                   To_String (Str_At (P, Str_Slot (P, WA)).Chars)
                                   = To_String (Str_At (P, Str_Slot (P, WB)).Chars);
                              begin
                                 R := (Same and then Ins.Cmp = Cmp_Eq)
                                   or else (not Same and then Ins.Cmp = Cmp_Ne);
                              end;
                           else
                              case Ins.Cmp is
                                 when Cmp_Eq => R := To_Raw (WA) = To_Raw (WB);
                                 when Cmp_Ne => R := To_Raw (WA) /= To_Raw (WB);
                                 when others => R := False;
                              end case;
                           end if;
                           S (Base + Ins.Dest) := Make_Bool (R);
                        end;

         when others => null;
      end case;
   end Run_Slice_Arithmetic;