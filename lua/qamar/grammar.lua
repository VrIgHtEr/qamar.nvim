local str = "print('hello world')"
local string = require 'toolshed.util.string'
local buffer = require 'qamar.buffer'(string.filteredcodepoints(str))

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

local precedence = {
    { 'or' },
    { 'and' },
    { '<', '>', '<=', '>=', '~=', '==' },
    { '|' },
    { '~' },
    { '&' },
    { '<<', '>>' },
    { '..' },
    { '+', '-' },
    { '*', '/', '//', '%' },
    { 'not', '#', '-', '~' },
    { '^' },
}
local unary_precedence = 11

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
        -- TODO: handle comments here
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
    buffer.begin()
    skipws()
    suspend_skip_ws()
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
    return alt(
        'nil',
        'false',
        'true',
        g.numeral,
        g.literalstring,
        '...',
        g.functiondef,
        g.prefixexp,
        g.tableconstructor,
        seq(g.exp, g.binop, g.exp),
        seq(g.unop, g.exp)
    )
    -- TODO: implement expression parser
end

function g.numeral()
    -- TODO: implement numeral parser
end

local function tohexdigit(c)
    if c == '0' or c == '1' or c == '2' or c == '3' or c == '4' or c == '5' or c == '6' or c == '7' or c == '8' or c == '9' then
        return string.byte(c) - 48
    elseif c == 'a' or c == 'b' or c == 'c' or c == 'd' or c == 'e' or c == 'f' then
        return string.byte(c) - 87
    elseif c == 'a' or c == 'b' or c == 'c' or c == 'd' or c == 'e' or c == 'f' then
        return string.byte(c) - 55
    end
end

local function todecimaldigit(c)
    if c == '0' or c == '1' or c == '2' or c == '3' or c == '4' or c == '5' or c == '6' or c == '7' or c == '8' or c == '9' then
        return string.byte(c) - 48
    end
end

local hex_to_binary_table = { '0000', '0001', '0010', '0011', '0100', '0101', '0110', '0111', '1000', '1001', '1010', '1011', '1100', '1101', '1110', '1111' }
local function utf8_encode(hex)
    if #hex > 0 then
        local binstr = {}
        for i, x in hex do
            binstr[i] = hex_to_binary_table[x + 1]
        end
        binstr = table.concat(binstr)
        local len, idx = string.len(binstr), binstr:find '1'
        if not idx then
            return string.char(0)
        elseif len ~= 32 or idx ~= 1 then
            local bits = len + 1 - idx
            binstr = string.sub(binstr, bits)
            if bits <= 7 then
                return string.char(tonumber(bits, 2))
            else
                local cont_bytes, rem, max
                if bits <= 6 * 1 + 5 then
                    cont_bytes, rem, max = 1, 5, 6 * 1 + 5
                elseif bits <= 6 * 2 + 4 then
                    cont_bytes, rem, max = 2, 4, 6 * 2 + 4
                elseif bits <= 6 * 3 + 3 then
                    cont_bytes, rem, max = 3, 3, 6 * 3 + 3
                elseif bits <= 6 * 4 + 2 then
                    cont_bytes, rem, max = 4, 2, 6 * 4 + 2
                elseif bits <= 6 * 5 + 1 then
                    cont_bytes, rem, max = 5, 1, 6 * 5 + 1
                end
                local ret = {}
                while bits < max do
                    binstr = '0' .. binstr
                    bits = bits + 1
                end
                local s = ''
                for _ = 1, 7 - rem do
                    s = '1' .. s
                end
                s = '0' .. s
                s = s .. string.sub(binstr, 1, rem)
                table.insert(ret, string.char(tonumber(s, 2)))
                binstr = string.sub(binstr, rem + 1)
                for x = 1, cont_bytes * 6 - 1, 6 do
                    table.insert(ret, string.char(tonumber('10' .. string.sub(binstr, x, x + 5), 2)))
                end
                return table.concat(ret)
            end
        end
    end
end

function g.literalstring()
    buffer.begin()
    buffer.skipws()
    suspend_skip_ws()
    local function fail()
        buffer.undo()
        resume_skip_ws()
    end
    local ret = {}

    local t = alt("'", '"')
    if t then
        while true do
            local c = buffer.take()
            if c == t then
                break
            elseif c == '\\' then
                c = buffer.take()
                if c == 'a' then
                    table.insert(ret, '\a')
                elseif c == 'b' then
                    table.insert(ret, '\b')
                elseif c == 'f' then
                    table.insert(ret, '\f')
                elseif c == 'n' then
                    table.insert(ret, '\n')
                elseif c == 'r' then
                    table.insert(ret, '\r')
                elseif c == 't' then
                    table.insert(ret, '\t')
                elseif c == 'v' then
                    table.insert(ret, '\v')
                elseif c == '\\' then
                    table.insert(ret, '\\')
                elseif c == '"' then
                    table.insert(ret, '"')
                elseif c == "'" then
                    table.insert(ret, "'")
                elseif c == '\n' then
                    table.insert(ret, '\n')
                elseif c == 'z' then
                    buffer.skipws()
                elseif c == 'x' then
                    local c1 = tohexdigit(buffer.take())
                    local c2 = tohexdigit(buffer.take())
                    if not c1 or not c2 then
                        return fail()
                    end
                    table.insert(ret, string.char(c1 * 16 + c2))
                elseif c == 'u' then
                    if buffer.take() ~= '{' then
                        return fail()
                    end
                    local digits = {}
                    while #digits < 8 do
                        local nextdigit = tohexdigit(buffer.peek())
                        if not nextdigit then
                            break
                        end
                        buffer.take()
                        table.insert(digits, nextdigit)
                    end
                    if buffer.take() ~= '}' then
                        return fail
                    end
                    local s = utf8_encode(digits)
                    if not s then
                        return fail()
                    end
                    table.insert(ret, s)
                elseif c == '0' or c == '1' or c == '2' or c == '3' or c == '4' or c == '5' or c == '6' or c == '7' or c == '8' or c == '9' then
                    local digits = { todecimaldigit(c) }
                    while #digits < 3 do
                        local nextdigit = todecimaldigit(buffer.peek())
                        if not nextdigit then
                            break
                        end
                        buffer.take()
                        table.insert(digits, nextdigit)
                    end
                    local num = 0
                    for _, d in ipairs(digits) do
                        num = num * 10 + d
                    end
                    if num > 255 then
                        return fail()
                    end
                    table.insert(ret, string.char(num))
                else
                    return fail()
                end
            elseif c == '\n' or c == '' then
                return fail()
            else
                table.insert(ret, c)
            end
        end
    else
        t = seq('[', zom '=', '[')
        if t then
            local closing = { ']' }
            for _ = 1, #t[2] do
                table.insert(closing, '=')
            end
            table.insert(closing, ']')
            closing = table.concat(closing)
            if buffer.peek() == '\n' then
                buffer.take()
            end
            while true do
                local closed = buffer.tryConsumeString(closing)
                if closed then
                    break
                end
                t = buffer.take()
                if t == '' then
                    return fail()
                elseif t == '\r' then
                    t = buffer.peek()
                    if t == '\n' then
                        buffer.take()
                    end
                    table.insert(ret, '\n')
                elseif t == '\n' then
                    if t == '\r' then
                        buffer.take()
                    end
                    table.insert(ret, '\n')
                end
            end
        else
            return fail()
        end
    end
    buffer.commit()
    resume_skip_ws()
    ret = table.concat(ret)
    return ret
end

return g
