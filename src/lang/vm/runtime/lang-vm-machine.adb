with Ada.Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Characters.Handling;
with Ada.Real_Time;
with Ada.Numerics.Long_Elementary_Functions;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;           use Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Ada.Unchecked_Conversion;
with Lang.VM.Allocator; use Lang.VM.Allocator;
with System.Storage_Elements;
with Interfaces;            use Interfaces;
with Lang.VM.IR;            use Lang.VM.IR;
with Lang.VM.Code;
with Lang.VM.Tagged_Word;
with Lang.VM.Box_Header; use Lang.VM.Box_Header;
with Lang.VM.Platform;
with System;
with Interfaces.C;
with Interfaces.C.Strings;

with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Directories;
with Ada.Environment_Variables;
with GNAT.Sockets;
with Ada.Long_Float_Text_IO;
with Ada.Text_IO;

package body Lang.VM.Machine is

   function Format_Decimal (V : Long_Float) return String is separate;

   use Lang.VM.Tagged_Word;

   --  Reference point for Clock.monotonic_ms, taken when the VM is elaborated.
   Mono_Epoch : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;

   function Index_Text (I : Integer_64) return String is
     (Ada.Strings.Fixed.Trim (Integer_64'Image (I), Ada.Strings.Left));

   --  Ends the whole program the way the language's process throw does: exit status 1.
   procedure C_Exit (Code : Interfaces.C.int);
   pragma Import (C, C_Exit, "exit");

   --  UTF-8 bytes of one Unicode code point; empty when the value is not a code point.
   function Utf8_Of (CP : Integer_64) return String is separate;

   use type VC.Builtin_Id;
   use VC;
   use System;
   use Interfaces.C;
   use Interfaces.C.Strings;

   Zero : constant TW := Make_Small_Int (0);


   function Str_Ptr (Slot : Natural) return TW is
     (Make_Heap_Ptr (Unsigned_64 (Slot) * 16));

   function Obj_Ptr (Slot : Natural) return TW is
     (Make_Heap_Ptr (Unsigned_64 (Slot) * 16 + 8));

   function Box_Ptr (Slot : Natural) return TW is
     (Make_Box_Ptr (Unsigned_64 (Slot) * 8));

   function Obj_At (P : Process_Access; I : Natural) return access Obj_Entry is separate;

   function VT_At (P : Process_Access; I : Natural) return access VTable_Entry is separate;

   function Box_At (P : Process_Access; I : Natural) return access Box_Entry is separate;

   function Str_At (P : Process_Access; I : Natural) return access Str_Entry is separate;

   function Str_Slot (P : Process_Access; W : TW) return Natural is separate;

   function Obj_Slot (P : Process_Access; W : TW) return Natural is separate;

   function Box_Slot (P : Process_Access; W : TW) return Natural is separate;

   function Chars_Of (P : Process_Access; W : TW) return Unbounded_String is separate;

   procedure Verify_Roots (M : in out Machine) is separate;


   function Make_Float (M : in out Machine; P : Process_Access; Value : Long_Float) return TW is separate;

   function Unbox_Float (P : Process_Access; W : TW) return Long_Float is separate;



   function Make_Int (M : in out Machine; P : Process_Access; Value : Interfaces.Integer_64) return TW is separate;

   function Unbox_Int (P : Process_Access; W : TW) return Interfaces.Integer_64 is separate;

   function Is_Int_Box (P : Process_Access; W : TW) return Boolean is separate;

   function Is_Float_Box (P : Process_Access; W : TW) return Boolean is separate;

   function Is_Int_Like (P : Process_Access; W : TW) return Boolean is separate;

   function To_U64 is new Ada.Unchecked_Conversion (Interfaces.Integer_64, Interfaces.Unsigned_64);
   function To_I64 is new Ada.Unchecked_Conversion (Interfaces.Unsigned_64, Interfaces.Integer_64);

   -- wrapping is done on the modular rype, so nothing depends on runtime overflow checks
   function Checked_Add (A, B : Interfaces.Integer_64) return Interfaces.Integer_64 is separate;

   function Checked_Sub (A, B : Interfaces.Integer_64) return Interfaces.Integer_64 is separate;

   function Checked_Mul (A, B : Interfaces.Integer_64) return Interfaces.Integer_64 is separate;

   function Checked_Div (A, B : Interfaces.Integer_64) return Interfaces.Integer_64 is separate;

   function Checked_Rem (A, B : Interfaces.Integer_64) return Interfaces.Integer_64 is separate;

   function Deep_Copy (M : in out Machine; SrcP, DstP : Process_Access; W : TW) return TW is separate;

   procedure Mail_Push (P : Process_Access; W : TW) is separate;

   function Mail_Pop (P : Process_Access) return TW is separate;

   procedure Push_Frame (M       : in out Machine;
                         P        : Process_Access;
                         Fn_Index : Natural;
                         Extent   : Natural;
                         Has_Ret  : Boolean;
                         Ret_Dest : Natural;
                         Base     : out Natural) is separate;
   function Func_Index (M : Machine; Name : String) return Natural is separate;

   function Find_Process (M : Machine; Pid : Natural) return Process_Access is separate;

   procedure Ensure_Compiled (M : in out Machine) is separate;

   procedure Create_Process (M : in out Machine; CI : Natural; New_Pid : out Natural) is separate;

   procedure Spawn_Process (M : in out Machine; Func_Name : String; New_Pid : out Natural) is separate;

   function Last_Result (M : Machine) return TW is separate;
   function Ffi_Address (Name : String) return System.Address is separate;

   procedure Run_Builtin_Text (M    : in out Machine;
                          P    : Process_Access;
                          Base : Natural;
                          Ins  : VC.Code_Instr) is separate;
   procedure Run_Builtin_Lists (M    : in out Machine;
                          P    : Process_Access;
                          Base : Natural;
                          Ins  : VC.Code_Instr) is separate;
   procedure Run_Builtin_Math (M    : in out Machine;
                          P    : Process_Access;
                          Base : Natural;
                          Ins  : VC.Code_Instr) is separate;
   procedure Run_Builtin_Console (M    : in out Machine;
                          P    : Process_Access;
                          Base : Natural;
                          Ins  : VC.Code_Instr) is separate;
   procedure Run_Builtin_Files (M    : in out Machine;
                          P    : Process_Access;
                          Base : Natural;
                          Ins  : VC.Code_Instr) is separate;
   procedure Run_Builtin_Processes (M    : in out Machine;
                          P    : Process_Access;
                          Base : Natural;
                          Ins  : VC.Code_Instr) is separate;
   procedure Run_Builtin_Net (M    : in out Machine;
                          P    : Process_Access;
                          Base : Natural;
                          Ins  : VC.Code_Instr) is separate;
   procedure Run_Builtin (M    : in out Machine;
                          P    : Process_Access;
                          Base : Natural;
                          Ins  : VC.Code_Instr) is separate;
   procedure Run_Slice (M : in out Machine; P : Process_Access);

   procedure Run_Slice (M : in out Machine; P : Process_Access) is
      D    : Natural;
      Fr   : Frame;
      Fn   : VC.Func_Code;
      Base : Natural;
      S    : Value_Array_Access;
      Pc   : Natural;
   begin
      begin
         if P.Depth = 0 then
            P.Status := Proc_Dead;
            return;
         end if;
         D    := P.Depth;
         Fr   := P.Frames (D);
         Fn   := M.Prog.Funcs (Fr.Func);
         Base := Fr.Base;
         S    := P.Stack;
         Pc   := Fr.Pc;

         while P.Status = Proc_Runnable and then P.Reductions > 0 and then P.Depth > 0 loop
            P.Reductions := P.Reductions - 1;

            if Pc > Fn.Code.all'Length then
               P.Sp := Base;
               P.Depth := D - 1;
               if P.Depth = 0 then
                  P.Status := Proc_Dead;
               else
                  D := P.Depth;
                  Fr := P.Frames (D);
                  Fn := M.Prog.Funcs (Fr.Func);
                  Base := Fr.Base;
                  S := P.Stack;
                  Pc := Fr.Pc;
               end if;
            else
               declare
                  Ins : VC.Code_Instr renames Fn.Code.all (Pc);
               begin
                  Pc := Pc + 1;

                  case Ins.Op is
                     when Op_Const_Int =>
                        S (Base + Ins.Dest) := Make_Int (M, P, Ins.Imm_Int);

                     when Op_Const_None =>
                        S (Base + Ins.Dest) := Make_None;

                     when Op_Const_Bool =>
                        S (Base + Ins.Dest) := Make_Bool (Ins.Imm_Bool);

                     when Op_Const_Float =>
                        S (Base + Ins.Dest) := Make_Float (M, P, Ins.Imm_Float);

                     when Op_Const_Str =>
                        declare
                           Slot : constant Natural := Alloc_Str (M, P);
                        begin
                           Str_At (P, Slot).Chars := M.Prog.Strings (Ins.Str);
                           Str_At (P, Slot).Pinned := True;
                           Promote_To_Large (P, Slot);
                           S (Base + Ins.Dest) := Str_Ptr (Slot);
                        end;

                     when Op_Move =>
                        S (Base + Ins.Dest) := S (Base + Ins.Src1);

                     when Op_FuncRef =>
                        declare
                           Slot   : constant Natural := Alloc_Obj (M, P);
                           Count  : constant Natural := 1 + Ins.Args_Count;
                           F      : Value_Array_Access := new Value_Array (1 .. Count);
                        begin
                           Obj_At (P, Slot).Type_Name := To_Unbounded_String ("Closure");
                           Obj_At (P, Slot).Count := Count;
                           F (1) := Make_Small_Int (Integer_64 (Ins.Callee));
                           for A in 1 .. Ins.Args_Count loop
                              F (A + 1) := P.Stack (Base + M.Prog.Args (Ins.Args_First + A - 1));
                           end loop;
                           Obj_At (P, Slot).Fields := F;
                           S (Base + Ins.Dest) := Obj_Ptr (Slot);
                        end;

                     when Op_Add_Int =>
                        S (Base + Ins.Dest) := Make_Int (M, P,
                          Checked_Add (Unbox_Int (P, S (Base + Ins.Src1)),
                                       Unbox_Int (P, S (Base + Ins.Src2))));

                     when Op_Sub_Int =>
                        S (Base + Ins.Dest) := Make_Int (M, P,
                          Checked_Sub (Unbox_Int (P, S (Base + Ins.Src1)),
                                       Unbox_Int (P, S (Base + Ins.Src2))));

                     when Op_Mul_Int =>
                        S (Base + Ins.Dest) := Make_Int (M, P,
                          Checked_Mul (Unbox_Int (P, S (Base + Ins.Src1)),
                                       Unbox_Int (P, S (Base + Ins.Src2))));

                     when Op_Add_Float =>
                        S (Base + Ins.Dest) := Make_Float (M, P,
                          Unbox_Float (P, S (Base + Ins.Src1)) +
                          Unbox_Float (P, S (Base + Ins.Src2)));

                     when Op_Sub_Float =>
                        S (Base + Ins.Dest) := Make_Float (M, P,
                          Unbox_Float (P, S (Base + Ins.Src1)) -
                          Unbox_Float (P, S (Base + Ins.Src2)));

                     when Op_Mul_Float =>
                        S (Base + Ins.Dest) := Make_Float (M, P,
                          Unbox_Float (P, S (Base + Ins.Src1)) *
                          Unbox_Float (P, S (Base + Ins.Src2)));

                     when Op_Div_Float =>
                        declare
                           Dv : constant Long_Float := Unbox_Float (P, S (Base + Ins.Src2));
                        begin
                           if Dv = 0.0 then
                              raise Constraint_Error with "division by zero";
                           end if;
                           S (Base + Ins.Dest) := Make_Float (M, P,
                             Unbox_Float (P, S (Base + Ins.Src1)) / Dv);
                        end;

                     when Op_Div_Int =>
                        S (Base + Ins.Dest) := Make_Int (M, P,
                          Checked_Div (Unbox_Int (P, S (Base + Ins.Src1)),
                                       Unbox_Int (P, S (Base + Ins.Src2))));

                     when Op_Mod_Int =>
                        S (Base + Ins.Dest) := Make_Int (M, P,
                          Checked_Rem (Unbox_Int (P, S (Base + Ins.Src1)),
                                       Unbox_Int (P, S (Base + Ins.Src2))));

                     when Op_Icmp =>
                        --  Integers (small or boxed) compare by value. Anything
                        --  else (none, bool, pointers) compares by raw word, so
                        --  none == none holds and none never equals an integer.
                        declare
                           WA : constant TW := S (Base + Ins.Src1);
                           WB : constant TW := S (Base + Ins.Src2);
                           R  : Boolean := False;
                        begin
                           if Is_Int_Like (P, WA) and then Is_Int_Like (P, WB) then
                              declare
                                 A : constant Integer_64 := Unbox_Int (P, WA);
                                 B : constant Integer_64 := Unbox_Int (P, WB);
                              begin
                                 case Ins.Cmp is
                                    when Cmp_Eq => R := A = B;
                                    when Cmp_Ne => R := A /= B;
                                    when Cmp_Lt => R := A < B;
                                    when Cmp_Le => R := A <= B;
                                    when Cmp_Gt => R := A > B;
                                    when Cmp_Ge => R := A >= B;
                                 end case;
                              end;
                           elsif Is_Float_Box (P, WA) and then Is_Float_Box (P, WB) then
                              declare
                                 A : constant Long_Float := Unbox_Float (P, WA);
                                 B : constant Long_Float := Unbox_Float (P, WB);
                              begin
                                 case Ins.Cmp is
                                    when Cmp_Eq => R := A = B;
                                    when Cmp_Ne => R := A /= B;
                                    when Cmp_Lt => R := A < B;
                                    when Cmp_Le => R := A <= B;
                                    when Cmp_Gt => R := A > B;
                                    when Cmp_Ge => R := A >= B;
                                 end case;
                              end;
                           elsif Str_Slot (P, WA) > 0 and then Str_Slot (P, WB) > 0
                             and then (Ins.Cmp = Cmp_Eq or else Ins.Cmp = Cmp_Ne)
                           then
                              declare
                                 Same : constant Boolean :=
                                   To_String (Str_At (P, Str_Slot (P, WA)).Chars)
                                   = To_String (Str_At (P, Str_Slot (P, WB)).Chars);
                              begin
                                 R := (Same and then Ins.Cmp = Cmp_Eq)
                                   or else (not Same and then Ins.Cmp = Cmp_Ne);
                              end;
                           else
                              case Ins.Cmp is
                                 when Cmp_Eq => R := To_Raw (WA) = To_Raw (WB);
                                 when Cmp_Ne => R := To_Raw (WA) /= To_Raw (WB);
                                 when others => R := False;
                              end case;
                           end if;
                           S (Base + Ins.Dest) := Make_Bool (R);
                        end;

                     when Op_Br =>
                        if Unbox_Bool (S (Base + Ins.Src1)) then
                           Pc := Ins.Target;
                        else
                           Pc := Ins.Target_F;
                        end if;

                     when Op_Jmp =>
                        Pc := Ins.Target;

                     when Op_Call =>
                        P.Frames (D).Pc := Pc;
                        if Ins.Builtin /= VC.Bi_None then
                           Run_Builtin (M, P, Base, Ins);
                        else
                           declare
                              Callee   : constant Natural := Ins.Callee;
                              Extent   : constant Natural :=
                                Natural'Max (M.Prog.Funcs (Callee).Frame_Size, Ins.Args_Count);
                              New_Base : Natural;
                           begin
                              P.Frames (D).Pc := Pc;
                              Push_Frame (M, P, Callee, Extent, Ins.Has_Dest, Ins.Dest, New_Base);
                              for A in 1 .. Ins.Args_Count loop
                                 P.Stack (New_Base + A - 1) :=
                                   P.Stack (Base + M.Prog.Args (Ins.Args_First + A - 1));
                              end loop;
                           end;
                        end if;
                        D := P.Depth;
                        if D > 0 then
                           Fr := P.Frames (D);
                           Fn := M.Prog.Funcs (Fr.Func);
                           Base := Fr.Base;
                           S := P.Stack;
                           Pc := Fr.Pc;
                        end if;

                     when Op_Ret =>
                        declare
                           RetVal : constant TW :=
                             (if Ins.Has_Src1 then S (Base + Ins.Src1) else Zero);
                        begin
                           P.Sp := Base;
                           P.Depth := D - 1;
                           if P.Depth = 0 then
                              Run_Process_Drops (M, P);
                              P.Result := RetVal;
                              P.Status := Proc_Dead;
                           elsif Fr.Has_Ret then
                              P.Stack (P.Frames (P.Depth).Base + Fr.Ret_Dest) := RetVal;
                           end if;
                        end;
                        if P.Depth > 0 then
                           D := P.Depth;
                           Fr := P.Frames (D);
                           Fn := M.Prog.Funcs (Fr.Func);
                           Base := Fr.Base;
                           S := P.Stack;
                           Pc := Fr.Pc;
                        end if;
                     when Op_Call_Indirect =>
                        P.Frames (D).Pc := Pc;
                        declare
                           W        : constant TW := S (Base + Ins.Src1);
                           O        : constant Natural := Obj_Slot (P, W);
                           Callee   : Natural := 0;
                           Captures : Natural := 0;
                           Extent   : Natural;
                           New_Base : Natural;
                        begin
                           if O > 0 and then Obj_At (P, O).Count >= 1
                             and then Is_Small_Int (Obj_At (P, O).Fields (1))
                           then
                              Callee := Natural (Unbox_Small_Int (Obj_At (P, O).Fields (1)));
                              Captures := Obj_At (P, O).Count - 1;
                           end if;
                           if Callee = 0 then
                              Put_Line ("invalid closure O=" & Natural'Image (O) & " count=" & Natural'Image ((if O>0 then Obj_At (P, O).Count else 0)));
                              raise Constraint_Error with "invalid closure";
                           end if;
                           Extent := Natural'Max (M.Prog.Funcs (Callee).Frame_Size, Captures + Ins.Args_Count);
                           Push_Frame (M, P, Callee, Extent, Ins.Has_Dest, Ins.Dest, New_Base);
                           for C in 1 .. Captures loop
                              P.Stack (New_Base + C - 1) := Obj_At (P, O).Fields (C + 1);
                           end loop;
                           for A in 1 .. Ins.Args_Count loop
                              P.Stack (New_Base + Captures + A - 1) :=
                                P.Stack (Base + M.Prog.Args (Ins.Args_First + A - 1));
                           end loop;
                        end;
                        D := P.Depth;
                        if D > 0 then
                           Fr := P.Frames (D);
                           Fn := M.Prog.Funcs (Fr.Func);
                           Base := Fr.Base;
                           S := P.Stack;
                           Pc := Fr.Pc;
                        end if;

                     when Op_Spawn =>
                        declare
                           NewPid : Natural;
                           T      : Natural := 1;
                        begin
                           Create_Process (M, Ins.Callee, NewPid);
                           for I in 2 .. M.Thread_Count loop
                              if Natural (M.Threads (I).Run_Queue.Length) < Natural (M.Threads (T).Run_Queue.Length) then
                                 T := I;
                              end if;
                           end loop;
                           M.Processes (NewPid).Assigned_Thread := T;
                           M.Threads (T).Run_Queue.Append (NewPid);
                           S (Base + Ins.Dest) := Make_Pid (Unsigned_64 (NewPid));
                        end;

                     when Op_Send =>
                        declare
                           Target : constant Process_Access :=
                             Find_Process (M, Natural (Unbox_Pid (S (Base + Ins.Src1))));
                        begin
                           if Target /= null then
                              Mail_Push (Target, Deep_Copy (M, P, Target, S (Base + Ins.Src2)));
                              if Target.Status = Proc_Blocked then
                                 Target.Status := Proc_Runnable;
                              end if;
                           end if;
                        end;

                     when Op_Receive =>
                        declare
                           Found_Match : Boolean := False;
                        begin
                           if P.Mail_Count > 0 and then (Ins.Recv_Pattern > 0 or Ins.Recv_Guard > 0) then
                              for I in 0 .. P.Mail_Count - 1 loop
                                 declare
                                    Msg : constant TW := P.Mail (((P.Mail_Head + I) mod P.Mail.all'Length) + 1);
                                    Pattern_Match : Boolean := True;
                                    Guard_Match : Boolean := True;
                                 begin
                                    if Ins.Recv_Pattern > 0 then
                                       Pattern_Match := (Msg = P.Stack (Base + Ins.Recv_Pattern));
                                    end if;
                                    if Ins.Recv_Guard > 0 then
                                       Guard_Match := Unbox_Bool (P.Stack (Base + Ins.Recv_Guard));
                                    end if;
                                    if Pattern_Match and then Guard_Match then
                                       Found_Match := True;
                                       exit;
                                    end if;
                                 end;
                              end loop;
                           elsif P.Mail_Count > 0 then
                              Found_Match := True;
                           end if;
                           if Found_Match then
                              S (Base + Ins.Dest) := Mail_Pop (P);
                              P.Blocked_Until := 0;
                              P.Recv_Timed_Out := False;
                           elsif Ins.Recv_Timeout = 0 then
                              if P.Blocked_Until = 0 then
                                 P.Blocked_Until := Natural'Last;
                              end if;
                              Pc := Pc - 1;
                              P.Status := Proc_Blocked;
                           elsif P.Recv_Timed_Out then
                              S (Base + Ins.Dest) := Make_None;
                              P.Blocked_Until := 0;
                              P.Recv_Timed_Out := False;
                           elsif P.Blocked_Until = 0 then
                              P.Blocked_Until := M.Clock + Ins.Recv_Timeout;
                              Pc := Pc - 1;
                              P.Status := Proc_Blocked;
                           elsif M.Clock >= P.Blocked_Until then
                              S (Base + Ins.Dest) := Make_None;
                              P.Blocked_Until := 0;
                              P.Recv_Timed_Out := False;
                           else
                              Pc := Pc - 1;
                              P.Status := Proc_Blocked;
                           end if;
                        end;

                     when Op_Self =>
                        S (Base + Ins.Dest) := Make_Pid (Unsigned_64 (P.Id));

                     when Op_New =>
                        declare
                           Slot : constant Natural := Alloc_Obj (M, P);
                           N    : constant Natural := Ins.Args_Count;
                           F    : constant Value_Array_Access := new Value_Array (1 .. N);
                        begin
                           for I in 1 .. N loop
                              F (I) := S (Base + M.Prog.Args (Ins.Args_First + I - 1));
                           end loop;
                           Obj_At (P, Slot).Fields := F;
                           Obj_At (P, Slot).Count := N;
                           Obj_At (P, Slot).Drop := M.Prog.Drops (Ins.Str);
                           Obj_At (P, Slot).Type_Name := M.Prog.Strings (Ins.Str);
                           S (Base + Ins.Dest) := Obj_Ptr (Slot);
                        end;

                     when Op_FieldGet =>
                        declare
                           O : constant Natural := Obj_Slot (P, S (Base + Ins.Src1));
                        begin
                           if O > 0 and then Ins.Field_Index < Obj_At (P, O).Count then
                              S (Base + Ins.Dest) := Obj_At (P, O).Fields (Ins.Field_Index + 1);
                           end if;
                        end;

                     when Op_FieldSet =>
                        declare
                           O : constant Natural := Obj_Slot (P, S (Base + Ins.Src1));
                        begin
                           if O > 0 and then Ins.Field_Index < Obj_At (P, O).Count then
                              Obj_At (P, O).Fields (Ins.Field_Index + 1) := S (Base + Ins.Src2);
                           end if;
                        end;

                     when Op_RefNew =>
                        declare
                           Slot : constant Natural := Alloc_Obj (M, P);
                           F    : constant Value_Array_Access := new Value_Array (1 .. 1);
                        begin
                           if Ins.Has_Src1 then
                              F (1) := S (Base + Ins.Src1);
                           else
                              F (1) := Zero;
                           end if;
                           Obj_At (P, Slot).Fields := F;
                           Obj_At (P, Slot).Count := 1;
                           S (Base + Ins.Dest) := Obj_Ptr (Slot);
                        end;

                     when Op_RefGet =>
                        declare
                           O : constant Natural := Obj_Slot (P, S (Base + Ins.Src1));
                        begin
                           if O > 0 and then Obj_At (P, O).Count >= 1 then
                              S (Base + Ins.Dest) := Obj_At (P, O).Fields (1);
                           end if;
                        end;

                     when Op_RefSet =>
                        declare
                           O : constant Natural := Obj_Slot (P, S (Base + Ins.Src1));
                        begin
                           if O > 0 and then Obj_At (P, O).Count >= 1 then
                              Obj_At (P, O).Fields (1) := S (Base + Ins.Src2);
                           end if;
                        end;

                     when Op_DynNew =>
                        declare
                           Slot : constant Natural := Alloc_Obj (M, P);
                           F    : constant Value_Array_Access := new Value_Array (1 .. 2);
                        begin
                           F (1) := S (Base + Ins.Src1);
                           F (2) := S (Base + Ins.Src2);
                           Obj_At (P, Slot).Fields := F;
                           Obj_At (P, Slot).Count := 2;
                           S (Base + Ins.Dest) := Obj_Ptr (Slot);
                        end;

                     when Op_DynCall =>
                        declare
                           O     : constant Natural := Obj_Slot (P, S (Base + Ins.Src1));
                           Self  : TW := Zero;
                           VIdx  : Natural := 0;
                           Func  : Natural := 0;
                        begin
                           if O > 0 then
                              if Obj_At (P, O).Count >= 1 then
                                 Self := Obj_At (P, O).Fields (1);
                              end if;
                              if Obj_At (P, O).Count >= 2 then
                                 VIdx := Natural (Unbox_Small_Int (Obj_At (P, O).Fields (2)));
                              end if;
                           end if;

                           if VIdx in 1 .. P.VT_Cap and then VT_At (P, VIdx).In_Use
                             and then Ins.Method_Index < VT_At (P, VIdx).Methods.all'Length
                           then
                              Func := VT_At (P, VIdx).Methods (Ins.Method_Index + 1);
                           end if;

                           if Func in 1 .. M.Prog.Funcs.all'Length then
                              P.Frames (D).Pc := Pc;
                              declare
                                 Extent   : constant Natural :=
                                   Natural'Max (M.Prog.Funcs (Func).Frame_Size, Ins.Args_Count + 1);
                                 New_Base : Natural;
                              begin
                                 Push_Frame (M, P, Func, Extent, Ins.Has_Dest, Ins.Dest, New_Base);
                                 P.Stack (New_Base) := Self;
                                 for A in 1 .. Ins.Args_Count loop
                                    P.Stack (New_Base + A) :=
                                      P.Stack (Base + M.Prog.Args (Ins.Args_First + A - 1));
                                 end loop;
                              end;
                           end if;
                        end;
                        if P.Depth > D then
                           D := P.Depth;
                           Fr := P.Frames (D);
                           Fn := M.Prog.Funcs (Fr.Func);
                           Base := Fr.Base;
                           S := P.Stack;
                           Pc := Fr.Pc;
                        end if;

                     when Op_Drop =>
                        declare
                           V  : TW := S (Base + Ins.Src1);
                           O0 : constant Natural := Obj_Slot (P, V);
                           O  : Natural := O0;
                           DropFn : Natural := 0;
                        begin
                           if O0 > 0 and then Obj_At (P, O0).Count = 2
                             and then Is_Small_Int (Obj_At (P, O0).Fields (2))
                           then
                              declare
                                 VIdx : constant Natural := Natural (Unbox_Small_Int (Obj_At (P, O0).Fields (2)));
                                 Data : constant TW := Obj_At (P, O0).Fields (1);
                              begin
                                 if VIdx >= 1 and then VIdx <= P.VT_Cap
                                   and then VT_At (P, VIdx).In_Use
                                 then
                                    O := Obj_Slot (P, Data);
                                    if O > 0 then
                                       V := Data;
                                    end if;
                                 end if;
                              end;
                           end if;
                           if O > 0 then
                              DropFn := Obj_At (P, O).Drop;
                              if DropFn = 0 then
                                 declare
                                    TypeName : constant String := To_String (Obj_At (P, O).Type_Name);
                                    Cand1    : constant String := TypeName & ".drop";
                                 begin
                                    if M.Func_Names.Contains (Cand1) then
                                       DropFn := M.Func_Names.Element (Cand1);
                                    elsif M.Func_Names.Contains ("drop") then
                                       DropFn := M.Func_Names.Element ("drop");
                                    end if;
                                 end;
                              end if;
                           end if;
                           if DropFn in 1 .. M.Prog.Funcs.all'Length then
                              P.Frames (D).Pc := Pc;
                              declare
                                 Extent   : constant Natural :=
                                   Natural'Max (M.Prog.Funcs (DropFn).Frame_Size, 1);
                                 New_Base : Natural;
                              begin
                                 Push_Frame (M, P, DropFn, Extent, False, 0, New_Base);
                                 P.Stack (New_Base) := V;
                              end;
                              D := P.Depth;
                              if D > 0 then
                                 Fr := P.Frames (D);
                                 Fn := M.Prog.Funcs (Fr.Func);
                                 Base := Fr.Base;
                                 S := P.Stack;
                                 Pc := Fr.Pc;
                              end if;
                           end if;
                        end;

                     when Op_FfiCall =>
                        declare
                           type A0 is access function return Integer_64;
                           pragma Convention (C, A0);
                           type A1 is access function (A : Integer_64) return Integer_64;
                           pragma Convention (C, A1);
                           type A2 is access function (A, B : Integer_64) return Integer_64;
                           pragma Convention (C, A2);
                           FuncName : constant String := To_String (M.Prog.Strings (Ins.Str));
                           Addr     : constant System.Address := Ffi_Address (FuncName);
                           NArgs    : constant Natural := Natural (Ins.Args_Count);
                           R        : Integer_64 := 0;

                           function Cvt0 is new Ada.Unchecked_Conversion (System.Address, A0);
                           function Cvt1 is new Ada.Unchecked_Conversion (System.Address, A1);
                           function Cvt2 is new Ada.Unchecked_Conversion (System.Address, A2);

                           function To_Int (W : TW) return Integer_64 is
                           begin
                              if Is_Small_Int (W) then
                                 return Unbox_Small_Int (W);
                              end if;
                              return 0;
                           end To_Int;
                        begin
                           if FuncName = "puts" or FuncName = "IO.puts" then
                              if Ins.Args_Count >= 1 then
                                 declare
                                    V : constant TW := P.Stack (Base + M.Prog.Args (Ins.Args_First));
                                 begin
                                    if Is_Heap_Pointer (V) then
                                       Put_Line (To_String (Chars_Of (P, V)));
                                    else
                                       Put_Line (Integer'Image (Integer (Unbox_Small_Int (V))));
                                    end if;
                                 end;
                              end if;
                              R := 0;
                           elsif FuncName = "strlen" or FuncName = "String.len" or FuncName = "len" then
                              if Ins.Args_Count >= 1 then
                                 declare
                                    Sl : constant Natural := Str_Slot (P, P.Stack (Base + M.Prog.Args (Ins.Args_First)));
                                 begin
                                    if Sl > 0 then
                                       R := Integer_64 (Length (Str_At (P, Sl).Chars));
                                    else
                                       R := 0;
                                    end if;
                                 end;
                              end if;
                           elsif FuncName = "sqrt" then
                              if Ins.Args_Count >= 1 then
                                 declare
                                    X : Integer_64 := Unbox_Small_Int (P.Stack (Base + M.Prog.Args (Ins.Args_First)));
                                    Rr : Integer_64 := X;
                                    Nr : Integer_64;
                                 begin
                                    if X <= 0 then
                                       R := 0;
                                    else
                                       loop
                                          Nr := (Rr + X / Rr) / 2;
                                          exit when Nr >= Rr;
                                          Rr := Nr;
                                       end loop;
                                       R := Rr;
                                    end if;
                                 end;
                              end if;
                           elsif FuncName = "getpid" then
                              R := Lang.VM.Platform.Current_Process_Id;
                           else
                              if Addr = System.Null_Address then
                                 Put_Line ("ffi: symbol not found " & FuncName);
                              else
                                 case NArgs is
                                    when 0 =>
                                       R := Cvt0 (Addr).all;
                                    when 1 =>
                                       R := Cvt1 (Addr).all (To_Int (P.Stack (Base + M.Prog.Args (Ins.Args_First))));
                                    when 2 =>
                                       R := Cvt2 (Addr).all
                                         (To_Int (P.Stack (Base + M.Prog.Args (Ins.Args_First))),
                                          To_Int (P.Stack (Base + M.Prog.Args (Ins.Args_First + 1))));
                                    when others =>
                                       Put_Line ("ffi: too many args");
                                 end case;
                              end if;
                           end if;
                           if Ins.Has_Dest then
                              S (Base + Ins.Dest) := Make_Int (M, P, R);
                           end if;
                        end;

                     when Op_VTableNew =>
                        declare
                           Slot    : Natural := Alloc_VT (M, P);
                           Methods : constant VC.Natural_Array_Access :=
                             new VC.Natural_Array (1 .. Ins.Args_Count);
                        begin
                           for I in 1 .. Ins.Args_Count loop
                              Methods (I) := M.Prog.Args (Ins.Args_First + I - 1);
                           end loop;
                           VT_At (P, Slot).Methods := Methods;
                           S (Base + Ins.Dest) := Make_Small_Int (Integer_64 (Slot));
                        end;

                     when others =>
                        null;
                  end case;
                  if P.Depth > 0 then
                     P.Frames (P.Depth).Pc := Pc;
                  end if;
               end;
            end if;
         end loop;
      exception
         when E : others =>
            Put_Line ("panic: " & Ada.Exceptions.Exception_Message (E));
            Flush (Standard_Output);
            C_Exit (1);
      end;

      if P.Reductions = 0 then
         if M.Verify_Roots then
            Verify_Roots (M);
         end if;
         M.Clock := M.Clock + (2000 - P.Reductions);
         P.Reductions := 2000;
      else
         M.Clock := M.Clock + (2000 - P.Reductions);
      end if;
   end Run_Slice;

   procedure Run (M : in out Machine; Entry_Name : String; Thread_Count : Natural := 1) is separate;


end Lang.VM.Machine;
