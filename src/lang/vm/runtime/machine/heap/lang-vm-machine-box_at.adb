separate (Lang.VM.Machine)
   function Box_At (P : Process_Access; I : Natural) return access Box_Entry is
      Chunk_Idx : constant Positive := (I - 1) / Box_Chunk_Size + 1;
      Offset    : constant Positive := (I - 1) mod Box_Chunk_Size + 1;
   begin
      return P.Box_Pool (Chunk_Idx).all (Offset)'Access;
   end Box_At;