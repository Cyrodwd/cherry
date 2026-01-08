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
/// Type of the value
enum ch_ValueType {
  Unknown = 0,
  Boolean,
  Number,
  String,
}

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

  /// Data value - as a string
  @property auto getString() const
  do { return _value; }

  @property auto valueType() const
  do { return _vtype; }

  /// Converts the digits into a native D numeric value (double).
  /// It only works if the value can be converted as a number
  /// Can throw exceptions if the value can't be converted to a ch_Number type (double)
  @property auto getRawNumber() const
  in (_vtype == CH_VALUE_NUMBER, "Data value is not a number")
  do {
    import std.conv : to;
    return _value.to!ch_Number;
  }

  @property bool isNegative() const
  in (_vtype == CH_VALUE_NUMBER, "Data value is not a number")
  do {
    // Well ... this works cuz '-' only works for numbers, and they cannot be
    // in other position than at the beginning.... 
    return _value.length > 0 && _value[0] == '-';
  }

  /// If it is a Boolean, it returns its value (in this case, `YES` = true, `NO` = false).
  @property bool isTrue() const
  in (_vtype == CH_VALUE_BOOLEAN, "Data value is not a boolean") {
    // Actually, this works! (Only for YES / NO)
    // I did this cuz since keywords are case-insensitive, it would be
    // stupid to compare each possible combination of 'YES'
    // So ... this is more direct.
    return _value.length == 3; // As 'yes' has three characters... lmto.
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

  /// Set a value to a single-type data
  @property void setValue(in ch_String value, in ch_ValueType type)
  do {
    _vtype = type;
    _value = value;
  }

private:
  /// Value type
  ch_ValueType _vtype = CH_VALUE_UNKNOWN;

  /// Identifier / Name of the data
  ch_String _id;
  ch_String _value;
}

struct ch_Label {
  // ======= //
  /* Getters */
  // ======= //

  @property auto id() const { return _id; }

  @property ch_Data getData(in ch_String key) const {
    if (key in _elements) {
      return _elements[key];
    }

    return ch_Data.init;
  }

  @property ch_List getList(in ch_String key) {
    if (key in _lists)
      return _lists[key];
    
    return ch_List.init;
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

  @property void append(ch_List list) {
    auto id = list.id();
    _lists[id] = list;
  }

  @property void clean() {
    _elements = null; // Damn
  }

  @property bool isValid() {
    return _elements.length > 0 || _lists.length > 0;
  }

private:
  /// Identifier / Name of the label
  ch_String _id;
  /// All data stored in the label
  ch_Data[ch_String] _elements;
  ch_List[ch_String] _lists;
}

struct ch_List {

  // ======================= //
  /* List related functions (TODO) */
  // ======================= //

   /// Identifier / Name of the data
  @property auto id() const { return _id; }

  @property void setId(in ch_String id)
  in(id.length > 0, "Passed identifier is empty")
  in (_id != id, "Identifier has no changes") {
    _id = id;
  }

  /// Append a new data to the list
  void append(ch_String str)
  do {
    if (str.length == 0 || str is null) {
      return;
    }

    _list ~= str;
  }

  /// Clear the list elements
  @property void clean() do {
    // destroy(_list);
  }

  /// The list length
  @property auto length() const do {
    return _list.length;
  }

  /***
    * Converts the value of an element into a number (double), starting the index from zero.
    * NOTE: Can throw exceptions.
    */ 
  @property ch_Number getNumber(in ulong index) const in (length() > 0, "List is empty")  {
    import std.conv : to;

    if (index >= _list.length) return 0;
    return _list[index].to!double;
  }

  /// Get the string value of an element, starting the index from zero.
  @property ch_String getString(in ulong index) const in (length() > 0, "List is empty") do {
    if (index >= _list.length) return null;
    return _list[index];
  }

private:
  /// List lmao
  ch_String        _id;
  ch_String[]     _list;
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

/***
 * Parse a full cherry configuration
 *
 * If, at the beginning of an instruction, a token is found that the parser cannot start with, it may
 * not throw any error. However, be sure to check that the data you are requesting is 
 * valid, because if it does not find valid tokens to start with, 
 * it will return an empty (invalid) result.
 * Params:
 *   source = Configuration source
 * Returns: A result (ch_Result). If a token is not valid to begin, then it returns an invalid result
 */
ch_Engine parseCherry(in ch_String source) {
  ch_Engine e;

  // Setup parser
  ch_Result result;
  e._parser.setup(source);

  // holyC o_O what i've done
  do {
    result = e._parser.eval();
    if (!result.isValid) {
      break;
    }

    if (result.type == ResultType.Label) {
      import std.stdio;
      e._labels[result.getLabel().id()] = result.getLabel();
      e._currentLabel = result.getLabel().id();
    } else {
      // Data and list
      if (e._currentLabel.length == 0 || e._currentLabel is null)
        throw new Exception("No label detected.");

      // Data or list :(
      if (result.type == ResultType.Data)
        e._labels[e._currentLabel].append(result.getData());
      else if (result.type == ResultType.List)
        e._labels[e._currentLabel].append(result.getList());
    }
  } while (true);

  return e;
}

// List and data
unittest
{
  ch_List list;
  // Crap
  list.append("Dumbass");
  list.append("230");
  list.append("8.5");
  list.append("YES");

  assert(list.length == 4, "List isn't appending correctly");
  assert(list.getString(index: 0) == "Dumbass");
  assert(list.getNumber(index: 1) == 230);
  list.clean();
}
