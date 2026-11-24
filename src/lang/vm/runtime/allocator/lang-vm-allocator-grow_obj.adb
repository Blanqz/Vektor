separate (Lang.VM.Allocator)
   procedure Grow_Obj (P : Process_Access) is
      Old_Cap : constant Natural := P.Obj_Cap;
      New_Cap : constant Natural := Old_Cap + Obj_Chunk_Size;
   begin
      P.Object_Pool.Append (new Obj_Chunk);
      P.Obj_Cap := New_Cap;
      Resize_Free (P.Obj_Free, P.Obj_Free_Top, New_Cap);
      for I in reverse Old_Cap + 1 .. New_Cap loop
         P.Obj_Free_Top := P.Obj_Free_Top + 1;
         P.Obj_Free (P.Obj_Free_Top) := I;
      end loop;
   end Grow_Obj;