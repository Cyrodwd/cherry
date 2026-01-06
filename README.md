# cherry

random configuration language written in D

Use ';' to write a single line comment.

## ch_Data
Data, literally. Can be a string or a number (double).

### Functions
`id()` - Identifier or name of the data
`type()` - Type (Single, List)
`getString()` - Only works if the data type is "single". It works with both numbers
and strings.

`valueType()` - Value type (boolean, number or string)

`getRawNumber()` - Converts the digits into a native D numeric value (double).
Can throw a generic exception.

`isTrue()` - If it is a Boolean, it returns its value (in this case, `YES` = true, `NO` = false).

You know what? It's better to look directly at the source code, it's very simple.
In fact, it's not finished yet. It's in an early stage, some features are missing, and many edge cases haven't been tested yet.

Managing exceptions can be cumbersome due to the way the API handles them.
Directly: It's quite experimental.
