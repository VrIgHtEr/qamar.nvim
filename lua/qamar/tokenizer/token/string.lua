local token = require 'qamar.tokenizer.types'
local string = require 'qamar.util.string'

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
        for i, x in ipairs(hex) do
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
                local index = 0
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
                index = index + 1
                ret[index] = string.char(tonumber(s, 2))
                binstr = string.sub(binstr, rem + 1)
                for x = 1, cont_bytes * 6 - 1, 6 do
                    index = index + 1
                    ret[index] = string.char(tonumber('10' .. string.sub(binstr, x, x + 5), 2))
                end
                return table.concat(ret)
            end
        end
    end
end

local MT = {
    __tostring = function(self)
        return string.escape(self.value)
    end,
}

local function terminator_parser(self)
    local tok = self:peek()
    if tok and (tok == "'" or tok == '"') then
        return self:take()
    end
end

local function long_form_parser(self)
    local start = self:peek()
    if start and start == '[' then
        self:begin()
        self:take()
        local ret = { '[' }
        local idx = 1
        local n
        while true do
            n = self:take()
            if n ~= '=' then
                break
            end
            idx = idx + 1
            ret[idx] = '='
        end
        if n == '[' then
            self:commit()
            idx = idx + 1
            ret[idx] = '['
            return table.concat(ret)
        end
        self:undo()
    end
end

return function(self, disallow_short_form)
    self:begin()
    self:skipws()
    local pos = self:pos()
    self:suspend_skip_ws()
    local function fail()
        self:resume_skip_ws()
        self:undo()
    end
    local ret = {}
    local i = 0
    local t = terminator_parser(self)
    if t then
        if disallow_short_form then
            return fail()
        end
        while true do
            local c = self:take()
            if c == t then
                break
            elseif c == '\\' then
                c = self:take()
                if c == 'a' then
                    i = i + 1
                    ret[i] = '\a'
                elseif c == 'b' then
                    i = i + 1
                    ret[i] = '\b'
                elseif c == 'f' then
                    i = i + 1
                    ret[i] = '\f'
                elseif c == 'n' then
                    i = i + 1
                    ret[i] = '\n'
                elseif c == 'r' then
                    i = i + 1
                    ret[i] = '\r'
                elseif c == 't' then
                    i = i + 1
                    ret[i] = '\t'
                elseif c == 'v' then
                    i = i + 1
                    ret[i] = '\v'
                elseif c == '\\' then
                    i = i + 1
                    ret[i] = '\\'
                elseif c == '"' then
                    i = i + 1
                    ret[i] = '"'
                elseif c == "'" then
                    i = i + 1
                    ret[i] = "'"
                elseif c == '\n' then
                    i = i + 1
                    ret[i] = '\n'
                elseif c == 'z' then
                    self:skipws()
                elseif c == 'x' then
                    local c1 = tohexdigit(self:take())
                    local c2 = tohexdigit(self:take())
                    if not c1 or not c2 then
                        return fail()
                    end
                    i = i + 1
                    ret[i] = string.char(c1 * 16 + c2)
                elseif c == 'u' then
                    if self:take() ~= '{' then
                        return fail()
                    end
                    local digits = {}
                    local idx = 0
                    while #digits < 8 do
                        local nextdigit = tohexdigit(self:peek())
                        if not nextdigit then
                            break
                        end
                        self:take()
                        idx = idx + 1
                        digits[idx] = nextdigit
                    end
                    if self:take() ~= '}' then
                        return fail()
                    end
                    local s = utf8_encode(digits)
                    if not s then
                        return fail()
                    end
                    i = i + 1
                    ret[i] = s
                elseif c == '0' or c == '1' or c == '2' or c == '3' or c == '4' or c == '5' or c == '6' or c == '7' or c == '8' or c == '9' then
                    local digits = { todecimaldigit(c) }
                    local idx = 1
                    while #digits < 3 do
                        local nextdigit = todecimaldigit(self:peek())
                        if not nextdigit then
                            break
                        end
                        self:take()
                        idx = idx + 1
                        digits[idx] = nextdigit
                    end
                    local num = 0
                    for _, d in ipairs(digits) do
                        num = num * 10 + d
                    end
                    if num > 255 then
                        return fail()
                    end
                    i = i + 1
                    ret[i] = string.char(num)
                else
                    return fail()
                end
            elseif not c or c == '\n' then
                return fail()
            else
                i = i + 1
                ret[i] = c
            end
        end
    else
        t = long_form_parser(self)
        if t then
            local closing = { ']' }
            local idx = 1
            for _ = 1, t:len() - 2 do
                idx = idx + 1
                closing[idx] = '='
            end
            idx = idx + 1
            closing[idx] = ']'
            closing = table.concat(closing)
            if self:peek() == '\n' then
                self:take()
            end
            while true do
                local closed = self:try_consume_string(closing)
                if closed then
                    break
                end
                t = self:take()
                if not t then
                    return fail()
                elseif t == '\r' then
                    t = self:peek()
                    if t == '\n' then
                        self:take()
                    end
                    i = i + 1
                    ret[i] = '\n'
                elseif t == '\n' then
                    if t == '\r' then
                        self:take()
                    end
                    i = i + 1
                    ret[i] = '\n'
                else
                    i = i + 1
                    ret[i] = t
                end
            end
        else
            return fail()
        end
    end
    self:commit()
    self:resume_skip_ws()
    ret = table.concat(ret)
    return setmetatable({
        value = ret,
        type = token.string,
        pos = {
            left = pos,
            right = self:pos(),
        },
    }, MT)
end
