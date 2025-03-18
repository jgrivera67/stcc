--
--  Copyright (c) 2025, German Rivera
--
--
--  SPDX-License-Identifier: Apache-2.0
--
with STC_Compiler.Lexer;
package body STC_Compiler.Parser is
   Operator_Precedence_Levels : constant := 16;

   --
   --  NOTE: Higher value means higher precedence
   --
   type Operator_Precedence_Type is range 1 .. Operator_Precedence_Levels;

   subtype Valid_AST_Operator_Type is AST_Operator_Type range
      AST_Operator_Type'First .. AST_Operator_Type'Pred (AST_Operator_Type'Last);

   --
   --  Table mapping operators to their precedence
   --
   --  NOTE: All unary operators are right-associative and
   --  all binary operators are left-associative.
   --
   Operator_Precedence_Table : constant array (Valid_AST_Operator_Type) of Operator_Precedence_Type :=
      [AST_Struct_Field_Op => Operator_Precedence_Type'Last,
       AST_Struct_Pointer_Field_Dereference_Op => Operator_Precedence_Type'Last,
       AST_Array_Declaration_Op => Operator_Precedence_Type'Last,
       AST_Array_Subscript_Op => Operator_Precedence_Type'Last,
       AST_Function_Call_Op => Operator_Precedence_Type'Last,
       AST_Type_Cast_Op => Operator_Precedence_Type'Last,
       AST_Address_Of_Op => Operator_Precedence_Type'Last - 1,
       AST_Pointer_Declaration_Op => Operator_Precedence_Type'Last - 1,
       AST_Pointer_Dereference_Op => Operator_Precedence_Type'Last - 1,
       AST_Sizeof_Op => Operator_Precedence_Type'Last - 1,
       AST_Arithmetic_Negate_Sign_Op => Operator_Precedence_Type'Last - 1,
       AST_Bitwise_Not_Op => Operator_Precedence_Type'Last - 1,
       AST_Logical_Not_Op => Operator_Precedence_Type'Last - 1,
       AST_Arithmetic_Divide_Op => Operator_Precedence_Type'Last - 2,
       AST_Arithmetic_Modulo_Op => Operator_Precedence_Type'Last - 2,
       AST_Arithmetic_Multiply_Op => Operator_Precedence_Type'Last - 2,
       AST_Arithmetic_Add_Op => Operator_Precedence_Type'Last - 3,
       AST_Arithmetic_Subtract_Op => Operator_Precedence_Type'Last - 3,
       AST_Bitwise_Left_Shift_Op => Operator_Precedence_Type'Last - 4,
       AST_Bitwise_Right_Shift_Op => Operator_Precedence_Type'Last - 4,
       AST_Arithmetic_Greater_Than_Op => Operator_Precedence_Type'Last - 5,
       AST_Arithmetic_Greater_Than_Or_Equal_To_Op => Operator_Precedence_Type'Last - 5,
       AST_Arithmetic_Less_Than_Op => Operator_Precedence_Type'Last - 5,
       AST_Arithmetic_Less_Than_Or_Equal_To_Op => Operator_Precedence_Type'Last - 5,
       AST_Arithmetic_Range_Op => Operator_Precedence_Type'Last - 5,
       AST_Arithmetic_Different_From_Op => Operator_Precedence_Type'Last - 6,
       AST_Arithmetic_Equal_To_Op => Operator_Precedence_Type'Last - 6,
       AST_Arithmetic_In_Range_Op => Operator_Precedence_Type'Last - 6,
       AST_Bitwise_And_Op => Operator_Precedence_Type'Last - 7,
       AST_Bitwise_Xor_Op => Operator_Precedence_Type'Last - 8,
       AST_Bitwise_Or_Op => Operator_Precedence_Type'Last - 9,
       AST_Logical_And_Op => Operator_Precedence_Type'Last - 10,
       AST_Logical_Or_Op => Operator_Precedence_Type'Last - 11,
       AST_Functional_If_Else_Op => Operator_Precedence_Type'Last - 12];

   procedure Init_Parser (Compiler_Obj : in out Compiler_Type) is
   begin
      Lexer.Get_Next_Token (Compiler_Obj);
   end Init_Parser;

   procedure Parse_File (Compiler_Obj : in out Compiler_Type) is
      Parser_Obj : Parser_Type renames Compiler_Obj.Parser_Obj;
   begin
      loop
         Current_Token_Obj : Token_Type renames Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index);
         exit when Current_Token_Obj.Kind = End_Of_File_Token;
         --  ???
         Log_Message ("'" & Current_Token_Obj.String_Buffer (1 .. Current_Token_Obj.String_Length) &
                      "' (token kind: " & Current_Token_Obj.Kind'Image & ")");
         --  ???
         Lexer.Get_Next_Token (Compiler_Obj);
      end loop;
   end Parse_File;

   procedure Stack_Push (Stack_Top : in out AST_Node_Pointer_Type;
                         Node : AST_Node_Pointer_Type)
      with Pre => Node /= null and then
                  Node.Next_In_Stack = null and then
                  Node /= Stack_Top,
         Post => Stack_Top = Node and then
                  Node.Next_In_Stack = Stack_Top
   is
   begin
      Node.Next_In_Stack := Stack_Top;
      Stack_Top := Node;
   end Stack_Push;

   procedure Stack_Pop (Stack_Top : in out AST_Node_Pointer_Type;
                        Stack_Bottom : AST_Node_Pointer_Type;
                        Node : out AST_Node_Pointer_Type)
      with Pre => Stack_Top /= Stack_Bottom,
         Post => Node = Stack_Top'Old and then
                  Node.Next_In_Stack = null and then
                  Stack_Top = Node.Next_In_Stack
   is
   begin
      Node := Stack_Top;
      Stack_Top := Node.Next_In_Stack;
      Node.Next_In_Stack := null;
   end Stack_Pop;

   procedure Parse_Expression (Compiler_Obj : in out Compiler_Type;
                               Operator_Stack_Bottom : AST_Node_Pointer_Type := null) is
      Parser_Obj : Parser_Type renames Compiler_Obj.Parser_Obj;

      procedure Operand_Stack_Push (Node : AST_Node_Pointer_Type) is
      begin
         Stack_Push (Parser_Obj.Operand_Stack_Top, Node);
      end Operand_Stack_Push;

      procedure Operand_Stack_Pop (Node : out AST_Node_Pointer_Type) is
      begin
         Stack_Pop (Parser_Obj.Operand_Stack_Top, null, Node);
      end Operand_Stack_Pop;

      procedure Operator_Stack_Push (Node : AST_Node_Pointer_Type) is
      begin
         Stack_Push (Parser_Obj.Operator_Stack_Top, Node);
      end Operator_Stack_Push;

      procedure Operator_Stack_Pop (Node : out AST_Node_Pointer_Type) is
      begin
         Stack_Pop (Parser_Obj.Operator_Stack_Top, Operator_Stack_Bottom, Node);
      end Operator_Stack_Pop;

      procedure Reduce_Operator is
         Operator_Node : AST_Node_Pointer_Type;
         Right_Operand_Node : AST_Node_Pointer_Type;
         Left_Operand_Node : AST_Node_Pointer_Type;
      begin
         Operator_Stack_Pop (Operator_Node);
         Operand_Stack_Pop (Right_Operand_Node);
         if Operator_Node.Node_Kind = AST_Binary_Expression_Node then
            Operand_Stack_Pop (Left_Operand_Node);
            Operator_Node.Left_Operand := Left_Operand_Node;
            Operator_Node.Right_Operand := Right_Operand_Node;
         else
            pragma Assert (Operator_Node.Node_Kind = AST_Unary_Expression_Node);
            Operator_Node.Operand := Right_Operand_Node;
         end if;

         Operand_Stack_Push (Operator_Node);
      end Reduce_Operator;

   begin
      loop
         Lexer.Get_Next_Token (Compiler_Obj);
         Current_Token_Obj : Token_Type renames Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index);
         Previous_Token_Obj : Token_Type renames Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index - 1);
         case Current_Token_Obj.Kind is
            when Identifier_Token =>
               --  - Lookup identifier in synbol table
               --  - if symbol found, get symbol's AST node from symbol table
               --  - else compiler error "undeclared symbol"
               --  - push operand
               null; --???

            when Minus_Op_Token =>
               Node_Kind : constant AST_Node_Kind_Type :=
                  (if Previous_Token_Obj.Is_Operator or else Previous_Token_Obj.Kind = Left_Parenthesis_Token then
                      AST_Unary_Expression_Node
                   else
                      AST_Binary_Expression_Node);

                  Operator_Node : AST_Node_Pointer_Type := new AST_Node_Type (Node_Kind);

               --  - if previous token is an operator or left parenthesis
               --    then this is a unary minus operator, CREATE unary minus node,
               --    (while precendence of operator stack top >= precedence of new operator, reduce) push new operator
               --  - else this is a binary minus operator, CREATE binary minus node,
               --    (while precendence of operator stack top >= precedence of new operator, reduce) push new operator
               null; --???

            when Plus_Op_Token =>
               --  - if previous token is an operator or left parenthesis
               --    then this is a unary plus operator
               --  - else this is a binary plus operator
               --  - push operator
               null; --???

            when Ampersand_Op_Token =>
               --  - push operator
               null; --???

            when Bitwise_Xor_Op_Token =>
               --  - push operator
               null; --???

            when Bitwise_Or_Op_Token =>
               --  - push operator
               null; --???

            when Logical_And_Op_Token =>
               --  - push operator
               null; --???

            when Logical_Or_Op_Token =>
               --  - push operator
               null; --???

            when Asterisk_Op_Token =>
               --  - push operator
               null; --???

            when Divide_Op_Token =>
               --  - push operator
               null; --???

            when Modulo_Op_Token =>
               --  - push operator
               null; --???

            when Dot_Op_Token =>
               --  - push operator
               null; --???

            when Arrow_Op_Token =>
               --  - push operator
               null; --???

            when Left_Parenthesis_Token =>
               Parse_Expression (Compiler_Obj, Parser_Obj.Operator_Stack_Top);

            when Right_Parenthesis_Token =>
               Reduce_Operator;
               return;

            when Comma_Token =>
               --  - pop operators until left parenthesis is found
               --  - push operand
               null; --???

            when others =>
               Log_Compiler_Error (Compiler_Obj,
                  "Unexpected token: '" &
                  Current_Token_Obj.String_Buffer (1 .. Current_Token_Obj.String_Length) &
                  "' (previous token: '" &
                  Previous_Token_Obj.String_Buffer (1 .. Previous_Token_Obj.String_Length) & "')");
               raise Program_Error;
         end case;
      end loop;
   end Parse_Expression;

end STC_Compiler.Parser;