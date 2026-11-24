separate (Lang.VM.Machine)
   function Obj_At (P : Process_Access; I : Natural) return access Obj_Entry is
      Chunk_Idx : constant Positive := (I - 1) / Obj_Chunk_Size + 1;
      Offset    : constant Positive := (I - 1) mod Obj_Chunk_Size + 1;
   begin
      return P.Object_Pool (Chunk_Idx).all (Offset)'Access;
   end Obj_At;