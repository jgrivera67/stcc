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
   procedure Compile_File (File_Name : String; Machine_Width : Positive := 32);

private
   type String_Pointer_Type is access String;

   type Token_Kind_Type is (
      Ampersand_Op_Token,
      Apostrophe_Op_Token,
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
      Bit_Token,
      Bits_Token,
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
      Decimal_Token,
      Decimal_Integer_Literal_Token,
      Default_Token,
      Delta_Token,
      Digits_Token,
      Divide_Op_Token,
      Do_Token,
      Dot_Op_Token,
      Else_Token,
      End_Of_File_Token,
      Enum_Token,
      Equality_Op_Token,
      False_Token,
      First_Token,
      Fixed_Token,
      Float_Token,
      Floating_Point_Literal_Token,
      For_Token,
      Foreign_Token,
      Global_Token,
      Goto_Token,
      Greater_Than_Op_Token,
      Greater_Than_Or_Equal_Op_Token,
      Hexadecimal_Integer_Literal_Token,
      Identifier_Token,
      If_Token,
      Import_Token,
      In_Token,
      Inout_Token,
      Lambda_Token,
      Last_Token,
      Loop_Invariant_Token,
      Loop_Variant_Token,
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
      Modular_Token,
      Module_Token,
      Modulo_Op_Token,
      Offset_Token,
      Out_Token,
      Packed_Token,
      Plus_Op_Token,
      Power_Op_Token,
      Post_Token,
      Pre_Token,
      Private_Token,
      Question_Mark_Token,
      Range_Token,
      Range_Op_Token,
      Reads_Token,
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
      Type_Invariant_Token,
      Union_Token,
      Unit_Token,
      Void_Token,
      Volatile_Token,
      While_Token,
      Writes_Token,

      Invalid_Token
   );

   Lexical_Unit_String_Max_Size : constant := 128;

   subtype Token_String_Cursor_Type is Positive range 1 .. Lexical_Unit_String_Max_Size + 1;
   subtype Token_String_Length_Type is Natural range 0 .. Lexical_Unit_String_Max_Size;

   type Token_Type is limited record
      Kind : Token_Kind_Type := Invalid_Token;
      Is_Operator : Boolean := False;
      --  Buffer to gather next token string from the input file
      String_Buffer : String (1 .. Lexical_Unit_String_Max_Size) := [others => ASCII.NUL];
      String_Length : Token_String_Length_Type := 0;
      --  Location where this token was found
      Line_Number : Positive := 1;
      Column_Number : Positive := 1;
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
      Name : String_Pointer_Type := null;  --  Identifier name string
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
      AST_Field_Attribute_Node,
      AST_For_Node,
      AST_Function_Call_Node,
      AST_Function_Declaration_Node,
      AST_Functional_If_Else_Node,
      AST_Global_Contract_Node,
      AST_If_Node,
      AST_Literal_Node,
      AST_Statement_Block_Node,
      AST_Struct_Field_Node,
      AST_Switch_Node,
      AST_Switch_Case_Node,
      AST_Switch_Default_Node,
      AST_Type_Cast_Node,
      AST_Type_Declaration_Node,
      AST_Unary_Expression_Node,
      AST_Variable_Declaration_Node,
      AST_Variable_Reference_Node,
      AST_While_Node
   );

   type AST_Operator_Type is (
      AST_Arithmetic_Add_Op,
      AST_Arithmetic_Different_From_Op,
      AST_Arithmetic_Equal_To_Op,
      AST_Arithmetic_Greater_Than_Op,
      AST_Arithmetic_Greater_Than_Or_Equal_To_Op,
      AST_Arithmetic_Less_Than_Op,
      AST_Arithmetic_Less_Than_Or_Equal_To_Op,
      AST_Arithmetic_Divide_Op,
      AST_Arithmetic_In_Range_Op,
      AST_Arithmetic_Modulo_Op,
      AST_Arithmetic_Multiply_Op,
      AST_Arithmetic_Negate_Sign_Op,
      AST_Arithmetic_Power_Op,
      AST_Arithmetic_Range_Op,
      AST_Arithmetic_Subtract_Op,
      AST_Address_Of_Op,
      AST_Array_Declaration_Op,
      AST_Array_Subscript_Op,
      AST_Bitwise_And_Op,
      AST_Bitwise_Left_Shift_Op,
      AST_Bitwise_Not_Op,
      AST_Bitwise_Or_Op,
      AST_Bitwise_Right_Shift_Op,
      AST_Bitwise_Xor_Op,
      AST_Functional_If_Else_Op,
      AST_Function_Call_Op,
      AST_Logical_And_Op,
      AST_Logical_Not_Op,
      AST_Logical_Or_Op,
      AST_Pointer_Declaration_Op,
      AST_Pointer_Dereference_Op,
      AST_Sizeof_Op,
      AST_Struct_Field_Op,
      AST_Struct_Pointer_Field_Dereference_Op,
      AST_Type_Cast_Op,
      --  Attribute operators (applied with ' operator)
      AST_First_Attribute_Op,
      AST_Last_Attribute_Op,
      AST_Range_Attribute_Op,
      AST_Size_Attribute_Op,

      AST_Invalid_Op
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
      --  Pointer to next node in operand or operator stack during expression parsing
      Next_In_Stack :  AST_Node_Pointer_Type := null;
      case Node_Kind is
         when AST_Binary_Expression_Node =>
            Binary_Operator : AST_Operator_Type := AST_Invalid_Op;
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
            Function_Reference : AST_Node_Pointer_Type := null;
            First_Argument : AST_Node_Pointer_Type := null;
         when AST_Function_Declaration_Node =>
            Function_Name : Identifier_Pointer_Type := null;
            Return_Type : AST_Node_Pointer_Type := null;
            First_Parameter : AST_Node_Pointer_Type := null;
            Function_Body : AST_Node_Pointer_Type := null;
            --  Contract clauses
            Precondition : AST_Node_Pointer_Type := null;
            Postcondition : AST_Node_Pointer_Type := null;
            First_Global_Clause : AST_Node_Pointer_Type := null;  --  Linked list of Global_Contract_Node
         when AST_Functional_If_Else_Node =>
            Functional_If_Condition : AST_Node_Pointer_Type := null;
            Functional_If_True_Operand : AST_Node_Pointer_Type := null;
            Functional_If_False_Operand : AST_Node_Pointer_Type := null;
         when AST_Global_Contract_Node =>
            Is_Reads : Boolean := False;  --  True for reads, False for writes
            First_Global_Variable : Identifier_Pointer_Type := null;  --  Linked via Identifier.Next
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
         when AST_Type_Cast_Node =>
            Type_Reference : Identifier_Pointer_Type := null;
            Operand_Expression : AST_Node_Pointer_Type := null;
         when AST_Field_Attribute_Node =>
            Attribute_Kind : Token_Kind_Type := Offset_Token;  -- offset, bit, bits, volatile
            Byte_Offset : AST_Node_Pointer_Type := null;       -- For offset(N)
            Bit_Position : AST_Node_Pointer_Type := null;      -- For bit(N)
            Bit_Start : AST_Node_Pointer_Type := null;         -- For bits(M..N)
            Bit_End : AST_Node_Pointer_Type := null;           -- For bits(M..N)
            Next_Attribute : AST_Node_Pointer_Type := null;     -- For multiple attributes
         when AST_Struct_Field_Node =>
            Field_Type : Identifier_Pointer_Type := null;
            Field_Name : Identifier_Pointer_Type := null;
            Is_Pointer : Boolean := False;
            Array_Dimensions : AST_Node_Pointer_Type := null;
            Default_Value : AST_Node_Pointer_Type := null;
            Field_Attributes : AST_Node_Pointer_Type := null;  -- Points to AST_Field_Attribute_Node chain
            Next_Field : AST_Node_Pointer_Type := null;
         when AST_Type_Declaration_Node =>
            Type_Name : Identifier_Pointer_Type := null;
            Type_Body : AST_Node_Pointer_Type := null;
            Type_Attributes : AST_Node_Pointer_Type := null;   -- For [[packed]], [[at(addr)]], etc.
         when AST_Unary_Expression_Node =>
            Unary_Operator : AST_Operator_Type := AST_Invalid_Op;
            Operand : AST_Node_Pointer_Type := null;
         when AST_Variable_Declaration_Node =>
            Variable_Name : Identifier_Pointer_Type := null;
            Variable_Type : Identifier_Pointer_Type := null;
            Var_Is_Pointer : Boolean := False;
            Var_Is_Const : Boolean := False;
            Var_Is_Volatile : Boolean := False;
            Var_Init_Value : AST_Node_Pointer_Type := null;
            Variable_Attributes : AST_Node_Pointer_Type := null;  -- For [[at(address)]], etc.
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

   Num_Tokens_Remembered : constant := 2;

   type Tokens_Array_Index_Type is mod Num_Tokens_Remembered;

   type Tokens_Array_Type is array (Tokens_Array_Index_Type) of Token_Type;

   type Parser_Type is limited record
      Latest_Tokens : Tokens_Array_Type;
      Next_Token_Index : Tokens_Array_Index_Type := 0;
      Current_Token_Index : Tokens_Array_Index_Type := Tokens_Array_Index_Type'Last;
      AST_Root : AST_Node_Pointer_Type := null;
      Operand_Stack_Top : AST_Node_Pointer_Type := null;
      Operator_Stack_Top : AST_Node_Pointer_Type := null;
   end record
      with Dynamic_Predicate => Parser_Type.Next_Token_Index = Parser_Type.Current_Token_Index + 1;

   --------------------------------
   --  Compiler State Variables  --
   --------------------------------

   type Compiler_Type is limited record
      Initialized : Boolean := False;
      File_Name : String_Pointer_Type := null;
      File_Obj : Ada.Text_IO.File_Type;
      Lexer_Obj  : Lexer_Type;
      Parser_Obj : Parser_Type;
      Machine_Width : Positive := 32;
   end record;

   procedure Init_Compiler (Compiler_Obj : out Compiler_Type; File_Name : String; Machine_Width : Positive := 32)
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

   procedure Log_Compiler_Error (Compiler_Obj : Compiler_Type;
                                 Token : Token_Type;
                                 Message : String)
      with Pre => Compiler_Obj.Initialized;

   function Get_Currrent_Token_Kind (Compiler_Obj : Compiler_Type) return Token_Kind_Type is
      (Compiler_Obj.Parser_Obj.Latest_Tokens (Compiler_Obj.Parser_Obj.Current_Token_Index).Kind)
      with Ghost;

end STC_Compiler;
