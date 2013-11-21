### Cyan ###

Cyan is a table serialization library that is fast (LPeg), free (as always for my libraries), and far more flexible than JSON or even Lua table syntax. Besides all that, the Cyan library is only one file, and depends only on LPeg.

#### Installing Cyan ####

For [Corona SDK](http://www.coronalabs.com) users, all you need to do is download the ZIP, copy `cyan.lua` into your project, and start using it (Corona already has LPeg in the package).

If you're using "raw" Lua, the same procedure applies, but you'll need to include the LPeg library from [here](http://www.inf.puc-rio.br/~roberto/lpeg/) to run Cyan.

#### Usage #####

Reading Cyan strings:
```Lua
local cyan = require("cyan")
local cyanString = "key -> value"
local t = cyan.read(cyanString)
print(t.key) --> "value"
```
For users of Corona SDK, Cyan provides a function named `readFile` that simplifies reading from files.
```Lua
local cyan = require("cyan")
local t = cyan.readFile("cyanFile.cy", system.DocumentsDirectory)
```

Writing Cyan strings:
```Lua
local cyan = require("cyan")
local t = {
	this = "that",
	that = "this"
}
local cyanString = cyan.write(t)
print(cyanString) --> "this -> that that -> this"

local compressedCyan = cyan.write(t, "compressed")
print(compressedCyan) --> "this>that that>this"
```

#### Syntax ####

Each key/value pair in Cyan conforms to `key -> value`, where the "shaft" of the arrow can be any length, even zero, and the white space between elements and the arrow is optional.

The base table may not have brackets around it (usually denoting a table). For example, the following will work:
```
key1 -> value1
key2 -> value2
```
But not this:
```
[
	key1 -> value1
	key2 -> value2
]
```

Keys and values are equivalent; any type that can be a value can also be a key. This means you can use Booleans or even tables as keys.

##### Types #####

Overview of valid Cyan types.

###### Numbers ######
```
55
120.995
-5922
.99
0.665799
-.8
66e9
59e+9
3e-19
2E6
8E-9
2E+95
```

###### Booleans #######
```
true
yes
false
no
```
Both `true` or `yes` are both evaluated to `true`; the same applies for `false` and `no`.

###### Tables ######
```
[(cyan notation)]
[
	(cyan notation)
]
[              (cyan notation)              ]
```
Note that the base-level table may not have brackets around it.

###### Strings ######
Strings with no whitespace and not **beginning** with single or double quotation marks may omit the quotation marks.
```
abc
a-b-c
a`1234567890b~!@#$%^&*()_c'";A
a"b"c
```
Strings containing whitespace must be enclosed in one of the three quote styles.
```
"a b c"
'a b c'
"{ a b c}"
"
ab c
"
'
a b
c'
"{
a
bc}"
```
The Cyan escape character is a tilde `~`, and will not be read if the character following it is a quotation character that matches the style for the current string.
```
"a b ~" c"
'a b ~' c'
"{a b ~}" c}"
```

###### Comments ######
Comments in a Cyan string are ignored. Here are the comment formats:
```
!! Single-line comment; reads to end of line

!{
Block comment; reads to closing brace + exclamation mark.
}!

!{
Cyan block comments read to balanced comment symbols. This means that any internal block comments will be ignored until the ending one:

!{
I'm also ignored...
}!

This also means unclosed internal block comments will result in failure to parse the data.
}!

!! Declaration comment (the next key/value pair is completely ignored):

!! key -> value
!! key2 -> [
	abc -> 123
]

!! Both of the above keys/values will not be included in the resulting table
```

#### Why the Repository? ####

If Cyan is only a table serialization library, and built up of one file, why use an entire GitHub repository for it? I'm planning on making another version of Cyan that is a mini-language, with variables and math evaluation. Note that this is likely not something that will happen soon, though.
