module internal.parser;

import cherry;
import std.ascii : isWhite, isAlpha, isAlphaNum, isDigit, toLower;
import std.stdio : writeln;
import std.format;

public:

/// No way that 'Invalid' is being useless
enum TokenType : short {
  Invalid = -1,         /// Invalid token type

  Eof,                  /// End of file
  Identifier,           /// (A-Z / a-z / _ -> 0-9)
  LiteralString,        /// " "
  LiteralNumber,        /// (0-9)

  Colon,                /// ':'
  Comma,                /// ','
  Sign,                 /// '@'
  // Equal,             /// '='
  LeftBrace,            /// '{'
  RightBrace,           /// '}'
  // LeftBracket,       /// '['
  // RightBracket,      /// ']'

  SetKeyword,           /// 'set'
  CopyKeyword,          /// 'copy'
  YesKeyword,           /// 'yes'
  NoKeyword,            /// 'no'
  // GeaKeyword,        /// 'gea'

}

struct Token {
  /// Creates a new token
  static auto create(in TokenType type, in size_t line, in size_t row, in string content) {
    Token token;

    token._type = type;
    token._regLine = line;
    token._regRow = row;
    token._content = content;

    return token;
  }

  /// Creates a new invalid token
  static auto invalid(char c, size_t line, size_t row) {
    Token token;

    import std.conv : to;

    token._type = TokenType.Invalid;
    token._regLine = line, token._regRow = row;
    token._content = c.to!string;

    return token;
  }

  /// Get the token type
  @property auto type() const {
    return _type;
  }

  /// Get the line where the token was registered
  @property auto line() const {
    return _regLine;
  }

  /// Get the column / row where the token was registered
  @property auto row() const {
    return _regRow;
  }

  /**
   * Get the token content
   *
   * Executes an assert verifying that the content is not empty
   */
  @property string content() const in(hasContent(), "Token content is not valid") {
    return _content;
  }

  /***
    * Shortcut functions
    */

  /// Check if a token has valid content
  @property bool hasContent() const { return _content !is null && _content.length > 0; }
  /// Check if a token is valid along the type and the content
  @property bool isValid() const { return _type != TokenType.Invalid && hasContent(); }
  /// Check if the token is an identifier
  @property bool isIdentifier() const { return _type == TokenType.Identifier; }
  /// Check if the token is a literal number
  @property bool isNumber() const { return _type == TokenType.LiteralNumber; }
  /// Check if the token is a literal string
  @property bool isString() const { return _type == TokenType.LiteralString; }
  /// Check if a token is a boolean (YES / NO)
  @property bool isBoolean() const { return _type == TokenType.YesKeyword || _type == TokenType.NoKeyword; }

private:
  /// Token type : Keyword, operator, identifier, etc.
  TokenType        _type;
  /// Line where the token was registered
  size_t          _regLine;
  /// Column where the token was registered
  size_t          _regRow;
  /// Content of the token itself
  string       _content;
}

struct Lexer {

  void setup(string s) in(s.length > 0) {
    _sourceContent = s;
    _currentLine = 1, _currentRow = 1;
    _currentPosition = 0;

    _startLine = _startRow = _startPosition = 0;
    _currentChar = _sourceContent[_currentPosition];
  }

  /// Update tokens and evaluate them
  void eval() {
    // Parse first token
    _currentToken = parse(); // Second token
  }

  /// Get the token evaluated
  @property auto getToken() const in (_currentToken.isValid(), "Current token is not valid") {
    return _currentToken;
  }

private:
  /// Configuration file content
  string       _sourceContent;
  /// Current line being read
  size_t          _currentLine;
  /// Current column / row being read
  size_t          _currentRow;
  /// Current position in the source content
  size_t          _currentPosition;
  /// The starting line of a token
  size_t          _startLine = 1;
  /// The starting row / column of a token
  size_t          _startRow = 1;
  /// The starting position of a token
  size_t          _startPosition = 0;
  /// Current character in the source content
  char            _currentChar;
  /// Current token evaluated
  Token           _currentToken = Token.invalid(0,0,0);
  // Next token evaluated (NOT USED)
  // Token           _nextToken = Token.invalid(0,0,0);

  /// Symbol for comments
  immutable enum commentSymbol = ';';
  /// Symbol for labels
  immutable enum labelSymbol = '@';

  static immutable TokenType[string] keywords =
  [
    "set" : TokenType.SetKeyword,
    "copy" : TokenType.CopyKeyword,
    "yes" : TokenType.YesKeyword,
    "no" : TokenType.NoKeyword,
  ];

