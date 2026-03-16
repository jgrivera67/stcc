--
--  Copyright (c) 2025, German Rivera
--
--
--  SPDX-License-Identifier: Apache-2.0
--

--
--  @summary Strongly-Typed C compiler
--
with STC_Compiler.Lexer;
with STC_Compiler.Parser;
with Ada.Exceptions;
with Ada.Strings.Fixed;

package body STC_Compiler is
   procedure Compile_File (File_Name : String; Machine_Width : Positive := 32) with SPARK_Mode => Off is
      Compiler_Obj : Compiler_Type := (others => <>);
   begin
      Log_Message ("Compiling file " & File_Name & " ...");
      Init_Compiler (Compiler_Obj, File_Name, Machine_Width);
      Parser.Parse_File (Compiler_Obj);
      Cleanup_Compiler (Compiler_Obj);

   exception
      when E : others =>
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Ada.Exceptions.Exception_Message (E));
         raise;
   end Compile_File;

   procedure Init_Compiler (Compiler_Obj : out Compiler_Type; File_Name : String; Machine_Width : Positive := 32) is
   begin
      Ada.Text_IO.Open (File => Compiler_Obj.File_Obj,
                        Mode => Ada.Text_IO.In_File,
                        Name => File_Name);

      Compiler_Obj.File_Name := new String'(File_Name);
      Compiler_Obj.Machine_Width := Machine_Width;
      Compiler_Obj.Initialized := True;
      Lexer.Init_Lexer (Compiler_Obj);
      Parser.Init_Parser (Compiler_Obj);
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
      use Ada.Strings.Fixed;
      Lexer_Obj : Lexer_Type renames Compiler_Obj.Lexer_Obj;
   begin
      Log_Message (Compiler_Obj.File_Name.all & ":" &
                   Trim (Lexer_Obj.Line_Number'Image, Ada.Strings.Left) & ":" &
                   Trim (Lexer_Obj.Column_Number'Image, Ada.Strings.Left) &
                   " error: " & Message);
   end Log_Compiler_Error;

   procedure Log_Compiler_Error (Compiler_Obj : Compiler_Type;
                                 Token : Token_Type;
                                 Message : String) is
      use Ada.Strings.Fixed;
   begin
      Log_Message (Compiler_Obj.File_Name.all & ":" &
                   Trim (Token.Line_Number'Image, Ada.Strings.Left) & ":" &
                   Trim (Token.Column_Number'Image, Ada.Strings.Left) &
                   " error: " & Message);
   end Log_Compiler_Error;

end STC_Compiler;