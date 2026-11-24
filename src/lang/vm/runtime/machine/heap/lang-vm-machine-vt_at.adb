separate (Lang.VM.Machine)
   function VT_At (P : Process_Access; I : Natural) return access VTable_Entry is
      Chunk_Idx : constant Positive := (I - 1) / VT_Chunk_Size + 1;
      Offset    : constant Positive := (I - 1) mod VT_Chunk_Size + 1;
   begin
      return P.VTable_Pool (Chunk_Idx).all (Offset)'Access;
   end VT_At;