--
--  Copyright (c) 2025, German Rivera
--
--
--  SPDX-License-Identifier: Apache-2.0
--
with STC_Compiler.Lexer;
package body STC_Compiler.Parser is
   procedure Init_Parser (Parser_Obj : out Parser_Type) is
   begin
      null; --???
   end Init_Parser;

   procedure Parse_File (Parser_Obj : in out Parser_Type; Lexer_Obj : in out Lexer_Type;
                         File_Obj : in out Ada.Text_IO.File_Type) is
   begin
      loop
         Lexer.Get_Next_Token (Lexer_Obj, File_Obj, Parser_Obj.Last_Token);
         -- ???
         declare
            Token_Obj : Token_Type renames Parser_Obj.Last_Token;
         begin
            if Token_Obj.String_Value_Ptr /= null then
               Log_Message ("'" & Token_Obj.String_Value_Ptr.all & "'");
            end if;
         end;
         -- ???
         exit when Parser_Obj.Last_Token.Kind = End_Of_File_Token;
      end loop;
   end Parse_File;
end STC_Compiler.Parser;