with Lang.VM.Machine;
with Lang.VM.Tagged_Word; use Lang.VM.Tagged_Word;

package Lang.VM.Allocator is
   procedure Init_Heap (M : in out Lang.VM.Machine.Machine; P : Lang.VM.Machine.Process_Access);
   procedure Grow_Str (P : Lang.VM.Machine.Process_Access);
   procedure Grow_Obj (P : Lang.VM.Machine.Process_Access);
   procedure Grow_VT (P : Lang.VM.Machine.Process_Access);
   procedure Grow_Box (P : Lang.VM.Machine.Process_Access);
   function Alloc_Str (M : in out Lang.VM.Machine.Machine; P : Lang.VM.Machine.Process_Access) return Natural;
   function Alloc_Obj (M : in out Lang.VM.Machine.Machine; P : Lang.VM.Machine.Process_Access) return Natural;
   function Alloc_VT (M : in out Lang.VM.Machine.Machine; P : Lang.VM.Machine.Process_Access) return Natural;
   function Alloc_Box (M : in out Lang.VM.Machine.Machine; P : Lang.VM.Machine.Process_Access) return Natural;
   procedure Collect (M : in out Lang.VM.Machine.Machine);
   procedure Compact_Strings (M : in out Lang.VM.Machine.Machine; P : Lang.VM.Machine.Process_Access);
   procedure Maybe_GC_At_Safepoint (M : in out Lang.VM.Machine.Machine; P : Lang.VM.Machine.Process_Access);
   procedure Run_Process_Drops (M : in out Lang.VM.Machine.Machine; P : Lang.VM.Machine.Process_Access);
   function Alloc_Large_Buffer (P : Lang.VM.Machine.Process_Access) return Natural;
   procedure Retain_Large_Buffer (P : Lang.VM.Machine.Process_Access; Id : Natural);
   procedure Release_Large_Buffer (P : Lang.VM.Machine.Process_Access; Id : Natural);
   procedure Promote_To_Large (P : Lang.VM.Machine.Process_Access; Slot : Natural);
end Lang.VM.Allocator;
