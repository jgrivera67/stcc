--
--  Copyright (c) 2025, German Rivera
--
--
--  SPDX-License-Identifier: Apache-2.0
--

--
--  @summary Strong-Typed C compiler
--
private with Ada.Text_IO;
private with Ada.Containers.Indefinite_Ordered_Maps;

package STC_Compiler is
   procedure Compile_File (File_Name : String);

private
   type String_Pointer_Type is access String;

   type Token_Kind_Type is (
      Ampersand_Op_Token,
      Arrow_Op_Token,
      As_Token,
      Assert_Token,
      At_Token,
      Assignment_Op_Token,
      Assignment_Bitwise_And_Op_Token,
      Assignment_Bitwise_Or_Op_Token,
      Assignment_Bitwise_Xor_Op_Token,
      Assignment_Bitwise_Left_Shift_Op_Token,
      Assignment_Bitwise_Right_Shift_Op_Token,
      Assignment_Divide_Op_Token,
      Assignment_Minus_Op_Token,
      Assignment_Modulo_Op_Token,
      Assignment_Multiply_Op_Token,
      Assignment_Plus_Op_Token,
      Asterisk_Op_Token,
      Auto_Token,
      Binary_Integer_Literal_Token,
      Bitwise_Not_Op_Token,
      Bitwise_Or_Op_Token,
      Bitwise_Xor_Op_Token,
      Bitwise_Left_Shift_Op_Token,
      Bitwise_Right_Shift_Op_Token,
      Bool_Token,
      Break_Token,
      Case_Token,
      Char_Token,
      Character_Literal_Token,
      Colon_Token,
      Comma_Token,
      Compile_If_Token,
      Const_Token,
      Continue_Token,
      Convention_Token,
      Decimal_Integer_Literal_Token,
      Default_Token,
      Divide_Op_Token,
      Do_Token,
      Dot_Op_Token,
      Else_Token,
      End_Of_File_Token,
      Enum_Token,
      Equality_Op_Token,
      False_Token,
      Floating_Point_Literal_Token,
      For_Token,
      Foreign_Token,
      Goto_Token,
      Greater_Than_Op_Token,
      Greater_Than_Or_Equal_Op_Token,
      Hexadecimal_Integer_Literal_Token,
      Identifier_Token,
      If_Token,
      Import_Token,
      In_Token,
      Inout_Token,
      Invariant_Token,
      Lambda_Token,
      Left_Curly_Brace_Token,
      Left_Parenthesis_Token,
      Left_Square_Parenthesis_Token,
      Left_Double_Square_Parenthesis_Token,
      Less_Than_Op_Token,
      Less_Than_Or_Equal_Op_Token,
      Line_Comment_Token,
      Logical_And_Op_Token,
      Logical_Not_Op_Token,
      Logical_Or_Op_Token,
      Machine_Width_Token,
      Minus_Op_Token,
      Mod_Token,
      Modulo_Op_Token,
      Out_Token,
      Packed_Token,
      Plus_Op_Token,
      Post_Token,
      Pre_Token,
      Private_Token,
      Question_Mark_Token,
      Range_Token,
      Range_Op_Token,
      Renames_Token,
      Return_Token,
      Right_Curly_Brace_Token,
      Right_Parenthesis_Token,
      Right_Square_Parenthesis_Token,
      Right_Double_Square_Parenthesis_Token,
      Semicolon_Token,
      Size_Token,
      Sizeof_Token,
      Static_Token,
      String_Literal_Token,
      Struct_Token,
      Subtype_Token,
      Switch_Token,
      True_Token,
      Type_Token,
      Union_Token,
      Unit_Token,
      Void_Token,
      Volatile_Token,
      While_Token,
      Invalid_Token
   );

   Lexical_Unit_String_Max_Size : constant := 128;

   subtype Token_String_Cursor_Type is Positive range 1 .. Lexical_Unit_String_Max_Size + 1;
   subtype Token_String_Length_Type is Natural range 0 .. Lexical_Unit_String_Max_Size;

   type Token_Type is record
      Kind : Token_Kind_Type := Invalid_Token;
      Is_Operator : Boolean := False;
      --  Buffer to gather next token string from the input file
      String_Buffer : String (1 .. Lexical_Unit_String_Max_Size) := [others => ASCII.NUL];
      String_Length : Token_String_Length_Type := 0;
   end record;

   -----------------------------
   --  Lexer State Variables  --
   -----------------------------

   type Lexer_Type is limited record
      --  Next character to process from the input file
      Lookahead_Char : Character := ASCII.NUL;
      --  Current line number from the input file
      Line_Number : Positive := 1;
      --  Current column number within the current line
      Column_Number : Natural := 0;
   end record;

   ---------------------------------
   --  Symbol Table Declarations  --
   ---------------------------------

   type AST_Node_Type;
   type AST_Node_Pointer_Type is access AST_Node_Type;

   type Identifier_Kind_Type is (
      Compilation_Unit_Identifier,
      Constant_Identifier,
      Function_Identifier,
      Label_Identifier,
      Type_Identifier,
      Variable_Identifier,
      Invalid_Identifier
   );

   type Identifier_Type is limited record
      Kind : Identifier_Kind_Type := Invalid_Identifier;
      Declaration : AST_Node_Pointer_Type := null;
      Scope : AST_Node_Pointer_Type := null; --  Pointer to Statement_Block_Node if local scope
   end record;

   type Identifier_Pointer_Type is access Identifier_Type;

   package String_To_Identifier_Ordered_Maps is new
     Ada.Containers.Indefinite_Ordered_Maps
       (Key_Type        => String,
        Element_Type    => Identifier_Pointer_Type);

   subtype Symbol_Table_Type is String_To_Identifier_Ordered_Maps.Map;

   ------------------------------------------------
   --  Abstract Syntax Tree (AST)  Declarations  --
   ------------------------------------------------

   type AST_Node_Kind_Type is (
      AST_Binary_Expression_Node,
      AST_Compilation_Unit_Node,
      AST_Do_While_Node,
      AST_For_Node,
      AST_Function_Call_Node,
      AST_Function_Declaration_Node,
      AST_Functional_If_Node,
      AST_If_Node,
      AST_Literal_Node,
      AST_Statement_Block_Node,
      AST_Switch_Node,
      AST_Switch_Case_Node,
      AST_Switch_Default_Node,
      AST_Type_Declaration_Node,
      AST_Unary_Expression_Node,
      AST_Variable_Declaration_Node,
      AST_Variable_Reference_Node,
      AST_While_Node
   );

   type AST_Binary_Operator_Type is (
      AST_Add_Op,
      AST_And_Op,
      AST_Assignment_Op,
      AST_Divide_Op,
      AST_Multiply_Op,
      AST_Or_Op,
      AST_Modulo_Op,
      AST_Range_Op,
      AST_Struct_Field_Op,
      AST_Struct_Field_Dereference_Op,
      AST_Subtract_Op,
      AST_Xor_Op,
      AST_Invalid_Binary_Op
   );

   type AST_Unary_Operator_Type is (
      AST_Bitwise_Not_Op,
      AST_Logical_Not_Op,
      AST_Negate_Op,
      AST_Pointer_Op,
      AST_Invalid_Unary_Op
   );

   type AST_Literal_Kind_Type is (
      AST_Binary_Integer_Literal_Kind,
      AST_Boolean_Literal_Kind,
      AST_Character_Literal_Kind,
      AST_Decimal_Integer_Literal_Kind,
      AST_Float_Literal_Kind,
      AST_Hexadecimal_Integer_Literal_Kind,
      AST_String_Literal_Kind,
      AST_Invalid_Literal_Kind
   );

   type AST_Node_Type (Node_Kind : AST_Node_Kind_Type) is limited record
      Parent : AST_Node_Pointer_Type := null;
      Next_Sibling : AST_Node_Pointer_Type := null;
      case Node_Kind is
         when AST_Binary_Expression_Node =>
            Binary_Operator : AST_Binary_Operator_Type := AST_Invalid_Binary_Op;
            Left_Operand : AST_Node_Pointer_Type := null;
            Right_Operand : AST_Node_Pointer_Type := null;
         when AST_Compilation_Unit_Node =>
            Unit_Name_First_Identifier : Identifier_Pointer_Type := null; --  Compilation unit name???
            Alias_Name : Identifier_Pointer_Type := null;
            First_Public_Import : AST_Node_Pointer_Type := null;
            First_Public_Declaration : AST_Node_Pointer_Type := null;
            First_Private_Import : AST_Node_Pointer_Type := null;
            First_Private_Declaration : AST_Node_Pointer_Type := null;
            Global_Symbol_Table : Symbol_Table_Type;
         when AST_Do_While_Node =>
            Do_While_Body : AST_Node_Pointer_Type := null;
            Do_While_Condition : AST_Node_Pointer_Type := null;
         when AST_For_Node =>
            For_First_Step : AST_Node_Pointer_Type := null;
            For_Condition : AST_Node_Pointer_Type := null;
            For_Next_Step : AST_Node_Pointer_Type := null;
            For_Body : AST_Node_Pointer_Type := null;
         when AST_Function_Call_Node =>
            Invocation_Name : Identifier_Pointer_Type := null;
            First_Argument : AST_Node_Pointer_Type := null;
         when AST_Function_Declaration_Node =>
            Function_Name : Identifier_Pointer_Type := null;
            Return_Type : AST_Node_Pointer_Type := null;
            First_Parameter : AST_Node_Pointer_Type := null;
            Function_Body : AST_Node_Pointer_Type := null;
         when AST_Functional_If_Node =>
            Functional_If_Condition : AST_Node_Pointer_Type := null;
            Functional_If_True_Operand : AST_Node_Pointer_Type := null;
            Functional_If_False_Operand : AST_Node_Pointer_Type := null;
         when AST_If_Node =>
            If_Condition : AST_Node_Pointer_Type := null;
            Then_Body : AST_Node_Pointer_Type := null;
            Else_Body : AST_Node_Pointer_Type := null;
         when AST_Literal_Node =>
            Literal_Kind : AST_Literal_Kind_Type := AST_Invalid_Literal_Kind;
            Literal_Value : String_Pointer_Type := null;
         when AST_Statement_Block_Node =>
            First_Statement : AST_Node_Pointer_Type := null;
            Local_Symbol_Table : Symbol_Table_Type;
         when AST_Switch_Node =>
            Switch_Selector_Expression : AST_Node_Pointer_Type := null;
            Switch_First_Case : AST_Node_Pointer_Type := null;
            Switch_Default_Case : AST_Node_Pointer_Type := null;
         when AST_Switch_Case_Node =>
            Switch_Case_Value : AST_Node_Pointer_Type := null;
            Switch_Case_First_Statement : AST_Node_Pointer_Type := null;
         when AST_Switch_Default_Node =>
            Switch_Default_First_Statement : AST_Node_Pointer_Type := null;
         when AST_Type_Declaration_Node =>
            Type_Name : Identifier_Pointer_Type := null;
         when AST_Unary_Expression_Node =>
            Unary_Operator : AST_Unary_Operator_Type := AST_Invalid_Unary_Op;
            Operand : AST_Node_Pointer_Type := null;
         when AST_Variable_Declaration_Node =>
            Variable_Name : Identifier_Pointer_Type := null;
         when AST_Variable_Reference_Node =>
            Variable : AST_Node_Pointer_Type := null;
         when AST_While_Node =>
            While_Condition : AST_Node_Pointer_Type := null;
            While_Body : AST_Node_Pointer_Type := null;
      end case;
   end record;

   ------------------------------
   --  Parser State Variables  --
   ------------------------------

   type Parser_Type is limited record
      Last_Token : Token_Type;
      AST_Root : AST_Node_Pointer_Type := null;
   end record;

   --------------------------------
   --  Compiler State Variables  --
   --------------------------------

   type Compiler_Type is limited record
      Initialized : Boolean := False;
      File_Name : String_Pointer_Type := null;
      File_Obj : Ada.Text_IO.File_Type;
      Lexer_Obj  : Lexer_Type;
      Parser_Obj : Parser_Type;
   end record;

   procedure Init_Compiler (Compiler_Obj : out Compiler_Type; File_Name : String)
      with Pre => not Compiler_Obj.Initialized,
           Post => Compiler_Obj.Initialized and then
                   Ada.Text_IO.Is_Open (Compiler_Obj.File_Obj);

   procedure Cleanup_Compiler (Compiler_Obj : in out Compiler_Type)
      with Pre => Compiler_Obj.Initialized and then
                  Ada.Text_IO.Is_Open (Compiler_Obj.File_Obj),
           Post => not Compiler_Obj.Initialized and then
                   not Ada.Text_IO.Is_Open (Compiler_Obj.File_Obj);

   procedure Log_Message (Message : String);

   procedure Log_Compiler_Error (Compiler_Obj : Compiler_Type; Message : String)
      with Pre => Compiler_Obj.Initialized;

end STC_Compiler;
