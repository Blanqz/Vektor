with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Unchecked_Conversion;
with Interfaces; use Interfaces;

package body Native_Helpers is
   function Sanitize (S : String) return String is
      R : Unbounded_String := To_Unbounded_String ("");
   begin
      for C of S loop
         if C = '.' then
            Append (R, '_');
         else
            Append (R, C);
         end if;
      end loop;
      return To_String (R);
   end Sanitize;

   function Float_Bits (V : Long_Float) return Unsigned_64 is
      function Cast is new Ada.Unchecked_Conversion (Long_Float, Unsigned_64);
   begin
      return Cast (V);
   end Float_Bits;

   function Escape_Asciz (S : String) return String is
      R : Unbounded_String := To_Unbounded_String ("");
   begin
      for C of S loop
         case C is
            when '"' =>
               Append (R, '\');
               Append (R, '"');
            when '\' =>
               Append (R, '\');
               Append (R, '\');
            when ASCII.LF =>
               Append (R, '\');
               Append (R, 'n');
            when ASCII.CR =>
               Append (R, '\');
               Append (R, 'r');
            when ASCII.HT =>
               Append (R, '\');
               Append (R, 't');
            when others =>
               Append (R, C);
         end case;
      end loop;
      return To_String (R);
   end Escape_Asciz;
end Native_Helpers;
