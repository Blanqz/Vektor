with Interfaces.C;
with Interfaces.C.Strings;

package body Lang.VM.Platform
is

   use Interfaces.C;
   use Interfaces.C.Strings;
   use type System.Address;

   Rtld_Lazy : constant int := 1;

   function Dlopen (Name : chars_ptr; Flags : int) return System.Address;
   pragma Import (C, Dlopen, "dlopen");

   function Dlsym (Handle : System.Address; Name : chars_ptr) return System.Address;
   pragma Import (C, Dlsym, "dlsym");

   function Getpid return int;
   pragma Import (C, Getpid, "getpid");

   function Lookup_In_Library (Library : String; Name : chars_ptr) return System.Address;

   function Lookup_In_Library (Library : String; Name : chars_ptr) return System.Address
   is
      C_Library : chars_ptr := New_String (Library);
      Handle    : System.Address;
      Addr      : System.Address;
   begin
      Handle := Dlopen (C_Library, Rtld_Lazy);
      Free (C_Library);
      if Handle = System.Null_Address then
         return System.Null_Address;
      end if;
      Addr := Dlsym (Handle, Name);
      return Addr;
   end Lookup_In_Library;

   function Resolve_Symbol (Name : String) return System.Address
   is
      C_Name : chars_ptr := New_String (Name);
      Addr   : System.Address;
   begin
      --  A null handle makes dlsym search the global scope (RTLD_DEFAULT).
      Addr := Dlsym (System.Null_Address, C_Name);
      if Addr = System.Null_Address then
         Addr := Lookup_In_Library ("libc.so.6", C_Name);
      end if;
      if Addr = System.Null_Address then
         Addr := Lookup_In_Library ("libm.so.6", C_Name);
      end if;
      if Addr = System.Null_Address then
         Addr := Lookup_In_Library (Name, C_Name);
      end if;
      Free (C_Name);
      return Addr;
   end Resolve_Symbol;

   function Current_Process_Id return Interfaces.Integer_64
   is
   begin
      return Interfaces.Integer_64 (Getpid);
   end Current_Process_Id;

end Lang.VM.Platform;
