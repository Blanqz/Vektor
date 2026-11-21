with Interfaces.C;
with System;
with Interfaces.C.Strings;

package Runtime is
   use Interfaces.C;
   use Interfaces.C.Strings;

   procedure Vect_Puts (S : in chars_ptr);
   pragma Export (C, Vect_Puts, "vect_puts");

   function Vect_Int_To_String (X : in long_long) return chars_ptr;
   pragma Export (C, Vect_Int_To_String, "vect_int_to_string");

   function Vect_Len (S : in chars_ptr) return long_long;
   pragma Export (C, Vect_Len, "vect_len");

   function Vect_Concat (A, B : in chars_ptr) return chars_ptr;
   pragma Export (C, Vect_Concat, "vect_concat");
   function Vect_Str_From_C (S : in chars_ptr) return chars_ptr;
   pragma Export (C, Vect_Str_From_C, "vect_str_from_c");

   function Vect_Obj_New (N : in long_long) return System.Address;
   pragma Export (C, Vect_Obj_New, "vect_obj_new");

   procedure Vect_Obj_Set (Obj : in System.Address; Index : in long_long; Val : in long_long);
   pragma Export (C, Vect_Obj_Set, "vect_obj_set");

   function Vect_Obj_Get (Obj : in System.Address; Index : in long_long) return long_long;
   pragma Export (C, Vect_Obj_Get, "vect_obj_get");

   procedure Vect_GC_Collect;
   pragma Export (C, Vect_GC_Collect, "vect_gc_collect");

   function Vect_Process_Spawn (Entry_Func : in System.Address) return long_long;
   pragma Import (C, Vect_Process_Spawn, "vect_process_spawn");

   function Vect_Ffi_Address (Name : in chars_ptr) return System.Address;
   pragma Export (C, Vect_Ffi_Address, "vect_ffi_address");
   procedure Vect_Trap;
   pragma Export (C, Vect_Trap, "vect_trap");
   procedure Vect_Send (Target : in long_long; Msg : in long_long);
   pragma Import (C, Vect_Send, "vect_send");

   function Vect_Receive return long_long;
   pragma Import (C, Vect_Receive, "vect_receive");

   function Vect_Call_Indirect (Closure : in System.Address) return System.Address;
   pragma Export (C, Vect_Call_Indirect, "vect_call_indirect");

   -- Process scheduling support
   procedure Vect_Yield;
   pragma Import (C, Vect_Yield, "vect_yield");

   procedure Vect_Scheduler_Run (Entry_Func : in System.Address);
   pragma Import (C, Vect_Scheduler_Run, "vect_scheduler_run");

   function Vect_Get_Reduction_Counter return long_long;
   pragma Import (C, Vect_Get_Reduction_Counter, "vect_get_reduction_counter");

   procedure Vect_Set_Reduction_Counter (Val : long_long);
   pragma Import (C, Vect_Set_Reduction_Counter, "vect_set_reduction_counter");

   procedure Vect_Decrement_Reduction;
   pragma Import (C, Vect_Decrement_Reduction, "vect_decrement_reduction");

end Runtime;
