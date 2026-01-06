module internal.parser;

import cherry;
import std.ascii : isWhite, isAlpha, isAlphaNum, isDigit, toLower;
import std.format;

public:

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
  static auto create(in TokenType type, in size_t line, in size_t row, in ch_String content) {
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
  @property ch_String content() const in(hasContent(), "Token content is not valid") {
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
  ch_String       _content;
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
  ch_String       _sourceContent;
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
  // Next token evaluated
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

  auto error(in ch_String name, in ch_String expected) {
    return format("Lexer (%s)[%d:%d] - %s", name, _currentLine, _currentRow,
      expected);
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

  TokenType getIdType(in ch_String str) {
    import std.conv : to;
    import std.algorithm.iteration : map;

    // Convert it to lowercase (case-insensitive)
    ch_String convId = str.map!(a => toLower(a)).to!string;
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
    bool hasPoint = false; // For floating-points

    updateStartingPosition();

    // Integers-only for now
    while ( ( isDigit ( _currentChar ) || isCurrEq('.') ) && !isCurrEq(ch: 0) ) {
      // Do not start with zero if  there are more digits before it
      if (_startPosition == _currentPosition && (isCurrEq(ch: '0') && isDigit(peek()) )) {
        throw new Exception(error("parseNumber", "An intenger cannot start with a zero")); }
          
      // Floating  point unique
      if (isCurrEq(ch: '.'))
      {
        if (hasPoint) { throw new Exception(error("parseNumber", "Invalid floating-point format")); }
        else hasPoint = true; // Accept it
      }

      step();
    }

    content = _sourceContent[_startPosition .. _currentPosition];
    // Verify if the number ends with '.' (which is not valid)
    auto len = (_currentPosition - _startPosition) - 1;
    if (content[ len ] == '.' ) {
      throw new Exception(error("parseNumber", "A number cannot have a dot at the end"));
    }

    type = TokenType.LiteralNumber;

    result = Token.create(type, _startLine, _startRow, content);
    return result;
  }

  Token parseString() {
    Token result;
    TokenType type = TokenType.LiteralString;
    string content;

    step(); // Skip opening '"'
    updateStartingPosition();

    while ( !isCurrEq(ch: '"') ) {
      step();
    }

    if (!isCurrEq(ch: '"') ) {
      throw new Exception(error("parseString", "Expected: '\"' to close the string"));
    }

    content = _sourceContent[_startPosition .. _currentPosition];
    step(); // Skip last double-quote

    result = Token.create(type, _startLine, _startRow, content);
    return result;
  }

  /// Generates a new token
  Token parse() {

    // While character is valid
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
      if ( isDigit( _currentChar ) ) {
       return parseNumber();
      }

      if ( isCurrEq(ch: '"') ) {
        return parseString();
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

enum ResultType {
  Unknown,
  Label,
  Data,
  List
}

struct ch_Result {
  alias bool16 = short;
  ResultType type;
  bool16 isValid;

  union Value {
    ch_Label label;
    ch_Data data;
    ch_List list;
  }
  Value value;

  /// Get a label
  ch_Label getLabel() in (type == ResultType.Label, "Result is not a label") {
    return value.label;
  }

  /// Get a single data
  ch_Data getData() in (type == ResultType.Data, "Result is not a single data") {
    return value.data;
  }

  /// Get the list
  ch_List getList() in (type == ResultType.List, "Result is not a list") {
    return value.list;
  }
}

struct Parser {

  void setup(string source) {
    _lexer.setup(source);
    _lexer.eval();
  }
  
  ch_Result eval() {

    // Start parsing
    if (isTokenEqual(TokenType.Sign)) {
      return parseLabel();
    }

    if ( isTokenEqual(TokenType.SetKeyword) ) {
      return parseAssignment();
    }

    ch_Result result;
    result.isValid = false;
    return result;
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

  ch_String error(in ch_String name, in ch_String expected) const {
    return format("Parser (%s)[%d:%d]: Unexpected token. Got '%s'. Expected '%s'.", name,
      currentToken().line(), currentToken().row(), currentToken().content(),
        expected);
  }

  bool isTokenLiteral() const {
    return currentToken.isString() || currentToken.isNumber()
      || currentToken.isBoolean();
  }

  // ======= //
  /* Parsing */
  // ======= //

  ch_Result parseLabel() {
    ch_Result result;
    ch_Label label;
    result.type = ResultType.Label;

    step(); // Skip sign
    if (!currentToken.isIdentifier()) {
      throw new Exception(error("parseLabel", "An identifier"));
    }

    // Set id lol
    label.setId(currentToken().content());
    step(); // Skip identifier

    if (!isTokenEqual(TokenType.Colon)) {
      throw new Exception(error("parseLabel", ":"));
    }
    step(); // Skip colon
    result.isValid = true;
    result.value.label = label;
    return result;
  }

  ch_Result parseAssignment() {
    ch_Result result;
    ch_List list;
    ch_Data data;
    auto valueType = CH_VALUE_UNKNOWN;
    result.type = ResultType.Data; // Single data by default

    // Skip assignment ('set' keyword)
    step();

    // =========== //
    /* List value */
    // =========== //

    if ( isTokenEqual(TokenType.LeftBrace) ) {
      // Well, it is a list
      result.type = ResultType.List;
      step(); // Consume '{' and other literal values (from goto)

    recursion:
      if ( !isTokenLiteral() ) {
        throw new Exception(error("parseAssignment | List", "String / Number / Boolean"));
      }
      
      /// Append content
      list.append(currentToken.content);
      step(); // Skip literal

      if ( isTokenEqual(TokenType.Comma) ) {
        step();
        goto recursion;
      } else if ( !isTokenEqual(TokenType.RightBrace) ) {
        throw new Exception(error("parseAssignment | List", "'}' to close the list"));
      }
      
      step(); // Skip closing '}'
      goto checkId;
    }

    // ============ //
    /* Single value */
    // ============ //

    // Verify if a literal value is passed
    if ( !isTokenLiteral() ) {
      throw new Exception(error("parseAssignment", "String / Number / Boolean"));
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
    data.setValue(currentToken().content(), valueType);

    step(); // Skip literal value

checkId:
    // Verify if a comma is next
    if (!isTokenEqual(TokenType.Comma)) {
      throw new Exception(error("parseAssignment", ","));
    }

    step(); // Skip comma

    if (!currentToken.isIdentifier()) {
      throw new Exception(error("parseAssignment", "An identifier"));
    }
    // Get name
    data.setId(currentToken().content());
    list.setId(currentToken.content);
    step(); // Skip identifier

    result.isValid = true;
    if (result.type == ResultType.Data)
      result.value.data = data;
    else if (result.type == ResultType.List)
      result.value.list = list;
    
    return result; 
  }
}

// Tokenizer and parser
unittest {
  import std.stdio : writeln, writefln;

  ch_Data number;
  number.setId("My_Number");
  number.setValue("180.6", CH_VALUE_NUMBER);

  writefln("Number data identifier: %s\nNumber data value: %.1f\n",
    number.id(), number.getRawNumber());

  auto source =
  "@ User:\n
    SET       \"nonsense_User\", name\n
    Set       18, age\n
  @ Video:\n
    ; Cherry works lmao\n
    set       0.6, brightness\n
    set       Yes, vsync\n
    set       { 255, 255, 255 }, color";

  // Engine
  ch_Engine engine;
  engine = parseCherry(source);

  auto userLabel = engine.getLabel("User");
  ch_Data username = userLabel.getData("name");

  assert(username.id() == "name");
  writeln("User::Name: ", username.getString());

  ch_Data age = userLabel.getData("age");
  
  assert(age.getString() != "10");
  writeln("User::Age: ", age.getRawNumber());

  auto videoLabel = engine.getLabel("Video");
  ch_Data brightness = videoLabel.getData("brightness");

  assert(brightness.getRawNumber() == 0.6);
  writeln("Video::Brightness: ", brightness.getRawNumber());

  ch_Data vsync = videoLabel.getData("vsync");

  assert(vsync.isTrue());
  writeln("Video::Vsync: ", vsync.getString());

  ch_List saturation = videoLabel.getList("color");
  writeln("List length: ", saturation.id());
  writeln("Saturation R: ", saturation.getNumber(index: 0));
  writeln("Saturation G: ", saturation.getNumber(index: 1));
  writeln("Saturation B: ", saturation.getNumber(index: 0));

  engine.clean();
}
