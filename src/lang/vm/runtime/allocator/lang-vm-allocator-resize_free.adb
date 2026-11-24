separate (Lang.VM.Allocator)
   procedure Resize_Free (Free : in out Index_Array_Access; Top : Natural; New_Cap : Natural) is
      Fresh : constant Index_Array_Access := new Index_Array (1 .. New_Cap);
   begin
      if Free /= null then
         for I in 1 .. Top loop
            Fresh (I) := Free (I);
         end loop;
         Free_Index (Free);
      end if;
      Free := Fresh;
   end Resize_Free;