--
--  Copyright (c) 2025, German Rivera
--
--
--  SPDX-License-Identifier: Apache-2.0
--
with Ada.Characters.Handling;

package body STC_Compiler.Lexer with
   SPARK_Mode => Off
is
   package String_To_Token_Kind_Package is new
     Ada.Containers.Indefinite_Ordered_Maps
       (Key_Type        => String,
        Element_Type    => Token_Kind_Type);

   --  Table mapping reserved-word strings to reserved-word tokens
   Reserved_Words_Table : String_To_Token_Kind_Package.Map;

   procedure Get_Next_Char (Compiler_Obj : in out Compiler_Type) with
      Pre => Ada.Text_IO.Is_Open (Compiler_Obj.File_Obj)
   is
      Lexer_Obj : Lexer_Type renames Compiler_Obj.Lexer_Obj;
   begin
      if Lexer_Obj.Has_Pending_Char then
         Lexer_Obj.Lookahead_Char := Lexer_Obj.Pending_Char;
         Lexer_Obj.Has_Pending_Char := False;
         Lexer_Obj.Column_Number := @ + 1;
      else
         Ada.Text_IO.Get (Compiler_Obj.File_Obj, Lexer_Obj.Lookahead_Char);
         pragma Assert (Lexer_Obj.Lookahead_Char /= ASCII.NUL);
         Lexer_Obj.Column_Number := @ + 1;
      end if;
   exception
      when Ada.Text_IO.End_Error =>
         Lexer_Obj.Lookahead_Char := ASCII.NUL;
         --  Ensure Column_Number is valid (Positive) even after EOF;
         --  it may be 0 if a newline reset it just before EOF was detected.
         if Lexer_Obj.Column_Number = 0 then
            Lexer_Obj.Column_Number := 1;
         end if;
   end Get_Next_Char;

   procedure Init_Lexer (Compiler_Obj : in out Compiler_Type) is
   begin
      Get_Next_Char (Compiler_Obj);
   end Init_Lexer;

   function Is_Separator_Char (C : Character) return Boolean is
      (C = ' ' or else C = ASCII.HT or else C = ASCII.LF or else C = ASCII.CR);

   function Is_Word_Char (C : Character) return Boolean is
      (Ada.Characters.Handling.Is_Alphanumeric (C) or else C = '_');

   function Is_Hexadecimal_Digit (C : Character) return Boolean is
      (C in '0' .. '9' or else C in 'A' .. 'F' or else C in 'a' .. 'f');

   procedure Skip_Separators (Compiler_Obj : in out Compiler_Type) is
      Lexer_Obj : Lexer_Type renames Compiler_Obj.Lexer_Obj;
   begin
      --  Skip spaces and control characters:
      while Is_Separator_Char (Lexer_Obj.Lookahead_Char) loop
         if Lexer_Obj.Lookahead_Char = ASCII.LF then
            Lexer_Obj.Line_Number := @ + 1;
            Lexer_Obj.Column_Number := 0;  -- Reset column; Get_Next_Char will increment to 1
         end if;

         Get_Next_Char (Compiler_Obj);
      end loop;
   end Skip_Separators;

   procedure Scan_Identifier_Or_Reserved_Word (Compiler_Obj : in out Compiler_Type;
                                               Token_Obj : out Token_Type) with
      Pre => Ada.Characters.Handling.Is_Letter (Compiler_Obj.Lexer_Obj.Lookahead_Char)
   is
      Lexer_Obj : Lexer_Type renames Compiler_Obj.Lexer_Obj;
      Cursor : Token_String_Cursor_Type := 1;
   begin
      Token_Obj.String_Buffer (Cursor) := Lexer_Obj.Lookahead_Char;
      Cursor := @ + 1;
      --  Scan contiguous alphanumeric and '_' characters:
      loop
         Get_Next_Char (Compiler_Obj);
         exit when not Is_Word_Char (Lexer_Obj.Lookahead_Char);
         if Cursor > Token_Obj.String_Buffer'Length then
            Token_Obj.String_Length := Token_Obj.String_Buffer'Length;
            Log_Compiler_Error (Compiler_Obj, "Token is too long: '" & Token_Obj.String_Buffer & "'");
            raise Program_Error;
         end if;

         Token_Obj.String_Buffer (Cursor) := Lexer_Obj.Lookahead_Char;
         Cursor := @ + 1;
      end loop;

      Token_Obj.String_Length := Cursor - 1;
      declare
         Token_String : String renames Token_Obj.String_Buffer (1 .. Token_Obj.String_Length);
      begin
         Token_Obj.Kind := Reserved_Words_Table.Element (Token_String);
      exception
         when Constraint_Error =>
            Token_Obj.Kind := Identifier_Token;
      end;
   end Scan_Identifier_Or_Reserved_Word;

   procedure Scan_Character_Literal (Compiler_Obj : in out Compiler_Type;
                                     Token_Obj : out Token_Type) is
      Lexer_Obj : Lexer_Type renames Compiler_Obj.Lexer_Obj;
   begin
      if not Ada.Characters.Handling.Is_Graphic (Lexer_Obj.Lookahead_Char) then
         Log_Compiler_Error (Compiler_Obj, "Expected printable character: '" & Lexer_Obj.Lookahead_Char & "'");
         raise Program_Error;
      end if;

      Token_Obj.String_Buffer (1) := Lexer_Obj.Lookahead_Char;
      Get_Next_Char (Compiler_Obj);
      if Lexer_Obj.Lookahead_Char /= ''' then
         Log_Compiler_Error (Compiler_Obj, "Expected ': '" & Lexer_Obj.Lookahead_Char & "'");
         raise Program_Error;
      end if;

      Token_Obj.String_Length := 1;
      Token_Obj.Kind := Character_Literal_Token;
      Get_Next_Char (Compiler_Obj);
   end Scan_Character_Literal;

   procedure Scan_String_Literal (Compiler_Obj : in out Compiler_Type;
                             Token_Obj : out Token_Type) is
      Lexer_Obj : Lexer_Type renames Compiler_Obj.Lexer_Obj;
      Cursor : Token_String_Cursor_Type := 1;
   begin
      --  Scan characters up to next '"':
      loop
         exit when Lexer_Obj.Lookahead_Char = '"';
         if Cursor > Token_Obj.String_Buffer'Length then
            Token_Obj.String_Length := Token_Obj.String_Buffer'Length;
            Log_Compiler_Error (Compiler_Obj, "Token is too long: '" & Token_Obj.String_Buffer & "'");
            raise Program_Error;
         end if;

         if not Ada.Characters.Handling.Is_Graphic (Lexer_Obj.Lookahead_Char) then
            Log_Compiler_Error (Compiler_Obj, "Expected printable character: '" & Lexer_Obj.Lookahead_Char & "'");
            raise Program_Error;
         end if;

         Token_Obj.String_Buffer (Cursor) := Lexer_Obj.Lookahead_Char;
         Cursor := @ + 1;
         Get_Next_Char (Compiler_Obj);
      end loop;

      Token_Obj.String_Length := Cursor - 1;
      Token_Obj.Kind := String_Literal_Token;
      Get_Next_Char (Compiler_Obj);
   end Scan_String_Literal;

   procedure Scan_Line_Comment (Compiler_Obj : in out Compiler_Type;
                                Token_Obj : out Token_Type) is
      Lexer_Obj : Lexer_Type renames Compiler_Obj.Lexer_Obj;
   begin
      --  Skip to end of current line
      if not Ada.Text_IO.End_Of_File (Compiler_Obj.File_Obj) then
         Ada.Text_IO.Skip_Line (Compiler_Obj.File_Obj);
         Lexer_Obj.Line_Number := @ + 1;
         Lexer_Obj.Column_Number := 0;

         --  Read first character of next line using Get_Next_Char for consistency
         Get_Next_Char (Compiler_Obj);  -- This will increment column to 1
      end if;

      Token_Obj.String_Length := 0;
      Token_Obj.Kind := Line_Comment_Token;
   end Scan_Line_Comment;

   procedure Scan_Floating_Point_Literal_Fraction_Part (Compiler_Obj : in out Compiler_Type;
                                                        Token_Obj : out Token_Type;
                                                        Initial_Cursor : Token_String_Cursor_Type)
      with Pre => Initial_Cursor >= 3
   is
      Lexer_Obj : Lexer_Type renames Compiler_Obj.Lexer_Obj;
      Cursor : Token_String_Cursor_Type := Initial_Cursor;
   begin
      if Lexer_Obj.Lookahead_Char not in '0' .. '9' then
         Log_Compiler_Error (Compiler_Obj, "Expected decimal digit: '" & Lexer_Obj.Lookahead_Char & "'");
         raise Program_Error;
      end if;

      loop
         if Cursor > Token_Obj.String_Buffer'Length then
            Token_Obj.String_Length := Token_Obj.String_Buffer'Length;
            Log_Compiler_Error (Compiler_Obj, "Token is too long: '" & Token_Obj.String_Buffer & "'");
            raise Program_Error;
         end if;

         Token_Obj.String_Buffer (Cursor) := Lexer_Obj.Lookahead_Char;
         Cursor := @ + 1;
         Get_Next_Char (Compiler_Obj);
         exit when Lexer_Obj.Lookahead_Char not in '0' .. '9';
      end loop;

      Token_Obj.String_Length := Cursor - 1;
      Token_Obj.Kind := Floating_Point_Literal_Token;
   end Scan_Floating_Point_Literal_Fraction_Part;

   procedure Scan_Non_Zero_Decimal_Integer_Or_Floating_Point_Literal (Compiler_Obj : in out Compiler_Type;
                                                                      Token_Obj : out Token_Type) with
      Pre => Compiler_Obj.Lexer_Obj.Lookahead_Char in '1' .. '9'
   is
      Lexer_Obj : Lexer_Type renames Compiler_Obj.Lexer_Obj;
      Cursor : Token_String_Cursor_Type := 1;
      Has_Apostrophe : Boolean := False;
      Has_Underscore : Boolean := False;
   begin
      loop
         if Cursor > Token_Obj.String_Buffer'Length then
            Token_Obj.String_Length := Token_Obj.String_Buffer'Length;
            Log_Compiler_Error (Compiler_Obj, "Token is too long: '" & Token_Obj.String_Buffer & "'");
            raise Program_Error;
         end if;

         if Lexer_Obj.Lookahead_Char = ''' then
            Has_Apostrophe := True;
            if Has_Underscore then
               Log_Compiler_Error (Compiler_Obj, "Mixed digit separators (' and _) not allowed in same literal");
               raise Program_Error;
            end if;
            Token_Obj.String_Buffer (Cursor) := '_';
         elsif Lexer_Obj.Lookahead_Char = '_' then
            Has_Underscore := True;
            if Has_Apostrophe then
               Log_Compiler_Error (Compiler_Obj, "Mixed digit separators (' and _) not allowed in same literal");
               raise Program_Error;
            end if;
            Token_Obj.String_Buffer (Cursor) := '_';
         else
            Token_Obj.String_Buffer (Cursor) := Lexer_Obj.Lookahead_Char;
         end if;

         Cursor := @ + 1;
         Get_Next_Char (Compiler_Obj);
         exit when Lexer_Obj.Lookahead_Char not in '0' .. '9' | ''' | '_';
      end loop;

      if Token_Obj.String_Buffer (Cursor - 1) = '_' then
         Log_Compiler_Error (Compiler_Obj, "Expected decimal digit: '" & Lexer_Obj.Lookahead_Char & "'");
         raise Program_Error;
      end if;

      if Lexer_Obj.Lookahead_Char = '.' then
         --  Peek at the character after '.' to distinguish float (N.digit) from range (N..)
         declare
            Next_Char : Character;
            End_Of_Line : Boolean;
         begin
            if Ada.Text_IO.End_Of_File (Compiler_Obj.File_Obj) then
               Next_Char := ASCII.NUL;
            else
               Ada.Text_IO.Look_Ahead (Compiler_Obj.File_Obj, Next_Char, End_Of_Line);
            end if;

            if Next_Char = '.' then
               --  This is "N.." — return integer, leave Lookahead_Char = '.' for next token
               Token_Obj.String_Length := Cursor - 1;
               Token_Obj.Kind := Decimal_Integer_Literal_Token;
            else
               --  This is a float literal (e.g. 3.14)
               Token_Obj.String_Buffer (Cursor) := '.';
               Get_Next_Char (Compiler_Obj);
               Scan_Floating_Point_Literal_Fraction_Part (Compiler_Obj, Token_Obj, Cursor + 1);
            end if;
         end;
      else
         Token_Obj.String_Length := Cursor - 1;
         Token_Obj.Kind := Decimal_Integer_Literal_Token;
      end if;
   end Scan_Non_Zero_Decimal_Integer_Or_Floating_Point_Literal;

   procedure Scan_Hexadecimal_Integer_Literal (Compiler_Obj : in out Compiler_Type;
                                               Token_Obj : out Token_Type) is
      Lexer_Obj : Lexer_Type renames Compiler_Obj.Lexer_Obj;
      Cursor : Token_String_Cursor_Type := 1;
      Has_Apostrophe : Boolean := False;
      Has_Underscore : Boolean := False;
   begin
      if not Is_Hexadecimal_Digit (Lexer_Obj.Lookahead_Char) then
         Log_Compiler_Error (Compiler_Obj, "Expected hexadecimal digit: '" & Lexer_Obj.Lookahead_Char & "'");
         raise Program_Error;
      end if;

      loop
         if Cursor > Token_Obj.String_Buffer'Length then
            Token_Obj.String_Length := Token_Obj.String_Buffer'Length;
            Log_Compiler_Error (Compiler_Obj, "Token is too long: '" & Token_Obj.String_Buffer & "'");
            raise Program_Error;
         end if;

         if Lexer_Obj.Lookahead_Char = ''' then
            Has_Apostrophe := True;
            if Has_Underscore then
               Log_Compiler_Error (Compiler_Obj, "Mixed digit separators (' and _) not allowed in same literal");
               raise Program_Error;
            end if;
            Token_Obj.String_Buffer (Cursor) := '_';
         elsif Lexer_Obj.Lookahead_Char = '_' then
            Has_Underscore := True;
            if Has_Apostrophe then
               Log_Compiler_Error (Compiler_Obj, "Mixed digit separators (' and _) not allowed in same literal");
               raise Program_Error;
            end if;
            Token_Obj.String_Buffer (Cursor) := '_';
         elsif Is_Hexadecimal_Digit (Lexer_Obj.Lookahead_Char) then
            Token_Obj.String_Buffer (Cursor) := Lexer_Obj.Lookahead_Char;
         end if;

         Cursor := @ + 1;
         Get_Next_Char (Compiler_Obj);
         exit when not (Is_Hexadecimal_Digit (Lexer_Obj.Lookahead_Char) or else
                        Lexer_Obj.Lookahead_Char in ''' | '_');
      end loop;

      if Token_Obj.String_Buffer (Cursor - 1) = '_' then
         Log_Compiler_Error (Compiler_Obj, "Expected hexadecimal digit: '" & Lexer_Obj.Lookahead_Char & "'");
         raise Program_Error;
      end if;

      Token_Obj.String_Length := Cursor - 1;
      Token_Obj.Kind := Hexadecimal_Integer_Literal_Token;
   end Scan_Hexadecimal_Integer_Literal;

   procedure Scan_Binary_Integer_Literal (Compiler_Obj : in out Compiler_Type;
                                          Token_Obj : out Token_Type) is
      Lexer_Obj : Lexer_Type renames Compiler_Obj.Lexer_Obj;
      Cursor : Token_String_Cursor_Type := 1;
      Has_Apostrophe : Boolean := False;
      Has_Underscore : Boolean := False;
   begin
      if Lexer_Obj.Lookahead_Char not in '0' .. '1' then
         Log_Compiler_Error (Compiler_Obj, "Expected binary digit: '" & Lexer_Obj.Lookahead_Char & "'");
         raise Program_Error;
      end if;

      loop
         if Cursor > Token_Obj.String_Buffer'Length then
            Token_Obj.String_Length := Token_Obj.String_Buffer'Length;
            Log_Compiler_Error (Compiler_Obj, "Token is too long: '" & Token_Obj.String_Buffer & "'");
            raise Program_Error;
         end if;

         if Lexer_Obj.Lookahead_Char = ''' then
            Has_Apostrophe := True;
            if Has_Underscore then
               Log_Compiler_Error (Compiler_Obj, "Mixed digit separators (' and _) not allowed in same literal");
               raise Program_Error;
            end if;
            Token_Obj.String_Buffer (Cursor) := '_';
         elsif Lexer_Obj.Lookahead_Char = '_' then
            Has_Underscore := True;
            if Has_Apostrophe then
               Log_Compiler_Error (Compiler_Obj, "Mixed digit separators (' and _) not allowed in same literal");
               raise Program_Error;
            end if;
            Token_Obj.String_Buffer (Cursor) := '_';
         else
            Token_Obj.String_Buffer (Cursor) := Lexer_Obj.Lookahead_Char;
         end if;

         Cursor := @ + 1;
         Get_Next_Char (Compiler_Obj);
         exit when Lexer_Obj.Lookahead_Char not in '0' .. '1' | ''' | '_';
      end loop;

      if Token_Obj.String_Buffer (Cursor - 1) = '_' then
         Log_Compiler_Error (Compiler_Obj, "Expected binary digit: '" & Lexer_Obj.Lookahead_Char & "'");
         raise Program_Error;
      end if;

      Token_Obj.String_Length := Cursor - 1;
      Token_Obj.Kind := Binary_Integer_Literal_Token;
   end Scan_Binary_Integer_Literal;

   procedure Get_Next_Token (Compiler_Obj : in out Compiler_Type) is
      Lexer_Obj : Lexer_Type renames Compiler_Obj.Lexer_Obj;
      Parser_Obj : Parser_Type renames Compiler_Obj.Parser_Obj;
      Token_Obj : Token_Type renames Parser_Obj.Latest_Tokens (Parser_Obj.Next_Token_Index);
   begin
      Token_Obj.Kind := Invalid_Token;
      Token_Obj.Is_Operator := False;
      Skip_Separators (Compiler_Obj);

      --  Capture token location after skipping whitespace/comments
      Token_Obj.Line_Number := Lexer_Obj.Line_Number;
      Token_Obj.Column_Number := Lexer_Obj.Column_Number;

      if Ada.Characters.Handling.Is_Letter (Lexer_Obj.Lookahead_Char) then
         Scan_Identifier_Or_Reserved_Word (Compiler_Obj, Token_Obj);
      else
         case Lexer_Obj.Lookahead_Char is
            when ''' =>
               --  Could be character literal 'x' or apostrophe operator (for attributes)
               --  Look ahead to distinguish
               if not Ada.Text_IO.End_Of_File (Compiler_Obj.File_Obj) then
                  declare
                     Next_Char : Character;
                     End_Of_Line : Boolean;
                     Is_Char_Literal : Boolean := False;
                  begin
                     Ada.Text_IO.Look_Ahead (Compiler_Obj.File_Obj, Next_Char, End_Of_Line);
                     if Ada.Characters.Handling.Is_Letter (Next_Char) then
                        --  Could be 'X' (char literal) or 'identifier (tick attribute).
                        --  Consume the letter, peek one more char to decide.
                        declare
                           Letter       : Character;
                           After_Letter : Character;
                           After_EOL    : Boolean;
                        begin
                           Ada.Text_IO.Get (Compiler_Obj.File_Obj, Letter);
                           Ada.Text_IO.Look_Ahead (Compiler_Obj.File_Obj, After_Letter, After_EOL);
                           --  Put the letter back via Pending_Char for Get_Next_Char
                           Lexer_Obj.Pending_Char    := Letter;
                           Lexer_Obj.Has_Pending_Char := True;
                           --  If the character after the letter is a closing quote, it's 'X'
                           if After_Letter = ''' then
                              Is_Char_Literal := True;
                           end if;
                           --  Otherwise it's a tick attribute ('first, 'last, etc.)
                        end;
                     elsif Ada.Characters.Handling.Is_Graphic (Next_Char) and then Next_Char /= ''' then
                        --  Non-letter graphic char: '!', '0', ' ', etc. — char literal
                        Is_Char_Literal := True;
                     end if;

                     Get_Next_Char (Compiler_Obj);
                     if Is_Char_Literal then
                        Scan_Character_Literal (Compiler_Obj, Token_Obj);
                     else
                        --  Apostrophe operator
                        Token_Obj.String_Buffer (1) := ''';
                        Token_Obj.String_Length := 1;
                        Token_Obj.Kind := Apostrophe_Op_Token;
                        Token_Obj.Is_Operator := True;
                     end if;
                  end;
               else
                  --  End of file after ', treat as operator
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1) := ''';
                  Token_Obj.String_Length := 1;
                  Token_Obj.Kind := Apostrophe_Op_Token;
                  Token_Obj.Is_Operator := True;
               end if;
            when '"' =>
               Get_Next_Char (Compiler_Obj);
               Scan_String_Literal (Compiler_Obj, Token_Obj);
            when '0' =>
               Get_Next_Char (Compiler_Obj);
               if Ada.Characters.Handling.To_Lower (Lexer_Obj.Lookahead_Char) = 'x' then
                  Get_Next_Char (Compiler_Obj);
                  Scan_Hexadecimal_Integer_Literal (Compiler_Obj, Token_Obj);
               elsif Ada.Characters.Handling.To_Lower (Lexer_Obj.Lookahead_Char) = 'b' then
                  Get_Next_Char (Compiler_Obj);
                  Scan_Binary_Integer_Literal (Compiler_Obj, Token_Obj);
               elsif Lexer_Obj.Lookahead_Char = '.' then
                  --  Peek to distinguish 0.N (float) from 0.. (integer + range)
                  declare
                     Next_Char : Character;
                     End_Of_Line : Boolean;
                  begin
                     if Ada.Text_IO.End_Of_File (Compiler_Obj.File_Obj) then
                        Next_Char := ASCII.NUL;
                     else
                        Ada.Text_IO.Look_Ahead (Compiler_Obj.File_Obj, Next_Char, End_Of_Line);
                     end if;

                     if Next_Char = '.' then
                        --  This is "0.." — return 0 as integer, leave Lookahead_Char = '.'
                        Token_Obj.String_Buffer (1) := '0';
                        Token_Obj.String_Length := 1;
                        Token_Obj.Kind := Decimal_Integer_Literal_Token;
                     else
                        Token_Obj.String_Buffer (1 .. 2) := "0.";
                        Get_Next_Char (Compiler_Obj);
                        Scan_Floating_Point_Literal_Fraction_Part (Compiler_Obj, Token_Obj, Initial_Cursor => 3);
                     end if;
                  end;
               elsif Is_Word_Char (Lexer_Obj.Lookahead_Char) then
                  Log_Compiler_Error (Compiler_Obj, "Unexpected character after 0: '" & Lexer_Obj.Lookahead_Char & "'");
                  raise Program_Error;
               else
                  Token_Obj.String_Buffer (1) := '0';
                  Token_Obj.String_Length := 1;
                  Token_Obj.Kind := Decimal_Integer_Literal_Token;
               end if;
            when '1' .. '9' =>
               Scan_Non_Zero_Decimal_Integer_Or_Floating_Point_Literal (Compiler_Obj, Token_Obj);
            when '=' =>
               Get_Next_Char (Compiler_Obj);
               if Lexer_Obj.Lookahead_Char = '=' then
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1 .. 2) := "==";
                  Token_Obj.String_Length := 2;
                  Token_Obj.Kind := Equality_Op_Token;
               else
                  Token_Obj.String_Buffer (1) := '=';
                  Token_Obj.String_Length := 1;
                  Token_Obj.Kind := Assignment_Op_Token;
               end if;
               Token_Obj.Is_Operator := True;
            when '&' =>
               Get_Next_Char (Compiler_Obj);
               if Lexer_Obj.Lookahead_Char = '&' then
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1 .. 2) := "&&";
                  Token_Obj.String_Length := 2;
                  Token_Obj.Kind := Logical_And_Op_Token;
               elsif Lexer_Obj.Lookahead_Char = '=' then
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1 .. 2) := "&=";
                  Token_Obj.String_Length := 2;
                  Token_Obj.Kind := Assignment_Bitwise_And_Op_Token;
               else
                  Token_Obj.String_Buffer (1) := '&';
                  Token_Obj.String_Length := 1;
                  Token_Obj.Kind := Ampersand_Op_Token;
               end if;
               Token_Obj.Is_Operator := True;
            when '|' =>
               Get_Next_Char (Compiler_Obj);
               if Lexer_Obj.Lookahead_Char = '|' then
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1 .. 2) := "||";
                  Token_Obj.String_Length := 2;
                  Token_Obj.Kind := Logical_Or_Op_Token;
               elsif Lexer_Obj.Lookahead_Char = '=' then
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1 .. 2) := "|=";
                  Token_Obj.String_Length := 2;
                  Token_Obj.Kind := Assignment_Bitwise_Or_Op_Token;
               else
                  Token_Obj.String_Buffer (1) := '|';
                  Token_Obj.String_Length := 1;
                  Token_Obj.Kind := Bitwise_Or_Op_Token;
               end if;
               Token_Obj.Is_Operator := True;
            when '<' =>
               Get_Next_Char (Compiler_Obj);
               if Lexer_Obj.Lookahead_Char = '<' then
                  Get_Next_Char (Compiler_Obj);
                  if Lexer_Obj.Lookahead_Char = '=' then
                     Get_Next_Char (Compiler_Obj);
                     Token_Obj.String_Buffer (1 .. 3) := "<<=";
                     Token_Obj.String_Length := 3;
                     Token_Obj.Kind := Assignment_Bitwise_Left_Shift_Op_Token;
                  else
                     Token_Obj.String_Buffer (1 .. 2) := "<<";
                     Token_Obj.String_Length := 2;
                     Token_Obj.Kind := Bitwise_Left_Shift_Op_Token;
                  end if;
               elsif Lexer_Obj.Lookahead_Char = '=' then
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1 .. 2) := "<=";
                  Token_Obj.String_Length := 2;
                  Token_Obj.Kind := Less_Than_Or_Equal_Op_Token;
               else
                  Token_Obj.String_Buffer (1) := '<';
                  Token_Obj.String_Length := 1;
                  Token_Obj.Kind := Less_Than_Op_Token;
               end if;
               Token_Obj.Is_Operator := True;
            when '>' =>
               Get_Next_Char (Compiler_Obj);
               if Lexer_Obj.Lookahead_Char = '>' then
                  Get_Next_Char (Compiler_Obj);
                  if Lexer_Obj.Lookahead_Char = '=' then
                     Get_Next_Char (Compiler_Obj);
                     Token_Obj.String_Buffer (1 .. 3) := ">>=";
                     Token_Obj.String_Length := 3;
                     Token_Obj.Kind := Assignment_Bitwise_Right_Shift_Op_Token;
                  else
                     Token_Obj.String_Buffer (1 .. 2) := ">>";
                     Token_Obj.String_Length := 2;
                     Token_Obj.Kind := Bitwise_Right_Shift_Op_Token;
                  end if;
               elsif Lexer_Obj.Lookahead_Char = '=' then
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1 .. 2) := ">=";
                  Token_Obj.String_Length := 2;
                  Token_Obj.Kind := Greater_Than_Or_Equal_Op_Token;
               else
                  Token_Obj.String_Buffer (1) := '>';
                  Token_Obj.String_Length := 1;
                  Token_Obj.Kind := Greater_Than_Op_Token;
               end if;
               Token_Obj.Is_Operator := True;
            when '^' =>
               Get_Next_Char (Compiler_Obj);
               if Lexer_Obj.Lookahead_Char = '=' then
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1 .. 2) := "^=";
                  Token_Obj.String_Length := 2;
                  Token_Obj.Kind := Assignment_Bitwise_Xor_Op_Token;
               else
                  Token_Obj.String_Buffer (1) := '^';
                  Token_Obj.String_Length := 1;
                  Token_Obj.Kind := Bitwise_Xor_Op_Token;
               end if;
               Token_Obj.Is_Operator := True;
            when '+' =>
               Get_Next_Char (Compiler_Obj);
               if Lexer_Obj.Lookahead_Char = '=' then
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1 .. 2) := "+=";
                  Token_Obj.String_Length := 2;
                  Token_Obj.Kind := Assignment_Plus_Op_Token;
               else
                  Token_Obj.String_Buffer (1) := '+';
                  Token_Obj.String_Length := 1;
                  Token_Obj.Kind := Plus_Op_Token;
               end if;
               Token_Obj.Is_Operator := True;
            when '-' =>
               Get_Next_Char (Compiler_Obj);
               if Lexer_Obj.Lookahead_Char = '=' then
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1 .. 2) := "-=";
                  Token_Obj.String_Length := 2;
                  Token_Obj.Kind := Assignment_Minus_Op_Token;
               elsif Lexer_Obj.Lookahead_Char = '>' then
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1 .. 2) := "->";
                  Token_Obj.String_Length := 2;
                  Token_Obj.Kind := Arrow_Op_Token;
               else
                  Token_Obj.String_Buffer (1) := '-';
                  Token_Obj.String_Length := 1;
                  Token_Obj.Kind := Minus_Op_Token;
               end if;
               Token_Obj.Is_Operator := True;
            when '*' =>
               Get_Next_Char (Compiler_Obj);
               if Lexer_Obj.Lookahead_Char = '=' then
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1 .. 2) := "*=";
                  Token_Obj.String_Length := 2;
                  Token_Obj.Kind := Assignment_Multiply_Op_Token;
               elsif Lexer_Obj.Lookahead_Char = '*' then
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1 .. 2) := "**";
                  Token_Obj.String_Length := 2;
                  Token_Obj.Kind := Power_Op_Token;
               else
                  Token_Obj.String_Buffer (1) := '*';
                  Token_Obj.String_Length := 1;
                  Token_Obj.Kind := Asterisk_Op_Token;
               end if;
               Token_Obj.Is_Operator := True;
            when '%' =>
               Get_Next_Char (Compiler_Obj);
               if Lexer_Obj.Lookahead_Char = '=' then
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1 .. 2) := "%=";
                  Token_Obj.String_Length := 2;
                  Token_Obj.Kind := Assignment_Modulo_Op_Token;
               else
                  Token_Obj.String_Buffer (1) := '%';
                  Token_Obj.String_Length := 1;
                  Token_Obj.Kind := Modulo_Op_Token;
               end if;
               Token_Obj.Is_Operator := True;
            when '/' =>
               Get_Next_Char (Compiler_Obj);
               if Lexer_Obj.Lookahead_Char = '/' then
                  Scan_Line_Comment (Compiler_Obj, Token_Obj);
               elsif Lexer_Obj.Lookahead_Char = '=' then
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1 .. 2) := "/=";
                  Token_Obj.String_Length := 2;
                  Token_Obj.Kind := Assignment_Divide_Op_Token;
                  Token_Obj.Is_Operator := True;
               else
                  Token_Obj.String_Buffer (1) := '/';
                  Token_Obj.String_Length := 1;
                  Token_Obj.Kind := Divide_Op_Token;
                  Token_Obj.Is_Operator := True;
               end if;
            when '.' =>
               Get_Next_Char (Compiler_Obj);
               if Lexer_Obj.Lookahead_Char = '.' then
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1 .. 2) := "..";
                  Token_Obj.String_Length := 2;
                  Token_Obj.Kind := Range_Op_Token;
               else
                  Token_Obj.String_Buffer (1) := '.';
                  Token_Obj.String_Length := 1;
                  Token_Obj.Kind := Dot_Op_Token;
               end if;
               Token_Obj.Is_Operator := True;
            when '!' =>
               Get_Next_Char (Compiler_Obj);
               Token_Obj.String_Buffer (1) := '!';
               Token_Obj.String_Length := 1;
               Token_Obj.Kind := Logical_Not_Op_Token;
               Token_Obj.Is_Operator := True;
            when '~' =>
               Get_Next_Char (Compiler_Obj);
               Token_Obj.String_Buffer (1) := '~';
               Token_Obj.String_Length := 1;
               Token_Obj.Kind := Bitwise_Not_Op_Token;
               Token_Obj.Is_Operator := True;
            when ',' =>
               Get_Next_Char (Compiler_Obj);
               Token_Obj.String_Buffer (1) := ',';
               Token_Obj.String_Length := 1;
               Token_Obj.Kind := Comma_Token;
            when ';' =>
               Get_Next_Char (Compiler_Obj);
               Token_Obj.String_Buffer (1) := ';';
               Token_Obj.String_Length := 1;
               Token_Obj.Kind := Semicolon_Token;
            when '?' =>
               Get_Next_Char (Compiler_Obj);
               Token_Obj.String_Buffer (1) := '?';
               Token_Obj.String_Length := 1;
               Token_Obj.Kind := Question_Mark_Token;
               Token_Obj.Is_Operator := True;
            when ':' =>
               Get_Next_Char (Compiler_Obj);
               Token_Obj.String_Buffer (1) := ':';
               Token_Obj.String_Length := 1;
               Token_Obj.Kind := Colon_Token;
               Token_Obj.Is_Operator := True;
            when '{' =>
               Get_Next_Char (Compiler_Obj);
               Token_Obj.String_Buffer (1) := '{';
               Token_Obj.String_Length := 1;
               Token_Obj.Kind := Left_Curly_Brace_Token;
            when '(' =>
               Get_Next_Char (Compiler_Obj);
               Token_Obj.String_Buffer (1) := '(';
               Token_Obj.String_Length := 1;
               Token_Obj.Kind := Left_Parenthesis_Token;
            when '[' =>
               Get_Next_Char (Compiler_Obj);
               if Lexer_Obj.Lookahead_Char = '[' then
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1 .. 2) := "[[";
                  Token_Obj.String_Length := 2;
                  Token_Obj.Kind := Left_Double_Square_Parenthesis_Token;
               else
                  Token_Obj.String_Buffer (1) := '[';
                  Token_Obj.String_Length := 1;
                  Token_Obj.Kind := Left_Square_Parenthesis_Token;
               end if;
            when '}' =>
               Get_Next_Char (Compiler_Obj);
               Token_Obj.String_Buffer (1) := '}';
               Token_Obj.String_Length := 1;
               Token_Obj.Kind := Right_Curly_Brace_Token;
            when ')' =>
               Get_Next_Char (Compiler_Obj);
               Token_Obj.String_Buffer (1) := ')';
               Token_Obj.String_Length := 1;
               Token_Obj.Kind := Right_Parenthesis_Token;
            when ']' =>
               Get_Next_Char (Compiler_Obj);
               if Lexer_Obj.Lookahead_Char = ']' then
                  Get_Next_Char (Compiler_Obj);
                  Token_Obj.String_Buffer (1 .. 2) := "]]";
                  Token_Obj.String_Length := 2;
                  Token_Obj.Kind := Right_Double_Square_Parenthesis_Token;
               else
                  Token_Obj.String_Buffer (1) := ']';
                  Token_Obj.String_Length := 1;
                  Token_Obj.Kind := Right_Square_Parenthesis_Token;
               end if;
            when ASCII.NUL =>
               Token_Obj.Kind := End_Of_File_Token;

            when others =>
               Log_Compiler_Error (Compiler_Obj, "Unrecognized character: '" & Lexer_Obj.Lookahead_Char & "'");
               raise Program_Error;
         end case;
      end if;

      --  Check if we need to skip comments BEFORE updating indices
      declare
         Is_Comment : constant Boolean := Token_Obj.Kind = Line_Comment_Token;
      begin
         Parser_Obj.Current_Token_Index := Parser_Obj.Next_Token_Index;
         Parser_Obj.Next_Token_Index := @ + 1;

         --  Skip comments by tail recursively calling Get_Next_Token
         if Is_Comment then
            Get_Next_Token (Compiler_Obj);
         end if;
      end;
   end Get_Next_Token;

   procedure Init_Reserved_Words_Table with
      Pre => Reserved_Words_Table.Is_Empty,
      Post => not Reserved_Words_Table.Is_Empty is
   begin
      Reserved_Words_Table.Insert ("as", As_Token);
      Reserved_Words_Table.Insert ("at", At_Token); --  attribute
      Reserved_Words_Table.Insert ("assert", Assert_Token);
      Reserved_Words_Table.Insert ("auto", Auto_Token);
      Reserved_Words_Table.Insert ("bit", Bit_Token);  --  single-bit field attribute
      Reserved_Words_Table.Insert ("bits", Bits_Token);  --  multi-bit field attribute
      Reserved_Words_Table.Insert ("bool", Bool_Token);
      Reserved_Words_Table.Insert ("break", Break_Token);
      Reserved_Words_Table.Insert ("case", Case_Token);
      Reserved_Words_Table.Insert ("char", Char_Token);
      Reserved_Words_Table.Insert ("compile_if", Compile_If_Token);
      Reserved_Words_Table.Insert ("const", Const_Token);
      Reserved_Words_Table.Insert ("continue", Continue_Token);
      Reserved_Words_Table.Insert ("convention", Convention_Token); --  attribute
      Reserved_Words_Table.Insert ("decimal", Decimal_Token);
      Reserved_Words_Table.Insert ("default", Default_Token);
      Reserved_Words_Table.Insert ("delta", Delta_Token);
      Reserved_Words_Table.Insert ("digits", Digits_Token);
      Reserved_Words_Table.Insert ("abstract_state", Abstract_State_Token); --  module attribute
      Reserved_Words_Table.Insert ("align", Align_Token); --  type/variable alignment attribute
      Reserved_Words_Table.Insert ("depends", Depends_Token); --  contract clause
      Reserved_Words_Table.Insert ("do", Do_Token);
      Reserved_Words_Table.Insert ("else", Else_Token);
      Reserved_Words_Table.Insert ("enum", Enum_Token);
      Reserved_Words_Table.Insert ("export", Export_Token); --  variable/function export attribute
      Reserved_Words_Table.Insert ("false", False_Token);
      Reserved_Words_Table.Insert ("first", First_Token); --  attribute
      Reserved_Words_Table.Insert ("fixed", Fixed_Token);
      Reserved_Words_Table.Insert ("float", Float_Token);
      Reserved_Words_Table.Insert ("for", For_Token);
      Reserved_Words_Table.Insert ("foreign", Foreign_Token);
      Reserved_Words_Table.Insert ("generic", Generic_Token); --  generic formal part
      Reserved_Words_Table.Insert ("global", Global_Token); --  contract clause
      Reserved_Words_Table.Insert ("goto", Goto_Token);
      Reserved_Words_Table.Insert ("if", If_Token);
      Reserved_Words_Table.Insert ("in", In_Token);
      Reserved_Words_Table.Insert ("inout", Inout_Token);
      Reserved_Words_Table.Insert ("import", Import_Token);
      Reserved_Words_Table.Insert ("last", Last_Token); --  attribute
      Reserved_Words_Table.Insert ("length", Length_Token); --  array length attribute
      Reserved_Words_Table.Insert ("loop_invariant", Loop_Invariant_Token); --  loop contract
      Reserved_Words_Table.Insert ("loop_variant", Loop_Variant_Token); --  loop contract
      --  machine_width is a built-in constant, not a keyword
      --  It's handled as an identifier by the lexer and substituted in the parser
      Reserved_Words_Table.Insert ("modular", Modular_Token);
      Reserved_Words_Table.Insert ("module", Module_Token);
      Reserved_Words_Table.Insert ("no_return", No_Return_Token); --  function attribute
      Reserved_Words_Table.Insert ("offset", Offset_Token);  --  bit field offset attribute
      Reserved_Words_Table.Insert ("out", Out_Token);
      Reserved_Words_Table.Insert ("packed", Packed_Token); --  attribute
      Reserved_Words_Table.Insert ("post", Post_Token); --  attribute
      Reserved_Words_Table.Insert ("pre", Pre_Token); --  attribute
      Reserved_Words_Table.Insert ("private", Private_Token);
      Reserved_Words_Table.Insert ("range", Range_Token);
      Reserved_Words_Table.Insert ("reads", Reads_Token); --  contract clause
      Reserved_Words_Table.Insert ("refined_state", Refined_State_Token); --  variable attribute
      Reserved_Words_Table.Insert ("renames", Renames_Token);
      Reserved_Words_Table.Insert ("return", Return_Token);
      Reserved_Words_Table.Insert ("section", Section_Token); --  variable linker section attribute
      Reserved_Words_Table.Insert ("size", Size_Token); --  attribute
      Reserved_Words_Table.Insert ("sizeof", Sizeof_Token);
      Reserved_Words_Table.Insert ("static", Static_Token);
      Reserved_Words_Table.Insert ("struct", Struct_Token);
      Reserved_Words_Table.Insert ("subtype", Subtype_Token);
      Reserved_Words_Table.Insert ("switch", Switch_Token);
      Reserved_Words_Table.Insert ("true", True_Token);
      Reserved_Words_Table.Insert ("type", Type_Token);
      Reserved_Words_Table.Insert ("type_invariant", Type_Invariant_Token); --  type attribute
      Reserved_Words_Table.Insert ("union", Union_Token);
      Reserved_Words_Table.Insert ("void", Void_Token);
      Reserved_Words_Table.Insert ("volatile", Volatile_Token);
      Reserved_Words_Table.Insert ("while", While_Token);
      Reserved_Words_Table.Insert ("writes", Writes_Token); --  contract clause
   end Init_Reserved_Words_Table;

--  Package elaboration:
begin
   Init_Reserved_Words_Table;
end STC_Compiler.Lexer;