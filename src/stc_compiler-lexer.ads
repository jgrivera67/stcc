--
--  Copyright (c) 2025, German Rivera
--
--
--  SPDX-License-Identifier: Apache-2.0
--

with Ada.Text_IO;
private package STC_Compiler.Lexer is
   procedure Init_Lexer (Lexer_Obj : out Lexer_Type);
   procedure Get_Next_Token (Lexer_Obj : in out Lexer_Type;
                             File_Obj : in out Ada.Text_IO.File_Type;
                             Token_Obj : out Token_Type)
      with Pre => Ada.Text_IO.Is_Open (File_Obj);

end STC_Compiler.Lexer;