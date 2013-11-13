--------------------------------------------------------------------------------
-- Cyan Library
--------------------------------------------------------------------------------
local cyan = {}

--------------------------------------------------------------------------------
-- Localize
--------------------------------------------------------------------------------
local table_insert = table.insert
local table_concat = table.concat
local tonumber = tonumber
local tostring = tostring
local pairs = pairs
local type = type
local getFileContents = function(filename, base) local base = base or system.ResourceDirectory local path = system.pathForFile(filename, base) local contents local file = io.open(path, "r") if file then contents = file:read("*a") io.close(file) file = nil end return contents end

--------------------------------------------------------------------------------
-- Set Up LPeg
--------------------------------------------------------------------------------
local lpeg = require("lpeg")
local P = lpeg.P
local R = lpeg.R
local S = lpeg.S
local C = lpeg.C
local Cs = lpeg.Cs
local Ct = lpeg.Ct
local V = lpeg.V


--------------------------------------------------------------------------------
--[[
Cyan Reader

v1.0

Transforms Cyan strings into tables.
--]]
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Minor Patterns
--------------------------------------------------------------------------------
local any = P(1)
local nothing = P(0)
local escape = P("~")
local ws = S(" \n\t")
local whitespace = ws ^ 0
local whitespace_singleline = S(" \t") ^ 0

--------------------------------------------------------------------------------
-- Type Generators (string to type)
--------------------------------------------------------------------------------
-- "true"/"false" -> true/false
local _boolean = function(str) if str == "false" then return false else return true end end

-- "123" -> 123
local _number = tonumber

-- "[a -> 1]" -> {a = 1}
local _table = function(t) t = t:match("%[(.+)%]") return cyan.read(t) end

-- ""abc"" -> "abc"
local _string = function(str) if str:match("^\".-\"$") then str = str:sub(2, -2) end return str end


--------------------------------------------------------------------------------
-- Pattern Functions
--------------------------------------------------------------------------------
-- Matches: [s] ... [e] balanced
local function balanced(s, e)
	local s = P(s)
	
	local pat = P(
		{s * ((any - (s + e)) + V(1)) ^ 0 * e}
	)

	return pat
end

-- Matches: [s] ... [e]
local function start_end(s, e)
	local content = (any - e) ^ 0

	local pat = s * content * e

	return pat
end

-- Matches: [s] ... [e], ignoring escaped characters
local function start_end_escaped(s, ...)
	local e = P(arg[1])
	for i = 2, #arg do
		e = e + P(arg[i])
	end

	local unescaped_start = -escape * s
	local unescaped_end = -escape * e
	local escaped_end = escape * C(e)
	local content = Ct((C(any - unescaped_end - escape) + escaped_end + C(escape)) ^ 0) / table_concat

	local pat = unescaped_start * content * unescaped_end

	return pat
end

-- Matches [p] anywhere
local function anywhere(p) return (any - p) ^ 0 * p end

--------------------------------------------------------------------------------
-- Actual Patterns
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Arrows
--------------------------------------------------------------------------------
local arrow = {}
	arrow.unescaped_dash = -escape * "-"
	arrow.point = P(">")
	arrow.arrow = arrow.unescaped_dash ^ 0 * arrow.point

--------------------------------------------------------------------------------
-- Numbers
--------------------------------------------------------------------------------
local numbers = {}
	local digit = R("09")

	numbers.integer =
		(S("+-") ^ -1) *
		(digit   ^  1)
	numbers.fractional =
		(P(".")   ) *
		(digit ^ 1)
	numbers.decimal =	
		(numbers.integer *              -- Integer
		(numbers.fractional ^ -1)) +    -- Fractional
		(S("+-") * numbers.fractional)  -- Completely fractional number
	numbers.scientific = 
		numbers.decimal *  -- Decimal number
		S("Ee") *          -- E or e
		numbers.integer    -- Exponent
	numbers.number =
		numbers.decimal + numbers.scientific -- Decimal number allows for everything else and scientific matches scientific

