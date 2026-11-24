separate (Lang.VM.Machine)
   procedure Run_Builtin_Console (M    : in out Machine;
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
         when VC.Bi_Read_Line =>
            declare
               Line : String := Get_Line;
               Slot : constant Natural := Allocator.Alloc_Str (M, P);
            begin
               Str_At (P, Slot).Chars := To_Unbounded_String (Line);
               if Ins.Has_Dest then
                  Set_Dest (Str_Ptr (Slot));
               end if;
            end;

         when VC.Bi_Read_Int =>
            declare
               Line : constant String := Get_Line;
               Val  : Integer_64;
            begin
               Val := Integer_64'Value (Ada.Strings.Fixed.Trim (Line, Ada.Strings.Both));
               if Ins.Has_Dest then
                  Set_Dest (Make_Small_Int (Val));
               end if;
            exception
               when others =>
                  if Ins.Has_Dest then
                     Set_Dest (Zero);
                  end if;
            end;

         when VC.Bi_Err_Puts =>
            if Ins.Args_Count >= 1 then
               declare
                  V   : constant TW := Arg (1);
                  Msg : constant String :=
                    (if Is_Heap_Pointer (V) then To_String (Chars_Of (P, V))
                     elsif V = Make_None then "none"
                     elsif V = Make_None then "none"
                     else Integer'Image (Integer (Unbox_Small_Int (V))));
               begin
                  Flush (Standard_Output);
                  Put_Line (Standard_Error, Msg);
                  Flush (Standard_Error);
               end;
            end if;
            if Ins.Has_Dest then
               Set_Dest (Zero);
            end if;

         when VC.Bi_Clock_Mono_Ms =>
            if Ins.Has_Dest then
               declare
                  Span : constant Ada.Real_Time.Time_Span :=
                    Ada.Real_Time."-" (Ada.Real_Time.Clock, Mono_Epoch);
               begin
                  Set_Dest (Make_Small_Int (Integer_64 (
                    Long_Float (Ada.Real_Time.To_Duration (Span)) * 1000.0)));
               end;
            end if;

         when VC.Bi_Clock_Sleep_Ms =>
            declare
               Ms : constant Integer_64 := Unbox_Int (P, Arg (1));
            begin
               if Ms > 0 then
                  delay Duration (Long_Float (Ms) / 1000.0);
               end if;
               if Ins.Has_Dest then
                  Set_Dest (Make_Unit);
               end if;
            end;

         when VC.Bi_None =>
            null;



         when others => null;
      end case;
end Run_Builtin_Console;