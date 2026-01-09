module internal.api;

import std.conv : to, ConvException;
import std.stdio : writefln;

import internal.parser;

/** 
 * Cherry (Configuration format) @2026
 * Cyrodwd - Bjankadev
 */

/// Type of the value
enum chValueType {
  Unknown = 0,
  Boolean,
  Number,
  String,
}

/// An alias to `ch_ValueType.Unknown`
alias CH_VALUE_UNKNOWN = chValueType.Unknown;
/// An alias to `ch_ValueType.Boolean`
alias CH_VALUE_BOOLEAN = chValueType.Boolean;

/// An alias to `ch_ValueType.Integer`
alias CH_VALUE_NUMBER = chValueType.Number;

/// An alias to `ch_ValueType.String`
alias CH_VALUE_STRING = chValueType.String;

/* Structs */

/// Struct of a data
struct chData {
  // ======= //
  /* Getters */
  // ======= //

  /// Identifier / Name of the data
  @property auto id() const { return _id; }

  @property auto valueType() const
  do { return _vtype; }

  /// Data value - as a string
  @property auto toString() const @safe
  do { return _value; }

  // Signed values
  mixin convertInto!(byte, "toByte");
  mixin convertInto!(short, "toShort");
  mixin convertInto!(int, "toInt");
  mixin convertInto!(long, "toLong");

  // Unsigned values
  mixin convertInto!(ubyte, "toUnsignedByte");
  mixin convertInto!(ushort, "toUnsignedShort");
  mixin convertInto!(uint, "toUnsigned");
  mixin convertInto!(ulong, "toUnsignedLong");

  // Floating-point values
  mixin convertInto!(float, "toFloat");
  mixin convertInto!(double, "toDouble");
  mixin convertInto!(real, "toReal");

  /// If it is a Boolean, it returns its value (in this case, `YES` = true, `NO` = false).
  @property bool isTrue() const
  in (_vtype == CH_VALUE_BOOLEAN, "Data value is not a boolean") {
    // Actually, this works! (Only for YES / NO)
    // I did this cuz since keywords are case-insensitive, it would be
    // stupid to compare each possible combination of 'YES'
    // So ... this is more direct.
    return _value.length == 3; // As 'yes' has three characters... lmto.
  }

  /// Is it a negative number?
  @property bool isNegative() const
  in (_vtype == CH_VALUE_NUMBER, "Data value is not a number")
  do {
    // Well ... this works cuz '-' only works for numbers, and they cannot be
    // in other position than at the beginning.... 
    return _value.length > 0 && _value[0] == '-';
  }

  // ======= //
  /* Setters */
  // ======= //

  /// Set an identifier for the data
  @property void setId(in string id)
    in (id.length > 0, "Passed identifier is empty") // First assert
    in (_id != id, "You're passing the same identifier") // Second assert
    do {
      _id = id;
    }

  /// Set a value to a single-type data
  @property void setValue(in string value, in chValueType type)
  do {
    _vtype = type;
    _value = value;
  }

private:
  /// Value type
  chValueType _vtype = CH_VALUE_UNKNOWN;

  /// Identifier / Name of the data
  string _id;
  string _value;