--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------
local types = {}
	types.string_singlequoted = start_end_escaped("'", "'")
	types.string_doublequoted = start_end_escaped("\"", "\"")
	types.string_strong = start_end_escaped("\"{", "}\"")
	types.string_singleword = C((any - ws) ^ 1)
	types.string_singleword_noarrow = C((any - ws - arrow.arrow) ^ 1)
	types.string_generic = (types.string_strong + types.string_singlequoted + types.string_doublequoted)
	types.string = (types.string_strong + types.string_singlequoted + types.string_doublequoted + types.string_singleword) / _string
	types.string_noarrow = (types.string_generic + types.string_singleword_noarrow) / _string

	types.number = numbers.number / _number

	types.boolean = ((P("true") + P("yes")) / "true" + (P("false") + P("no")) / "false") / _boolean * ws

	types.table = balanced("[", "]") / _table

	types.type = (types.boolean + types.number +  types.table)
	types.type_key = types.type + types.string_noarrow
	types.type = types.type + types.string

--------------------------------------------------------------------------------
-- Declaration
--------------------------------------------------------------------------------
local declare = {}

declare.name_typed = types.type_key
declare.name_floating = C((any - ws - arrow.arrow) ^ 1)

declare.name =
	declare.name_typed +
	declare.name_floating

declare.declare_kv =
	Ct(
		declare.name * whitespace *
		arrow.arrow * whitespace *
		types.type
	) / function(t) t.type = "kv" return t end

declare.declare_index =
	(
		(P("@") * whitespace * types.type) +
		(types.type * whitespace * P(";"))
	) / function(s) return {s, type = "index"} end

declare.declare = declare.declare_kv + declare.declare_index

--------------------------------------------------------------------------------
-- Comments
--------------------------------------------------------------------------------
local comment = {}
	comment.line = start_end("!!", "\n", "") / "" -- Single-line comment
	comment.block = balanced("!{", "}!") / "" -- Block comment
	comment.declare = (P("!!") * whitespace_singleline * declare.declare) / "" -- Commented-out declare statement
	comment.comment =
		comment.declare + -- First comes declare, so we don't get line comments for commented declarations
		comment.block +   -- Then comes block, so the { isn't ignored
		comment.line      -- Last of all comes line comments

--------------------------------------------------------------------------------
-- Element
--------------------------------------------------------------------------------
local element =
	whitespace * (
		comment.declare +
		declare.declare +
		comment.comment
	)

--------------------------------------------------------------------------------
-- Master Pattern
--------------------------------------------------------------------------------
local master = whitespace * Ct(element ^ 0) * whitespace

--------------------------------------------------------------------------------
-- String to Table
--------------------------------------------------------------------------------
function cyan.read(str)
	local str = str

	local matches = master:match(str)

	local t = {}
	local index = 1

	for i = 1, #matches do
		if matches[i] ~= "" then
			if matches[i].type == "kv" then
				t[matches[i][1] ] = matches[i][2]
			elseif matches[i].type == "index" then
				t[index] = matches[i][1]
				index = index + 1
			end
		end
	end

	return t
end

function cyan.readFile(filename, base)
	local contents = getFileContents(filename, base)
	return cyan.read(contents)
end



--------------------------------------------------------------------------------
--[[
Cyan Writer

v1.0

Writes Cyan strings, given a table as the argument.
--]]
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Cyan Writing Patterns
--------------------------------------------------------------------------------
local escape_double_quotes = Cs((P("\"") / "~\"" + 1) ^ 0)
local arrow_anywhere = anywhere(arrow.arrow)

--------------------------------------------------------------------------------
-- Process String
--------------------------------------------------------------------------------
local function processValue(val, mode, _type)
	local _type = _type or type(val)

	if _type == "number" then
		return val
	elseif _type == "boolean" then
		return tostring(sval)
	elseif _type == "string" then
		if types.string_singleword:match(val) == val and arrow_anywhere:match(val) == nil then
			return val
		else
			return "\"" .. escape_double_quotes:match(val) .. "\""
		end
	elseif _type == "table" then
		return "[ " .. cyan.write(val, mode) .. "]"
	end
end

--------------------------------------------------------------------------------
-- Table to String
--------------------------------------------------------------------------------
function cyan.write(t, mode)
	local write = {}

	local arrow
	if mode == "compressed" then
		arrow = ">"
	else
		arrow = " -> "
	end

	local index = 1

	for k, v in pairs(t) do
		local kType = type(k)
		local _k = processValue(k, mode, kType)
		local _v = processValue(v, mode)

		if kType ~= "number" then
			table_insert(write, _k)
			table_insert(write, arrow)
		else
			if index == k then
				table_insert(write, "@")
				index = index + 1
			else
				table_insert(write, _k)
				table_insert(write, arrow)
			end
		end

		table_insert(write, _v)
		table_insert(write, " ")
	end

	return table_concat(write)
end

return cyan