with Ada.Text_IO; use Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Interfaces; use Interfaces;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Lang.VM.IR; use Lang.VM.IR;
with Lang.VM.Machine; use Lang.VM.Machine;
with Lang.VM.Tagged_Word; use Lang.VM.Tagged_Word;

procedure VM_Main is
   F : File_Type;
   Text : Unbounded_String := To_Unbounded_String ("");
   Line : String (1 .. 4096);
   Last : Natural;
   Project_Path : Unbounded_String := To_Unbounded_String ("");
   Input_Path : Unbounded_String := To_Unbounded_String ("");
   Gc_Stress : Natural := 0;
   Verify : Boolean := False;
   Thread_Count : Natural := 1;
   Initial_Memory : Natural := 1024;
   Max_Memory : Natural := 0;
   Profile : Unbounded_String := To_Unbounded_String ("");
   Source_Roots : Unbounded_String := To_Unbounded_String ("");

   procedure Read_Project (Path : String) is
      PF : File_Type;
      PLine : String (1 .. 4096);
      PLast : Natural;
   begin
      Open (PF, In_File, Path);
      while not End_Of_File (PF) loop
         Get_Line (PF, PLine, PLast);
         declare
            L : constant String := Ada.Strings.Fixed.Trim (PLine (1 .. PLast), Ada.Strings.Both);
            Eq : Natural := 0;
         begin
            if L'Length > 0 and then L (L'First) /= '#' then
               for K in L'Range loop
                  if L (K) = '=' or else L (K) = ':' then
                     Eq := K; exit;
                  end if;
               end loop;
               if Eq > 0 then
                  declare
                     Key : constant String := Ada.Strings.Fixed.Trim (L (L'First .. Eq - 1), Ada.Strings.Both);
                     Val : constant String := Ada.Strings.Fixed.Trim (L (Eq + 1 .. L'Last), Ada.Strings.Both);
                  begin
                     if Key = "profile" then
                        Profile := To_Unbounded_String (Val);
                     elsif Key = "source_root" or Key = "source_roots" or Key = "source" then
                        if Length (Source_Roots) > 0 then
                           Source_Roots := Source_Roots & To_Unbounded_String (",");
                        end if;
                        Source_Roots := Source_Roots & To_Unbounded_String (Val);
                     end if;
                  end;
               end if;
            end if;
         end;
      end loop;
      Close (PF);
   end Read_Project;

   I : Integer := 1;
begin
   while I <= Ada.Command_Line.Argument_Count loop
      declare
         Arg : constant String := Ada.Command_Line.Argument (I);
      begin
         if Arg = "--gc-stress" then
            if I = Ada.Command_Line.Argument_Count then
               Put_Line ("usage: vm [--project <file.vktproj>] [--gc-stress N] [--verify] <file.ir>");
               return;
            end if;
            Gc_Stress := Natural'Value (Ada.Command_Line.Argument (I + 1));
            I := I + 2;
         elsif Arg = "--verify" then
            Verify := True;
            I := I + 1;
         elsif Arg = "--threads" then
            if I = Ada.Command_Line.Argument_Count then
               Put_Line ("usage: vm [--project <file.vktproj>] [--gc-stress N] [--verify] [--threads N] <file.ir>");
               return;
            end if;
            Thread_Count := Natural'Value (Ada.Command_Line.Argument (I + 1));
            I := I + 2;
         elsif Arg = "--initial-memory" then
            if I = Ada.Command_Line.Argument_Count then
               Put_Line ("usage: vm [--initial-memory N] <file.ir>");
               return;
            end if;
            Initial_Memory := Natural'Value (Ada.Command_Line.Argument (I + 1));
            I := I + 2;
         elsif Arg = "--max-memory" then
            if I = Ada.Command_Line.Argument_Count then
               Put_Line ("usage: vm [--max-memory N] <file.ir>");
               return;
            end if;
            Max_Memory := Natural'Value (Ada.Command_Line.Argument (I + 1));
            I := I + 2;
         elsif Arg = "--project" then
            if I = Ada.Command_Line.Argument_Count then
               Put_Line ("usage: vm [--project <file.vktproj>] <file.ir>");
               return;
            end if;
            Project_Path := To_Unbounded_String (Ada.Command_Line.Argument (I + 1));
            I := I + 2;
         else
            if Length (Input_Path) > 0 then
               Put_Line ("usage: vm [--project <file.vktproj>] <file.ir>");
               return;
            end if;
            Input_Path := To_Unbounded_String (Arg);
            I := I + 1;
         end if;
      end;
   end loop;

   if Length (Input_Path) = 0 then
      Put_Line ("usage: vm [--project <file.vktproj>] <file.ir>");
      return;
   end if;

   if Length (Project_Path) > 0 then
      Read_Project (To_String (Project_Path));
   end if;

   Open (F, In_File, To_String (Input_Path));
   while not End_Of_File (F) loop
      Get_Line (F, Line, Last);
      Text := Text & To_Unbounded_String (Line (1 .. Last)) & To_Unbounded_String ((1 => ASCII.LF));
   end loop;
   Close (F);
   declare
      M : Ir_Module := Parse (To_String (Text));
      Mach : Machine;
      R : TW;
      P : Process_Access;
   begin
      Mach.GC_Stress_Interval := Gc_Stress;
      Mach.Verify_Roots := Verify;
      Mach.Initial_Memory := Initial_Memory;
      Mach.Max_Memory := Max_Memory;
      Mach.Modu := M;
      Run (Mach, "main", Thread_Count);
      R := Last_Result (Mach);
      if Natural (Mach.Processes.Length) > 0 then
         P := Mach.Processes (1);
      else
         P := null;
      end if;
      if R = Make_None then
         Put_Line ("result: none");
      elsif R = Make_Unit then
         Put_Line ("result: unit");
      elsif (Is_Box (R) and P /= null) and then Is_Int_Box (P, R) then
         Put_Line ("result: " & Integer_64'Image (Unbox_Int (P, R)));
      elsif Is_Box (R) and P /= null then
         Put_Line ("result: " & Long_Float'Image (Unbox_Float (P, R)));
      elsif Is_Heap_Pointer (R) and P /= null then
         declare
            S : constant Natural := Str_Slot (P, R);
         begin
            if S > 0 then
               Put_Line ("result: " & To_String (Str_At (P, S).Chars));
            else
               Put_Line ("result: " & Integer'Image (Integer (Unbox_Small_Int (R))));
            end if;
         end;
      elsif Is_Immediate (R) then
         if Unbox_Bool (R) then
            Put_Line ("result: true");
         else
            Put_Line ("result: false");
         end if;
      else
         Put_Line ("result: " & Integer'Image (Integer (Unbox_Small_Int (R))));
      end if;
   end;
end VM_Main;
