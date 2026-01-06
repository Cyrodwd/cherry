module internal.api;
import internal.parser;

/** 
 * Cherry (Configuration format) @2026
 * Cyrodwd - Bjankadev
 */

/// An alias of the `long` data type
alias ch_Number =     double;

/// An alias of the `string` data type
alias ch_String =     immutable(char)[];

/// Types to identify a single data, or a list.
enum ch_DataType {
  Unknown = 0,
  Single, // Single data
  List, // A list of multiple data
}

/// Type of the value
enum ch_ValueType {
  Unknown = 0,
  Boolean,
  Number,
  String,
}

/// An alias to `ch_DataType.Unknown`
alias CH_DATA_UNKNOWN = ch_DataType.Unknown;

/// An alias to `ch_DataType.Single`
alias CH_DATA_SINGLE = ch_DataType.Single;

/// An alias to `ch_DataType.List`
alias CH_DATA_LIST = ch_DataType.List;

/// An alias to `ch_ValueType.Unknown`
alias CH_VALUE_UNKNOWN = ch_ValueType.Unknown;
/// An alias to `ch_ValueType.Boolean`
alias CH_VALUE_BOOLEAN = ch_ValueType.Boolean;

/// An alias to `ch_ValueType.Integer`
alias CH_VALUE_NUMBER = ch_ValueType.Number;

/// An alias to `ch_ValueType.String`
alias CH_VALUE_STRING = ch_ValueType.String;

/* Structs */

/// Struct of a data
struct ch_Data {
  // ======= //
  /* Getters */
  // ======= //

  /// Identifier / Name of the data
  @property auto id() const { return _id; }

  /// Data type
  @property auto type() const { return _type; }

  /// Data value - as a string
  @property auto getString() const in (_type == CH_DATA_SINGLE, "Data type is a list or unknown")
  do { return _value.single; }

  @property auto valueType() const in (_type == CH_DATA_SINGLE, "Data type is a list or unknown")
  do { return _vtype; }

  /// Converts the digits into a native D numeric value (double).
  /// It only works if the value can be converted as a number
  /// Can throw exceptions if the value can't be converted to a ch_Number type (double)
  @property auto getRawNumber() const in (_type == CH_DATA_SINGLE, "Data type is a list or unknown")
  in (_vtype == CH_VALUE_NUMBER, "Data value is not a number")
  do {
    import std.conv : to;
    return _value.single.to!ch_Number;
  }

  /// If it is a Boolean, it returns its value (in this case, `YES` = true, `NO` = false).
  @property bool isTrue() const in (_type == CH_DATA_SINGLE, "Data type is a list or unknown")
  in (_vtype == CH_VALUE_BOOLEAN, "Data value is not a boolean") {
    return _value.single.length == 3; // As 'yes' has three characters... lmto.
  }

  // ======= //
  /* Setters */
  // ======= //

  /// Set an identifier for the data
  @property void setId(in ch_String id)
    in (id.length > 0, "Passed identifier is empty") // First assert
    in (_id != id, "You're passing the same identifier") // Second assert
    do {
      _id = id;
    }

  /// Set a type to the data
  @property void setType(in ch_DataType type)
  in(type != CH_DATA_UNKNOWN && _type != type, "Passed unknown data type")
  {
    _type = type;
  }

  /// Set a value to a single-type data
  @property void setValue(in ch_String value, in ch_ValueType type)
  in (_type == CH_DATA_SINGLE, "Data type is a list or unknown") do {
    _vtype = type;
    _value.single = value;
  }

  // ======================= //
  /* List related functions (TODO) */
  // ======================= //

  /// Append a new data to the list
  void append(in ch_Data data)
  in (_type == CH_DATA_LIST, "Data type is not a list") do {
    if (data.id() in _value.list) return;
    _value.list[data.id()] = data;
  }

  /// Create and append a new data to the list
  void append(in ch_String id, in ch_String value, in ch_ValueType type)
  in (_type == CH_DATA_LIST, "Data type is not a list") do {
    ch_Data data;

    data.setId(id);
    data.setValue(value, type);

    append(data);
  }

