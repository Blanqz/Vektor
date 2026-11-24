separate (Lang.VM.Allocator)
   procedure Release_Large_Buffer (P : Process_Access; Id : Natural) is
   begin
      if Id >= 1 and then Id <= 64 and then P.Large_Buffers (Id).In_Use then
         if P.Large_Buffers (Id).RefCnt > 0 then
            P.Large_Buffers (Id).RefCnt := P.Large_Buffers (Id).RefCnt - 1;
         end if;
         if P.Large_Buffers (Id).RefCnt = 0 then
            P.Large_Buffers (Id).In_Use := False;
            P.Large_Buffers (Id).Data := To_Unbounded_String ("");
         end if;
      end if;
   end Release_Large_Buffer;