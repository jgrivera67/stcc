--
--  Copyright (c) 2025, German Rivera
--
--
--  SPDX-License-Identifier: Apache-2.0
--
with STC_Compiler.Lexer;
package body STC_Compiler.Parser is
   Operator_Precedence_Levels : constant := 16;

   type Operator_Precedence_Type is range 1 .. Operator_Precedence_Levels;

   package Token_Kind_To_Precedence_Package is new
     Ada.Containers.Indefinite_Ordered_Maps
       (Key_Type        => Token_Kind_Type,
        Element_Type    => Operator_Precedence_Type);

   --
   --  Table mapping binary operators to their precedence
   --
   --  Note: All unary operators have higher precedence than
   --  any binary operator. All unary operators are right-associative
   --  all binary operators are left-associative.
   --
   Operator_Precedence_Table : Token_Kind_To_Precedence_Package.Map;

   procedure Init_Parser (Compiler_Obj : out Compiler_Type) is
   begin
      null; --???
   end Init_Parser;

   procedure Parse_File (Compiler_Obj : in out Compiler_Type) is
      Parser_Obj : Parser_Type renames Compiler_Obj.Parser_Obj;
   begin
      loop
         Lexer.Get_Next_Token (Compiler_Obj, Parser_Obj.Last_Token);
         exit when Parser_Obj.Last_Token.Kind = End_Of_File_Token;
         --  ???
         declare
            Token_Obj : Token_Type renames Parser_Obj.Last_Token;
         begin
            Log_Message ("'" & Token_Obj.String_Buffer (1 .. Token_Obj.String_Length) &
                         "' (token kind: " & Token_Obj.Kind'Image & ")");
         end;
         --  ???
      end loop;
   end Parse_File;

   procedure Init_Operator_Precedence_Table with
      Pre => Operator_Precedence_Table.Is_Empty,
      Post => not Operator_Precedence_Table.Is_Empty is
   begin
      Operator_Precedence_Table.Insert (Dot_Op_Token, Operator_Precedence_Type'Last);
      Operator_Precedence_Table.Insert (Arrow_Op_Token, Operator_Precedence_Type'Last);
      Operator_Precedence_Table.Insert (Asterisk_Op_Token, Operator_Precedence_Type'Last - 3);
      Operator_Precedence_Table.Insert (Divide_Op_Token, Operator_Precedence_Type'Last - 3);
      Operator_Precedence_Table.Insert (Modulo_Op_Token, Operator_Precedence_Type'Last - 3);
      Operator_Precedence_Table.Insert (Minus_Op_Token, Operator_Precedence_Type'Last - 4);
      Operator_Precedence_Table.Insert (Plus_Op_Token, Operator_Precedence_Type'Last - 4);
      Operator_Precedence_Table.Insert (Ampersand_Op_Token, Operator_Precedence_Type'Last - 8);
      Operator_Precedence_Table.Insert (Bitwise_Xor_Op_Token, Operator_Precedence_Type'Last - 9);
      Operator_Precedence_Table.Insert (Bitwise_Or_Op_Token, Operator_Precedence_Type'Last - 10);
      Operator_Precedence_Table.Insert (Logical_And_Op_Token, Operator_Precedence_Type'Last - 11);
      Operator_Precedence_Table.Insert (Logical_Or_Op_Token, Operator_Precedence_Type'Last - 12);
   end Init_Operator_Precedence_Table;

--  Package elaboration:
begin
   Init_Operator_Precedence_Table;
end STC_Compiler.Parser;