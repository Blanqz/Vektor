with Interfaces;
with System;

package Lang.VM.Platform
is

   use type Interfaces.Integer_64;

   function Resolve_Symbol (Name : String) return System.Address
     with Pre => Name'Length > 0;

   function Current_Process_Id return Interfaces.Integer_64
     with Post => Current_Process_Id'Result > 0;

end Lang.VM.Platform;