  /* Private functions */

  /// Check if the current character is null
  bool shouldEnd() {
    return _currentPosition >= _sourceContent.length;
  }

  /** 
   * Moves to the next character forward
   * Returns: The previous character before the step
   */
  char step() {
    char prevChar = _currentChar;

    _currentPosition++;

    // if EOF (before step)
    if (shouldEnd()) {
      _currentChar = '\0';
      return '\0'; // Equivalent to writing '\0'
    }

    _currentChar = _sourceContent[_currentPosition];

    if (_currentChar == '\n')
    {
      // Starts a <new line
      _currentLine++;
      _currentRow = 0; // Restarts the row counter lmao
    }
    else
    {
      _currentRow++;
    }

    // if EOF (after step)
    if (shouldEnd()) {
      _currentChar = '\0';
      return 0;
    }

    return prevChar;
  }

  /// Skip 'steps' characters
  void skip(short steps) {
    foreach (_ ; 1..steps) {
      step();
    }
  }

  /// Shows an error
  void error(in string name, in string expected) {
    format("Lexer (%s)[%d:%d] - %s", name, _currentLine, _currentRow,
      expected).writeln;
  }

  /// Peek a character in X depth
  char peek(short depth = 1) {
    if (!depth) // If depth is zero or less
      return _currentChar;
    
    auto position = _currentPosition + depth;
    if (position >= _sourceContent.length) {
      return '\0'; // Null-character
    }

    return _sourceContent[position];
  }

  /// Shortcut to compare the current character with other
  bool isCurrEq(char ch) {
    return _currentChar == ch;
  }

  void updateStartingPosition() {
    _startPosition = _currentPosition;
    _startLine = _currentLine;
    _startRow = _currentRow;
  }

  TokenType getIdType(in string str) {
    import std.conv : to;
    import std.algorithm.iteration : map;

    // Convert it to lowercase (case-insensitive)
    string convId = str.map!(a => toLower(a)).to!string;

    if (convId !in keywords)
      return TokenType.Identifier;

    // Return the token type of the keyword
    return keywords[convId];
  }

  // ========= //
  /* Tokenizer */
  // ========= //
  
  // Very autoexplicative

  void skipComment()
  {
    while ( !isCurrEq('\n') && !isCurrEq(ch: 0) ) {
      step(); // Skip characters until newline
    }
  }

  void skipWhitespaces() {
    while ( isWhite(_currentChar) && !isCurrEq(ch: 0) ) {
      step();
    }
  }

  Token invalidToken() {
    return Token.invalid(_currentChar, _currentLine, _currentRow);
  }

  /// Parse an identifier or a keyword
  Token parseIdKw() {
    Token result;
    TokenType type;
    string content;

    updateStartingPosition();
    while ( ( isAlphaNum(_currentChar) || isCurrEq('_') ) && !isCurrEq(0) ) {
      step();
    }

    content = _sourceContent[_startPosition .. _currentPosition];
    type = getIdType(content); // Keyword or identifier
    
    result = Token.create(type, _startLine, _startRow, content);
    return result;
  }

  /// Parse a decimal (base 10) number
  Token parseNumber() {
    Token result;
    TokenType type;
    string content;
    bool isNegative = false;
    bool hasPoint = false; // For floating-points

    updateStartingPosition();

    // Integer (positive and negative) and decimal numbers
    while ( ( isDigit ( _currentChar ) || isCurrEq('.') || isCurrEq('-') ) && !isCurrEq(ch: 0) ) {
      // Negative sign o_O
      if (_startPosition == _currentPosition && isCurrEq(ch: '-') ) {
        isNegative = true;
        step(); // Skip that bullshit

        continue;
      }

      // PLS IMPROVE ME: Oh my fuckin' god :( ...
      if ((isNegative && (_currentPosition == (_startPosition + 1)))
          || _startPosition == _currentPosition)
        
        if ( isCurrEq(ch: '0') && isDigit(peek()) ) {
          error("parseNumber", "A number cannot contain a zero at the beginning if there are more digits.");
          return invalidToken();
        }

      // This basically says that the number is a double (decimal), however
      // it doesn't allow more than ONE dot symbol. Cuz that doesn't even make sense.
      // Basically to avoid problems when converting it to a native D type by the API.
      if (isCurrEq(ch: '.'))
      {
        if (hasPoint) {
          error("parseNumber", "A number cannot contain more than one floating-point");
          return invalidToken();
        }
        else { hasPoint = true; } // Accept it
      }

      // No minus sign after using it :(
      if ( isCurrEq(ch: '-') ) {
        error("parseNumber", "Unexpected '-'. '-' should be only at the beginning");
        return invalidToken();
      }

      step();
    }

    content = _sourceContent[_startPosition .. _currentPosition];
    // Verify if the number ends with '.' (which is not valid)
    auto len = (_currentPosition - _startPosition) - 1;

    if (content[ len ] == '.' ) {
      error("parseNumber", "A number cannot have a dot at the end");
      return invalidToken();
    }

    type = TokenType.LiteralNumber;

    result = Token.create(type, _startLine, _startRow, content);
    return result;
  }

