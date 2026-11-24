separate (Lang.VM.Allocator)
   function Alloc_VT (M : in out Lang.VM.Machine.Machine; P : Process_Access) return Natural is
      S : Natural;
   begin
      --  Collect rebuilds the free list from scratch, so it's not refilled here.
      if P.VT_Free_Top = 0 then
         Collect (M);
         for I in 1 .. P.VT_Cap loop
            if not VT_At (P, I).In_Use then
               P.VT_Free_Top := P.VT_Free_Top + 1;
               P.VT_Free (P.VT_Free_Top) := I;
            end if;
         end loop;
      end if;
      if P.VT_Free_Top = 0 then
         Collect (M);
         for I in 1 .. P.VT_Cap loop
            if not VT_At (P, I).In_Use then
               P.VT_Free_Top := P.VT_Free_Top + 1;
               P.VT_Free (P.VT_Free_Top) := I;
            end if;
         end loop;
      end if;
      if P.VT_Free_Top = 0 then
         Grow_VT (P);
      end if;
      S := P.VT_Free (P.VT_Free_Top);
      P.VT_Free_Top := P.VT_Free_Top - 1;
      VT_At (P, S).Methods := null;
      VT_At (P, S).In_Use := True;
      VT_At (P, S).Marked := False;
      M.Allocations_Since_GC := M.Allocations_Since_GC + 1;
      if M.GC_Stress_Interval > 0 and then M.Allocations_Since_GC >= M.GC_Stress_Interval then
         Collect (M);
      end if;
      return S;
   end Alloc_VT;