with Ada.Containers.Vectors;
with GNAT.Sockets;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with Lang.VM.IR; use Lang.VM.IR;
with Lang.VM.Code;
with Lang.VM.Tagged_Word;
with Lang.VM.Box_Header; use Lang.VM.Box_Header;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Interfaces; use Interfaces;
use type Lang.VM.Tagged_Word.Tagged_Word;

package Lang.VM.Machine is

   package VC renames Lang.VM.Code;

   package Name_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type => String, Element_Type => Natural, Hash => Ada.Strings.Hash, Equivalent_Keys => "=");
   package Natural_Vectors is new Ada.Containers.Vectors (Positive, Natural);

   type Thread_Info is record
      Run_Queue : Natural_Vectors.Vector;
      Current   : Natural := 0;
   end record;
   package Thread_Info_Vectors is new Ada.Containers.Vectors (Positive, Thread_Info);

   subtype TW is Lang.VM.Tagged_Word.Tagged_Word;

   Heap_Exhausted : exception;

   Pool_Size        : constant := 512;   
   Object_Pool_Size : constant := 256;   
   VTable_Pool_Size : constant := 64;    
   Box_Pool_Size    : constant := 256;   

   
   Flag_No_Alias     : constant := 1;
   Flag_No_Null      : constant := 2;
   Flag_No_Overflow  : constant := 4;
   Flag_Exhaustive   : constant := 8;

   type Frame is record
      Func     : Natural := 0;
      Reg_Count : Natural := 0;
      Pc       : Natural := 1;
      Base     : Natural := 1;
      Ret_Dest : Natural := 0;
      Has_Ret  : Boolean := False;
      Owned_Mask : Interfaces.Unsigned_32 := 0;
   end record;

   type Frame_Array is array (Positive range <>) of Frame;
   type Frame_Array_Access is access Frame_Array;

   type Value_Array is array (Positive range <>) of TW;
   type Value_Array_Access is access Value_Array;

   type Process_Status is (Proc_Runnable, Proc_Blocked, Proc_Dead);

   type Str_Entry is record
      Chars  : Unbounded_String := To_Unbounded_String ("");
       In_Use : Boolean := False;
       Marked : Boolean := False;
       Pinned : Boolean := False;
       Large  : Boolean := False;
       Buf_Id : Natural := 0;
       Gen    : Natural := 0;
   end record;
   Str_Chunk_Size : constant := 512;
   type Str_Chunk is array (1 .. Str_Chunk_Size) of aliased Str_Entry;
   type Str_Chunk_Access is access Str_Chunk;
   package Str_Chunk_Vectors is new Ada.Containers.Vectors (Positive, Str_Chunk_Access);
   subtype Str_Pool_Access is Str_Chunk_Vectors.Vector;

   Large_Buffer_Threshold : constant := 256;

   type Large_Buffer is record
      Data   : Unbounded_String := To_Unbounded_String ("");
      RefCnt : Natural := 0;
      In_Use : Boolean := False;
   end record;
   type Large_Buffer_Array is array (1 .. 64) of Large_Buffer;
   type Large_Buffer_Array_Access is access Large_Buffer_Array;

   type Obj_Entry is record
      Type_Name : Unbounded_String := To_Unbounded_String ("");
      Drop      : Natural := 0;
      Count     : Natural := 0;
      Fields    : Value_Array_Access := null;
      In_Use    : Boolean := False;
      Marked    : Boolean := False;
      Pinned    : Boolean := False;
      Gen       : Natural := 0;
   end record;
   Obj_Chunk_Size : constant := 256;
   type Obj_Chunk is array (1 .. Obj_Chunk_Size) of aliased Obj_Entry;
   type Obj_Chunk_Access is access Obj_Chunk;
   package Obj_Chunk_Vectors is new Ada.Containers.Vectors (Positive, Obj_Chunk_Access);
   subtype Obj_Pool_Access is Obj_Chunk_Vectors.Vector;

   type VTable_Entry is record
      Methods : VC.Natural_Array_Access := null;
      In_Use  : Boolean := False;
      Marked  : Boolean := False;
   end record;
   VT_Chunk_Size : constant := 64;
   type VT_Chunk is array (1 .. VT_Chunk_Size) of aliased VTable_Entry;
   type VT_Chunk_Access is access VT_Chunk;
   package VT_Chunk_Vectors is new Ada.Containers.Vectors (Positive, VT_Chunk_Access);
   subtype VTable_Pool_Access is VT_Chunk_Vectors.Vector;

   type Box_Entry is record
      Header  : Lang.VM.Box_Header.Box_Header := Lang.VM.Box_Header.Make (Lang.VM.Box_Header.Kind_Int64);
      Value   : Interfaces.Unsigned_64 := 0;
      In_Use  : Boolean := False;
      Marked  : Boolean := False;
      Gen     : Natural := 0;
   end record;
   Box_Chunk_Size : constant := 256;
   type Box_Chunk is array (1 .. Box_Chunk_Size) of aliased Box_Entry;
   type Box_Chunk_Access is access Box_Chunk;
   package Box_Chunk_Vectors is new Ada.Containers.Vectors (Positive, Box_Chunk_Access);
   subtype Box_Pool_Access is Box_Chunk_Vectors.Vector;

   type Index_Array is array (Positive range <>) of Natural;
   type Index_Array_Access is access Index_Array;

   type Process;
   type Process_Access is access all Process;

   type Process is record
      Id         : Natural := 0;
       String_Pool  : Str_Chunk_Vectors.Vector;
       Str_Cap      : Natural := 0;
       Object_Pool  : Obj_Chunk_Vectors.Vector;
       Obj_Cap      : Natural := 0;
       VTable_Pool  : VT_Chunk_Vectors.Vector;
       VT_Cap       : Natural := 0;
       Box_Pool     : Box_Chunk_Vectors.Vector;
       Box_Cap      : Natural := 0;
       Str_Free     : Index_Array_Access := null;
       Str_Free_Top : Natural := 0;
       Obj_Free     : Index_Array_Access := null;
       Obj_Free_Top : Natural := 0;
       VT_Free      : Index_Array_Access := null;
       VT_Free_Top  : Natural := 0;
       Box_Free     : Index_Array_Access := null;
       Box_Free_Top : Natural := 0;
       Large_Buffers : Large_Buffer_Array_Access := null;
       Status     : Process_Status := Proc_Runnable;
       GC_Pending : Boolean := False;
       Result     : TW := Lang.VM.Tagged_Word.Make_Small_Int (0);
       Reductions : Natural := 2000;
       Frames     : Frame_Array_Access := null;
       Depth      : Natural := 0;
       Stack      : Value_Array_Access := null;
       Sp         : Natural := 1;
       Mail           : Value_Array_Access := null;
       Mail_Head      : Natural := 0;
       Mail_Count     : Natural := 0;
       Blocked_Until  : Natural := 0;
       Recv_Timed_Out : Boolean := False;
       Assigned_Thread : Natural := 1;
       Deep_Copy_In_Progress : Boolean := False;
   end record;

   package Process_Vectors is new Ada.Containers.Vectors (Positive, Process_Access);

   type Socket_Access is access GNAT.Sockets.Socket_Type;
   package Socket_Vectors is new Ada.Containers.Vectors (Positive, Socket_Access);
   package Bool_Vectors is new Ada.Containers.Vectors (Positive, Boolean);
   type Machine is record
       Modu      : Ir_Module;
       Prog      : Lang.VM.Code.Program;
       Compiled  : Boolean := False;
       Processes   : Process_Vectors.Vector;
       Func_Names  : Name_Maps.Map;
       Pid_To_Idx  : Natural_Vectors.Vector;
       Current     : Natural := 0;
       Next_Pid  : Natural := 1;
       Clock     : Natural := 0;
       Allocations_Since_GC : Natural := 0;
       GC_Stress_Interval : Natural := 0;
       Verify_Roots : Boolean := False;
       Threads : Thread_Info_Vectors.Vector;
       Thread_Count : Natural := 1;
       GC_Safepoint_Pending : Boolean := False;
       Major_GC : Boolean := False;
       GC_Generation : Natural := 0;
       Initial_Memory : Natural := 1024;
       Max_Memory : Natural := 0;
       Net_Sockets : Socket_Vectors.Vector;
       Net_Active  : Bool_Vectors.Vector;
   end record;

   function Func_Index (M : Machine; Name : String) return Natural;
   procedure Spawn_Process (M : in out Machine; Func_Name : String; New_Pid : out Natural);
   procedure Run (M : in out Machine; Entry_Name : String; Thread_Count : Natural := 1);
   procedure Verify_Roots (M : in out Machine);
   function Last_Result (M : Machine) return TW;

   procedure Maybe_GC_At_Safepoint (M : in out Machine; P : Process_Access);
   procedure Compact_Strings (M : in out Machine; P : Process_Access);
   procedure Run_Process_Drops (M : in out Machine; P : Process_Access);

   function Alloc_Large_Buffer (P : Process_Access) return Natural;
   procedure Retain_Large_Buffer (P : Process_Access; Id : Natural);
   procedure Release_Large_Buffer (P : Process_Access; Id : Natural);
   procedure Promote_To_Large (P : Process_Access; Slot : Natural);

   function Str_Slot (P : Process_Access; W : TW) return Natural;
   function Chars_Of (P : Process_Access; W : TW) return Ada.Strings.Unbounded.Unbounded_String;

   function Make_Float (M : in out Machine; P : Process_Access; Value : Long_Float) return TW;
   function Unbox_Float (P : Process_Access; W : TW) return Long_Float;

   function Make_Int (M : in out Machine; P : Process_Access; Value : Interfaces.Integer_64)
     return TW;
   function Unbox_Int (P : Process_Access; W : TW) return Interfaces.Integer_64;
   function Is_Int_Box (P : Process_Access; W : TW) return Boolean;

   function Str_At (P : Process_Access; I : Natural) return access Str_Entry;
end Lang.VM.Machine;