  /// Yes.
  int getEscapeCharacter() {
    switch ( _currentChar ) {
      case '\\':
        return '\\';
      case '\'':
        return '\'';
      case '\"':
        return '\"';
      case 'n':
        return '\n';
      case 't':
        return '\t';
      case 'v':
        return '\v';
      default:
        return -1;
    }

    // Unreachable
    assert(0, "getEscapeCharacter: UNREACHABLE");
  }

  /// Escape sequences, yey!!!!
  Token parseString() {
    Token result = Token.invalid(0,0,0);
    TokenType type = TokenType.LiteralString;
    string content = null;

    step(); // Skip opening '"'
    updateStartingPosition();

    while ( !isCurrEq(ch: '"') && !isCurrEq(ch: '\0') ) {
      // Escape character
      if ( isCurrEq(ch: '\\') ) {
        step(); // Skip backslash

        int c = getEscapeCharacter();

        // Unknown escape sequence
        if (c < 0) { 
          error("parseString", "A valid escape character");
          return invalidToken();
        }

        content ~= c; step(); // Append that character dude
        continue;
      }

      content ~= _currentChar;
      step(); // Next character
    }

    // Close '"'
    if (!isCurrEq(ch: '"') ) {
      error("parseString", "'\"' to end string");
      return invalidToken();
    }

    step(); // Skip last double-quote

    result = Token.create(type, _startLine, _startRow, content);
    return result;
  }

  /// No escape sequences bro
  Token parseRawString() {
    Token result = Token.invalid(0,0,0);
    TokenType type = TokenType.LiteralString;
    string content = null;

    step(); // Skip opening single-quote (')
    updateStartingPosition();

    while ( !isCurrEq(ch: '\'') && !isCurrEq(ch: 0) ) {
      step(); // Using length based on position
    }

    // Slice content :D
    content = _sourceContent[_startPosition .. _currentPosition];

    // Closing character
    if ( !isCurrEq( '\'' ) ) {
      error("parseRawString", "Closing single-quote: \"'\"");
      return invalidToken();
    }

    step(); // Skip closing single-quote (')

    result = Token.create(type, _startLine, _startRow, content);
    return result;
  }

  /// Generates a new token
  Token parse() {

    // While character is valid ('\0' is zero)
    while ( !isCurrEq(ch: 0) ) {
      // White spaces
      if ( isWhite(_currentChar) ) {
        skipWhitespaces();
        continue;
      }

      // Comments
      if ( isCurrEq( commentSymbol ) ) {
        skipComment();
        continue;
      }

      // Identifier - Also labels
      if ( isAlpha( _currentChar ) || isCurrEq('_') ) {
        return parseIdKw();
      }

      // Digits
      if ( isDigit( _currentChar ) || isCurrEq('-') ) {
       return parseNumber();
      }

      // String (with escape sequences)
      if ( isCurrEq(ch: '"') ) {
        return parseString();
      }

      // String (without escape sequences)
      if ( isCurrEq(ch: '\'') ) {
        return parseRawString();
      }

      // Single characters
      size_t opLine = _currentLine;
      size_t opRow = _currentRow;
      char op = step();
      switch (op)
      {
        case ':': return          Token.create(TokenType.Colon,      opLine, opRow, ":");
        case ',': return          Token.create(TokenType.Comma,      opLine, opRow, ",");
        case '{': return          Token.create(TokenType.LeftBrace,  opLine, opRow, "{");
        case '}': return          Token.create(TokenType.RightBrace, opLine, opRow, "}");
        case labelSymbol: return  Token.create(TokenType.Sign,       opLine, opRow, "@");
        default: return Token.invalid(op, opLine, opRow); // Unknown / Invalid
      }
    }

    Token eof = Token.create(TokenType.Eof, _currentLine, _currentRow, "<eof>");
    return eof;
  }
}

