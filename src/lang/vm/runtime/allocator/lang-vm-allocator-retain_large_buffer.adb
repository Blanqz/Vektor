separate (Lang.VM.Allocator)
   procedure Retain_Large_Buffer (P : Process_Access; Id : Natural) is
   begin
      if Id >= 1 and then Id <= 64 and then P.Large_Buffers (Id).In_Use then
         P.Large_Buffers (Id).RefCnt := P.Large_Buffers (Id).RefCnt + 1;
      end if;
   end Retain_Large_Buffer;