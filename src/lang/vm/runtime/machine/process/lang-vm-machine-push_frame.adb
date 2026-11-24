separate (Lang.VM.Machine)
   procedure Push_Frame (M       : in out Machine;
                         P        : Process_Access;
                         Fn_Index : Natural;
                         Extent   : Natural;
                         Has_Ret  : Boolean;
                         Ret_Dest : Natural;
                         Base     : out Natural) is
   begin
      if P.Depth = P.Frames.all'Length then
         declare
            Old_Len : constant Natural := P.Frames.all'Length;
            Bigger  : constant Frame_Array_Access := new Frame_Array (1 .. 2 * Old_Len);
         begin
            Bigger (1 .. P.Depth) := P.Frames (1 .. P.Depth);
            Free_Frames (P.Frames);
            P.Frames := Bigger;
         end;
      end if;

      Base := P.Sp;
      if Base + Extent - 1 > P.Stack.all'Length then
         declare
            Old_Len  : constant Natural := P.Stack.all'Length;
            New_Size : constant Natural := Natural'Max (2 * Old_Len, Base + Extent - 1);
            Bigger   : constant Value_Array_Access := new Value_Array (1 .. New_Size);
         begin
            Bigger (1 .. Old_Len) := P.Stack.all;
            Free_Values (P.Stack);
            P.Stack := Bigger;
         end;
      end if;

      for I in Base .. Base + Extent - 1 loop
         P.Stack (I) := Zero;
      end loop;

      P.Depth := P.Depth + 1;
      P.Frames (P.Depth) := (Func      => Fn_Index,
                             Pc        => 1,
                             Base      => Base,
                             Reg_Count => Extent,
                             Ret_Dest  => Ret_Dest,
                             Has_Ret   => Has_Ret,
                             Owned_Mask => M.Prog.Funcs (Fn_Index).Owned_Mask);
      P.Sp := Base + Extent;
   end Push_Frame;