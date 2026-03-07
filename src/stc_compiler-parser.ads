--
--  Copyright (c) 2025, German Rivera
--
--
--  SPDX-License-Identifier: Apache-2.0
--

with Ada.Text_IO;
private package STC_Compiler.Parser is
   procedure Init_Parser (Compiler_Obj : in out Compiler_Type);

   procedure Parse_File (Compiler_Obj : in out Compiler_Type)
      with Pre => Ada.Text_IO.Is_Open (Compiler_Obj.File_Obj),
           Post => Get_Currrent_Token_Kind (Compiler_Obj) = End_Of_File_Token and then
                   Compiler_Obj.Lexer_Obj.Lookahead_Char = ASCII.NUL;

private

   procedure Parse_Expression (Compiler_Obj : in out Compiler_Type;
                               Operator_Stack_Bottom : AST_Node_Pointer_Type := null);

   procedure Parse_Field_Attributes (Compiler_Obj : in out Compiler_Type;
                                     Attr_List : out AST_Node_Pointer_Type);

   procedure Parse_Type_Attributes (Compiler_Obj : in out Compiler_Type;
                                    Attr_List : out AST_Node_Pointer_Type);

   procedure Parse_Variable_Attributes (Compiler_Obj : in out Compiler_Type;
                                        Attr_List : out AST_Node_Pointer_Type);

end STC_Compiler.Parser;