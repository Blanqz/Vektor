separate (Lang.VM.Machine)
   function Chars_Of (P : Process_Access; W : TW) return Unbounded_String is
      S : constant Natural := Str_Slot (P, W);
   begin
      if S > 0 then
         if Str_At (P, S).Large and then Str_At (P, S).Buf_Id > 0 then
            return P.Large_Buffers (Str_At (P, S).Buf_Id).Data;
         end if;
         return Str_At (P, S).Chars;
      end if;
      return Null_Unbounded_String;
   end Chars_Of;