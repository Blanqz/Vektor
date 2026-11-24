separate (Lang.VM.Allocator)
   procedure Grow_Box (P : Process_Access) is
      Old_Cap : constant Natural := P.Box_Cap;
      New_Cap : constant Natural := Old_Cap + Box_Chunk_Size;
   begin
      P.Box_Pool.Append (new Box_Chunk);
      P.Box_Cap := New_Cap;
      Resize_Free (P.Box_Free, P.Box_Free_Top, New_Cap);
      for I in reverse Old_Cap + 1 .. New_Cap loop
         P.Box_Free_Top := P.Box_Free_Top + 1;
         P.Box_Free (P.Box_Free_Top) := I;
      end loop;
   end Grow_Box;