/// Label data or list ... damn bro
enum ResultType {
  Unknown,
  Eof,
  Label,
  Data,
  List,
}

struct chResult {
  alias bool16 = short;
  ResultType type;
  bool16 isValid;

  union Value {
    short error;
    chLabel label;
    chData data;
    chList list;
  }
  Value value;

  /// Get a label
  chLabel getLabel() in (type == ResultType.Label, "Result is not a label") {
    return value.label;
  }

  /// Get a single data
  chData getData() in (type == ResultType.Data, "Result is not a single data") {
    return value.data;
  }

  /// Get the list
  chList getList() in (type == ResultType.List, "Result is not a list") {
    return value.list;
  }

  static auto eof() {
    chResult r;

    r.type = ResultType.Eof;
    r.value.error = 0;
    r.isValid = true;

    return r;
  }

  /// Creating a label
  static auto create( chLabel label ) {
    chResult r;

    r.type = ResultType.Label;
    r.value.label = label;
    r.isValid = true;

    return r;
  }

  /// Creating data
  static auto create( chData data ) {
    chResult r;
    
    r.type = ResultType.Data;
    r.value.data = data;
    r.isValid = true;

    return r;
  }

  /// Creating a list
  static auto create ( chList list ) {
    chResult r;

    r.type = ResultType.List;
    r.value.list = list;
    r.isValid = true;

    return r;
  }

  /// Invalid value
  static auto invalid() {
    chResult r;

    r.type = ResultType.Unknown;
    r.value.error = -1;
    r.isValid = false;

    return r;
  }
}

struct Parser {

  /// Setup lexer
  void setup(string source) {
    _lexer.setup(source);
    _lexer.eval();
  }
  
  chResult eval() {

    // Directly.
    if (isTokenEqual(TokenType.Eof)) {
      return chResult.eof();
    }

    // Well, this is for labels
    if (isTokenEqual(TokenType.Sign)) {
      return parseLabel();
    }

    /* Keywords */
    if ( isTokenEqual(TokenType.SetKeyword) ) {
      return parseAssignment();
    }

    // Ehem... unexpected tokens at the beginning
    error("eval", " @ or keywords ");
    return chResult.invalid();
  }

package:
  /// Line (debug)
  @property size_t line() const {
    return currentToken.line();
  }

  /// Row (Debug)
  @property size_t row() const {
    return currentToken.row();
  }

private:
  /// The lexer
  Lexer     _lexer;

  /// Advance dude
  void step() {
    _lexer.eval();
  }

  /// Shortcut to current token
  Token currentToken() const {
    return _lexer.getToken();
  }

  /// Shortcut to next token
  // Token nextToken() const {
    // return _lexer.nextToken();
  // }

  /// Compare if a token type is the same as other
  bool isTokenEqual(TokenType a) const {
    return a == currentToken.type;
  }

  chResult invalidResult() {
    return chResult.invalid();
  }

  void error(in string name, in string expected) const {
    format("Parser (%s)[%d:%d]: Unexpected token. Got '%s'. Expected '%s'.", name,
      currentToken().line(), currentToken().row(), currentToken().content(),
        expected).writeln;
  }

  bool isTokenLiteral() const {
    return currentToken.isString() || currentToken.isNumber()
      || currentToken.isBoolean();
  }

  // ======= //
  /* Parsing */
  // ======= //

  chResult parseLabel() {
    chLabel label; // Label :U

    step(); // Skip sign
    if (!currentToken.isIdentifier()) {
      error("parseLabel", "An identifier");
      return invalidResult();
    }

    // Set id lol
    label.setId(currentToken().content());
    step(); // Skip identifier

    if (!isTokenEqual(TokenType.Colon)) {
      error("parseLabel", ":");
      return invalidResult();
    }

    step(); // Skip colon
    return chResult.create( label );
  }

