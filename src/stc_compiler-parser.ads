--
--  Copyright (c) 2025, German Rivera
--
--
--  SPDX-License-Identifier: Apache-2.0
--

with Ada.Text_IO;
private package STC_Compiler.Parser is
   procedure Init_Parser (Parser_Obj : out Parser_Type);

   procedure Parse_File (Parser_Obj : in out Parser_Type;
                         Lexer_Obj : in out Lexer_Type;
                         File_Obj : in out Ada.Text_IO.File_Type)
      with Pre => Ada.Text_IO.Is_Open (File_Obj),
           Post => Parser_Obj.Last_Token.Kind = End_Of_File_Token and then
                   Lexer_Obj.Lookahead_Char = ASCII.NUL;

end STC_Compiler.Parser;