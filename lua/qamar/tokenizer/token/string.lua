local token = require 'qamar.tokenizer.types'
local string = require 'toolshed.util.string'

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

local MT = {
    __tostring = function(self)
        local ret, sep = {}, nil
        do
            if
                false
                and (
                    self.value:find '\a'
                    or self.value:find '\b'
                    or self.value:find '\f'
                    or self.value:find '\n'
                    or self.value:find '\r'
                    or self.value:find '\t'
                    or self.value:find '\v'
                    or (self.value:find "'" and self.value:find '"')
                )
            then
                local eqs = ''
                while true do
                    sep = ']' .. eqs .. ']'
                    if not string.find(self.value, sep) then
                        table.insert(ret, '[' .. eqs .. '[')
                        break
                    end
                    eqs = eqs .. '='
                end
            else
                sep = self.value:find "'" and '"' or "'"
                table.insert(ret, sep)
            end
        end
        for c in string.codepoints(self.value) do
            local v = c
            if v == '\\' then
                v = '\\\\'
            elseif v == '\a' then
                v = '\\a'
            elseif v == '\b' then
                v = '\\b'
            elseif v == '\f' then
                v = '\\f'
            elseif v == '\n' then
                v = '\\n'
            elseif v == '\r' then
                v = '\\r'
            elseif v == '\t' then
                v = '\\t'
            elseif v == '\v' then
                v = '\\v'
            elseif v == '"' and sep == '"' then
                v = '\\"'
            elseif v == "'" and sep == "'" then
                v = "\\'"
            end
            table.insert(ret, v)
        end
        table.insert(ret, sep)
        return table.concat(ret)
    end,
}

return function(stream, disallow_short_form)
    stream.begin()
    stream.skipws()
    local pos = stream.pos()
    stream.suspend_skip_ws()
    local function fail()
        stream.resume_skip_ws()
        stream.undo()
    end
    local ret = {}
    local t = stream.combinators.alt("'", '"')()
    if t then
        if disallow_short_form then
            return fail()
        end
        while true do
            local c = stream.take()
            if c == t then
                break
            elseif c == '\\' then
                c = stream.take()
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
                    stream.skipws()
                elseif c == 'x' then
                    local c1 = tohexdigit(stream.take())
                    local c2 = tohexdigit(stream.take())
                    if not c1 or not c2 then
                        return fail()
                    end
                    table.insert(ret, string.char(c1 * 16 + c2))
                elseif c == 'u' then
                    if stream.take() ~= '{' then
                        return fail()
                    end
                    local digits = {}
                    while #digits < 8 do
                        local nextdigit = tohexdigit(stream.peek())
                        if not nextdigit then
                            break
                        end
                        stream.take()
                        table.insert(digits, nextdigit)
                    end
                    if stream.take() ~= '}' then
                        return fail()
                    end
                    local s = utf8_encode(digits)
                    if not s then
                        return fail()
                    end
                    table.insert(ret, s)
                elseif c == '0' or c == '1' or c == '2' or c == '3' or c == '4' or c == '5' or c == '6' or c == '7' or c == '8' or c == '9' then
                    local digits = { todecimaldigit(c) }
                    while #digits < 3 do
                        local nextdigit = todecimaldigit(stream.peek())
                        if not nextdigit then
                            break
                        end
                        stream.take()
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
            elseif not c or c == '\n' then
                return fail()
            else
                table.insert(ret, c)
            end
        end
    else
        t = stream.combinators.seq('[', stream.combinators.zom '=', '[')()
        if t then
            local closing = { ']' }
            for _ = 1, #t[2] do
                table.insert(closing, '=')
            end
            table.insert(closing, ']')
            closing = table.concat(closing)
            if stream.peek() == '\n' then
                stream.take()
            end
            while true do
                local closed = stream.try_consume_string(closing)
                if closed then
                    break
                end
                t = stream.take()
                if not t then
                    return fail()
                elseif t == '\r' then
                    t = stream.peek()
                    if t == '\n' then
                        stream.take()
                    end
                    table.insert(ret, '\n')
                elseif t == '\n' then
                    if t == '\r' then
                        stream.take()
                    end
                    table.insert(ret, '\n')
                else
                    table.insert(ret, t)
                end
            end
        else
            return fail()
        end
    end
    stream.commit()
    stream.resume_skip_ws()
    ret = table.concat(ret)
    return setmetatable({
        value = ret,
        type = token.string,
        pos = {
            left = pos,
            right = stream.pos(),
        },
    }, MT)
end
