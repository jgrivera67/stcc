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
begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "Usage: stcc <.stc file>");
      raise Program_Error;
   end if;

   STC_Compiler.Compile_File (Ada.Command_Line.Argument (1));

exception
   when others =>
      Ada.Command_Line.Set_Exit_Status (1);
end Main;