separate (Lang.VM.Allocator)
   function Alloc_Large_Buffer (P : Process_Access) return Natural is
   begin
      for I in 1 .. 64 loop
         if not P.Large_Buffers (I).In_Use then
            P.Large_Buffers (I).In_Use := True;
            P.Large_Buffers (I).RefCnt := 1;
            P.Large_Buffers (I).Data := To_Unbounded_String ("");
            return I;
         end if;
      end loop;
      return 0;
   end Alloc_Large_Buffer;