separate (Lang.VM.Machine)
   function Deep_Copy (M : in out Machine; SrcP, DstP : Process_Access; W : TW) return TW is
      S  : Natural;
      O  : Natural;
      Slot : Natural;
      VIdx : Natural;
      DSlot : Natural;
   begin
      DstP.Deep_Copy_In_Progress := True;
      begin
         if not Is_Heap_Pointer (W) then
            DstP.Deep_Copy_In_Progress := False;
            return W;
         end if;
      S := Str_Slot (SrcP, W);
      if S > 0 then
         Slot := Allocator.Alloc_Str (M, DstP);
         Str_At (DstP, Slot).Chars := Str_At (SrcP, S).Chars;
         Str_At (DstP, Slot).Pinned := Str_At (SrcP, S).Pinned;
         return Str_Ptr (Slot);
      end if;
      O := Obj_Slot (SrcP, W);
      if O > 0 then
         declare
            SrcObj : Obj_Entry renames Obj_At (SrcP, O).all;
            Count  : constant Natural := SrcObj.Count;
            F      : Value_Array_Access := null;
         begin
            Slot := Allocator.Alloc_Obj (M, DstP);
            Obj_At (DstP, Slot).Pinned := True;
            Obj_At (DstP, Slot).Type_Name := SrcObj.Type_Name;
            Obj_At (DstP, Slot).Drop := SrcObj.Drop;
            Obj_At (DstP, Slot).Count := Count;
            if Count > 0 then
               F := new Value_Array (1 .. Count);
               Obj_At (DstP, Slot).Fields := F;
               for I in 1 .. Count loop
                  F (I) := Deep_Copy (M, SrcP, DstP, SrcObj.Fields (I));
               end loop;
               if Count >= 2 and then Is_Small_Int (SrcObj.Fields (2)) then
                  VIdx := Natural (Unbox_Small_Int (SrcObj.Fields (2)));
                  if VIdx >= 1 and then VIdx <= SrcP.VT_Cap and then VT_At (SrcP, VIdx).In_Use then
                     DSlot := Allocator.Alloc_VT (M, DstP);
                     if VT_At (SrcP, VIdx).Methods /= null then
                        declare
                           N : constant Natural := VT_At (SrcP, VIdx).Methods.all'Length;
                           MArr : VC.Natural_Array_Access := new VC.Natural_Array (1 .. N);
                        begin
                           MArr (1 .. N) := VT_At (SrcP, VIdx).Methods (1 .. N);
                           VT_At (DstP, DSlot).Methods := MArr;
                        end;
                     end if;
                     F (2) := Make_Small_Int (Integer_64 (DSlot));
                  end if;
               end if;
            end if;
            Obj_At (DstP, Slot).Pinned := False;
            return Obj_Ptr (Slot);
         end;
      end if;
      declare
         B : constant Natural := Box_Slot (SrcP, W);
      begin
         if B > 0 then
            declare
               Slot : constant Natural := Allocator.Alloc_Box (M, DstP);
            begin
               Box_At (DstP, Slot).Header := Box_At (SrcP, B).Header;
               Box_At (DstP, Slot).Value := Box_At (SrcP, B).Value;
               return Box_Ptr (Slot);
            end;
         end if;
      end;  -- declare box
      end;  -- inner begin
      DstP.Deep_Copy_In_Progress := False;
      return W;
   end Deep_Copy;