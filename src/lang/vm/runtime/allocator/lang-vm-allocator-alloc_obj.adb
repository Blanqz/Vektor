separate (Lang.VM.Allocator)
   function Alloc_Obj (M : in out Lang.VM.Machine.Machine; P : Process_Access) return Natural is
      S : Natural;
   begin
      if P.Obj_Free_Top = 0 then
         Collect (M);
      end if;
      if P.Obj_Free_Top = 0 then
         Grow_Obj (P);
      end if;
      S := P.Obj_Free (P.Obj_Free_Top);
      P.Obj_Free_Top := P.Obj_Free_Top - 1;
      Obj_At (P, S).Type_Name := To_Unbounded_String ("");
      Obj_At (P, S).Drop := 0;
      Obj_At (P, S).Count := 0;
      Obj_At (P, S).Fields := null;
      Obj_At (P, S).In_Use := True;
      Obj_At (P, S).Marked := False;
      Obj_At (P, S).Pinned := False;
      Obj_At (P, S).Gen := M.GC_Generation;
      M.Allocations_Since_GC := M.Allocations_Since_GC + 1;
      if M.GC_Stress_Interval > 0 and then M.Allocations_Since_GC >= M.GC_Stress_Interval then
         Collect (M);
      end if;
      return S;
   end Alloc_Obj;