  /// Clear the list elements
  @property void clean() in(_type == CH_DATA_LIST, "Data type is not a list") do {
    destroy(_value.list);
  }

  /// The list length
  @property auto length() const in(_type == CH_DATA_LIST, "Data type is not a list") do {
    return _value.list.length;
  }

private:
  /// Data type
  ch_DataType _type = CH_DATA_UNKNOWN;

  /// Value type
  ch_ValueType _vtype = CH_VALUE_UNKNOWN;

  /// Identifier / Name of the data
  ch_String _id;

  union ch_Value {
    ch_String single;
    ch_Data[string] list;
  }

  /// Data value (single or list)
  ch_Value _value;
}

struct ch_Label {
  // ======= //
  /* Getters */
  // ======= //

  @property auto id() const { return _id; }

  @property ch_Data find(in ch_String key) const {
    if (key in _elements) {
      return _elements[key];
    }

    return ch_Data.init;
  }

  // ======= //
  /* Setters */
  // ======= //

  @property void setId(in ch_String id)
  in(id.length > 0, "Passed identifier is empty")
  in (_id != id, "Identifier has no changes") {
    _id = id;
  }

  @property void append(in ch_Data data) {
    auto id = data.id();
    
    if (id in _elements) {
      import std.format : format;
      ch_String error = format("Cannot override '%s'", data.id());
      throw new Exception(error);
    }

    _elements[id] = data;
  }

  @property void clean() {
    _elements = null; // Damn
  }

  @property bool isValid() {
    return _elements.length > 0;
  }

private:
  /// Identifier / Name of the label
  ch_String _id;
  /// All data stored in the label
  ch_Data[ch_String] _elements;
}

struct ch_Engine {
  
  ch_Label getLabel(in ch_String key) {
    if (key !in _labels) return ch_Label.init;
    return _labels[key];
  }

  void clean() {
    foreach (ref label ; _labels) {
      label.clean();
    }

    _labels.clear();
  }

private:
  Parser              _parser;
  ch_Label[ch_String] _labels;
  ch_String           _currentLabel = null;
}

ch_Engine parseCherry(in ch_String source) {
  ch_Engine e;

  // Setup parser
  ch_Result result;
  e._parser.setup(source);

  // Oh my gosh lmao
  do {
    result = e._parser.eval();
    if (!result.isValid) {
      break;
    }

    if (result.isLabel) {
      import std.stdio;
      e._labels[result.getLabel().id()] = result.getLabel();
      e._currentLabel = result.getLabel().id();
    }

    if (!result.isLabel) {
      if (e._currentLabel.length == 0 || e._currentLabel is null)
        throw new Exception("No label detected.");

      e._labels[e._currentLabel].append(result.getData());
    }
  } while (true);

  return e;
}

unittest {
  import std.stdio : writeln, writefln;

  ch_Data number;
  number.setId("My_Number");
  number.setType(CH_DATA_SINGLE);
  number.setValue("180.6", CH_VALUE_NUMBER);

  writefln("Number data identifier: %s\nNumber data type: %s\nNumber data value: %.1f\n",
    number.id(), number.type(), number.getRawNumber());

  auto source =
  "@ User:\n
    SET       \"nonsense_User\", name\n
    Set       18, age\n
  @ Video:\n
    ; Cherry works lmao\n
    set       0.6, brightness\n
    set       Yes, vsync\n";

  // Engine
  ch_Engine engine;
  engine = parseCherry(source);

  auto userLabel = engine.getLabel("User");
  ch_Data username = userLabel.find("name");

  assert(username.id() == "name");
  writeln("User::Name: ", username.getString());

  ch_Data age = userLabel.find("age");
  
  assert(age.getString() != "10");
  writeln("User::Age: ", age.getRawNumber());

  auto videoLabel = engine.getLabel("Video");
  ch_Data brightness = videoLabel.find("brightness");

  assert(brightness.getRawNumber() == 0.6);
  writeln("Video::Brightness: ", brightness.getRawNumber());

  ch_Data vsync = videoLabel.find("vsync");

  assert(vsync.isTrue());
  writeln("Video::Vsync: ", vsync.getString());

  engine.clean();
}