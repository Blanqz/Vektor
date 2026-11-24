separate (Lang.VM.Allocator)
   procedure Compact_Strings (M : in out Lang.VM.Machine.Machine; P : Process_Access) is
      Map : Index_Array_Access := new Index_Array'(1 .. P.Str_Cap => 0);
      New_Top : Natural := 0;
      function Update_Str_Ref (W : TW) return TW is
         S : Natural;
      begin
         S := Str_Slot (P, W);
         if S > 0 and then Map (S) > 0 then
            return Str_Ptr (Map (S));
         end if;
         return W;
      end Update_Str_Ref;
   begin
      for I in 1 .. P.Str_Cap loop
         if Str_At (P, I).In_Use then
            New_Top := New_Top + 1;
            Map (I) := New_Top;
         else
            Map (I) := 0;
         end if;
      end loop;
      if New_Top = 0 then
         return;
      end if;
      declare
         Already_Compact : Boolean := True;
      begin
         for I in 1 .. P.Str_Cap loop
            if Str_At (P, I).In_Use and then Map (I) /= I then
               Already_Compact := False;
               exit;
            end if;
         end loop;
         if Already_Compact then
            return;
         end if;
      end;
      for I in 1 .. P.Str_Cap loop
         if Map (I) > 0 and then Map (I) /= I then
            Str_At (P, Map (I)).all := Str_At (P, I).all;
            Str_At (P, I).In_Use := False;
            Str_At (P, I).Chars := Null_Unbounded_String;
         end if;
      end loop;
      for F in 1 .. P.Depth loop
         for I in 0 .. P.Frames (F).Reg_Count - 1 loop
            P.Stack (P.Frames (F).Base + I) := Update_Str_Ref (P.Stack (P.Frames (F).Base + I));
         end loop;
      end loop;
      for I in 0 .. P.Mail_Count - 1 loop
         declare
            Idx : constant Natural := ((P.Mail_Head + I) mod P.Mail.all'Length) + 1;
         begin
            P.Mail (Idx) := Update_Str_Ref (P.Mail (Idx));
         end;
      end loop;
      for O in 1 .. P.Obj_Cap loop
         if Obj_At (P, O).In_Use and then Obj_At (P, O).Fields /= null then
            for I in 1 .. Obj_At (P, O).Count loop
               Obj_At (P, O).Fields (I) := Update_Str_Ref (Obj_At (P, O).Fields (I));
            end loop;
         end if;
      end loop;
      P.Result := Update_Str_Ref (P.Result);
      P.Str_Free_Top := 0;
      for I in reverse 1 .. P.Str_Cap loop
         if not Str_At (P, I).In_Use then
            P.Str_Free_Top := P.Str_Free_Top + 1;
            P.Str_Free (P.Str_Free_Top) := I;
         end if;
      end loop;
      Free_Index (Map);
   end Compact_Strings;