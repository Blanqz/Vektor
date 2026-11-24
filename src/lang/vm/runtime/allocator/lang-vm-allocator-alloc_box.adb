separate (Lang.VM.Allocator)
   function Alloc_Box (M : in out Lang.VM.Machine.Machine; P : Process_Access) return Natural is
      S : Natural;
   begin
      --  Collect rebuilds the free list from scratch, so it's not refilled here.
      if P.Box_Free_Top = 0 then
         Collect (M);
         for I in 1 .. P.Box_Cap loop
            if not Box_At (P, I).In_Use then
               P.Box_Free_Top := P.Box_Free_Top + 1;
               P.Box_Free (P.Box_Free_Top) := I;
            end if;
         end loop;
      end if;
      if P.Box_Free_Top = 0 then
         Collect (M);
         for I in 1 .. P.Box_Cap loop
            if not Box_At (P, I).In_Use then
               P.Box_Free_Top := P.Box_Free_Top + 1;
               P.Box_Free (P.Box_Free_Top) := I;
            end if;
         end loop;
      end if;
      if P.Box_Free_Top = 0 then
         Grow_Box (P);
      end if;
      S := P.Box_Free (P.Box_Free_Top);
      P.Box_Free_Top := P.Box_Free_Top - 1;
      Box_At (P, S).Header := Lang.VM.Box_Header.Make (Lang.VM.Box_Header.Kind_Float64);
      Box_At (P, S).Value := 0;
      Box_At (P, S).In_Use := True;
      Box_At (P, S).Marked := False;
      Box_At (P, S).Gen := M.GC_Generation;
      M.Allocations_Since_GC := M.Allocations_Since_GC + 1;
      if M.GC_Stress_Interval > 0 and then M.Allocations_Since_GC >= M.GC_Stress_Interval then
         Collect (M);
      end if;
      return S;
   end Alloc_Box;