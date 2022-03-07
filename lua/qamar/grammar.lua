local str = "print('hello world')"
local string = require 'toolshed.util.string'
local buffer = require 'qamar.buffer'(string.codepoints(str))

local reserved_keywords = {
    ['and'] = true,
    ['break'] = true,
    ['do'] = true,
    ['else'] = true,
    ['elseif'] = true,
    ['end'] = true,
    ['false'] = true,
    ['for'] = true,
    ['function'] = true,
    ['goto'] = true,
    ['if'] = true,
    ['in'] = true,
    ['local'] = true,
    ['nil'] = true,
    ['not'] = true,
    ['or'] = true,
    ['repeat'] = true,
    ['return'] = true,
    ['then'] = true,
    ['true'] = true,
    ['until'] = true,
    ['while'] = true,
}

local skip_ws_ctr = 0

local function suspend_skip_ws()
    skip_ws_ctr = skip_ws_ctr + 1
end

local function resume_skip_ws()
    if skip_ws_ctr > 0 then
        skip_ws_ctr = skip_ws_ctr - 1
    end
end

local function skipws()
    if skip_ws_ctr == 0 then
        buffer.skipws()
    end
end

local function alt(...)
    skipws()
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

local function opt(x)
    local t = type(x)
    skipws()
    local v
    if t == 'string' then
        v = alt(x)
    elseif t == 'function' then
        t = x()
    else
        return nil
    end
    if v == nil then
        return {}
    end
end

local function zom(x)
    local ret = {}
    local t = type(x)
    while true do
        skipws()
        local v
        if t == 'string' then
            v = alt(x)
        elseif t == 'function' then
            t = x()
        else
            v = nil
        end
        if v == nil then
            return ret
        end
        table.insert(ret, v)
    end
end

local function seq(...)
    local ret = {}
    buffer.begin()
    for _, x in ipairs { ... } do
        skipws()
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

function g.alpha()
    return alt(
        '_',
        'a',
        'b',
        'c',
        'd',
        'e',
        'f',
        'g',
        'h',
        'i',
        'j',
        'k',
        'l',
        'm',
        'n',
        'o',
        'p',
        'q',
        'r',
        's',
        't',
        'u',
        'v',
        'w',
        'x',
        'y',
        'z',
        'A',
        'B',
        'C',
        'D',
        'E',
        'F',
        'G',
        'H',
        'I',
        'J',
        'K',
        'L',
        'M',
        'N',
        'O',
        'P',
        'Q',
        'R',
        'S',
        'T',
        'U',
        'V',
        'W',
        'X',
        'Y',
        'Z'
    )
end

function g.numeric()
    return alt('0', '1', '2', '3', '4', '5', '6', '7', '8', '9')
end

function g.alphanumeric()
    return alt(g.alpha, g.numeric)
end

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

function g.block()
    return seq(zom(g.stat), opt(g.retstat))
end

function g.attnamelist()
    return seq(g.name, g.attrib, zom(seq(',', g.name, g.attrib)))
end

function g.attrib()
    return opt(seq('<', g.name, '>'))
end

function g.retstat()
    return seq('return', opt(g.explist), opt ';')
end

function g.label()
    return seq('::', g.name, '::')
end

function g.funcname()
    return seq(g.name, zom(seq('.', g.name)), opt(seq(':', g.name)))
end

function g.varlist()
    return seq(g.var, zom(seq(',', g.name)))
end

function g.var()
    return alt(g.name, seq(g.prefixexp, '[', g.exp, ']'), seq(g.prefixexp, '.', g.name))
end

function g.namelist()
    return seq(g.name, zom(seq(',', g.name)))
end

function g.explist()
    return seq(g.exp, zom(seq(',', g.exp)))
end

function g.prefixexp()
    return alt(g.var, g.functioncall, seq('(', g.exp, ')'))
end

function g.functioncall()
    return alt(seq(g.prefixexp, g.args), seq(g.prefixexp, ':', g.name, g.args))
end

function g.args()
    return alt(seq('(', g.explist, ')'), g.tableconstructor, g.literalstring)
end

function g.functiondef()
    return seq('function', g.funcbody)
end

function g.funcbody()
    return seq('(', opt(g.parlist), ')', g.block, 'end')
end

function g.parlist()
    return alt(seq(g.namelist, opt(seq(',', '...'))), '...')
end

function g.tableconstructor()
    return seq('{', opt(g.fieldlist), '}')
end

function g.fieldlist()
    return seq(g.field, zom(seq(g.fieldsep, g.field)), opt(g.fieldsep))
end

function g.name()
    suspend_skip_ws()
    buffer.begin()
    skipws()
    local ret = {}
    local t = g.alpha()
    if t == nil then
        buffer.undo()
        resume_skip_ws()
        return nil
    end
    while true do
        table.insert(ret, t)
        t = g.alphanumeric()
        if t == nil then
            break
        end
    end
    ret = table.concat(ret)
    if reserved_keywords[ret] then
        buffer.undo()
        resume_skip_ws()
        return nil
    end
    buffer.commit()
    resume_skip_ws()
    return ret
end

function g.stat()
    return alt(
        ';',
        seq(g.varlist, '=', g.explist),
        g.functioncall,
        g.label,
        'break',
        seq('goto', g.name),
        seq('do', g.block, 'end'),
        seq('while', g.exp, 'do', g.block, 'end'),
        seq('repeat', g.block, 'until', g.exp),
        seq('if', g.exp, 'then', g.block, zom(seq('elseif', g.exp, 'then', g.block)), opt(seq('else', g.block)), 'end'),
        seq('for', g.name, '=', g.exp, ',', g.exp, opt(seq(',', g.exp)), 'do', g.block, 'end'),
        seq('for', g.namelist, 'in', g.explist, 'do', g.block, 'end'),
        seq('function', g.funcname, g.funcbody),
        seq('local', 'function', g.name, g.funcbody),
        seq('local', g.attnamelist, opt(seq('=', g.explist)))
    )
end

function g.exp()
    -- TODO: implement expression parser
    -- exp ::=  nil | false | true | Numeral | LiteralString | ‘...’ | functiondef | prefixexp | tableconstructor | exp binop exp | unop exp
end

function g.numeral()
    -- TODO: implement numeral parser
end

function g.literalstring()
    -- TODO: implement numeral parser
end

return g
