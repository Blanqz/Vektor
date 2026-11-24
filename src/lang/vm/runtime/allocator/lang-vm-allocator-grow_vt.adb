separate (Lang.VM.Allocator)
   procedure Grow_VT (P : Process_Access) is
      Old_Cap : constant Natural := P.VT_Cap;
      New_Cap : constant Natural := Old_Cap + VT_Chunk_Size;
   begin
      P.VTable_Pool.Append (new VT_Chunk);
      P.VT_Cap := New_Cap;
      Resize_Free (P.VT_Free, P.VT_Free_Top, New_Cap);
      for I in reverse Old_Cap + 1 .. New_Cap loop
         P.VT_Free_Top := P.VT_Free_Top + 1;
         P.VT_Free (P.VT_Free_Top) := I;
      end loop;
   end Grow_VT;