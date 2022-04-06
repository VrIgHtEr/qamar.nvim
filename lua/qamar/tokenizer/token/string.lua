local token = require 'qamar.tokenizer.types'
local string = require 'qamar.util.string'

local stream = require 'qamar.tokenizer.char_stream'
local begin = stream.begin
local skipws = stream.skipws
local suspend_skip_ws = stream.suspend_skip_ws
local spos = stream.pos
local try_consume_string = stream.try_consume_string
local resume_skip_ws = stream.resume_skip_ws
local undo = stream.undo
local commit = stream.commit
local peek = stream.peek
local take = stream.take

local sbyte = string.byte
local slen = string.len
local schar = string.char
local ssub = string.sub
local sescape = string.escape
local sfind = string.find

local concat = table.concat
local ipairs = ipairs
local tstring = token.string
local range = require 'qamar.util.range'
local T = require 'qamar.tokenizer.token'

---converts a hex character to its equivalent number value
---@param c string
---@return number|nil
local function tohexdigit(c)
    if c == '0' or c == '1' or c == '2' or c == '3' or c == '4' or c == '5' or c == '6' or c == '7' or c == '8' or c == '9' then
        return sbyte(c) - 48
    elseif c == 'a' or c == 'b' or c == 'c' or c == 'd' or c == 'e' or c == 'f' then
        return sbyte(c) - 87
    elseif c == 'a' or c == 'b' or c == 'c' or c == 'd' or c == 'e' or c == 'f' then
        return sbyte(c) - 55
    end
end

---converts a decimal character to its equivalent number value
---@param c string
---@return number|nil
local function todecimaldigit(c)
    if c == '0' or c == '1' or c == '2' or c == '3' or c == '4' or c == '5' or c == '6' or c == '7' or c == '8' or c == '9' then
        return sbyte(c) - 48
    end
end

local hex_to_binary_table = { '0000', '0001', '0010', '0011', '0100', '0101', '0110', '0111', '1000', '1001', '1010', '1011', '1100', '1101', '1110', '1111' }

---parses a hex string into a unicode character as a string
---@param hex string
---@return string
local function utf8_encode(hex)
    if #hex > 0 then
        local binstr = {}
        for i, x in ipairs(hex) do
            binstr[i] = hex_to_binary_table[x + 1]
        end
        binstr = concat(binstr)
        local len, idx = slen(binstr), sfind(binstr, '1')
        if not idx then
            return schar(0)
        elseif len ~= 32 or idx ~= 1 then
            local bits = len + 1 - idx
            binstr = ssub(binstr, bits)
            if bits <= 7 then
                return schar(tonumber(bits, 2))
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
                s = s .. ssub(binstr, 1, rem)
                index = index + 1
                ret[index] = schar(tonumber(s, 2))
                binstr = ssub(binstr, rem + 1)
                for x = 1, cont_bytes * 6 - 1, 6 do
                    index = index + 1
                    ret[index] = schar(tonumber('10' .. ssub(binstr, x, x + 5), 2))
                end
                return concat(ret)
            end
        end
    end
end

local MT = {
    ---@param self token
    ---@return any
    __tostring = function(self)
        return sescape(self.value)
    end,
}

---tries to consume "'" or '"'
---@param self char_stream
---@return string|nil
local function terminator_parser(self)
    local tok = peek(self)
    if tok and (tok == "'" or tok == '"') then
        return take(self)
    end
end

---tries to consume a lua verbatim opening terminator
---@param self char_stream
---@return string|nil
local function long_form_parser(self)
    local start = peek(self)
    if start and start == '[' then
        begin(self)
        take(self)
        local ret = { '[' }
        local idx = 1
        local n
        while true do
            n = take(self)
            if n ~= '=' then
                break
            end
            idx = idx + 1
            ret[idx] = '='
        end
        if n == '[' then
            commit(self)
            idx = idx + 1
            ret[idx] = '['
            return concat(ret)
        end
        undo(self)
    end
end

---tries to consume a lua string
---if disallow_short_form is not false then only a verbatim string is allowed
---@param self char_stream
---@param disallow_short_form boolean|nil
---@return token|nil
return function(self, disallow_short_form)
    begin(self)
    skipws(self)
    local pos = spos(self)
    suspend_skip_ws(self)
    local function fail()
        resume_skip_ws(self)
        undo(self)
    end
    local ret = {}
    local i = 0
    local t = terminator_parser(self)
    if t then
        if disallow_short_form then
            return fail()
        end
        while true do
            local c = take(self)
            if c == t then
                break
            elseif c == '\\' then
                c = take(self)
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
                    skipws(self)
                elseif c == 'x' then
                    local c1 = tohexdigit(take(self))
                    local c2 = tohexdigit(take(self))
                    if not c1 or not c2 then
                        return fail()
                    end
                    i = i + 1
                    ret[i] = schar(c1 * 16 + c2)
                elseif c == 'u' then
                    if take(self) ~= '{' then
                        return fail()
                    end
                    local digits = {}
                    local idx = 0
                    while #digits < 8 do
                        local nextdigit = tohexdigit(peek(self))
                        if not nextdigit then
                            break
                        end
                        take(self)
                        idx = idx + 1
                        digits[idx] = nextdigit
                    end
                    if take(self) ~= '}' then
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
                        local nextdigit = todecimaldigit(peek(self))
                        if not nextdigit then
                            break
                        end
                        take(self)
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
                    ret[i] = schar(num)
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
            for _ = 1, slen(t) - 2 do
                idx = idx + 1
                closing[idx] = '='
            end
            idx = idx + 1
            closing[idx] = ']'
            closing = concat(closing)
            if peek(self) == '\n' then
                take(self)
            end
            while true do
                local closed = try_consume_string(self, closing)
                if closed then
                    break
                end
                t = take(self)
                if not t then
                    return fail()
                elseif t == '\r' then
                    t = peek(self)
                    if t == '\n' then
                        take(self)
                    end
                    i = i + 1
                    ret[i] = '\n'
                elseif t == '\n' then
                    if t == '\r' then
                        take(self)
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
    commit(self)
    resume_skip_ws(self)
    return T(tstring, concat(ret), range(pos, spos(self)), MT)
end
