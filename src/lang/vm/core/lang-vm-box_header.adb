with Interfaces;
use Interfaces;

package body Lang.VM.Box_Header is

   Kind_Mask : constant Unsigned_64 := 1;
   Mark_Mask : constant Unsigned_64 := 16#2#;

   function Make (Kind : Box_Kind) return Box_Header is
   begin
      if Kind = Kind_Int64 then
         return Box_Header (0);
      else
         return Box_Header (1);
      end if;
   end Make;

   function Kind_Of (H : Box_Header) return Box_Kind is
   begin
      if (Unsigned_64 (H) and Kind_Mask) = 0 then
         return Kind_Int64;
      else
         return Kind_Float64;
      end if;
   end Kind_Of;

   function Is_Marked (H : Box_Header) return Boolean is
   begin
      return (Unsigned_64 (H) and Mark_Mask) /= 0;
   end Is_Marked;

   procedure Set_Marked (H : in out Box_Header; Value : Boolean) is
   begin
      if Value then
         H := Box_Header (Unsigned_64 (H) or Mark_Mask);
      else
         H := Box_Header (Unsigned_64 (H) and (not Mark_Mask));
      end if;
   end Set_Marked;

end Lang.VM.Box_Header;