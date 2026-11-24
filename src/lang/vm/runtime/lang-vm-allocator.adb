with Ada.Text_IO; use Ada.Text_IO;
with Lang.VM.Machine;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Interfaces; use Interfaces;
use type Lang.VM.Machine.Machine;
use Lang.VM.Machine;
with Lang.VM.Tagged_Word; use Lang.VM.Tagged_Word;
with Lang.VM.IR; use Lang.VM.IR;
with Lang.VM.Box_Header; use Lang.VM.Box_Header;

package body Lang.VM.Allocator is

   procedure Collect (M : in out Lang.VM.Machine.Machine) is separate;

    procedure Maybe_GC_At_Safepoint (M : in out Lang.VM.Machine.Machine; P : Process_Access) is
    begin
       if M.GC_Safepoint_Pending then
          Collect (M);
          M.GC_Safepoint_Pending := False;
       elsif M.GC_Stress_Interval > 0 and then M.Allocations_Since_GC >= M.GC_Stress_Interval then
          Collect (M);
       end if;
    end Maybe_GC_At_Safepoint;

   procedure Run_Process_Drops (M : in out Lang.VM.Machine.Machine; P : Process_Access) is separate;

   procedure Compact_Strings (M : in out Lang.VM.Machine.Machine; P : Process_Access) is separate;

   procedure Resize_Free (Free : in out Index_Array_Access; Top : Natural; New_Cap : Natural) is separate;

   procedure Grow_Str (P : Process_Access) is separate;

   procedure Grow_Obj (P : Process_Access) is separate;

   procedure Grow_VT (P : Process_Access) is separate;

   procedure Grow_Box (P : Process_Access) is separate;

   procedure Init_Heap (M : in out Lang.VM.Machine.Machine; P : Process_Access) is separate;

   function Alloc_Str (M : in out Lang.VM.Machine.Machine; P : Process_Access) return Natural is separate;

   function Alloc_Large_Buffer (P : Process_Access) return Natural is separate;

   procedure Retain_Large_Buffer (P : Process_Access; Id : Natural) is separate;

   procedure Release_Large_Buffer (P : Process_Access; Id : Natural) is separate;

   procedure Promote_To_Large (P : Process_Access; Slot : Natural) is separate;

   function Alloc_Obj (M : in out Lang.VM.Machine.Machine; P : Process_Access) return Natural is separate;

   function Alloc_VT (M : in out Lang.VM.Machine.Machine; P : Process_Access) return Natural is separate;

   function Alloc_Box (M : in out Lang.VM.Machine.Machine; P : Process_Access) return Natural is separate;

end Lang.VM.Allocator;
