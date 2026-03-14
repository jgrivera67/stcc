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
   --  NOTE: All unary operators are right-associative.
   --  Binary operators are left-associative except for:
   --    - Exponentiation (**) which is right-associative
   --    - Ternary conditional (? :) which is right-associative
   --
   Operator_Precedence_Table : constant array (Valid_AST_Operator_Type) of Operator_Precedence_Type :=
      [AST_Struct_Field_Op => Operator_Precedence_Type'Last,
       AST_Struct_Pointer_Field_Dereference_Op => Operator_Precedence_Type'Last,
       AST_Array_Declaration_Op => Operator_Precedence_Type'Last,
       AST_Array_Subscript_Op => Operator_Precedence_Type'Last,
       AST_Function_Call_Op => Operator_Precedence_Type'Last,
       AST_Type_Cast_Op => Operator_Precedence_Type'Last,
       --  Attribute operators have highest precedence (postfix operators)
       AST_First_Attribute_Op => Operator_Precedence_Type'Last,
       AST_Last_Attribute_Op => Operator_Precedence_Type'Last,
       AST_Length_Attribute_Op => Operator_Precedence_Type'Last,
       AST_Range_Attribute_Op => Operator_Precedence_Type'Last,
       AST_Size_Attribute_Op => Operator_Precedence_Type'Last,
       AST_Address_Of_Op => Operator_Precedence_Type'Last - 1,
       AST_Pointer_Declaration_Op => Operator_Precedence_Type'Last - 1,
       AST_Pointer_Dereference_Op => Operator_Precedence_Type'Last - 1,
       AST_Sizeof_Op => Operator_Precedence_Type'Last - 1,
       AST_Arithmetic_Negate_Sign_Op => Operator_Precedence_Type'Last - 1,
       AST_Bitwise_Not_Op => Operator_Precedence_Type'Last - 1,
       AST_Logical_Not_Op => Operator_Precedence_Type'Last - 1,
       AST_Arithmetic_Power_Op => Operator_Precedence_Type'Last - 2,
       AST_Arithmetic_Divide_Op => Operator_Precedence_Type'Last - 3,
       AST_Arithmetic_Modulo_Op => Operator_Precedence_Type'Last - 3,
       AST_Arithmetic_Multiply_Op => Operator_Precedence_Type'Last - 3,
       AST_Arithmetic_Add_Op => Operator_Precedence_Type'Last - 4,
       AST_Arithmetic_Subtract_Op => Operator_Precedence_Type'Last - 4,
       AST_Bitwise_Left_Shift_Op => Operator_Precedence_Type'Last - 5,
       AST_Bitwise_Right_Shift_Op => Operator_Precedence_Type'Last - 5,
       AST_Arithmetic_Greater_Than_Op => Operator_Precedence_Type'Last - 6,
       AST_Arithmetic_Greater_Than_Or_Equal_To_Op => Operator_Precedence_Type'Last - 6,
       AST_Arithmetic_Less_Than_Op => Operator_Precedence_Type'Last - 6,
       AST_Arithmetic_Less_Than_Or_Equal_To_Op => Operator_Precedence_Type'Last - 6,
       AST_Arithmetic_Range_Op => Operator_Precedence_Type'Last - 6,  -- Not used in expressions
       AST_Arithmetic_Different_From_Op => Operator_Precedence_Type'Last - 7,
       AST_Arithmetic_Equal_To_Op => Operator_Precedence_Type'Last - 7,
       AST_Arithmetic_In_Range_Op => Operator_Precedence_Type'Last - 7,
       AST_Bitwise_And_Op => Operator_Precedence_Type'Last - 8,
       AST_Bitwise_Xor_Op => Operator_Precedence_Type'Last - 9,
       AST_Bitwise_Or_Op => Operator_Precedence_Type'Last - 10,
       AST_Logical_And_Op => Operator_Precedence_Type'Last - 11,
       AST_Logical_Or_Op => Operator_Precedence_Type'Last - 12,
       AST_Functional_If_Else_Op => Operator_Precedence_Type'Last - 13];

   --
   --  Mapping tables from token kinds to AST operators
   --
   type Token_To_Binary_Operator_Map_Type is array (Token_Kind_Type) of AST_Operator_Type;

   Token_To_Binary_Operator_Map : constant Token_To_Binary_Operator_Map_Type :=
      [Plus_Op_Token => AST_Arithmetic_Add_Op,
       Minus_Op_Token => AST_Arithmetic_Subtract_Op,
       Asterisk_Op_Token => AST_Arithmetic_Multiply_Op,
       Divide_Op_Token => AST_Arithmetic_Divide_Op,
       Modulo_Op_Token => AST_Arithmetic_Modulo_Op,
       Power_Op_Token => AST_Arithmetic_Power_Op,
       Ampersand_Op_Token => AST_Bitwise_And_Op,
       Bitwise_Or_Op_Token => AST_Bitwise_Or_Op,
       Bitwise_Xor_Op_Token => AST_Bitwise_Xor_Op,
       Bitwise_Left_Shift_Op_Token => AST_Bitwise_Left_Shift_Op,
       Bitwise_Right_Shift_Op_Token => AST_Bitwise_Right_Shift_Op,
       Logical_And_Op_Token => AST_Logical_And_Op,
       Logical_Or_Op_Token => AST_Logical_Or_Op,
       Equality_Op_Token => AST_Arithmetic_Equal_To_Op,
       Less_Than_Op_Token => AST_Arithmetic_Less_Than_Op,
       Greater_Than_Op_Token => AST_Arithmetic_Greater_Than_Op,
       Less_Than_Or_Equal_Op_Token => AST_Arithmetic_Less_Than_Or_Equal_To_Op,
       Greater_Than_Or_Equal_Op_Token => AST_Arithmetic_Greater_Than_Or_Equal_To_Op,
       Range_Op_Token => AST_Arithmetic_Range_Op,
       In_Token => AST_Arithmetic_In_Range_Op,
       Dot_Op_Token => AST_Struct_Field_Op,
       Arrow_Op_Token => AST_Struct_Pointer_Field_Dereference_Op,
       others => AST_Invalid_Op];
   pragma Unreferenced (Token_To_Binary_Operator_Map);
   --  Reserved for future use in alternative operator parsing approach

   type Token_To_Unary_Operator_Map_Type is array (Token_Kind_Type) of AST_Operator_Type;

   Token_To_Unary_Operator_Map : constant Token_To_Unary_Operator_Map_Type :=
      [Minus_Op_Token => AST_Arithmetic_Negate_Sign_Op,
       Logical_Not_Op_Token => AST_Logical_Not_Op,
       Bitwise_Not_Op_Token => AST_Bitwise_Not_Op,
       Ampersand_Op_Token => AST_Address_Of_Op,
       Asterisk_Op_Token => AST_Pointer_Dereference_Op,
       others => AST_Invalid_Op];
   pragma Unreferenced (Token_To_Unary_Operator_Map);
   --  Reserved for future use in alternative operator parsing approach

   procedure Init_Parser (Compiler_Obj : in out Compiler_Type) is
   begin
      Lexer.Get_Next_Token (Compiler_Obj);
   end Init_Parser;

   --
   --  Helper procedures for parsing different constructs
   --

   procedure Stack_Push (Stack_Top : in out AST_Node_Pointer_Type;
                         Node : AST_Node_Pointer_Type)
      with Pre => Node /= null and then
                  Node.Next_In_Stack = null and then
                  Node /= Stack_Top,
           Post => Stack_Top = Node and then
                   Node.Next_In_Stack = Stack_Top'Old;

   procedure Stack_Pop (Stack_Top : in out AST_Node_Pointer_Type;
                        Stack_Bottom : AST_Node_Pointer_Type;
                        Node : out AST_Node_Pointer_Type)
      with Pre => Stack_Top /= Stack_Bottom,
           Post => Node = Stack_Top'Old and then
                   Node.Next_In_Stack = null;

   --  Returns True if the token kind can appear as a type name (identifier or built-in keyword type)
   function Is_Type_Name_Token (Kind : Token_Kind_Type) return Boolean is
      (Kind = Identifier_Token or else
       Kind = Bool_Token or else
       Kind = Char_Token or else
       Kind = Void_Token);

   procedure Parse_Statement (Compiler_Obj : in out Compiler_Type;
                              Statement_Node : out AST_Node_Pointer_Type);

   procedure Parse_Declaration (Compiler_Obj : in out Compiler_Type;
                               Declaration_Node : out AST_Node_Pointer_Type);

   --  TODO: Will be used once function declaration parsing is complete
   pragma Warnings (Off, "procedure ""Parse_Contract_Attribute"" is not referenced");
   procedure Parse_Contract_Attribute (Compiler_Obj : in out Compiler_Type;
                                       Contract_Type : out Token_Kind_Type;
                                       Contract_Node : out AST_Node_Pointer_Type);
   pragma Warnings (On, "procedure ""Parse_Contract_Attribute"" is not referenced");

   procedure Expect_Token (Compiler_Obj : in out Compiler_Type;
                          Expected : Token_Kind_Type) is
      Parser_Obj : Parser_Type renames Compiler_Obj.Parser_Obj;
      Current_Token_Obj : Token_Type renames
         Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index);
   begin
      if Current_Token_Obj.Kind /= Expected then
         Log_Compiler_Error (Compiler_Obj,
            Current_Token_Obj,
            "Expected " & Expected'Image & " but found '" &
            Current_Token_Obj.String_Buffer (
               1 .. Current_Token_Obj.String_Length) & "'");
         raise Program_Error;
      end if;
      Lexer.Get_Next_Token (Compiler_Obj);
   end Expect_Token;

   procedure Parse_Statement_Block (Compiler_Obj : in out Compiler_Type;
                                   Block_Node : out AST_Node_Pointer_Type)
   is
      Parser_Obj : Parser_Type renames Compiler_Obj.Parser_Obj;
      Current_Token_Obj : Token_Type renames
         Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index);
   begin
      Block_Node := new AST_Node_Type (AST_Statement_Block_Node);

      Expect_Token (Compiler_Obj, Left_Curly_Brace_Token);

      --  Parse statements and local declarations until we hit }
      while Current_Token_Obj.Kind /= Right_Curly_Brace_Token loop
         if Current_Token_Obj.Kind = End_Of_File_Token then
            Log_Compiler_Error (Compiler_Obj,
               "Unexpected end of file in statement block");
            raise Program_Error;
         end if;

         --  Try to parse as declaration or statement
         --  TODO: Implement proper logic to distinguish
         --  declarations from statements
         declare
            Stmt_Node : AST_Node_Pointer_Type;
         begin
            Parse_Statement (Compiler_Obj, Stmt_Node);
            if Stmt_Node /= null then
               --  Add to block's statement list
               if Block_Node.First_Statement = null then
                  Block_Node.First_Statement := Stmt_Node;
               else
                  --  Link to end of list
                  declare
                     Last_Stmt : AST_Node_Pointer_Type :=
                        Block_Node.First_Statement;
                  begin
                     while Last_Stmt.Next_Sibling /= null loop
                        Last_Stmt := Last_Stmt.Next_Sibling;
                     end loop;
                     Last_Stmt.Next_Sibling := Stmt_Node;
                  end;
               end if;
            end if;
         end;
      end loop;

      Expect_Token (Compiler_Obj, Right_Curly_Brace_Token);
   end Parse_Statement_Block;

   procedure Parse_Statement (Compiler_Obj : in out Compiler_Type;
                             Statement_Node : out AST_Node_Pointer_Type)
   is
      Parser_Obj : Parser_Type renames Compiler_Obj.Parser_Obj;
      Current_Token_Obj : Token_Type renames
         Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index);
   begin
      Statement_Node := null;

      case Current_Token_Obj.Kind is
         when If_Token =>
            --  Parse if statement
            declare
               If_Node : constant AST_Node_Pointer_Type :=
                  new AST_Node_Type (AST_If_Node);
            begin
               Lexer.Get_Next_Token (Compiler_Obj);  --  Skip 'if'
               Expect_Token (Compiler_Obj, Left_Parenthesis_Token);
               Parse_Expression (Compiler_Obj);
               --  TODO: Get condition from operand stack
               Expect_Token (Compiler_Obj, Right_Parenthesis_Token);
               Parse_Statement_Block (Compiler_Obj, If_Node.Then_Body);

               if Current_Token_Obj.Kind = Else_Token then
                  Lexer.Get_Next_Token (Compiler_Obj);  --  Skip 'else'
                  Parse_Statement_Block (Compiler_Obj, If_Node.Else_Body);
               end if;

               Statement_Node := If_Node;
            end;

         when While_Token =>
            --  Parse while loop
            declare
               While_Node : constant AST_Node_Pointer_Type :=
                  new AST_Node_Type (AST_While_Node);
            begin
               Lexer.Get_Next_Token (Compiler_Obj);  --  Skip 'while'
               Expect_Token (Compiler_Obj, Left_Parenthesis_Token);
               Parse_Expression (Compiler_Obj);
               --  TODO: Get condition from operand stack
               Expect_Token (Compiler_Obj, Right_Parenthesis_Token);
               Parse_Statement_Block (Compiler_Obj, While_Node.While_Body);
               Statement_Node := While_Node;
            end;

         when For_Token =>
            --  Parse for loop
            declare
               For_Node : constant AST_Node_Pointer_Type := new AST_Node_Type (AST_For_Node);
            begin
               Lexer.Get_Next_Token (Compiler_Obj);  --  Skip 'for'
               Expect_Token (Compiler_Obj, Left_Parenthesis_Token);
               --  Parse initialization
               if Current_Token_Obj.Kind /= Semicolon_Token then
                  Parse_Expression (Compiler_Obj);
                  --  TODO: Get init expression from operand stack
               end if;
               Expect_Token (Compiler_Obj, Semicolon_Token);
               --  Parse condition
               if Current_Token_Obj.Kind /= Semicolon_Token then
                  Parse_Expression (Compiler_Obj);
                  --  TODO: Get condition from operand stack
               end if;
               Expect_Token (Compiler_Obj, Semicolon_Token);
               --  Parse increment
               if Current_Token_Obj.Kind /= Right_Parenthesis_Token then
                  Parse_Expression (Compiler_Obj);
                  --  TODO: Get increment from operand stack
               end if;
               Expect_Token (Compiler_Obj, Right_Parenthesis_Token);
               Parse_Statement_Block (Compiler_Obj, For_Node.For_Body);
               Statement_Node := For_Node;
            end;

         when Return_Token =>
            --  Parse return statement
            Lexer.Get_Next_Token (Compiler_Obj);  --  Skip 'return'
            if Current_Token_Obj.Kind /= Semicolon_Token then
               Parse_Expression (Compiler_Obj);
               --  TODO: Create return statement node with expression
            end if;
            Expect_Token (Compiler_Obj, Semicolon_Token);
            --  TODO: Create and return statement node

         when Left_Curly_Brace_Token =>
            --  Nested block
            Parse_Statement_Block (Compiler_Obj, Statement_Node);

         when others =>
            --  Try to parse as expression statement (assignment or function call)
            Parse_Expression (Compiler_Obj);
            --  TODO: Pop expression from operand stack and wrap in statement node
            if Current_Token_Obj.Kind = Semicolon_Token then
               Lexer.Get_Next_Token (Compiler_Obj);
            end if;
      end case;
   end Parse_Statement;

   --  Create a new identifier from the current token's string and the given kind
   function Make_Identifier (Compiler_Obj : Compiler_Type;
                              Kind         : Identifier_Kind_Type)
                              return Identifier_Pointer_Type
   is
      Parser_Obj : Parser_Type renames Compiler_Obj.Parser_Obj;
      Current_Token_Obj : Token_Type renames
         Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index);
      Id : constant Identifier_Pointer_Type := new Identifier_Type;
   begin
      Id.Kind := Kind;
      Id.Name := new String'(Current_Token_Obj.String_Buffer (1 .. Current_Token_Obj.String_Length));
      return Id;
   end Make_Identifier;

   procedure Parse_Type_Declaration (Compiler_Obj : in out Compiler_Type;
                                     Type_Node : out AST_Node_Pointer_Type) is
      Parser_Obj : Parser_Type renames Compiler_Obj.Parser_Obj;
   begin
      Type_Node := new AST_Node_Type (AST_Type_Declaration_Node);
      Lexer.Get_Next_Token (Compiler_Obj);  --  Skip 'type'

      --  Parse type declarator (range/mod/struct/enum/union)
      case Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind is
         when Range_Token =>
            --  Range type: type range 0 .. 100 Foo;
            Lexer.Get_Next_Token (Compiler_Obj);
            Parse_Expression (Compiler_Obj);
            Expect_Token (Compiler_Obj, Range_Op_Token);
            Parse_Expression (Compiler_Obj);
            --  TODO: Create range type node

         when Modular_Token =>
            --  Modular type: type modular 256 Foo;
            Lexer.Get_Next_Token (Compiler_Obj);
            Parse_Expression (Compiler_Obj);
            --  TODO: Create modular type node

         when Float_Token =>
            --  Floating point type: type float digits 6 Foo;
            --  or: type float digits 6 range -273.15 .. 1000.0 Foo;
            Lexer.Get_Next_Token (Compiler_Obj);
            Expect_Token (Compiler_Obj, Digits_Token);
            Parse_Expression (Compiler_Obj);  --  Precision (digits)
            --  Check for optional range clause
            if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Range_Token then
               Lexer.Get_Next_Token (Compiler_Obj);
               Parse_Expression (Compiler_Obj);  --  Min value
               Expect_Token (Compiler_Obj, Range_Op_Token);
               Parse_Expression (Compiler_Obj);  --  Max value
            end if;
            --  TODO: Create float type node

         when Fixed_Token =>
            --  Ordinary fixed point type: type fixed delta 0.01 range -100.0 .. 100.0 Foo;
            Lexer.Get_Next_Token (Compiler_Obj);
            Expect_Token (Compiler_Obj, Delta_Token);
            Parse_Expression (Compiler_Obj);  --  Delta value
            Expect_Token (Compiler_Obj, Range_Token);
            Parse_Expression (Compiler_Obj);  --  Min value
            Expect_Token (Compiler_Obj, Range_Op_Token);
            Parse_Expression (Compiler_Obj);  --  Max value
            --  TODO: Create fixed type node

         when Decimal_Token =>
            --  Decimal fixed point type: type decimal delta 0.01 digits 10 Foo;
            Lexer.Get_Next_Token (Compiler_Obj);
            Expect_Token (Compiler_Obj, Delta_Token);
            Parse_Expression (Compiler_Obj);  --  Delta value
            Expect_Token (Compiler_Obj, Digits_Token);
            Parse_Expression (Compiler_Obj);  --  Precision (digits)
            --  TODO: Create decimal type node

         when Struct_Token | Union_Token =>
            --  Struct or union type: type struct { ... } Foo;
            Lexer.Get_Next_Token (Compiler_Obj);
            Expect_Token (Compiler_Obj, Left_Curly_Brace_Token);

            --  Parse field declarations: (<type-id> ["*"] <field-id> ["[" expr "]"]* ["=" expr] ";")+
            declare
               First_Field : AST_Node_Pointer_Type := null;
               Last_Field  : AST_Node_Pointer_Type := null;
            begin
               loop
                  exit when Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Right_Curly_Brace_Token;

                  declare
                     Field_Node       : AST_Node_Pointer_Type;
                     Field_Type_Id    : Identifier_Pointer_Type;
                     Field_Name_Id    : Identifier_Pointer_Type;
                     Field_Is_Pointer : Boolean := False;
                     Field_Attrs      : AST_Node_Pointer_Type := null;
                  begin
                     --  Parse type identifier (may be keyword like 'bool' or user-defined name)
                     if not Is_Type_Name_Token (Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind) then
                        Log_Compiler_Error (Compiler_Obj, "Expected type identifier in struct/union field");
                        raise Program_Error;
                     end if;
                     Field_Type_Id := Make_Identifier (Compiler_Obj, Type_Identifier);
                     Lexer.Get_Next_Token (Compiler_Obj);

                     --  Check for optional pointer "*"
                     if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Asterisk_Op_Token then
                        Field_Is_Pointer := True;
                        Lexer.Get_Next_Token (Compiler_Obj);
                     end if;

                     --  Parse field identifier
                     if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= Identifier_Token then
                        Log_Compiler_Error (Compiler_Obj, "Expected field identifier");
                        raise Program_Error;
                     end if;
                     Field_Name_Id := Make_Identifier (Compiler_Obj, Variable_Identifier);
                     Lexer.Get_Next_Token (Compiler_Obj);

                     --  Create field node now that we have names
                     Field_Node := new AST_Node_Type (AST_Struct_Field_Node);
                     Field_Node.Field_Type  := Field_Type_Id;
                     Field_Node.Field_Name  := Field_Name_Id;
                     Field_Node.Is_Pointer  := Field_Is_Pointer;

                     --  Parse optional array dimensions "[" expr "]"*
                     while Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind =
                        Left_Square_Parenthesis_Token
                     loop
                        Lexer.Get_Next_Token (Compiler_Obj);
                        Parse_Expression (Compiler_Obj);
                        Expect_Token (Compiler_Obj, Right_Square_Parenthesis_Token);
                        --  TODO: Store array dimension in Field_Node.Array_Dimensions
                     end loop;

                     --  Parse optional field attributes [[offset(...) bit(...)]], [[volatile]], etc.
                     Parse_Field_Attributes (Compiler_Obj, Field_Attrs);
                     Field_Node.Field_Attributes := Field_Attrs;

                     --  Parse optional default value "= <constant-expression>"
                     if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Assignment_Op_Token then
                        Lexer.Get_Next_Token (Compiler_Obj);
                        Parse_Expression (Compiler_Obj);
                        Stack_Pop (Parser_Obj.Operand_Stack_Top, null, Field_Node.Default_Value);
                     end if;

                     Expect_Token (Compiler_Obj, Semicolon_Token);

                     --  Link field into chain
                     if Last_Field = null then
                        First_Field := Field_Node;
                     else
                        Last_Field.Next_Field := Field_Node;
                     end if;
                     Last_Field := Field_Node;
                  end;
               end loop;

               Type_Node.Type_Body := First_Field;
            end;

            Expect_Token (Compiler_Obj, Right_Curly_Brace_Token);

         when Enum_Token =>
            --  Enum type: type enum { ... } Foo;
            Lexer.Get_Next_Token (Compiler_Obj);
            Expect_Token (Compiler_Obj, Left_Curly_Brace_Token);

            --  Parse enum entries: identifier ("=" expr)? ("," identifier ("=" expr)?)*
            loop
               --  Parse enum entry identifier
               if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= Identifier_Token then
                  Log_Compiler_Error (Compiler_Obj, "Expected enum entry identifier");
                  raise Program_Error;
               end if;
               --  TODO: Store enum entry name
               Lexer.Get_Next_Token (Compiler_Obj);

               --  Check for optional "= <constant-expression>"
               if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Assignment_Op_Token then
                  Lexer.Get_Next_Token (Compiler_Obj);
                  Parse_Expression (Compiler_Obj);
                  --  TODO: Store enum entry value expression
               end if;

               --  Check for comma (more entries) or closing brace (end of enum)
               exit when Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= Comma_Token;
               Lexer.Get_Next_Token (Compiler_Obj);  --  Skip comma
            end loop;

            Expect_Token (Compiler_Obj, Right_Curly_Brace_Token);

         when others =>
            Log_Compiler_Error (Compiler_Obj, "Expected type declarator (range, modular, struct, enum, or union)");
            raise Program_Error;
      end case;

      --  Get type name (comes after the type declarator in C-like syntax)
      if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= Identifier_Token then
         Log_Compiler_Error (Compiler_Obj, "Expected type name");
         raise Program_Error;
      end if;
      Type_Node.Type_Name := Make_Identifier (Compiler_Obj, Type_Identifier);
      Lexer.Get_Next_Token (Compiler_Obj);

      --  Parse optional type-level attributes [[at(addr)]]
      declare
         Type_Attributes : AST_Node_Pointer_Type := null;
      begin
         Parse_Type_Attributes (Compiler_Obj, Type_Attributes);
         Type_Node.Type_Attributes := Type_Attributes;
      end;

      Expect_Token (Compiler_Obj, Semicolon_Token);
   end Parse_Type_Declaration;

   procedure Parse_Field_Attributes (Compiler_Obj : in out Compiler_Type;
                                     Attr_List : out AST_Node_Pointer_Type)
   is
      Parser_Obj : Parser_Type renames Compiler_Obj.Parser_Obj;
      Attr_Node : AST_Node_Pointer_Type;
      Last_Attr : AST_Node_Pointer_Type := null;
   begin
      Attr_List := null;

      --  Parse multiple [[...]] attributes
      while Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Left_Double_Square_Parenthesis_Token loop
         Lexer.Get_Next_Token (Compiler_Obj);  --  Skip [[

         --  Create field attribute node
         Attr_Node := new AST_Node_Type (AST_Field_Attribute_Node);

         --  Parse attribute kind
         case Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind is
            when Offset_Token =>
               --  Parse: offset(byte) bit(n) or offset(byte) bits(start..end)
               Attr_Node.Attribute_Kind := Offset_Token;
               Lexer.Get_Next_Token (Compiler_Obj);  --  Skip 'offset'
               Expect_Token (Compiler_Obj, Left_Parenthesis_Token);
               Parse_Expression (Compiler_Obj);
               Stack_Pop (Parser_Obj.Operand_Stack_Top, null, Attr_Node.Byte_Offset);
               Expect_Token (Compiler_Obj, Right_Parenthesis_Token);

               --  Expect bit(...) or bits(...)
               if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Bit_Token then
                  --  Parse: bit(n)
                  Lexer.Get_Next_Token (Compiler_Obj);  --  Skip 'bit'
                  Expect_Token (Compiler_Obj, Left_Parenthesis_Token);
                  Parse_Expression (Compiler_Obj);
                  Stack_Pop (Parser_Obj.Operand_Stack_Top, null, Attr_Node.Bit_Position);
                  Expect_Token (Compiler_Obj, Right_Parenthesis_Token);

               elsif Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Bits_Token then
                  --  Parse: bits(start..end)
                  Lexer.Get_Next_Token (Compiler_Obj);  --  Skip 'bits'
                  Expect_Token (Compiler_Obj, Left_Parenthesis_Token);
                  Parse_Expression (Compiler_Obj);
                  Stack_Pop (Parser_Obj.Operand_Stack_Top, null, Attr_Node.Bit_Start);
                  Expect_Token (Compiler_Obj, Range_Op_Token);
                  Parse_Expression (Compiler_Obj);
                  Stack_Pop (Parser_Obj.Operand_Stack_Top, null, Attr_Node.Bit_End);
                  Expect_Token (Compiler_Obj, Right_Parenthesis_Token);

               else
                  Log_Compiler_Error (Compiler_Obj, "Expected 'bit' or 'bits' after 'offset'");
                  raise Program_Error;
               end if;

            when others =>
               Log_Compiler_Error (Compiler_Obj, "Invalid field attribute (expected 'offset')");
               raise Program_Error;
         end case;

         Expect_Token (Compiler_Obj, Right_Double_Square_Parenthesis_Token);

         --  Link to attribute list
         if Attr_List = null then
            Attr_List := Attr_Node;
         else
            Last_Attr.Next_Attribute := Attr_Node;
         end if;
         Last_Attr := Attr_Node;
      end loop;
   end Parse_Field_Attributes;

   procedure Parse_Type_Attributes (Compiler_Obj : in out Compiler_Type;
                                    Attr_List : out AST_Node_Pointer_Type)
   is
      Parser_Obj : Parser_Type renames Compiler_Obj.Parser_Obj;
      Attr_Node : AST_Node_Pointer_Type;
      Last_Attr : AST_Node_Pointer_Type := null;
   begin
      Attr_List := null;

      --  Parse multiple [[...]] attributes
      while Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Left_Double_Square_Parenthesis_Token loop
         Lexer.Get_Next_Token (Compiler_Obj);  --  Skip [[

         --  Create type attribute node (reuse AST_Field_Attribute_Node for type attributes)
         Attr_Node := new AST_Node_Type (AST_Field_Attribute_Node);

         --  Parse attribute kind
         case Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind is
            when At_Token =>
               --  Parse: [[at(address)]]
               Attr_Node.Attribute_Kind := At_Token;
               Lexer.Get_Next_Token (Compiler_Obj);  --  Skip 'at'
               Expect_Token (Compiler_Obj, Left_Parenthesis_Token);
               Parse_Expression (Compiler_Obj);
               Stack_Pop (Parser_Obj.Operand_Stack_Top, null, Attr_Node.Byte_Offset);
               Expect_Token (Compiler_Obj, Right_Parenthesis_Token);

            when others =>
               Log_Compiler_Error (Compiler_Obj, "Invalid type attribute (expected 'at')");
               raise Program_Error;
         end case;

         Expect_Token (Compiler_Obj, Right_Double_Square_Parenthesis_Token);

         --  Link to attribute list
         if Attr_List = null then
            Attr_List := Attr_Node;
         else
            Last_Attr.Next_Attribute := Attr_Node;
         end if;
         Last_Attr := Attr_Node;
      end loop;
   end Parse_Type_Attributes;

   procedure Parse_Variable_Attributes (Compiler_Obj : in out Compiler_Type;
                                        Attr_List : out AST_Node_Pointer_Type)
   is
      Parser_Obj : Parser_Type renames Compiler_Obj.Parser_Obj;
      Attr_Node : AST_Node_Pointer_Type;
      Last_Attr : AST_Node_Pointer_Type := null;
   begin
      Attr_List := null;

      --  Parse multiple [[...]] attributes
      while Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Left_Double_Square_Parenthesis_Token loop
         Lexer.Get_Next_Token (Compiler_Obj);  --  Skip [[

         --  Create variable attribute node (reuse AST_Field_Attribute_Node for variable attributes)
         Attr_Node := new AST_Node_Type (AST_Field_Attribute_Node);

         --  Parse attribute kind
         case Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind is
            when At_Token =>
               --  Parse: [[at(address)]]
               Attr_Node.Attribute_Kind := At_Token;
               Lexer.Get_Next_Token (Compiler_Obj);  --  Skip 'at'
               Expect_Token (Compiler_Obj, Left_Parenthesis_Token);
               Parse_Expression (Compiler_Obj);
               Stack_Pop (Parser_Obj.Operand_Stack_Top, null, Attr_Node.Byte_Offset);
               Expect_Token (Compiler_Obj, Right_Parenthesis_Token);

            when others =>
               Log_Compiler_Error (Compiler_Obj, "Invalid variable attribute (expected 'at')");
               raise Program_Error;
         end case;

         Expect_Token (Compiler_Obj, Right_Double_Square_Parenthesis_Token);

         --  Link to attribute list
         if Attr_List = null then
            Attr_List := Attr_Node;
         else
            Last_Attr.Next_Attribute := Attr_Node;
         end if;
         Last_Attr := Attr_Node;
      end loop;
   end Parse_Variable_Attributes;

   procedure Parse_Contract_Attribute (Compiler_Obj : in out Compiler_Type;
                                       Contract_Type : out Token_Kind_Type;
                                       Contract_Node : out AST_Node_Pointer_Type)
   is
      Parser_Obj : Parser_Type renames Compiler_Obj.Parser_Obj;
      Current_Token_Obj : Token_Type renames
         Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index);
   begin
      Contract_Node := null;
      Contract_Type := Invalid_Token;

      --  Expect [[ to start contract attribute
      if Current_Token_Obj.Kind /= Left_Double_Square_Parenthesis_Token then
         return;  --  No contract attribute
      end if;
      Lexer.Get_Next_Token (Compiler_Obj);  --  Skip [[

      --  Expect contract type: pre, post, or global
      case Current_Token_Obj.Kind is
         when Pre_Token | Post_Token =>
            Contract_Type := Current_Token_Obj.Kind;
            Lexer.Get_Next_Token (Compiler_Obj);  --  Skip pre/post
            Expect_Token (Compiler_Obj, Left_Parenthesis_Token);
            Parse_Expression (Compiler_Obj);
            --  TODO: Pop expression from stack and store in Contract_Node
            Expect_Token (Compiler_Obj, Right_Parenthesis_Token);

         when Global_Token =>
            Contract_Type := Global_Token;
            Lexer.Get_Next_Token (Compiler_Obj);  --  Skip global
            Expect_Token (Compiler_Obj, Left_Parenthesis_Token);

            --  Parse global clauses: reads => (...), writes => (...)
            while Current_Token_Obj.Kind = Reads_Token or else
                  Current_Token_Obj.Kind = Writes_Token
            loop
               declare
                  Global_Node : constant AST_Node_Pointer_Type :=
                     new AST_Node_Type (AST_Global_Contract_Node);
               begin
                  Global_Node.Is_Reads := (Current_Token_Obj.Kind = Reads_Token);
                  Lexer.Get_Next_Token (Compiler_Obj);  --  Skip reads/writes

                  Expect_Token (Compiler_Obj, Arrow_Op_Token);  --  =>
                  Expect_Token (Compiler_Obj, Left_Parenthesis_Token);

                  --  Parse list of identifiers: (var1, var2, ...)
                  loop
                     if Current_Token_Obj.Kind /= Identifier_Token then
                        Log_Compiler_Error (Compiler_Obj,
                           Current_Token_Obj,
                           "Expected variable identifier in global clause");
                        raise Program_Error;
                     end if;
                     --  TODO: Create identifier and link to Global_Node.First_Global_Variable
                     Lexer.Get_Next_Token (Compiler_Obj);

                     exit when Current_Token_Obj.Kind /= Comma_Token;
                     Lexer.Get_Next_Token (Compiler_Obj);  --  Skip comma
                  end loop;

                  Expect_Token (Compiler_Obj, Right_Parenthesis_Token);

                  --  Link global node to contract list
                  if Contract_Node = null then
                     Contract_Node := Global_Node;
                  else
                     --  Find end of list and append
                     declare
                        Last_Node : AST_Node_Pointer_Type := Contract_Node;
                     begin
                        while Last_Node.Next_Sibling /= null loop
                           Last_Node := Last_Node.Next_Sibling;
                        end loop;
                        Last_Node.Next_Sibling := Global_Node;
                     end;
                  end if;

                  --  Check for comma (more clauses) or closing paren
                  exit when Current_Token_Obj.Kind /= Comma_Token;
                  Lexer.Get_Next_Token (Compiler_Obj);  --  Skip comma
               end;
            end loop;

            Expect_Token (Compiler_Obj, Right_Parenthesis_Token);

         when others =>
            Log_Compiler_Error (Compiler_Obj,
               Current_Token_Obj,
               "Expected contract type (pre, post, or global) in [[...]] attribute");
            raise Program_Error;
      end case;

      --  Expect ]] to close contract attribute
      Expect_Token (Compiler_Obj, Right_Double_Square_Parenthesis_Token);
   end Parse_Contract_Attribute;

   procedure Parse_Subtype_Declaration (Compiler_Obj : in out Compiler_Type;
                                        Subtype_Node : out AST_Node_Pointer_Type) is
      Parser_Obj : Parser_Type renames Compiler_Obj.Parser_Obj;
   begin
      Subtype_Node := new AST_Node_Type (AST_Type_Declaration_Node);
      Lexer.Get_Next_Token (Compiler_Obj);  --  Skip 'subtype'

      --  Parse base type identifier
      if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= Identifier_Token then
         Log_Compiler_Error (Compiler_Obj, "Expected base type identifier");
         raise Program_Error;
      end if;
      --  TODO: Store base type name
      Lexer.Get_Next_Token (Compiler_Obj);

      --  Expect 'range' keyword
      if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= Range_Token then
         Log_Compiler_Error (Compiler_Obj, "Expected 'range' keyword in subtype declaration");
         raise Program_Error;
      end if;
      Lexer.Get_Next_Token (Compiler_Obj);

      --  Parse range bounds
      Parse_Expression (Compiler_Obj);
      Expect_Token (Compiler_Obj, Range_Op_Token);
      Parse_Expression (Compiler_Obj);
      --  TODO: Create subtype range node

      --  Get subtype name
      if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= Identifier_Token then
         Log_Compiler_Error (Compiler_Obj, "Expected subtype name");
         raise Program_Error;
      end if;
      --  TODO: Store subtype name
      Lexer.Get_Next_Token (Compiler_Obj);

      Expect_Token (Compiler_Obj, Semicolon_Token);
   end Parse_Subtype_Declaration;

   procedure Parse_Declaration (Compiler_Obj : in out Compiler_Type;
                               Declaration_Node : out AST_Node_Pointer_Type) is
      Parser_Obj : Parser_Type renames Compiler_Obj.Parser_Obj;
   begin
      Declaration_Node := null;

      case Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind is
         when Type_Token =>
            Parse_Type_Declaration (Compiler_Obj, Declaration_Node);

         when Subtype_Token =>
            Parse_Subtype_Declaration (Compiler_Obj, Declaration_Node);

         when Const_Token =>
            --  Parse constant declaration
            --  Syntax: const <type> <name> "=" <expr> ";"
            declare
               Var_Node    : AST_Node_Pointer_Type;
               Var_Type_Id : Identifier_Pointer_Type;
               Var_Name_Id : Identifier_Pointer_Type;
            begin
               Lexer.Get_Next_Token (Compiler_Obj);  --  Skip 'const'

               --  Parse type identifier (may be keyword like 'bool' or user-defined name)
               if not Is_Type_Name_Token (Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind) then
                  Log_Compiler_Error (Compiler_Obj, "Expected type identifier after 'const'");
                  raise Program_Error;
               end if;
               Var_Type_Id := Make_Identifier (Compiler_Obj, Type_Identifier);
               Lexer.Get_Next_Token (Compiler_Obj);

               --  Parse constant name
               if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= Identifier_Token then
                  Log_Compiler_Error (Compiler_Obj, "Expected constant name");
                  raise Program_Error;
               end if;
               Var_Name_Id := Make_Identifier (Compiler_Obj, Constant_Identifier);
               Lexer.Get_Next_Token (Compiler_Obj);

               --  Constants require an initializer
               if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= Assignment_Op_Token then
                  Log_Compiler_Error (Compiler_Obj, "Expected '=' in constant declaration");
                  raise Program_Error;
               end if;
               Lexer.Get_Next_Token (Compiler_Obj);
               Parse_Expression (Compiler_Obj);

               --  Create const variable declaration node
               Var_Node := new AST_Node_Type (AST_Variable_Declaration_Node);
               Var_Node.Var_Is_Const := True;
               Var_Node.Var_Is_Volatile := False;
               Var_Node.Var_Is_Pointer := False;
               Var_Node.Variable_Type := Var_Type_Id;
               Var_Node.Variable_Name := Var_Name_Id;
               Stack_Pop (Parser_Obj.Operand_Stack_Top, null, Var_Node.Var_Init_Value);

               Expect_Token (Compiler_Obj, Semicolon_Token);
               Declaration_Node := Var_Node;
            end;

         when Volatile_Token =>
            --  Parse volatile variable declaration
            --  Syntax: volatile <type> ["*"] <name> [[[at(addr)]]] ["=" <init>] ";"
            declare
               Var_Node    : AST_Node_Pointer_Type;
               Var_Type_Id : Identifier_Pointer_Type;
               Var_Name_Id : Identifier_Pointer_Type;
               Is_Pointer  : Boolean := False;
            begin
               Lexer.Get_Next_Token (Compiler_Obj);  --  Skip 'volatile'

               --  Parse type identifier (may be keyword like 'bool' or user-defined name)
               if not Is_Type_Name_Token (Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind) then
                  Log_Compiler_Error (Compiler_Obj, "Expected type identifier after 'volatile'");
                  raise Program_Error;
               end if;
               Var_Type_Id := Make_Identifier (Compiler_Obj, Type_Identifier);
               Lexer.Get_Next_Token (Compiler_Obj);

               --  Check for pointer "*"
               if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Asterisk_Op_Token then
                  Is_Pointer := True;
                  Lexer.Get_Next_Token (Compiler_Obj);
               end if;

               --  Parse variable name
               if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= Identifier_Token then
                  Log_Compiler_Error (Compiler_Obj, "Expected variable name");
                  raise Program_Error;
               end if;
               Var_Name_Id := Make_Identifier (Compiler_Obj, Variable_Identifier);
               Lexer.Get_Next_Token (Compiler_Obj);

               --  Create variable declaration node
               Var_Node := new AST_Node_Type (AST_Variable_Declaration_Node);
               Var_Node.Var_Is_Pointer := Is_Pointer;
               Var_Node.Var_Is_Const := False;
               Var_Node.Var_Is_Volatile := True;
               Var_Node.Variable_Type := Var_Type_Id;
               Var_Node.Variable_Name := Var_Name_Id;

               --  Parse optional [[at(address)]] attribute
               if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind =
                  Left_Double_Square_Parenthesis_Token
               then
                  Parse_Variable_Attributes (Compiler_Obj, Var_Node.Variable_Attributes);
               end if;

               --  Parse optional initialization "= <expression>"
               if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Assignment_Op_Token then
                  Lexer.Get_Next_Token (Compiler_Obj);
                  Parse_Expression (Compiler_Obj);
                  Stack_Pop (Parser_Obj.Operand_Stack_Top, null, Var_Node.Var_Init_Value);
               end if;

               Expect_Token (Compiler_Obj, Semicolon_Token);

               Declaration_Node := Var_Node;
            end;

         when Foreign_Token =>
            --  TODO: Parse foreign declaration
            Lexer.Get_Next_Token (Compiler_Obj);
            Log_Message ("Parsing foreign declaration (not yet implemented)");

         when Identifier_Token | Bool_Token | Char_Token =>
            --  Parse variable or function declaration
            --  Syntax: <type> ["*"] <name> [[[at(addr)]]] ["=" <init>] ";"
            --      or: <type> <name> "(" ... ")" - function
            declare
               Var_Node    : AST_Node_Pointer_Type;
               Var_Type_Id : Identifier_Pointer_Type;
               Var_Name_Id : Identifier_Pointer_Type;
               Is_Pointer  : Boolean := False;
            begin
               --  Parse type identifier
               Var_Type_Id := Make_Identifier (Compiler_Obj, Type_Identifier);
               Lexer.Get_Next_Token (Compiler_Obj);

               --  Check for pointer "*"
               if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Asterisk_Op_Token then
                  Is_Pointer := True;
                  Lexer.Get_Next_Token (Compiler_Obj);
               end if;

               --  If we see '(' here, the "type" we just parsed was actually a function name
               --  whose return type was already consumed (e.g. void was skipped separately).
               --  Skip the entire function body and return.
               if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Left_Parenthesis_Token then
                  Log_Message ("Skipping function declaration (not yet implemented)");
                  while Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /=
                        Left_Curly_Brace_Token and then
                        Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /=
                        End_Of_File_Token
                  loop
                     Lexer.Get_Next_Token (Compiler_Obj);
                  end loop;
                  if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Left_Curly_Brace_Token then
                     declare
                        Depth : Natural := 1;
                     begin
                        loop
                           Lexer.Get_Next_Token (Compiler_Obj);
                           exit when Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind =
                                     End_Of_File_Token;
                           if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind =
                              Left_Curly_Brace_Token
                           then
                              Depth := Depth + 1;
                           elsif Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind =
                                 Right_Curly_Brace_Token
                           then
                              Depth := Depth - 1;
                              exit when Depth = 0;
                           end if;
                        end loop;
                        Lexer.Get_Next_Token (Compiler_Obj);  --  Consume closing '}'
                     end;
                  end if;
                  return;
               end if;

               --  Parse variable/function name
               if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= Identifier_Token then
                  Log_Compiler_Error (Compiler_Obj, "Expected variable or function name");
                  raise Program_Error;
               end if;
               Var_Name_Id := Make_Identifier (Compiler_Obj, Variable_Identifier);
               Lexer.Get_Next_Token (Compiler_Obj);

               --  Check if this is a function (has opening parenthesis after the name)
               if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Left_Parenthesis_Token then
                  --  This is a function declaration (return_type name(...) {...})
                  Log_Message ("Skipping non-void function declaration (not yet implemented)");
                  while Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /=
                        Left_Curly_Brace_Token and then
                        Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /=
                        End_Of_File_Token
                  loop
                     Lexer.Get_Next_Token (Compiler_Obj);
                  end loop;
                  if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Left_Curly_Brace_Token then
                     declare
                        Depth : Natural := 1;
                     begin
                        loop
                           Lexer.Get_Next_Token (Compiler_Obj);
                           exit when Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind =
                                     End_Of_File_Token;
                           if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind =
                              Left_Curly_Brace_Token
                           then
                              Depth := Depth + 1;
                           elsif Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind =
                                 Right_Curly_Brace_Token
                           then
                              Depth := Depth - 1;
                              exit when Depth = 0;
                           end if;
                        end loop;
                        Lexer.Get_Next_Token (Compiler_Obj);  --  Consume closing '}'
                     end;
                  end if;
                  return;
               end if;

               --  Create variable declaration node
               Var_Node := new AST_Node_Type (AST_Variable_Declaration_Node);
               Var_Node.Var_Is_Pointer := Is_Pointer;
               Var_Node.Var_Is_Const := False;
               Var_Node.Var_Is_Volatile := False;
               Var_Node.Variable_Type := Var_Type_Id;
               Var_Node.Variable_Name := Var_Name_Id;

               --  Parse optional array dimensions "[" expr "]"*
               while Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind =
                  Left_Square_Parenthesis_Token
               loop
                  Lexer.Get_Next_Token (Compiler_Obj);
                  Parse_Expression (Compiler_Obj);
                  Expect_Token (Compiler_Obj, Right_Square_Parenthesis_Token);
                  --  TODO: Store array dimension in Var_Node.Array_Dimensions
               end loop;

               --  Parse optional [[at(address)]] attribute
               if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind =
                  Left_Double_Square_Parenthesis_Token
               then
                  Parse_Variable_Attributes (Compiler_Obj, Var_Node.Variable_Attributes);
               end if;

               --  Parse optional initialization "= <expression>"
               if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Assignment_Op_Token then
                  Lexer.Get_Next_Token (Compiler_Obj);
                  Parse_Expression (Compiler_Obj);
                  Stack_Pop (Parser_Obj.Operand_Stack_Top, null, Var_Node.Var_Init_Value);
               end if;

               Expect_Token (Compiler_Obj, Semicolon_Token);

               Declaration_Node := Var_Node;
            end;

         when Void_Token =>
            --  Void function declaration — skip until end of function body
            --  TODO: Parse function declaration fully
            Log_Message ("Skipping void function declaration (not yet implemented)");
            --  Skip past parameter list, optional annotations, and function body
            while Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /=
                  Left_Curly_Brace_Token and then
                  Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /=
                  End_Of_File_Token
            loop
               Lexer.Get_Next_Token (Compiler_Obj);
            end loop;
            --  Skip the balanced { ... } function body
            if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Left_Curly_Brace_Token then
               declare
                  Depth : Natural := 1;
               begin
                  loop
                     Lexer.Get_Next_Token (Compiler_Obj);
                     exit when Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind =
                               End_Of_File_Token;
                     if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind =
                        Left_Curly_Brace_Token
                     then
                        Depth := Depth + 1;
                     elsif Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind =
                           Right_Curly_Brace_Token
                     then
                        Depth := Depth - 1;
                        exit when Depth = 0;
                     end if;
                  end loop;
                  Lexer.Get_Next_Token (Compiler_Obj);  --  Consume closing '}'
               end;
            end if;

         when others =>
            Log_Compiler_Error (Compiler_Obj, "Expected declaration");
            raise Program_Error;
      end case;
   end Parse_Declaration;

   procedure Parse_File (Compiler_Obj : in out Compiler_Type) is
      Parser_Obj : Parser_Type renames Compiler_Obj.Parser_Obj;
      Compilation_Unit_Node : AST_Node_Pointer_Type;
   begin
      --  Create compilation unit AST node
      Compilation_Unit_Node := new AST_Node_Type (AST_Compilation_Unit_Node);
      Parser_Obj.AST_Root := Compilation_Unit_Node;

      --  Expect "module <name> {"
      if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= Module_Token then
         Log_Compiler_Error (Compiler_Obj, "Expected 'module' keyword at start of file");
         raise Program_Error;
      end if;
      Lexer.Get_Next_Token (Compiler_Obj);

      --  Parse module name
      if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= Identifier_Token then
         Log_Compiler_Error (Compiler_Obj, "Expected module name");
         raise Program_Error;
      end if;
      --  TODO: Store module name
      Lexer.Get_Next_Token (Compiler_Obj);

      --  TODO: Handle dotted names for child modules (module parent.child {)

      Expect_Token (Compiler_Obj, Left_Curly_Brace_Token);

      --  Parse import declarations
      while Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Import_Token loop
         Lexer.Get_Next_Token (Compiler_Obj);  --  Skip 'import'
         --  TODO: Parse import statement
         Log_Message ("Parsing import (not yet fully implemented)");
         --  Skip to semicolon
         while Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= Semicolon_Token and then
               Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= End_Of_File_Token loop
            Lexer.Get_Next_Token (Compiler_Obj);
         end loop;
         if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Semicolon_Token then
            Lexer.Get_Next_Token (Compiler_Obj);
         end if;
      end loop;

      --  Parse public declarations
      while Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= Private_Token and then
            Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= Right_Curly_Brace_Token and then
            Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= End_Of_File_Token loop
         declare
            Decl_Node : AST_Node_Pointer_Type;
         begin
            Parse_Declaration (Compiler_Obj, Decl_Node);
            if Decl_Node /= null then
               --  Add to compilation unit's declaration list
               if Compilation_Unit_Node.First_Public_Declaration = null then
                  Compilation_Unit_Node.First_Public_Declaration := Decl_Node;
               else
                  --  Link to end of list
                  declare
                     Last_Decl : AST_Node_Pointer_Type := Compilation_Unit_Node.First_Public_Declaration;
                  begin
                     while Last_Decl.Next_Sibling /= null loop
                        Last_Decl := Last_Decl.Next_Sibling;
                     end loop;
                     Last_Decl.Next_Sibling := Decl_Node;
                  end;
               end if;
            end if;
         end;
      end loop;

      --  Parse private section if present
      if Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind = Private_Token then
         Lexer.Get_Next_Token (Compiler_Obj);  --  Skip 'private'

         --  Parse private declarations
         while Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= Right_Curly_Brace_Token and then
               Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind /= End_Of_File_Token loop
            declare
               Decl_Node : AST_Node_Pointer_Type;
            begin
               Parse_Declaration (Compiler_Obj, Decl_Node);
               if Decl_Node /= null then
                  --  Add to compilation unit's private declaration list
                  if Compilation_Unit_Node.First_Private_Declaration = null then
                     Compilation_Unit_Node.First_Private_Declaration := Decl_Node;
                  else
                     --  Link to end of list
                     declare
                        Last_Decl : AST_Node_Pointer_Type := Compilation_Unit_Node.First_Private_Declaration;
                     begin
                        while Last_Decl.Next_Sibling /= null loop
                           Last_Decl := Last_Decl.Next_Sibling;
                        end loop;
                        Last_Decl.Next_Sibling := Decl_Node;
                     end;
                  end if;
               end if;
            end;
         end loop;
      end if;

      --  Expect closing brace for module
      Expect_Token (Compiler_Obj, Right_Curly_Brace_Token);

      Log_Message ("Parsing complete");
   end Parse_File;

   procedure Stack_Push (Stack_Top : in out AST_Node_Pointer_Type;
                         Node : AST_Node_Pointer_Type)
   is
   begin
      Node.Next_In_Stack := Stack_Top;
      Stack_Top := Node;
   end Stack_Push;

   procedure Stack_Pop (Stack_Top : in out AST_Node_Pointer_Type;
                        Stack_Bottom : AST_Node_Pointer_Type;
                        Node : out AST_Node_Pointer_Type)
   is
      pragma Unreferenced (Stack_Bottom);
   begin
      Node := Stack_Top;
      Stack_Top := Node.Next_In_Stack;
      Node.Next_In_Stack := null;
   end Stack_Pop;

   procedure Log_Unexpected_Token_Error (Compiler_Obj : Compiler_Type) is
      Parser_Obj : Parser_Type renames Compiler_Obj.Parser_Obj;
      Current_Token_Obj : Token_Type renames Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index);
      Previous_Token_Obj : Token_Type renames Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index - 1);
   begin
      Log_Compiler_Error (Compiler_Obj,
         "Unexpected token: '" &
         Current_Token_Obj.String_Buffer (1 .. Current_Token_Obj.String_Length) &
         "' (previous token: '" &
         Previous_Token_Obj.String_Buffer (1 .. Previous_Token_Obj.String_Length) & "')");
   end Log_Unexpected_Token_Error;

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

      function Operand_Stack_Is_Empty return Boolean is
         (Parser_Obj.Operand_Stack_Top = null);

      procedure Operator_Stack_Push (Node : AST_Node_Pointer_Type) is
      begin
         Stack_Push (Parser_Obj.Operator_Stack_Top, Node);
      end Operator_Stack_Push;

      procedure Operator_Stack_Pop (Node : out AST_Node_Pointer_Type) is
      begin
         Stack_Pop (Parser_Obj.Operator_Stack_Top, Operator_Stack_Bottom, Node);
      end Operator_Stack_Pop;

      function Operator_Stack_Is_Empty return Boolean is
         (Parser_Obj.Operator_Stack_Top = Operator_Stack_Bottom);

      function Get_Operator_Stack_Top return AST_Node_Pointer_Type is
         (Parser_Obj.Operator_Stack_Top);

      procedure Reduce_Operator is
         Operator_Node : AST_Node_Pointer_Type;
         Right_Operand_Node : AST_Node_Pointer_Type;
         Left_Operand_Node : AST_Node_Pointer_Type;
      begin
         if Operator_Stack_Is_Empty then
            return;
         end if;

         Operator_Stack_Pop (Operator_Node);

         if Operand_Stack_Is_Empty then
            Log_Unexpected_Token_Error (Compiler_Obj);
            raise Program_Error;
         end if;

         Operand_Stack_Pop (Right_Operand_Node);

         if Operator_Node.Node_Kind = AST_Binary_Expression_Node then
            if Operand_Stack_Is_Empty then
               Log_Unexpected_Token_Error (Compiler_Obj);
               raise Program_Error;
            end if;
            Operand_Stack_Pop (Left_Operand_Node);
            Operator_Node.Left_Operand := Left_Operand_Node;
            Operator_Node.Right_Operand := Right_Operand_Node;
         elsif Operator_Node.Node_Kind = AST_Unary_Expression_Node then
            Operator_Node.Operand := Right_Operand_Node;
         elsif Operator_Node.Node_Kind = AST_Functional_If_Else_Node then
            --  Right operand is the false branch
            Operator_Node.Functional_If_False_Operand := Right_Operand_Node;
            --  Pop the true branch
            if Operand_Stack_Is_Empty then
               Log_Unexpected_Token_Error (Compiler_Obj);
               raise Program_Error;
            end if;
            Operand_Stack_Pop (Operator_Node.Functional_If_True_Operand);
            --  Pop the condition
            if Operand_Stack_Is_Empty then
               Log_Unexpected_Token_Error (Compiler_Obj);
               raise Program_Error;
            end if;
            Operand_Stack_Pop (Operator_Node.Functional_If_Condition);
         end if;

         Operand_Stack_Push (Operator_Node);
      end Reduce_Operator;

      procedure Handle_Operator (Op : AST_Operator_Type; Node_Kind : AST_Node_Kind_Type) is
         Operator_Node : constant AST_Node_Pointer_Type := new AST_Node_Type (Node_Kind);
      begin
         if Node_Kind = AST_Unary_Expression_Node then
            Operator_Node.Unary_Operator := Op;
         else
            Operator_Node.Binary_Operator := Op;
         end if;

         --  Reduce operators with higher or equal precedence
         --  (For right-associative operators, only reduce higher precedence)
         while not Operator_Stack_Is_Empty loop
            declare
               Top_Node : constant AST_Node_Pointer_Type := Get_Operator_Stack_Top;
               Top_Op : constant AST_Operator_Type :=
                  (if Top_Node.Node_Kind = AST_Unary_Expression_Node then
                      Top_Node.Unary_Operator
                   elsif Top_Node.Node_Kind = AST_Binary_Expression_Node then
                      Top_Node.Binary_Operator
                   else AST_Invalid_Op);
               Is_Right_Associative : constant Boolean :=
                  Op = AST_Arithmetic_Power_Op or else Op = AST_Functional_If_Else_Op;
            begin
               exit when Top_Op = AST_Invalid_Op;
               --  For right-associative operators, exit when precedence is >=
               --  For left-associative operators, exit when precedence is >
               if Is_Right_Associative then
                  exit when Operator_Precedence_Table (Op) >= Operator_Precedence_Table (Top_Op);
               else
                  exit when Operator_Precedence_Table (Op) > Operator_Precedence_Table (Top_Op);
               end if;
               Reduce_Operator;
            end;
         end loop;

         Operator_Stack_Push (Operator_Node);
      end Handle_Operator;

      procedure Create_Literal_Node (Literal_Kind : AST_Literal_Kind_Type) is
         Literal_Node : constant AST_Node_Pointer_Type := new AST_Node_Type (AST_Literal_Node);
         Current_Token_Obj : Token_Type renames Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index);
      begin
         Literal_Node.Literal_Kind := Literal_Kind;
         Literal_Node.Literal_Value := new String'(
            Current_Token_Obj.String_Buffer (
               1 .. Current_Token_Obj.String_Length));
         Operand_Stack_Push (Literal_Node);
      end Create_Literal_Node;

   begin
      loop
         declare
            Current_Token_Obj : Token_Type renames Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index);
            Previous_Token_Obj : Token_Type renames Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index - 1);
            Is_Unary_Context : constant Boolean :=
               Previous_Token_Obj.Is_Operator or else
               Previous_Token_Obj.Kind = Left_Parenthesis_Token or else
               Previous_Token_Obj.Kind = Comma_Token or else
               Previous_Token_Obj.Kind = Semicolon_Token or else
               Previous_Token_Obj.Kind = Range_Token;
         begin
            case Current_Token_Obj.Kind is
               when Identifier_Token =>
                  --  If we already have an operand and previous token wasn't an operator/punctuation,
                  --  this identifier is not part of the expression
                  if not Is_Unary_Context and then Parser_Obj.Operand_Stack_Top /= null then
                     --  End of expression - leave identifier for caller
                     while not Operator_Stack_Is_Empty loop
                        Reduce_Operator;
                     end loop;
                     return;
                  end if;

                  --  Check for built-in constants
                  if Current_Token_Obj.String_Length = 13 and then
                     Current_Token_Obj.String_Buffer (1 .. 13) = "machine_width"
                  then
                     --  Replace machine_width with its integer value
                     declare
                        Literal_Node : constant AST_Node_Pointer_Type :=
                           new AST_Node_Type (AST_Literal_Node);
                        Width_Str : constant String := Compiler_Obj.Machine_Width'Image;
                        --  'Image includes leading space for positive numbers, so skip it
                        Width_Str_Trimmed : constant String := Width_Str (2 .. Width_Str'Last);
                     begin
                        Literal_Node.Literal_Kind := AST_Decimal_Integer_Literal_Kind;
                        Literal_Node.Literal_Value := new String'(Width_Str_Trimmed);
                        Operand_Stack_Push (Literal_Node);
                     end;
                  else
                     --  TODO: Lookup identifier in symbol table
                     --  For now, create a variable reference node
                     declare
                        Var_Ref_Node : constant AST_Node_Pointer_Type :=
                           new AST_Node_Type (AST_Variable_Reference_Node);
                     begin
                        Operand_Stack_Push (Var_Ref_Node);
                     end;
                  end if;

               when Decimal_Integer_Literal_Token =>
                  Create_Literal_Node (AST_Decimal_Integer_Literal_Kind);

               when Hexadecimal_Integer_Literal_Token =>
                  Create_Literal_Node (AST_Hexadecimal_Integer_Literal_Kind);

               when Binary_Integer_Literal_Token =>
                  Create_Literal_Node (AST_Binary_Integer_Literal_Kind);

               when Floating_Point_Literal_Token =>
                  Create_Literal_Node (AST_Float_Literal_Kind);

               when Character_Literal_Token =>
                  Create_Literal_Node (AST_Character_Literal_Kind);

               when String_Literal_Token =>
                  Create_Literal_Node (AST_String_Literal_Kind);

               when True_Token | False_Token =>
                  Create_Literal_Node (AST_Boolean_Literal_Kind);

               when Minus_Op_Token =>
                  if Is_Unary_Context then
                     Handle_Operator (AST_Arithmetic_Negate_Sign_Op, AST_Unary_Expression_Node);
                  else
                     Handle_Operator (AST_Arithmetic_Subtract_Op, AST_Binary_Expression_Node);
                  end if;

               when Plus_Op_Token =>
                  if not Is_Unary_Context then
                     Handle_Operator (AST_Arithmetic_Add_Op, AST_Binary_Expression_Node);
                  end if;
                  --  Unary plus is a no-op, just skip it

               when Asterisk_Op_Token =>
                  if Is_Unary_Context then
                     Handle_Operator (AST_Pointer_Dereference_Op, AST_Unary_Expression_Node);
                  else
                     Handle_Operator (AST_Arithmetic_Multiply_Op, AST_Binary_Expression_Node);
                  end if;

               when Ampersand_Op_Token =>
                  if Is_Unary_Context then
                     Handle_Operator (AST_Address_Of_Op, AST_Unary_Expression_Node);
                  else
                     Handle_Operator (AST_Bitwise_And_Op, AST_Binary_Expression_Node);
                  end if;

               when Logical_Not_Op_Token =>
                  Handle_Operator (AST_Logical_Not_Op, AST_Unary_Expression_Node);

               when Bitwise_Not_Op_Token =>
                  Handle_Operator (AST_Bitwise_Not_Op, AST_Unary_Expression_Node);

               when Sizeof_Token =>
                  --  sizeof operator: sizeof(type) or sizeof(expression)
                  Lexer.Get_Next_Token (Compiler_Obj);  --  Skip 'sizeof'
                  Expect_Token (Compiler_Obj, Left_Parenthesis_Token);
                  --  Parse the argument (could be type or expression)
                  --  For now, just parse as expression
                  --  TODO: Distinguish between type identifiers and variable identifiers
                  Parse_Expression (Compiler_Obj);
                  Expect_Token (Compiler_Obj, Right_Parenthesis_Token);
                  --  Create sizeof operator node
                  Handle_Operator (AST_Sizeof_Op, AST_Unary_Expression_Node);

               when Divide_Op_Token =>
                  Handle_Operator (AST_Arithmetic_Divide_Op, AST_Binary_Expression_Node);

               when Modulo_Op_Token =>
                  Handle_Operator (AST_Arithmetic_Modulo_Op, AST_Binary_Expression_Node);

               when Power_Op_Token =>
                  Handle_Operator (AST_Arithmetic_Power_Op, AST_Binary_Expression_Node);

               when Bitwise_Or_Op_Token =>
                  Handle_Operator (AST_Bitwise_Or_Op, AST_Binary_Expression_Node);

               when Bitwise_Xor_Op_Token =>
                  Handle_Operator (AST_Bitwise_Xor_Op, AST_Binary_Expression_Node);

               when Bitwise_Left_Shift_Op_Token =>
                  Handle_Operator (AST_Bitwise_Left_Shift_Op, AST_Binary_Expression_Node);

               when Bitwise_Right_Shift_Op_Token =>
                  Handle_Operator (AST_Bitwise_Right_Shift_Op, AST_Binary_Expression_Node);

               when Logical_And_Op_Token =>
                  Handle_Operator (AST_Logical_And_Op, AST_Binary_Expression_Node);

               when Logical_Or_Op_Token =>
                  Handle_Operator (AST_Logical_Or_Op, AST_Binary_Expression_Node);

               when Equality_Op_Token =>
                  Handle_Operator (AST_Arithmetic_Equal_To_Op, AST_Binary_Expression_Node);

               when Less_Than_Op_Token =>
                  Handle_Operator (AST_Arithmetic_Less_Than_Op, AST_Binary_Expression_Node);

               when Greater_Than_Op_Token =>
                  Handle_Operator (AST_Arithmetic_Greater_Than_Op, AST_Binary_Expression_Node);

               when Less_Than_Or_Equal_Op_Token =>
                  Handle_Operator (AST_Arithmetic_Less_Than_Or_Equal_To_Op, AST_Binary_Expression_Node);

               when Greater_Than_Or_Equal_Op_Token =>
                  Handle_Operator (AST_Arithmetic_Greater_Than_Or_Equal_To_Op, AST_Binary_Expression_Node);

               --  Note: Range_Op_Token (..) is not an expression operator
               --  It's only used as a delimiter in type declarations

               when In_Token =>
                  Handle_Operator (AST_Arithmetic_In_Range_Op, AST_Binary_Expression_Node);

               when Dot_Op_Token =>
                  Handle_Operator (AST_Struct_Field_Op, AST_Binary_Expression_Node);

               when Arrow_Op_Token =>
                  Handle_Operator (AST_Struct_Pointer_Field_Dereference_Op, AST_Binary_Expression_Node);

               when Apostrophe_Op_Token =>
                  --  Identifier attribute operator: identifier'Attribute
                  --  The identifier is already on the operand stack
                  Lexer.Get_Next_Token (Compiler_Obj);  --  Skip '

                  --  Expect attribute name (first, last, length, range, size)
                  declare
                     Attr_Op : AST_Operator_Type;
                  begin
                     case Current_Token_Obj.Kind is
                        when First_Token =>
                           Attr_Op := AST_First_Attribute_Op;
                        when Last_Token =>
                           Attr_Op := AST_Last_Attribute_Op;
                        when Length_Token =>
                           Attr_Op := AST_Length_Attribute_Op;
                        when Range_Token =>
                           Attr_Op := AST_Range_Attribute_Op;
                        when Size_Token =>
                           Attr_Op := AST_Size_Attribute_Op;
                        when others =>
                           Log_Compiler_Error (Compiler_Obj,
                              Current_Token_Obj,
                              "Expected attribute name (first, last, length, range, size) after apostrophe");
                           raise Program_Error;
                     end case;

                     Handle_Operator (Attr_Op, AST_Unary_Expression_Node);
                  end;

               when Question_Mark_Token =>
                  --  Ternary operator - reduce previous expression
                  while not Operator_Stack_Is_Empty loop
                     Reduce_Operator;
                  end loop;
                  declare
                     Ternary_Node : constant AST_Node_Pointer_Type := new AST_Node_Type (AST_Functional_If_Else_Node);
                  begin
                     Operator_Stack_Push (Ternary_Node);
                  end;

               when Colon_Token =>
                  --  Part of ternary operator - reduce until we find the ? operator
                  while not Operator_Stack_Is_Empty loop
                     declare
                        Top_Node : constant AST_Node_Pointer_Type := Get_Operator_Stack_Top;
                     begin
                        exit when Top_Node.Node_Kind = AST_Functional_If_Else_Node;
                        Reduce_Operator;
                     end;
                  end loop;

               when Left_Parenthesis_Token =>
                  --  Recursive call to parse subexpression
                  Lexer.Get_Next_Token (Compiler_Obj);  --  Skip '('
                  Parse_Expression (Compiler_Obj, Parser_Obj.Operator_Stack_Top);
                  --  Parse_Expression returns when it sees ')', so skip it
                  pragma Assert (Parser_Obj.Latest_Tokens (Parser_Obj.Current_Token_Index).Kind =
                                Right_Parenthesis_Token);

               when Right_Parenthesis_Token |
                    Semicolon_Token |
                    Comma_Token =>
                  --  End of expression
                  while not Operator_Stack_Is_Empty loop
                     Reduce_Operator;
                  end loop;
                  return;

               when others =>
                  --  Not an expression token, end of expression
                  while not Operator_Stack_Is_Empty loop
                     Reduce_Operator;
                  end loop;
                  return;
            end case;

            Lexer.Get_Next_Token (Compiler_Obj);
         end;
      end loop;
   end Parse_Expression;

end STC_Compiler.Parser;