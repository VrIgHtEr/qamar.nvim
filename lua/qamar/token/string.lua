local types = require 'qamar.token.types'

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

return function(buffer, disallow_short_form)
    buffer.begin()
    buffer.skipws()
    local pos = buffer.pos()
    buffer.suspend_skip_ws()
    local function fail()
        buffer.resume_skip_ws()
        buffer.undo()
    end
    local ret = {}
    local t = buffer.combinators.alt("'", '"')()
    if t then
        if disallow_short_form then
            return fail()
        end
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
        t = buffer.combinators.seq('[', buffer.combinators.zom '=', '[')()
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
                local closed = buffer.try_consume_string(closing)
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
    buffer.resume_skip_ws()
    ret = table.concat(ret)
    return {
        value = ret,
        type = types.string,
        pos = {
            left = pos,
            right = buffer.pos(),
        },
    }
end
