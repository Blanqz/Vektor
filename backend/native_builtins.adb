with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Native_Helpers; use Native_Helpers;

package body Native_Builtins is
   function Map_Builtin (Callee : String) return String is
   begin
      if Callee = "IO.puts" or Callee = "puts" then
         return "vect_puts";
      elsif Callee = "Int.to_string" or Callee = "to_string" then
         return "vect_int_to_string";
      elsif Callee = "String.concat" or Callee = "concat" then
         return "vect_concat";
      elsif Callee = "String.len" or Callee = "len" then
         return "vect_len";
      else
         return Sanitize (Callee);
      end if;
   end Map_Builtin;
end Native_Builtins;
