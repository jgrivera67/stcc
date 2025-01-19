--
--  Copyright (c) 2025, German Rivera
--
--
--  SPDX-License-Identifier: Apache-2.0
--
With Ada.Characters.Handling;

package body STC_Compiler.Lexer is
   procedure Init_Lexer (Lexer_Obj : out Lexer_Type) is
   begin
      null; -- ???
   end Init_Lexer;

   procedure Get_Next_Token (Lexer_Obj : in out Lexer_Type;
                             File_Obj : in out Ada.Text_IO.File_Type;
                             Token_Obj : out Token_Type) is
   begin
      Token_Obj := (others => <>);
      if Lexer_Obj.Lookahead_Char = ASCII.NUL then
         Ada.Text_IO.Get (File_Obj, Lexer_Obj.Lookahead_Char);
         pragma Assert (Lexer_Obj.Lookahead_Char /= ASCII.NUL);
      end if;

   exception
      when Ada.Text_IO.End_Error =>
         Token_Obj.Kind := End_Of_File_Token;
   end Get_Next_Token;
end STC_Compiler.Lexer;
