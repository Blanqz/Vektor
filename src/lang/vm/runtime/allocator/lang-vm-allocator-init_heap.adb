separate (Lang.VM.Allocator)
   procedure Init_Heap (M : in out Lang.VM.Machine.Machine; P : Process_Access) is
      Init_Str : constant Natural := Natural'Max (Pool_Size, M.Initial_Memory);
   begin
      P.String_Pool.Clear;
      for C in 1 .. (Init_Str + Str_Chunk_Size - 1) / Str_Chunk_Size loop
         P.String_Pool.Append (new Str_Chunk);
      end loop;
      P.Str_Cap := Natural (P.String_Pool.Length) * Str_Chunk_Size;

      P.Object_Pool.Clear;
      P.Object_Pool.Append (new Obj_Chunk);
      P.Obj_Cap := Obj_Chunk_Size;
      P.VTable_Pool.Clear;
      P.VTable_Pool.Append (new VT_Chunk);
      P.VT_Cap := VT_Chunk_Size;
      P.Box_Pool.Clear;
      P.Box_Pool.Append (new Box_Chunk);
      P.Box_Cap := Box_Chunk_Size;
      P.Str_Free := new Index_Array (1 .. Init_Str);
      P.Obj_Free := new Index_Array (1 .. Obj_Chunk_Size);
      P.VT_Free := new Index_Array (1 .. VT_Chunk_Size);
      P.Box_Free := new Index_Array (1 .. Box_Chunk_Size);
      for I in reverse 1 .. Init_Str loop
         P.Str_Free_Top := P.Str_Free_Top + 1;
         P.Str_Free (P.Str_Free_Top) := I;
      end loop;
      for I in reverse 1 .. Obj_Chunk_Size loop
         P.Obj_Free_Top := P.Obj_Free_Top + 1;
         P.Obj_Free (P.Obj_Free_Top) := I;
      end loop;
      for I in reverse 1 .. VT_Chunk_Size loop
         P.VT_Free_Top := P.VT_Free_Top + 1;
         P.VT_Free (P.VT_Free_Top) := I;
      end loop;
      for I in reverse 1 .. Box_Chunk_Size loop
         P.Box_Free_Top := P.Box_Free_Top + 1;
         P.Box_Free (P.Box_Free_Top) := I;
      end loop;
   end Init_Heap;