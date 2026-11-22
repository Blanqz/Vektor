with Interfaces.C;
with Interfaces.C.Strings;

package body Lang.VM.Platform
is

   use Interfaces.C;
   use Interfaces.C.Strings;
   use type System.Address;

   function LoadLibraryA (Name : chars_ptr) return System.Address;
   pragma Import (Stdcall, LoadLibraryA, "LoadLibraryA");

   function GetProcAddress (Module : System.Address; Name : chars_ptr) return System.Address;
   pragma Import (Stdcall, GetProcAddress, "GetProcAddress");

   function GetCurrentProcessId return unsigned_long;
   pragma Import (Stdcall, GetCurrentProcessId, "GetCurrentProcessId");

   function Lookup_In_Module (Module : String; Name : chars_ptr) return System.Address;

   function Lookup_In_Module (Module : String; Name : chars_ptr) return System.Address
   is
      C_Module : chars_ptr := New_String (Module);
      Handle   : System.Address;
      Addr     : System.Address;
   begin
      Handle := LoadLibraryA (C_Module);
      Free (C_Module);
      if Handle = System.Null_Address then
         return System.Null_Address;
      end if;
      Addr := GetProcAddress (Handle, Name);
      return Addr;
   end Lookup_In_Module;

   function Resolve_Symbol (Name : String) return System.Address
   is
      C_Name : chars_ptr := New_String (Name);
      Addr   : System.Address;
   begin
      Addr := Lookup_In_Module ("msvcrt.dll", C_Name);
      if Addr = System.Null_Address then
         Addr := Lookup_In_Module ("kernel32.dll", C_Name);
      end if;
      if Addr = System.Null_Address then
         Addr := Lookup_In_Module ("user32.dll", C_Name);
      end if;
      if Addr = System.Null_Address then
         Addr := Lookup_In_Module (Name, C_Name);
      end if;
      Free (C_Name);
      return Addr;
   end Resolve_Symbol;

   function Current_Process_Id return Interfaces.Integer_64
   is
   begin
      return Interfaces.Integer_64 (GetCurrentProcessId);
   end Current_Process_Id;

end Lang.VM.Platform;
