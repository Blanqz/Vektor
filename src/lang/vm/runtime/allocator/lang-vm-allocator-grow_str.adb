separate (Lang.VM.Allocator)
   procedure Grow_Str (P : Process_Access) is
      Old_Cap : constant Natural := P.Str_Cap;
      New_Cap : constant Natural := Old_Cap + Str_Chunk_Size;
   begin
      P.String_Pool.Append (new Str_Chunk);
      P.Str_Cap := New_Cap;
      Resize_Free (P.Str_Free, P.Str_Free_Top, New_Cap);
      for I in reverse Old_Cap + 1 .. New_Cap loop
         P.Str_Free_Top := P.Str_Free_Top + 1;
         P.Str_Free (P.Str_Free_Top) := I;
      end loop;
   end Grow_Str;