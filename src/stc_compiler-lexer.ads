--
--  Copyright (c) 2025, German Rivera
--
--
--  SPDX-License-Identifier: Apache-2.0
--

with Ada.Text_IO;
private package STC_Compiler.Lexer is
   procedure Init_Lexer (Compiler_Obj : in out Compiler_Type)
      with Pre => Ada.Text_IO.Is_Open (Compiler_Obj.File_Obj),
           Post => Compiler_Obj.Lexer_Obj.Lookahead_Char /= ASCII.NUL or else
                   Ada.Text_IO.End_Of_File (Compiler_Obj.File_Obj);

   procedure Get_Next_Token (Compiler_Obj : in out Compiler_Type)
      with Pre => Ada.Text_IO.Is_Open (Compiler_Obj.File_Obj) and then
                  (Compiler_Obj.Lexer_Obj.Lookahead_Char /= ASCII.NUL or else
                   Ada.Text_IO.End_Of_File (Compiler_Obj.File_Obj)),
           Post => Get_Currrent_Token_Kind (Compiler_Obj) /= Invalid_Token;

end STC_Compiler.Lexer;