  chResult parseList() {
    chList list;
    step(); // Consume '{'

    // Expect a literal value
    if ( !isTokenLiteral() ) {
      error("parseAssignment | List", "String / Number / Boolean");
      return invalidResult();
    }

appendElement:
    list.append ( currentToken().content );
    step(); // Skip literal

    if ( isTokenEqual (TokenType.Comma) ) {
      step(); // Trailing comma

      if ( isTokenLiteral() ) {
        goto appendElement;
      }
    }

    // Close '}'
    if ( !isTokenEqual (TokenType.RightBrace) ) {
      error("parseList", "Right brace to close list (})");
      return invalidResult();
    }

    step(); // Skip closing brace '}'

    /* Parse identifier */

    if ( !isTokenEqual (TokenType.Comma) ) {
      error("parseList", "A comma (,)");
      return invalidResult();
    }

    step(); // Skip comma

    if ( !isTokenEqual (TokenType.Identifier) ) {
      error("parseList", "An identifier");
      return invalidResult();
    }

    list.setId ( currentToken.content );
    step(); // Skip identifier

    return chResult.create( list );
  }

  chResult parseAssignment() {
    chValueType valueType;
    chData data;

    // Skip assignment ('set' keyword)
    step();

    // =========== //
    /* List value */
    // =========== //
    if ( isTokenEqual(TokenType.LeftBrace) /* Left brace: '{'*/ ) {
      return parseList();
    }

    // ============ //
    /* Single value */
    // ============ //

    // Verify if a literal value is passed
    if ( !isTokenLiteral() ) {
      error("parseAssignment", "String / Number / Boolean");
      return invalidResult();
    }

    // Get content and value type
    switch (currentToken.type())
    {
      // String and number
      case TokenType.LiteralString: valueType = CH_VALUE_STRING; break;
      case TokenType.LiteralNumber: valueType = CH_VALUE_NUMBER; break;

      // Boolean
      case TokenType.YesKeyword:
      case TokenType.NoKeyword:
          valueType = CH_VALUE_BOOLEAN; break;
      // ?
      default: break;
    }

    // Single data type (later: Lists)
    data.setValue( currentToken.content() , valueType);
    step(); // Skip literal value

    // Verify if a comma is next
    if (!isTokenEqual(TokenType.Comma)) {
      error("parseAssignment", "A comma (,)");
      return invalidResult();
    }

    step(); // Skip comma

    if (!currentToken.isIdentifier() ) {
      error("parseAssignment", "An identifier");
      return invalidResult();
    }

    // Get name
    data.setId( currentToken.content );
    step(); // Skip identifier

    return chResult.create( data );
  }
}

// Tokenizer and parser
unittest {
  import std.stdio : writeln, writefln;

  chData number;
  number.setId("My_Number");
  number.setValue("180.6", CH_VALUE_NUMBER);

  writefln("Number data identifier: %s\nNumber data value: %.1f\n",
    number.id(), number.toDouble());

  auto source =
  "@ User:\n
    SET       \"random_\\\"USER\\\"\", name ; Escape sequences\n
    Set       \"New\\nLine! And \\tTabs!\", description
    Set       18, age\n
  @ Video:\n
    ; Cherry works lmao\n
    set       0.6, brightness\n
    set       Yes, vsync\n
    set       { 255, 255, 255, }, color ; Trailing comma\n
    set       -1, errorcode\n
    ";

  // Engine
  chEngine engine;
  engine = parseCherry(source);

  auto userLabel = engine.getLabel("User");
  chData username = userLabel.getData("name");

  assert(username.id() == "name");
  writeln("User::Name: ", username.toString());

  chData description = userLabel.getData("description");
  assert(description.toString() != "NewnLine! And tTabs!");
  writefln("User::Description: <%s>", description.toString());

  chData age = userLabel.getData("age");
  assert(age.toString() == "18", "Integer numbers aren't working");
  writeln("User::Age: ", age.toInt());

  auto videoLabel = engine.getLabel("Video");
  chData brightness = videoLabel.getData("brightness");

  assert(brightness.toDouble() == 0.6, "Brightness hasn't a float value");
  writeln("Video::Brightness: ", brightness.toDouble());

  chData vsync = videoLabel.getData("vsync");

  assert(vsync.isTrue(), "Vsync is not true?");
  writeln("Video::Vsync: ", vsync.toString());

  chList saturation = videoLabel.getList("color");
  assert(saturation.length() == 3, "Saturation list is not working");

  writeln("List length: ", saturation.id());
  writeln("Saturation R: ", saturation.toInt(index: 0));
  writeln("Saturation G: ", saturation.toInt(index: 1));
  writeln("Saturation B: ", saturation.toInt(index: 0));

  chData errorcode = videoLabel.getData("errorcode");
  assert(errorcode.toInt() == -1, "Errorcode is NOT -1. Negative numbers aren't working");
  writeln("Error code (Video): ", errorcode.toDouble());

  engine.clean();
}
