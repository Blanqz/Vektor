with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Interfaces; use Interfaces;

package Native_Helpers is
   function Sanitize (S : String) return String;
   function Float_Bits (V : Long_Float) return Unsigned_64;
   function Escape_Asciz (S : String) return String;
end Native_Helpers;
