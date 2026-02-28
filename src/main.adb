--
--  Copyright (c) 2025, German Rivera
--
--
--  SPDX-License-Identifier: Apache-2.0
--

with STC_Compiler;
with Ada.Command_Line;
with Ada.Text_IO;

procedure Main with SPARK_Mode => Off is
   File_Name : String (1 .. 256) := [others => ' '];
   File_Name_Length : Natural := 0;
   Machine_Width : Positive := 32;  -- Default value
begin
   if Ada.Command_Line.Argument_Count = 0 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "Usage: stcc [--machine-width=N] <.stc file>");
      raise Program_Error;
   end if;

   --  Parse command-line arguments
   for I in 1 .. Ada.Command_Line.Argument_Count loop
      declare
         Arg : constant String := Ada.Command_Line.Argument (I);
      begin
         if Arg'Length > 16 and then Arg (Arg'First .. Arg'First + 15) = "--machine-width=" then
            Machine_Width := Positive'Value (Arg (Arg'First + 16 .. Arg'Last));
         elsif Arg (Arg'First) /= '-' then
            --  This is the file name
            File_Name_Length := Arg'Length;
            File_Name (1 .. File_Name_Length) := Arg;
         else
            Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "Unknown option: " & Arg);
            raise Program_Error;
         end if;
      end;
   end loop;

   if File_Name_Length = 0 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "Error: No input file specified");
      raise Program_Error;
   end if;

   STC_Compiler.Compile_File (File_Name (1 .. File_Name_Length), Machine_Width);

exception
   when others =>
      Ada.Command_Line.Set_Exit_Status (1);
end Main;