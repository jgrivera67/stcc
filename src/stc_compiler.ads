--
--  Copyright (c) 2025, German Rivera
--
--
--  SPDX-License-Identifier: Apache-2.0
--

--
--  @summary Strong-Typed C compiler
--
private with Ada.Text_IO;

package STC_Compiler is
   procedure Compile_File (File_Name : String);

private
   type String_Pointer_Type is access String;

   type Token_Kind_Type is (
	   Break_Token,
      Case_Token,
      Character_Literal_Token,
      Comma_Token,
      Comment_Token,
      Continue_Token,
      Do_Token,
      Dot_Token,
      Else_Token,
      End_Of_File_Token,
      For_Token,
      Identifier_Token,
      If_Token,
      Invalid_Token,
      Left_Curly_Brace_Token,
      Left_Parenthesis_Token,
      Numeric_Literal_Token,
      Return_Token,
      Right_Curly_Brace_Token,
      Right_Parenthesis_Token,
      Semicolor_Token,
      String_Literal_Token,
      Switch_Token,
      Type_Token,
      Void_Token,
      While_Token);

   type Token_Type is record
      Kind : Token_Kind_Type := Invalid_Token;
      String_Value_Ptr : String_Pointer_Type := null;
   end record;

   type Token_Pointer_Type is access Token_Type;

   type Lexer_Type is limited record
      --  Next character to process from the input file
      Lookahead_Char : Character := ASCII.NUL;
      --  Current line number from the input file
      Line_Number : Positive := 1;
      --  Current column number from the current line
      Column_Number : Positive := 1;
   end record;

   type Parser_Type is limited record
      Last_Token : Token_Type;
   end record;

   type Compiler_Type is limited record
      Initialized : Boolean := False;
      File_Name : String_Pointer_Type := null;
      File_Obj : Ada.Text_IO.File_Type;
      Lexer_Obj  : Lexer_Type;
      Parser_Obj : Parser_Type;
   end record;

   procedure Init_Compiler (Compiler_Obj : out Compiler_Type; File_Name : String)
      with Pre => not Compiler_Obj.Initialized,
           Post => Compiler_Obj.Initialized and then
                   Ada.Text_IO.Is_Open (Compiler_Obj.File_Obj);

   procedure Cleanup_Compiler (Compiler_Obj : in out Compiler_Type)
      with Pre => Compiler_Obj.Initialized and then
                  Ada.Text_IO.Is_Open (Compiler_Obj.File_Obj),
           Post => not Compiler_Obj.Initialized and then
                   not Ada.Text_IO.Is_Open (Compiler_Obj.File_Obj);

   procedure Log_Message (Message : String);

   procedure Log_Compiler_Error (Compiler_Obj : Compiler_Type; Message : String)
      with Pre => Compiler_Obj.Initialized;

end STC_Compiler;
