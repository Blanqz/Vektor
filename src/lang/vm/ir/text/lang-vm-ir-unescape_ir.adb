separate (Lang.VM.IR)
   function Unescape_IR (S : String) return String is
      R : Unbounded_String;
      I : Natural := S'First;
   begin
      while I <= S'Last loop
         if S (I) = '\' and then I < S'Last then
            case S (I + 1) is
               when 'n'    => Append (R, ASCII.LF);
               when 't'    => Append (R, ASCII.HT);
               when 'r'    => Append (R, ASCII.CR);
               when '0'    => Append (R, ASCII.NUL);
               when others => Append (R, S (I + 1));
            end case;
            I := I + 2;
         else
            Append (R, S (I));
            I := I + 1;
         end if;
      end loop;
      return To_String (R);
   end Unescape_IR;