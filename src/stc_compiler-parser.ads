--
--  Copyright (c) 2025, German Rivera
--
--
--  SPDX-License-Identifier: Apache-2.0
--

with Ada.Text_IO;
private package STC_Compiler.Parser is
   procedure Init_Parser (Compiler_Obj : out Compiler_Type);

   procedure Parse_File (Compiler_Obj : in out Compiler_Type)
      with Pre => Ada.Text_IO.Is_Open (Compiler_Obj.File_Obj),
           Post => Compiler_Obj.Parser_Obj.Last_Token.Kind = End_Of_File_Token and then
                   Compiler_Obj.Lexer_Obj.Lookahead_Char = ASCII.NUL;

end STC_Compiler.Parser;