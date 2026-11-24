separate (Lang.VM.Machine)
   function Box_Slot (P : Process_Access; W : TW) return Natural is
   begin
      if Is_Box (W) then
         declare
            Idx : constant Unsigned_64 := Unbox_Box_Ptr (W) / 8;
         begin
            if Idx >= 1 and then Idx <= Unsigned_64 (P.Box_Cap)
              and then Box_At (P, Natural (Idx)).In_Use
            then
               return Natural (Idx);
            end if;
         end;
      end if;
      return 0;
   end Box_Slot;