local str = "print('hello world')"
local string = require 'toolshed.util.string'
local buffer = require 'qamar.buffer'(string.codepoints(str))

local function alt(...)
    for _, s in ipairs { ... } do
        local t = type(s)
        if t == 'string' then
            if buffer.tryConsumeString(s) then
                return s
            end
        elseif t == 'function' then
            t = t()
            if t ~= nil then
                return t
            end
        end
    end
end

local function seq(...)
    local ret = {}
    buffer.begin()
    for _, x in ipairs { ... } do
        buffer.skipws()
        local t = type(x)
        if t == 'function' then
            t = t()
        elseif t == 'string' then
            t = alt(t)
        else
            t = nil
        end
        if t == nil then
            buffer.undo()
            return nil
        end
        table.insert(ret, t)
    end
    buffer.commit()
    return ret
end

local g = {}

function g.unop()
    return alt('-', 'not', '#', '~')
end

function g.binop()
    return alt('+', '-', '*', '/', '//', '^', '%', '&', '~', '|', '>>', '<<', '..', '<', '<=', '>', '>=', '==', '~=', 'and', 'or')
end

function g.fieldsep()
    return alt(',', ';')
end

function g.field()
    return alt(seq('[', g.exp, ']', '=', g.exp), seq(g.name, '=', g.exp), g.exp)
end

function g.chunk()
    return g.block()
end

local _grammar = [[
	block ::= {stat} [retstat]

	stat ::=  ‘;’ | 
		 varlist ‘=’ explist | 
		 functioncall | 
		 label | 
		 break | 
		 goto Name | 
		 do block end | 
		 while exp do block end | 
		 repeat block until exp | 
		 if exp then block {elseif exp then block} [else block] end | 
		 for Name ‘=’ exp ‘,’ exp [‘,’ exp] do block end | 
		 for namelist in explist do block end | 
		 function funcname funcbody | 
		 local function Name funcbody | 
		 local attnamelist [‘=’ explist] 

	attnamelist ::=  Name attrib {‘,’ Name attrib}

	attrib ::= [‘<’ Name ‘>’]

	retstat ::= return [explist] [‘;’]

	label ::= ‘::’ Name ‘::’

	funcname ::= Name {‘.’ Name} [‘:’ Name]

	varlist ::= var {‘,’ var}

	var ::=  Name | prefixexp ‘[’ exp ‘]’ | prefixexp ‘.’ Name 

	namelist ::= Name {‘,’ Name}

	explist ::= exp {‘,’ exp}

	exp ::=  nil | false | true | Numeral | LiteralString | ‘...’ | functiondef | 
		 prefixexp | tableconstructor | exp binop exp | unop exp 

	prefixexp ::= var | functioncall | ‘(’ exp ‘)’

	functioncall ::=  prefixexp args | prefixexp ‘:’ Name args 

	args ::=  ‘(’ [explist] ‘)’ | tableconstructor | LiteralString 

	functiondef ::= function funcbody

	funcbody ::= ‘(’ [parlist] ‘)’ block end

	parlist ::= namelist [‘,’ ‘...’] | ‘...’

	tableconstructor ::= ‘{’ [fieldlist] ‘}’

	fieldlist ::= field {fieldsep field} [fieldsep]

]]
return g
