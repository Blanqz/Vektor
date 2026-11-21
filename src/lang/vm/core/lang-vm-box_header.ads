with Interfaces;
use Interfaces;

package Lang.VM.Box_Header is

   type Box_Kind is (Kind_Int64, Kind_Float64);

   type Box_Header is private;

   function Make (Kind : Box_Kind) return Box_Header;
   function Kind_Of (H : Box_Header) return Box_Kind;
   function Is_Marked (H : Box_Header) return Boolean;
   procedure Set_Marked (H : in out Box_Header; Value : Boolean);

private

   type Box_Header is new Interfaces.Unsigned_64;
   for Box_Header'Size use 64;

end Lang.VM.Box_Header;