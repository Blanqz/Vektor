separate (Lang.VM.Machine)
   function Str_At (P : Process_Access; I : Natural) return access Str_Entry is
      Chunk_Idx : constant Positive := (I - 1) / Str_Chunk_Size + 1;
      Offset    : constant Positive := (I - 1) mod Str_Chunk_Size + 1;
   begin
      return P.String_Pool (Chunk_Idx).all (Offset)'Access;
   end Str_At;