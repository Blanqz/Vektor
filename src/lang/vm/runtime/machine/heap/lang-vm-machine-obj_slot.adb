separate (Lang.VM.Machine)
   function Obj_Slot (P : Process_Access; W : TW) return Natural is
   begin
      if Is_Heap_Pointer (W) then
         declare
            Addr : constant Unsigned_64 := Unbox_Heap_Ptr (W);
         begin
            if Addr mod 16 = 8 then
               declare
                  Idx : constant Unsigned_64 := Addr / 16;
               begin
                  if Idx >= 1 and then Idx <= Unsigned_64 (P.Obj_Cap)
                    and then Obj_At (P, Natural (Idx)).In_Use
                  then
                     return Natural (Idx);
                  end if;
               end;
            end if;
         end;
      end if;
      return 0;
   end Obj_Slot;