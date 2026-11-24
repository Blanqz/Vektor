separate (Lang.VM.Machine)
   procedure Run_Builtin_Net (M    : in out Machine;
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
         when VC.Bi_Net_Connect =>
            declare
               Host : constant String :=
                 (if Ins.Args_Count >= 1 then To_String (Chars_Of (P, Arg (1))) else "localhost");
               Port : constant Integer :=
                 (if Ins.Args_Count >= 2 then Integer (Unbox_Int (P, Arg (2))) else 0);
               Sock : GNAT.Sockets.Socket_Type;
               Addr : GNAT.Sockets.Sock_Addr_Type;
               Ok   : Boolean := True;
               H    : Natural := 0;
            begin
               begin
                  GNAT.Sockets.Create_Socket (Sock);
                  Addr.Addr := GNAT.Sockets.Inet_Addr (Host);
                  Addr.Port := GNAT.Sockets.Port_Type (Port);
                  GNAT.Sockets.Connect_Socket (Sock, Addr);
                  M.Net_Sockets.Append (new GNAT.Sockets.Socket_Type'(Sock));
                  M.Net_Active.Append (True);
                  H := Natural (M.Net_Sockets.Length);
               exception
                  when others =>
                     Ok := False;
                     begin GNAT.Sockets.Close_Socket (Sock); exception when others => null; end;
               end;
               if Ins.Has_Dest then
                  if Ok then Set_Dest (Make_Small_Int (Integer_64 (H)));
                  else Set_Dest (Make_Small_Int (0)); end if;
               end if;
            end;

         when VC.Bi_Net_Send =>
            declare
               H    : constant Integer :=
                 (if Ins.Args_Count >= 1 then Integer (Unbox_Int (P, Arg (1))) else 0);
               Data : constant String :=
                 (if Ins.Args_Count >= 2 then To_String (Chars_Of (P, Arg (2))) else "");
               Last : Ada.Streams.Stream_Element_Offset;
               Buf  : Ada.Streams.Stream_Element_Array (1 .. Data'Length);
               Sock : GNAT.Sockets.Socket_Type;
               Ok   : Boolean := False;
            begin
               if H >= 1 and then H <= Natural (M.Net_Sockets.Length) and then M.Net_Active (H) then
                  Sock := M.Net_Sockets (H).all;
                  for I in Data'Range loop
                     Buf (Ada.Streams.Stream_Element_Offset (I - Data'First + 1)) := Ada.Streams.Stream_Element (Character'Pos (Data (I)));
                  end loop;
                  begin
                     GNAT.Sockets.Send_Socket (Sock, Buf, Last);
                     Ok := True;
                  exception
                     when others => Ok := False;
                  end;
               end if;
               if Ins.Has_Dest then
                  if Ok then Set_Dest (Make_Small_Int (Integer_64 (Last)));
                  else Set_Dest (Make_Small_Int (-1)); end if;
               end if;
            end;

         when VC.Bi_Net_Recv =>
            declare
               H       : constant Integer :=
                 (if Ins.Args_Count >= 1 then Integer (Unbox_Int (P, Arg (1))) else 0);
               Sock    : GNAT.Sockets.Socket_Type;
               Buf     : Ada.Streams.Stream_Element_Array (1 .. 4096);
               Last    : Ada.Streams.Stream_Element_Offset;
               Content : Unbounded_String := To_Unbounded_String ("");
            begin
               if H >= 1 and then H <= Natural (M.Net_Sockets.Length) and then M.Net_Active (H) then
                  Sock := M.Net_Sockets (H).all;
                  begin
                     GNAT.Sockets.Receive_Socket (Sock, Buf, Last);
                     for I in 1 .. Last loop
                        Append (Content, Character'Val (Integer (Buf (I))));
                     end loop;
                  exception
                     when others => null;
                  end;
               end if;
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

         when VC.Bi_Net_Close =>
            declare
               H : constant Integer :=
                 (if Ins.Args_Count >= 1 then Integer (Unbox_Int (P, Arg (1))) else 0);
            begin
               if H >= 1 and then H <= Natural (M.Net_Sockets.Length) and then M.Net_Active (H) then
                  begin
                     GNAT.Sockets.Close_Socket (M.Net_Sockets (H).all);
                  exception
                     when others => null;
                  end;
                  M.Net_Active (H) := False;
               end if;
               if Ins.Has_Dest then
                  Set_Dest (Make_Bool (True));
               end if;
            end;

         when VC.Bi_Net_Listen =>
            declare
               Port : constant Integer :=
                 (if Ins.Args_Count >= 1 then Integer (Unbox_Int (P, Arg (1))) else 0);
               Sock : GNAT.Sockets.Socket_Type;
               Addr : GNAT.Sockets.Sock_Addr_Type;
               Ok   : Boolean := True;
               H    : Natural := 0;
            begin
               begin
                  GNAT.Sockets.Create_Socket (Sock, GNAT.Sockets.Family_Inet, GNAT.Sockets.Socket_Stream);
                  Addr.Addr := GNAT.Sockets.Any_Inet_Addr;
                  Addr.Port := GNAT.Sockets.Port_Type (Port);
                  GNAT.Sockets.Bind_Socket (Sock, Addr);
                  GNAT.Sockets.Listen_Socket (Sock);
                  M.Net_Sockets.Append (new GNAT.Sockets.Socket_Type'(Sock));
                  M.Net_Active.Append (True);
                  H := Natural (M.Net_Sockets.Length);
               exception
                  when others =>
                     Ok := False;
                     begin GNAT.Sockets.Close_Socket (Sock); exception when others => null; end;
               end;
               if Ins.Has_Dest then
                  if Ok then Set_Dest (Make_Small_Int (Integer_64 (H)));
                  else Set_Dest (Make_Small_Int (0)); end if;
               end if;
            end;

         when VC.Bi_Net_Accept =>
            declare
               H        : constant Integer :=
                 (if Ins.Args_Count >= 1 then Integer (Unbox_Int (P, Arg (1))) else 0);
               Listener : GNAT.Sockets.Socket_Type;
               Client   : GNAT.Sockets.Socket_Type;
               Addr     : GNAT.Sockets.Sock_Addr_Type;
               Ok       : Boolean := True;
               NH       : Natural := 0;
            begin
               if H >= 1 and then H <= Natural (M.Net_Sockets.Length) and then M.Net_Active (H) then
                  Listener := M.Net_Sockets (H).all;
                  begin
                     GNAT.Sockets.Accept_Socket (Listener, Client, Addr);
                     M.Net_Sockets.Append (new GNAT.Sockets.Socket_Type'(Client));
                     M.Net_Active.Append (True);
                     NH := Natural (M.Net_Sockets.Length);
                  exception
                     when others => Ok := False;
                  end;
               else
                  Ok := False;
               end if;
               if Ins.Has_Dest then
                  if Ok then Set_Dest (Make_Small_Int (Integer_64 (NH)));
                  else Set_Dest (Make_Small_Int (0)); end if;
               end if;
            end;

         when others => null;
      end case;
end Run_Builtin_Net;