  mixin template convertInto(T, string id) if (!is(T : string)) {
    mixin ("@property ", T, " ", id, "() const in (_vtype == CH_VALUE_NUMBER, \"Data value is not a number\")
    do {
      ", T, " result = ", T, ".init;

      try
        result = _value.to!",T,";
      catch (ConvException ce)
        writefln(\"Cannot convert data into ", T, ": %s\", ce.msg);
      
      return result;
    }");
  }
}

struct chLabel {
  // ======= //
  /* Getters */
  // ======= //

  @property auto id() const { return _id; }

  @property chData getData(in string key) const {
    if (key in _elements) {
      return _elements[key];
    }

    return chData.init;
  }

  @property chList getList(in string key) {
    if (key in _lists)
      return _lists[key];
    
    return chList.init;
  }

  // ======= //
  /* Setters */
  // ======= //

  @property void setId(in string id)
  in(id.length > 0, "Passed identifier is empty")
  in (_id != id, "Identifier has no changes") {
    _id = id;
  }

  /// Append data
  @property void append(in chData data) {
    auto id = data.id();
    
    if (id in _elements) {
      import std.format : format;

      string error = format("Cannot override '%s'", data.id());
      throw new Exception(error);
    }

    _elements[id] = data;
  }

  /// Append a list
  @property void append(chList list) {
    auto id = list.id();
    _lists[id] = list;
  }

  /// Basically checks if the listarray has elements.
  /// If `elements` is zero or less, then it checks if the label has lists in general.
  /// If `elements` is specified, it will check if this labels has EXACTLY that count}
  /// By default, `elements` is set as zero (general check).
  @property size_t hasLists(int elements = 0) const {
    if (elements <= 0) return _lists.length > 0;
    return _lists.length == elements;
  }

  /// Basically checks if the data array has elements.
  /// If `elements` is zero or less, then it checks if the label has lists in general.
  /// If `elements` is specified, it will check if this labels has EXACTLY that count
  /// By default, `elements` is set as zero (general check).
  @property size_t hasData(int elements = 0) const {
    if (elements <= 0) return _elements.length > 0;

    return _elements.length == elements;
  }

  /// Clean elements
  @property void clean() {
    _elements = null; // Damn
  }

  /// Has elements or lists?
  @property bool isValid() {
    return hasData() || hasLists();
  }

private:
  /// Identifier / Name of the label
  string _id;
  /// All data stored in the label
  chData[string] _elements;
  chList[string] _lists;
}

struct chList {

  // ======================= //
  /* List related functions (TODO) */
  // ======================= //

   /// Identifier / Name of the data
  @property auto id() const { return _id; }

  @property void setId(in string id)
  in(id.length > 0, "Passed identifier is empty")
  in (_id != id, "Identifier has no changes") {
    _id = id;
  }

  /// Append a new data to the list
  void append(string str)
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

  // Signed values
  mixin convertInto!(byte, "toByte");
  mixin convertInto!(short, "toShort");
  mixin convertInto!(int, "toInt");
  mixin convertInto!(long, "toLong");

  // Unsigned values
  mixin convertInto!(ubyte, "toUnsignedByte");
  mixin convertInto!(ushort, "toUnsignedShort");
  mixin convertInto!(uint, "toUnsigned");
  mixin convertInto!(ulong, "toUnsignedLong");

  // Floating-point values
  mixin convertInto!(float, "toFloat");
  mixin convertInto!(double, "toDouble");
  mixin convertInto!(real, "toReal");

  /// Get the string value of an element, starting the index from zero.
  @property string toString(in ulong index) const in (length() > 0, "List is empty") do {
    if (index >= _list.length) {
      indexErrorMsg(index);
      return null;
    }

    return _list[index];
  }

private:
  /// List lmao
  string        _id;
  string[]     _list;

  void indexErrorMsg(in ulong i) const {
    writefln("Index '%u' exceeds the length of the list", i);
  }

  mixin template convertInto(T, string id) {
    mixin("@property ", T, " ", id, "(in ulong index) const in (length() > 0, \"List is empty\") {
      if (index >= _list.length) {
        indexErrorMsg(index);
        return ", T, ".init;
      }
      ", T, " result = ", T, ".init;
      try
        result = _list[index].to!", T, ";
      catch (ConvException ce)
        writefln(\"Cannot convert into ", T, ": %s\", ce.msg);
      
      return result;
    }");
  }
}

struct chEngine {
  
  /// Gets a label
  chLabel getLabel(in string key) {
    if (key !in _labels) return chLabel.init;
    return _labels[key];
  }

  /// Clean???
  void clean() {
    foreach (ref label ; _labels) {
      label.clean();
    }

    _labels.clear();
  }

private:
  Parser              _parser;
  chLabel[string] _labels;
  string           _currentLabel = null;
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
 * Returns: An engine with labels
 */
chEngine parseCherry(in string source) {
  chEngine e;

  // Setup parser
  chResult result;
  e._parser.setup(source);

  // holyC o_O what i've done
  do {
    result = e._parser.eval();

    // EOF
    if (result.type == ResultType.Eof) break;

    // An invalid result
    if (!result.isValid) {
      writefln("Warning: got an invalid result from [%d:%d]", e._parser.line(), e._parser.row());
      break;
    }

    if (result.type == ResultType.Label) {
      e._labels[result.getLabel().id()] = result.getLabel();
      e._currentLabel = result.getLabel().id();
    } else {
      // Data and list
      if (e._currentLabel.length == 0 || e._currentLabel is null)
      {
        writefln("Engine error: No label detected for '%s'.",
          result.type == ResultType.Data ? result.getData().id() : result.getList.id());
        continue;
      }

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
  chList list;
  // Crap
  list.append("String");
  list.append("230");
  list.append("8.5");
  list.append("YES");

  assert(list.length == 4, "List isn't appending correctly");
  assert(list.toString(index: 0) == "String");
  assert(list.toInt(index: 1) == 230);
  list.clean();
}
