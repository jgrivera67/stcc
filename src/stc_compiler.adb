--
--  Copyright (c) 2025, German Rivera
--
--
--  SPDX-License-Identifier: Apache-2.0
--

--
--  @summary Strong-Typed C compiler
--
with STC_Compiler.Lexer;
with STC_Compiler.Parser;
with Ada.Exceptions;

package body STC_Compiler is
   procedure Compile_File (File_Name : String) with SPARK_Mode => Off is
      Compiler_Obj : Compiler_Type := (others => <>);
   begin
      Log_Message ("Compiling file " & File_Name & " ...");
      Init_Compiler (Compiler_Obj, File_Name);

      Cleanup_Compiler (Compiler_Obj);

   exception
      when E : Ada.Text_IO.Name_Error | Storage_Error | Program_Error =>
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Ada.Exceptions.Exception_Message (E));
         raise;
   end Compile_File;

   procedure Init_Compiler (Compiler_Obj : out Compiler_Type; File_Name : String) is
   begin
      Ada.Text_IO.Open (File => Compiler_Obj.File_Obj,
                        Mode => Ada.Text_IO.In_File,
                        Name => File_Name);

      Compiler_Obj.File_Name := new String'(File_Name);
      Lexer.Init_Lexer (Compiler_Obj.Lexer_Obj);
      Parser.Init_Parser (Compiler_Obj.Parser_Obj);
      Compiler_Obj.Initialized := True;
   end Init_Compiler;

   procedure Cleanup_Compiler (Compiler_Obj : in out Compiler_Type) is
   begin
      Ada.Text_IO.Close (File => Compiler_Obj.File_Obj);
      Compiler_Obj.Initialized := False;
   end Cleanup_Compiler;

   procedure Log_Message (Message : String) with SPARK_Mode => Off is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Message);
   end Log_Message;

   procedure Log_Compiler_Error (Compiler_Obj : Compiler_Type; Message : String) is
      Lexer_Obj : Lexer_Type renames Compiler_Obj.Lexer_Obj;
   begin
      Log_Message (Compiler_Obj.File_Name.all & ":" & Lexer_Obj.Line_Number'Image &
                   ":" & Lexer_Obj.Column_Number'Image & " error: " & Message);
   end Log_Compiler_Error;
end STC_Compiler;