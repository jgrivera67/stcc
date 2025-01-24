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
      Assert_Token,
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
      Invalid_Token,
      Invariant_Token,
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
      Sizeof_Token,
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
      While_Token
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

   type Token_Pointer_Type is access Token_Type;

   type Identifier_Kind_Type is (
      Compilation_unit_Identifier,
      Constant_Identifier,
      Function_Identifier,
      Invalid_Identifier,
      Type_Identifier,
      Variable_Identifier
   );

   type Identifier_Type is record
      Kind : Identifier_Kind_Type := Invalid_Identifier;
      String_Value_Ptr : String_Pointer_Type := null;
   end record;

   type Identifier_Pointer_Type is access Identifier_Type;

   package String_To_Identifier_Ordered_Maps is new
     Ada.Containers.Indefinite_Ordered_Maps
       (Key_Type        => String,
        Element_Type    => Identifier_Pointer_Type);

   type Lexer_Type is limited record
      --  Next character to process from the input file
      Lookahead_Char : Character := ASCII.NUL;
      --  Current line number from the input file
      Line_Number : Positive := 1;
      --  Current column number within the current line
      Column_Number : Natural := 0;
   end record;

   type Parser_Type is limited record
      Last_Token : Token_Type;
   end record;

   type Compiler_Type is limited record
      Initialized : Boolean := False;
      File_Name : String_Pointer_Type := null;
      File_Obj : Ada.Text_IO.File_Type;
      Lexer_Obj  : Lexer_Type;
      Parser_Obj : Parser_Type;
      Symbol_Table : String_To_Identifier_Ordered_Maps.Map;
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
