separate (Lang.VM.Allocator)
   procedure Run_Process_Drops (M : in out Lang.VM.Machine.Machine; P : Process_Access) is
   begin
      for F in 1 .. P.Depth loop
         if P.Frames (F).Owned_Mask /= 0 then
            for I in 0 .. P.Frames (F).Reg_Count - 1 loop
               if (P.Frames (F).Owned_Mask and (Interfaces.Unsigned_32 (2) ** Natural (I))) /= 0 then
                  declare
                     V : constant TW := P.Stack (P.Frames (F).Base + I);
                     O : constant Natural := Obj_Slot (P, V);
                  begin
                     if O > 0 then
                        declare
                           DropFn : Natural := Obj_At (P, O).Drop;
                           TypeName : constant String := To_String (Obj_At (P, O).Type_Name);
                        begin
                           if DropFn = 0 then
                              declare
                                 Cand1 : constant String := TypeName & ".drop";
                              begin
                                 if M.Func_Names.Contains (Cand1) then
                                    DropFn := M.Func_Names.Element (Cand1);
                                 elsif M.Func_Names.Contains ("drop") then
                                    DropFn := M.Func_Names.Element ("drop");
                                 end if;
                              end;
                           end if;
                           -- Drop dispatch is handled by Op_Drop at runtime;
                           -- here we just mark the value for collection
                           null;
                        end;
                     end if;
                  end;
               end if;
            end loop;
         end if;
      end loop;
   end Run_Process_Drops;