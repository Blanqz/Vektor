separate (Lang.VM.Machine)
   function Utf8_Of (CP : Integer_64) return String is
      function Ch (N : Integer_64) return Character is (Character'Val (Integer (N)));
   begin
      if CP < 0 or else CP > 16#10FFFF# then
         return "";
      elsif CP < 16#80# then
         return (1 => Ch (CP));
      elsif CP < 16#800# then
         return (Ch (16#C0# + CP / 64), Ch (16#80# + CP mod 64));
      elsif CP < 16#10000# then
         return (Ch (16#E0# + CP / 4096), Ch (16#80# + (CP / 64) mod 64), Ch (16#80# + CP mod 64));
      else
         return (Ch (16#F0# + CP / 262144), Ch (16#80# + (CP / 4096) mod 64),
                 Ch (16#80# + (CP / 64) mod 64), Ch (16#80# + CP mod 64));
      end if;
   end Utf8_Of;