separate (Lang.VM.Machine)
   procedure Run_Builtin_Files (M    : in out Machine;
                          P    : Process_Access;
                          Base : Natural;
                          Ins  : VC.Code_Instr) is
      function Arg (I : Positive) return TW is
      begin
         return P.Stack (Base + M.Prog.Args (Ins.Args_First + I - 1));
      end Arg;

      procedure Set_Dest (W : TW) is
      begin
         P.Stack (Base + Ins.Dest) := W;
      end Set_Dest;
begin
      case Ins.Builtin is
         when VC.Bi_Read_File =>
            declare
               Name    : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               Content : Unbounded_String := To_Unbounded_String ("");
               SF      : Ada.Streams.Stream_IO.File_Type;
               Slot    : Natural;
            begin
               begin
                  Ada.Streams.Stream_IO.Open (SF, Ada.Streams.Stream_IO.In_File, Name);
                  declare
                     Size : constant Natural := Natural (Ada.Streams.Stream_IO.Size (SF));
                     Buf  : Ada.Streams.Stream_Element_Array
                              (1 .. Ada.Streams.Stream_Element_Offset (Size));
                     Last : Ada.Streams.Stream_Element_Offset;
                  begin
                     Ada.Streams.Stream_IO.Read (SF, Buf, Last);
                     for I in 1 .. Last loop
                        Append (Content, Character'Val (Integer (Buf (I))));
                     end loop;
                  end;
                  Ada.Streams.Stream_IO.Close (SF);
               exception
                  when others =>
                     Put_Line (Standard_Error, "cannot read file: " & Name);
               end;
               Slot := Allocator.Alloc_Str (M, P);
               Str_At (P, Slot).Chars := Content;
               Allocator.Promote_To_Large (P, Slot);
               if Ins.Has_Dest then
                  Set_Dest (Str_Ptr (Slot));
               end if;
            end;

         when VC.Bi_Os_Write_File =>
            declare
               Path : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               Content : constant String :=
                 (if Ins.Args_Count >= 2 then To_String (Chars_Of (P, Arg (2))) else "");
               SF : Ada.Streams.Stream_IO.File_Type;
               Ok  : Boolean := True;
            begin
               begin
                  Ada.Streams.Stream_IO.Create (SF, Ada.Streams.Stream_IO.Out_File, Path);
                  if Content'Length > 0 then
                     declare
                        Buf : Ada.Streams.Stream_Element_Array (1 .. Content'Length);
                     begin
                        for I in Content'Range loop
                           Buf (Ada.Streams.Stream_Element_Offset (I - Content'First + 1)) := Ada.Streams.Stream_Element (Character'Pos (Content (I)));
                        end loop;
                        Ada.Streams.Stream_IO.Write (SF, Buf);
                     end;
                  end if;
                  Ada.Streams.Stream_IO.Close (SF);
               exception
                  when others =>
                     Ok := False;
                     Put_Line (Standard_Error, "cannot write file: " & Path);
               end;
               if Ins.Has_Dest then
                  Set_Dest (Make_Bool (Ok));
               end if;
            end;

         when VC.Bi_Os_File_Exists =>
            declare
               Path : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               Ok : Boolean := False;
            begin
               Ok := Ada.Directories.Exists (Path);
               if Ins.Has_Dest then
                  Set_Dest (Make_Bool (Ok));
               end if;
            end;

         when VC.Bi_Os_List_Dir =>
            declare
               Path : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else ".");
               Content : Unbounded_String := To_Unbounded_String ("");
               First : Boolean := True;
               Iter : Ada.Directories.Search_Type;
               E : Ada.Directories.Directory_Entry_Type;
            begin
               begin
                  Ada.Directories.Start_Search (Iter, Path, "");
                  while Ada.Directories.More_Entries (Iter) loop
                     Ada.Directories.Get_Next_Entry (Iter, E);
                     declare
                        Nm : constant String := Ada.Directories.Simple_Name (E);
                     begin
                        if Nm /= "." and then Nm /= ".." then
                           if not First then Append (Content, Character'Val (10)); end if;
                           First := False;
                           Append (Content, Nm);
                        end if;
                     end;
                  end loop;
                  Ada.Directories.End_Search (Iter);
               exception
                  when others =>
                     Put_Line (Standard_Error, "cannot list dir: " & Path);
               end;
               declare
                  Slot : constant Natural := Allocator.Alloc_Str (M, P);
               begin
                  Str_At (P, Slot).Chars := Content;
                  Allocator.Promote_To_Large (P, Slot);
                  if Ins.Has_Dest then
                     Set_Dest (Str_Ptr (Slot));
                  end if;
               end;
            end;

         when VC.Bi_Os_Get_Env =>
            declare
               Name : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               Val  : Unbounded_String := To_Unbounded_String ("");
            begin
               begin
                  Val := To_Unbounded_String (Ada.Environment_Variables.Value (Name));
               exception
                  when others =>
                     Val := To_Unbounded_String ("");
               end;
               declare
                  Slot : constant Natural := Allocator.Alloc_Str (M, P);
               begin
                  Str_At (P, Slot).Chars := Val;
                  Allocator.Promote_To_Large (P, Slot);
                  if Ins.Has_Dest then
                     Set_Dest (Str_Ptr (Slot));
                  end if;
               end;
            end;

         when VC.Bi_Os_Cwd =>
            declare
               Cwd  : constant String := Ada.Directories.Current_Directory;
               Slot : constant Natural := Allocator.Alloc_Str (M, P);
            begin
               Str_At (P, Slot).Chars := To_Unbounded_String (Cwd);
               Allocator.Promote_To_Large (P, Slot);
               if Ins.Has_Dest then
                  Set_Dest (Str_Ptr (Slot));
               end if;
            end;

         when VC.Bi_Os_Remove_File =>
            declare
               Path : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               Ok : Boolean := True;
            begin
               begin
                  Ada.Directories.Delete_File (Path);
               exception
                  when others =>
                     Ok := False;
               end;
               if Ins.Has_Dest then
                  Set_Dest (Make_Bool (Ok));
               end if;
            end;

         when VC.Bi_Os_Make_Dir =>
            declare
               Path : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               Ok : Boolean := True;
            begin
               begin
                  Ada.Directories.Create_Directory (Path);
               exception
                  when others =>
                     Ok := False;
               end;
               if Ins.Has_Dest then
                  Set_Dest (Make_Bool (Ok));
               end if;
            end;

         when VC.Bi_Os_Append_File =>
            declare
               Path : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               Content : constant String :=
                 (if Ins.Args_Count >= 2 then To_String (Chars_Of (P, Arg (2))) else "");
               SF : Ada.Streams.Stream_IO.File_Type;
               Ok  : Boolean := True;
            begin
               begin
                  Ada.Streams.Stream_IO.Open (SF, Ada.Streams.Stream_IO.Append_File, Path);
                  if Content'Length > 0 then
                     declare
                        Buf : Ada.Streams.Stream_Element_Array (1 .. Content'Length);
                     begin
                        for I in Content'Range loop
                           Buf (Ada.Streams.Stream_Element_Offset (I - Content'First + 1)) :=
                             Ada.Streams.Stream_Element (Character'Pos (Content (I)));
                        end loop;
                        Ada.Streams.Stream_IO.Write (SF, Buf);
                     end;
                  end if;
                  Ada.Streams.Stream_IO.Close (SF);
               exception
                  when others =>
                     Ok := False;
                     Put_Line (Standard_Error, "cannot append file: " & Path);
               end;
               if Ins.Has_Dest then
                  Set_Dest (Make_Bool (Ok));
               end if;
            end;

         when VC.Bi_Os_Copy_File =>
            declare
               Src : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               Dst : constant String :=
                 (if Ins.Args_Count >= 2 then To_String (Chars_Of (P, Arg (2))) else "");
               SF  : Ada.Streams.Stream_IO.File_Type;
               DF  : Ada.Streams.Stream_IO.File_Type;
               Ok  : Boolean := True;
               Size : Natural := 0;
            begin
               begin
                  Ada.Streams.Stream_IO.Open (SF, Ada.Streams.Stream_IO.In_File, Src);
                  Size := Natural (Ada.Streams.Stream_IO.Size (SF));
                  Ada.Streams.Stream_IO.Create (DF, Ada.Streams.Stream_IO.Out_File, Dst);
                  if Size > 0 then
                     declare
                        Buf : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Size));
                        Last : Ada.Streams.Stream_Element_Offset;
                     begin
                        Ada.Streams.Stream_IO.Read (SF, Buf, Last);
                        Ada.Streams.Stream_IO.Write (DF, Buf (1 .. Last));
                     end;
                  end if;
                  Ada.Streams.Stream_IO.Close (SF);
                  Ada.Streams.Stream_IO.Close (DF);
               exception
                  when others =>
                     Ok := False;
                     Put_Line (Standard_Error, "cannot copy file: " & Src);
               end;
               if Ins.Has_Dest then
                  Set_Dest (Make_Bool (Ok));
               end if;
            end;

         when VC.Bi_Os_Move_File =>
            declare
               Src : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               Dst : constant String :=
                 (if Ins.Args_Count >= 2 then To_String (Chars_Of (P, Arg (2))) else "");
               Ok  : Boolean := True;
            begin
               begin
                  Ada.Directories.Rename (Src, Dst);
               exception
                  when others =>
                     Ok := False;
                     Put_Line (Standard_Error, "cannot move file: " & Src);
               end;
               if Ins.Has_Dest then
                  Set_Dest (Make_Bool (Ok));
               end if;
            end;

         when VC.Bi_Os_File_Size =>
            declare
               Path : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               Sz : Integer_64 := 0;
            begin
               begin
                  Sz := Integer_64 (Ada.Directories.Size (Path));
               exception
                  when others => Sz := 0;
               end;
               if Ins.Has_Dest then
                  Set_Dest (Make_Small_Int (Sz));
               end if;
            end;

         when VC.Bi_Os_Is_Dir =>
            declare
               Path : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "");
               Ok : Boolean := False;
               use Ada.Directories;
            begin
               Ok := Ada.Directories.Exists (Path) and then Ada.Directories.Kind (Path) = Ada.Directories.Directory;
               if Ins.Has_Dest then
                  Set_Dest (Make_Bool (Ok));
               end if;
            end;

         when others => null;
      end case;
end Run_Builtin_Files;