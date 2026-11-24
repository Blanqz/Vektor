separate (Lang.VM.Machine)
   function Str_Slot (P : Process_Access; W : TW) return Natural is
   begin
      if Is_Heap_Pointer (W) then
         declare
            Addr : constant Unsigned_64 := Unbox_Heap_Ptr (W);
         begin
            if Addr mod 16 = 0 then
               declare
                  Idx : constant Unsigned_64 := Addr / 16;
               begin
                  if Idx >= 1 and then Idx <= Unsigned_64 (P.Str_Cap)
                    and then Str_At (P, Natural (Idx)).In_Use
                  then
                     return Natural (Idx);
                  end if;
               end;
            end if;
         end;
      end if;
      return 0;
   end Str_Slot;