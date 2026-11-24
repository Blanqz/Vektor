separate (Lang.VM.Allocator)
   function Alloc_Str (M : in out Lang.VM.Machine.Machine; P : Process_Access) return Natural is
      S : Natural;
   begin
      if P.Str_Free_Top = 0 then
         Collect (M);
      end if;
      if P.Str_Free_Top = 0 then
         Grow_Str (P);
      end if;
      S := P.Str_Free (P.Str_Free_Top);
      P.Str_Free_Top := P.Str_Free_Top - 1;
      Str_At (P, S).Chars := To_Unbounded_String ("");
      Str_At (P, S).In_Use := True;
      Str_At (P, S).Marked := False;
      Str_At (P, S).Pinned := False;
      Str_At (P, S).Large := False;
      Str_At (P, S).Buf_Id := 0;
      Str_At (P, S).Gen := M.GC_Generation;
      M.Allocations_Since_GC := M.Allocations_Since_GC + 1;
      if M.GC_Stress_Interval > 0 and then M.Allocations_Since_GC >= M.GC_Stress_Interval then
         Collect (M);
      end if;
      return S;
   end Alloc_Str;