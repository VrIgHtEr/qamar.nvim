local char_stream = require 'qamar.tokenizer.char_stream'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local range = require 'qamar.util.range'
local N = require 'qamar.parser.node'
local E = require 'qamar.parser.node_expression'
local T = require 'qamar.tokenizer.token'
local utf8 = require('qamar.util.string').utf8
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert
local string = require 'qamar.util.string'
local stpos = char_stream.pos
local stpeek = char_stream.peek
local sttake = char_stream.take
local stundo = char_stream.undo
local stbegin = char_stream.begin
local stskipws = char_stream.skipws
local stsuspend_skip_ws = char_stream.suspend_skip_ws
local stresume_skip_ws = char_stream.resume_skip_ws
local stcommit = char_stream.commit
local sttry_consume_string = char_stream.try_consume_string
local stalpha = char_stream.alpha
local stnumeric = char_stream.numeric
local stalphanumeric = char_stream.alphanumeric
local concat = table.concat
local ipairs = ipairs
local sescape = string.escape
local sbyte = string.byte
local slen = string.len
local schar = string.char
local ssub = string.sub
local sfind = string.find
local slower = string.lower
local tostring = tostring

local tokenizer
do
    local comment
    local name
    local keyword
    local number
    local tok_string
    local symbol

    do
        local tcomment = token.comment

        ---tries to match and consume a lua comment
        ---@param self char_stream
        ---@return token
        return function(self)
            stbegin(self)
            stskipws(self)
            stsuspend_skip_ws(self)
            local pos = stpos(self)
            local cmt = sttry_consume_string(self, '--')
            if not cmt then
                stresume_skip_ws(self)
                stundo(self)
                return nil
            end
            local ret = tok_string(self, true)
            if ret then
                ret.type = tcomment
                ret.pos.left = pos
                stresume_skip_ws(self)
                stcommit(self)
                return ret
            end
            ret = {}
            local idx = 0
            while true do
                local c = stpeek(self)
                if not c or c == '\n' then
                    break
                end
                idx = idx + 1
                ret[idx] = sttake(self)
            end
            stcommit(self)
            stresume_skip_ws(self)
            return T(tcomment, concat(ret), range(pos, stpos(self)))
        end
    end

    local keywords
    do
        keywords = {
            'and',
            'break',
            'do',
            'else',
            'elseif',
            'end',
            'false',
            'for',
            'function',
            'goto',
            'if',
            'in',
            'local',
            'nil',
            'not',
            'or',
            'repeat',
            'return',
            'then',
            'true',
            'until',
            'while',
        }
        table.sort(keywords, function(a, b)
            local al, bl = a:len(), b:len()
            if al ~= bl then
                return al > bl
            end
            return a < b
        end)
        for i, x in ipairs(keywords) do
            keywords[x] = i
        end
    end

    do
        local tname = token.name

        ---tries to match and consume a lua name
        ---@param self char_stream
        ---@return token|nil
        name = function(self)
            stbegin(self)
            stskipws(self)
            local pos = stpos(self)
            stsuspend_skip_ws(self)
            local ret = {}
            local idx = 0
            local t = stalpha(self)
            if t == nil then
                stundo(self)
                stresume_skip_ws(self)
                return nil
            end
            while true do
                idx = idx + 1
                ret[idx] = t
                t = stalphanumeric(self)
                if t == nil then
                    break
                end
            end
            ret = concat(ret)
            if keywords[ret] then
                stundo(self)
                stresume_skip_ws(self)
                return nil
            end
            stcommit(self)
            stresume_skip_ws(self)
            return T(tname, ret, range(pos, stpos(self)))
        end
    end

    do
        ---tries to match and consume a lua keyword
        ---@param self char_stream
        ---@return string|nil
        local function parser(self)
            for _, x in ipairs(keywords) do
                if sttry_consume_string(self, x) then
                    return x
                end
            end
        end

        ---tries to match and consume a lua keyword
        ---@param self char_stream
        ---@return token|nil
        keyword = function(self)
            stbegin(self)
            stskipws(self)
            local pos = stpos(self)
            local ret = parser(self)
            if ret then
                stbegin(self)
                stsuspend_skip_ws(self)
                local next = stalphanumeric(self)
                stresume_skip_ws(self)
                stundo(self)
                if not next then
                    stcommit(self)
                    stresume_skip_ws(self)
                    return T(token['kw_' .. ret], ret, range(pos, stpos(self)))
                end
            end
            stundo(self)
        end
    end

    do
        local tnumber = token.number

        ---tries to consume either '0x' or '0X'
        ---@param self char_stream
        ---@return string|nil
        local function hex_start_parser(self)
            return sttry_consume_string(self, '0x') or sttry_consume_string(self, '0X')
        end

        ---tries to consume a hex digit
        ---@param self char_stream
        ---@return string|nil
        local function hex_digit_parser(self)
            local tok = stpeek(self)
            if tok then
                local b = sbyte(tok)
                if b >= 48 and b <= 57 or b >= 97 and b <= 102 or b >= 65 and b <= 70 then
                    return sttake(self)
                end
            end
        end

        ---tries to consume either 'p' or 'P'
        ---@param self char_stream
        ---@return string|nil
        local function hex_exponent_parser(self)
            local tok = stpeek(self)
            if tok and (tok == 'p' or tok == 'P') then
                return sttake(self)
            end
        end

        ---tries to consume either 'e' or 'E'
        ---@param self char_stream
        ---@return string|nil
        local function decimal_exponent_parser(self)
            local tok = stpeek(self)
            if tok and (tok == 'e' or tok == 'E') then
                return sttake(self)
            end
        end

        ---tries to consume either '-' or '+'
        ---@param self char_stream
        ---@return string|nil
        local function sign_parser(self)
            local tok = stpeek(self)
            if tok and (tok == '-' or tok == '+') then
                return sttake(self)
            end
        end

        ---tries to consume a lua number
        ---@param self char_stream
        ---@return token|nil
        number = function(self)
            stbegin(self)
            stskipws(self)
            stsuspend_skip_ws(self)
            local function fail()
                stresume_skip_ws(self)
                stundo(self)
            end
            local pos = stpos(self)
            local val = hex_start_parser(self)
            local ret = {}
            local idx = 0
            local digitparser, exponentparser
            if val then
                idx = idx + 1
                ret[idx] = slower(val)
                digitparser, exponentparser = hex_digit_parser, hex_exponent_parser
            else
                digitparser, exponentparser = stnumeric, decimal_exponent_parser
            end

            val = digitparser(self)
            if not val then
                return fail()
            end
            while val ~= nil do
                idx = idx + 1
                ret[idx] = slower(val)
                val = digitparser(self)
            end

            val = sttry_consume_string(self, '.')
            if val then
                idx = idx + 1
                ret[idx] = val
                val = digitparser(self)
                if not val then
                    return fail()
                end
                while val ~= nil do
                    idx = idx + 1
                    ret[idx] = slower(val)
                    val = digitparser(self)
                end
            end

            val = exponentparser(self)
            if val then
                idx = idx + 1
                ret[idx] = val
                local sign = sign_parser(self)
                val = stnumeric(self)
                if sign and not val then
                    return fail()
                end
                while val ~= nil do
                    idx = idx + 1
                    ret[idx] = slower(val)
                    val = digitparser(self)
                end
            end

            stresume_skip_ws(self)
            stcommit(self)
            return T(tnumber, concat(ret), range(pos, stpos(self)))
        end
    end

    do
        local tstring = token.string

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

        local hex_to_binary_table = {
            '0000',
            '0001',
            '0010',
            '0011',
            '0100',
            '0101',
            '0110',
            '0111',
            '1000',
            '1001',
            '1010',
            '1011',
            '1100',
            '1101',
            '1110',
            '1111',
        }

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

        local mt = {
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
            local tok = stpeek(self)
            if tok and (tok == "'" or tok == '"') then
                return sttake(self)
            end
        end

        ---tries to consume a lua verbatim opening terminator
        ---@param self char_stream
        ---@return string|nil
        local function long_form_parser(self)
            local start = stpeek(self)
            if start and start == '[' then
                stbegin(self)
                sttake(self)
                local ret = { '[' }
                local idx = 1
                local x
                while true do
                    x = sttake(self)
                    if x ~= '=' then
                        break
                    end
                    idx = idx + 1
                    ret[idx] = '='
                end
                if x == '[' then
                    stcommit(self)
                    idx = idx + 1
                    ret[idx] = '['
                    return concat(ret)
                end
                stundo(self)
            end
        end

        ---tries to consume a lua string
        ---if disallow_short_form is not false then only a verbatim string is allowed
        ---@param self char_stream
        ---@param disallow_short_form boolean|nil
        ---@return token|nil
        tok_string = function(self, disallow_short_form)
            stbegin(self)
            stskipws(self)
            local pos = stpos(self)
            stsuspend_skip_ws(self)
            local function fail()
                stresume_skip_ws(self)
                stundo(self)
            end
            local ret = {}
            local i = 0
            local t = terminator_parser(self)
            if t then
                if disallow_short_form then
                    return fail()
                end
                while true do
                    local c = sttake(self)
                    if c == t then
                        break
                    elseif c == '\\' then
                        c = sttake(self)
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
                            stskipws(self)
                        elseif c == 'x' then
                            local c1 = tohexdigit(sttake(self))
                            local c2 = tohexdigit(sttake(self))
                            if not c1 or not c2 then
                                return fail()
                            end
                            i = i + 1
                            ret[i] = schar(c1 * 16 + c2)
                        elseif c == 'u' then
                            if sttake(self) ~= '{' then
                                return fail()
                            end
                            local digits = {}
                            local idx = 0
                            while #digits < 8 do
                                local nextdigit = tohexdigit(stpeek(self))
                                if not nextdigit then
                                    break
                                end
                                sttake(self)
                                idx = idx + 1
                                digits[idx] = nextdigit
                            end
                            if sttake(self) ~= '}' then
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
                                local nextdigit = todecimaldigit(stpeek(self))
                                if not nextdigit then
                                    break
                                end
                                sttake(self)
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
                    if stpeek(self) == '\n' then
                        sttake(self)
                    end
                    while true do
                        local closed = sttry_consume_string(self, closing)
                        if closed then
                            break
                        end
                        t = sttake(self)
                        if not t then
                            return fail()
                        elseif t == '\r' then
                            t = stpeek(self)
                            if t == '\n' then
                                sttake(self)
                            end
                            i = i + 1
                            ret[i] = '\n'
                        elseif t == '\n' then
                            if t == '\r' then
                                sttake(self)
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
            stcommit(self)
            stresume_skip_ws(self)
            return T(tstring, concat(ret), range(pos, stpos(self)), mt)
        end
    end

    do
        local symbols = {
            ['+'] = token.plus,
            ['-'] = token.dash,
            ['*'] = token.asterisk,
            ['/'] = token.slash,
            ['%'] = token.percent,
            ['^'] = token.caret,
            ['#'] = token.hash,
            ['&'] = token.ampersand,
            ['~'] = token.tilde,
            ['|'] = token.pipe,
            ['<<'] = token.lshift,
            ['>>'] = token.rshift,
            ['//'] = token.doubleslash,
            ['=='] = token.equal,
            ['~='] = token.notequal,
            ['<='] = token.lessequal,
            ['>='] = token.greaterequal,
            ['<'] = token.less,
            ['>'] = token.greater,
            ['='] = token.assignment,
            ['('] = token.lparen,
            [')'] = token.rparen,
            ['{'] = token.lbrace,
            ['}'] = token.rbrace,
            ['['] = token.lbracket,
            [']'] = token.rbracket,
            ['::'] = token.doublecolon,
            [';'] = token.semicolon,
            [':'] = token.colon,
            [','] = token.comma,
            ['.'] = token.dot,
            ['..'] = token.doubledot,
            ['...'] = token.tripledot,
        }

        local t = {}
        do
            local pairs = pairs
            local tsort = table.sort
            local i = 0
            for k, _ in pairs(symbols) do
                i = i + 1
                t[i] = k
            end
            tsort(t, function(a, b)
                local al, bl = slen(a), slen(b)
                if al ~= bl then
                    return al > bl
                end
                return a < b
            end)
        end

        ---tries to consume a lua symbol token
        ---@param self char_stream
        ---@return string|nil
        local function parser(self)
            for _, x in ipairs(t) do
                if sttry_consume_string(self, x) then
                    return x
                end
            end
        end

        ---tries to consume a lua symbol token
        ---@param self char_stream
        ---@return token
        symbol = function(self)
            stbegin(self)
            stskipws(self)
            local pos = stpos(self)
            local ret = parser(self)
            if ret then
                stcommit(self)
                return T(symbols[ret], ret, range(pos, stpos(self)))
            end
            stundo(self)
        end
    end

    local tokenizers = { comment, name, keyword, number, tok_string, symbol }
    local tcomment = token.comment

    ---tries to parse the next lua token
    ---@param self char_stream
    ---@return token|nil
    tokenizer = function(self)
        ::restart::
        if stpeek(self) then
            for _, x in ipairs(tokenizers) do
                local ret = x(self)
                if ret then
                    if ret.type == tcomment then
                        goto restart
                    end
                    return ret
                end
            end
            stskipws(self)
            if stpeek(self) then
                local preview = {}
                stbegin(self)
                for i = 1, 30 do
                    local t = sttake(self)
                    if not t then
                        break
                    end
                    preview[i] = t
                end
                stundo(self)
                error(tostring(stpos(self)) .. ':INVALID_TOKEN: ' .. vim.inspect(concat(preview)))
            end
        end
    end
end

local deque
local setmetatable = setmetatable
do
    ---@class deque
    ---@field size function()
    ---@field push_back function(item)
    ---@field push_front function(item)
    ---@field pop_back function():any
    ---@field pop_front function():any
    ---@field peek_front function():any
    ---@field peek_back function():any

    ---creates a new deque
    ---@return deque
    deque = function()
        local parity, head, tail, capacity, version, buf = false, 0, 0, 1, 0, {}
        local function size()
            if parity then
                return capacity - (tail - head)
            else
                return head - tail
            end
        end

        local MT = {
            __metatable = function() end,
            __index = function(_, key)
                if type(key) == 'number' and key >= 1 and key <= size() then
                    local i = tail + key
                    if i > capacity then
                        i = i - capacity
                    end
                    return buf[i]
                end
            end,
        }
        ---@type deque
        local ret = setmetatable({ size = size }, MT)

        local function iterator()
            local h = head
            local p = parity
            local v = version

            return function()
                if v ~= version then
                    error 'collection modified while being iterated'
                end
                if h == tail and not p then
                    return nil
                end
                h = h + 1
                local r = buf[h]
                if h == capacity then
                    p = not p
                    h = 0
                end
                return r
            end
        end

        local function grow()
            local newbuf = {}
            local i = 0
            for x in iterator() do
                i = i + 1
                newbuf[i] = x
            end
            head = size()
            buf = newbuf
            capacity = capacity * 2
            parity = false
            tail = 0
        end

        function ret.push_back(item)
            if parity and head == tail then
                grow()
            end
            head = head + 1
            buf[head] = item
            if head == capacity then
                parity, head = not parity, 0
            end
            version = version + 1
        end

        function ret.push_front(item)
            if parity and head == tail then
                grow()
            end
            if tail == 0 then
                tail, parity = capacity, not parity
            end
            buf[tail] = item
            tail = tail - 1
            version = version + 1
        end

        function ret.pop_front()
            if parity or head ~= tail then
                tail = tail + 1
                local r = buf[tail]
                buf[tail] = nil
                if tail == capacity then
                    parity, tail = not parity, 0
                end
                version = version + 1
                return r
            end
        end

        function ret.pop_back()
            if parity or head ~= tail then
                if head == 0 then
                    parity, head = not parity, capacity
                end
                local r = buf[head]
                buf[head] = nil
                head, version = head - 1, version + 1
                return r
            end
        end

        function ret.peek_front()
            if parity or head ~= tail then
                return buf[tail]
            end
        end

        function ret.peek_back()
            if parity or head ~= tail then
                return buf[head]
            end
        end

        return ret
    end
end

---@class parser_transaction
---@field index number
---@field pos position

---@class parser
---@field stream char_stream
---@field tokenid number
---@field la deque
---@field ts table
---@field tc number
---@field t parser_transaction
---@field cache table
---@field cache_mapping deque
---@field on_flush function
local parser = {}

local assign
local attnamelist
local attrib
local block
local empty
local explist
local expression
local field
local fieldlist
local for_iter
local for_num
local func
local funcbody
local functioncall
local label
local localfunc
local localvar
local name
local namelist
local parlist
local retstat
local stat
local stat_break
local stat_do
local stat_goto
local stat_if
local stat_repeat
local stat_while
local var
local vararg
local varlist

local MT = {
    __metatable = function() end,
    __index = parser,
    ---@param self parser
    ---@return string
    __tostring = function(self)
        local ret = {}
        local idx = 0
        for i = 1, self.la.size() do
            local line = { ((i - 1 == self.t.index) and '==> ' or '    ') }
            local index = 1
            local x = self.la[i] or 'EOF'
            if x.type then
                index = index + 1
                line[index] = token[x.type]
                index = index + 1
                line[index] = ' '
            end
            index = index + 1
            line[index] = vim.inspect(x.value)
            idx = idx + 1
            ret[idx] = concat(line)
        end
        if self.t.index == self.la.size() then
            idx = idx + 1
            ret[idx] = '==>'
        end
        return concat(ret, '\n')
    end,
}

---creates a copy of a token_transaction
---@param self parser_transaction
---@return parser_transaction
local function copy_transaction(self)
    return { index = self.index, pos = self.pos }
end

local chunk
---creates a new parser
---@param stream char_stream
---@return node_block
local function parse_from_stream(stream)
    local pos = stpos(stream)
    if pos.file_byte == 0 then
        if stpeek(stream) == '#' and stpeek(stream, 1) == '!' then
            while true do
                local t = stpeek(stream)
                if not t then
                    break
                end
                sttake(stream)
                if stpos(stream).row > 1 then
                    break
                end
            end
        end
    end

    return chunk(setmetatable({
        stream = stream,
        tokenid = 0,
        la = deque(),
        ts = {},
        tc = 0,
        t = {
            index = 0,
            pos = stpos(stream),
        },
    }, MT))
end

---parses a lua chunk
---@param str string
---@return node_block
function parser.parse(str)
    return parse_from_stream(char_stream.new(utf8(str)))
end

---discards any consumed cached tokens if there are no pending transactions
---@param self parser
local function normalize(self)
    if self.tc == 0 then
        for _ = 1, self.t.index do
            self.la.pop_front()
        end
        self.t.index = 0
    end
end
parser.normalize = normalize

---fills the parser's token buffer to contain N items, unless the end of the stream has been reached
---@param self any
---@param amt number
local function fill(self, amt)
    while self.la.size() < amt do
        local c = tokenizer(self.stream)
        if c then
            c.id = self.tokenid
            self.tokenid = self.tokenid + 1
            self.la.push_back(c)
        elseif self.la.size() == 0 or self.la[self.la.size()] then
            self.la.push_back(false)
            break
        end
    end
end
parser.fill = fill

---gets the Nth (zero based) token from the token cache
---skip defaults to 0
---@param self parser
---@param skip number|nil
---@return token
local function peek(self, skip)
    skip = skip == nil and 0 or skip
    local idx = self.t.index + skip + 1
    fill(self, idx)
    return self.la[idx] or nil
end
parser.peek = peek

---consumes N tokens from the token cache.
---skip defaults to 1
---@param self parser
---@param skip number|nil
---@return token|table
local function take(self, skip)
    skip = skip == nil and 1 or skip
    local idx = self.t.index + skip
    fill(self, idx)
    local ret = {}
    for i = 1, skip do
        local c = self.la[self.t.index + 1]
        if not c then
            break
        end
        ret[i] = c
        self.t.pos = c.pos.right
        self.t.index = self.t.index + 1
    end
    normalize(self)
    return #ret > 1 and ret or (#ret == 1 and ret[1] or nil)
end
parser.take = take

---gets the rightmost position in the token stream
---@self parser
---@return position
local function pos(self)
    return self.t.pos
end
parser.pos = pos

---gets the next available token id
---@return number
local function next_id(self)
    local x = peek(self)
    return x and x.id or self.tokenid
end
parser.next_id = next_id

---consumes tokens until one with the specified id or larger is encountered
---@param self parser
---@param id number
local function take_until(self, id)
    while true do
        local x = peek(self)
        if not x or x.id >= id then
            return
        end
        take(self)
    end
end
parser.take_until = take_until

---begins a new parser transaction. must be paired with a subsequent call to undo or normalize
---@param self parser
local function begin(self)
    self.tc = self.tc + 1
    self.ts[self.tc] = copy_transaction(self.t)
end
parser.begin = begin

---undoes a parser transaction. must be paired with a preceding call to begin
---@param self parser
local function undo(self)
    self.t, self.ts[self.tc], self.tc = self.ts[self.tc], nil, self.tc - 1
end
parser.undo = undo

---commits a parser transaction. must be paired with a preceding call to begin
---@param self parser
local function commit(self)
    self.ts[self.tc], self.tc = nil, self.tc - 1
    normalize(self)
    if self.tc == 0 and self.on_flush then
        self.on_flush(next_id(self))
    end
end
parser.commit = commit

---begins a new parser transaction and consumes the next token
---@param self parser
---@param amt number
---@return token|nil
local function begintake(self, amt)
    begin(self)
    return take(self, amt)
end
parser.begintake = begintake

--------------------------------------------------------------------------------------------------------------

do
    local field_raw
    local field_name

    do
        ---@class node_field_raw:node
        ---@field key node_expression
        ---@field value node_expression

        local tlbracket = token.lbracket
        local trbracket = token.rbracket
        local tassignment = token.assignment
        local nfield_raw = n.field_raw

        local mt = {
            ---@param self node_field_raw
            ---@return string
            __tostring = function(self)
                return tconcat { '[', self.key, ']', '=', self.value }
            end,
        }

        ---try to consume a lua raw table access
        ---@param self parser
        ---@return node_field_raw|nil
        field_raw = function(self)
            local tok = peek(self)
            if tok and tok.type == tlbracket then
                begin(self)
                local left = take(self).pos.left
                local key = expression(self)
                if key then
                    tok = take(self)
                    if tok and tok.type == trbracket then
                        tok = take(self)
                        if tok and tok.type == tassignment then
                            local value = expression(self)
                            if value then
                                commit(self)
                                local ret = N(nfield_raw, range(left, value.pos.right), mt)
                                ret.key = key
                                ret.value = value
                                return ret
                            end
                        end
                    end
                end
                undo(self)
            end
        end
    end

    do
        ---@class node_field_name:node
        ---@field key string
        ---@field value node_expression

        local tname = token.name
        local tassignment = token.assignment
        local nfield_name = n.field_name

        local mt = {
            ---@param self node_field_name
            ---@return string
            __tostring = function(self)
                return tconcat { self.key, '=', self.value }
            end,
        }

        ---try to consume a lua table field with a name
        ---@param self parser
        ---@return node_field_name|nil
        field_name = function(self)
            local key = peek(self)
            if key and key.type == tname then
                begin(self)
                local left = take(self).pos.left
                local tok = take(self)
                if tok and tok.type == tassignment then
                    local value = expression(self)
                    if value then
                        commit(self)
                        local ret = N(nfield_name, range(left, value.pos.right), mt)
                        ret.key = key.value
                        ret.value = value
                        return ret
                    end
                end
                undo(self)
            end
        end
    end

    ---try to parse a lua table field
    ---@param self parser
    ---@return node|nil
    return function(self)
        return field_raw(self) or field_name(self) or expression(self)
    end
end

do
    ---@class node_fieldlist:node

    local nfieldlist = n.fieldlist
    local tcomma = token.comma
    local tsemicolon = token.semicolon

    local mt = {
        ---@param self node_fieldlist
        ---@return string
        __tostring = function(self)
            local ret, idx = {}, 1
            for i, x in ipairs(self) do
                if i > 1 then
                    ret[idx], idx = ',', idx + 1
                end
                ret[idx], idx = x, idx + 1
            end
            return tconcat(ret)
        end,
    }

    ---try to consume a lua field list
    ---@param self parser
    ---@return node_fieldlist|nil
    fieldlist = function(self)
        local f = field(self)
        if f then
            local p = range(f.pos.left)
            local ret = N(nfieldlist, p, mt)
            ret[1] = f
            local idx = 1
            while true do
                local tok = peek(self)
                if tok and (tok.type == tcomma or tok.type == tsemicolon) then
                    begin(self)
                    take(self)
                    f = field(self)
                    if not f then
                        undo(self)
                        break
                    end
                    idx = idx + 1
                    ret[idx] = f
                    commit(self)
                else
                    break
                end
            end
            local tok = peek(self)
            if tok and (tok.type == tcomma or tok.type == tsemicolon) then
                take(self)
                p.right = tok.pos.right
            else
                p.right = ret[idx].pos.right
            end
            return ret
        end
    end
end

do
    local nname = n.name
    local ntable_nameaccess = n.table_nameaccess
    local ntable_rawaccess = n.table_rawaccess

    ---try to consume a lua variable
    ---@param self parser
    ---@return node_name|node_table_nameaccess|node_table_rawaccess
    var = function(self)
        begin(self)
        local ret = expression(self)
        if ret and (ret.type == nname or ret.type == ntable_nameaccess or ret.type == ntable_rawaccess) then
            commit(self)
            return ret
        end
        undo(self)
    end
end

do
    ---@class node_vararg:node

    local mt = {
        __tostring = function()
            return '...'
        end,
    }

    local ttripledot = token.tripledot
    local nvararg = n.vararg

    ---try to consume a vararg token
    ---@param self parser
    ---@return node_vararg|nil
    vararg = function(self)
        local tok = peek(self)
        if tok and tok.type == ttripledot then
            take(self)
            return N(nvararg, tok.pos, mt)
        end
    end
end

do
    ---@class node_parlist:node

    local nparlist = n.parlist
    local tcomma = token.comma

    local mt = {
        ---@param self node_parlist
        ---@return string
        __tostring = function(self)
            local ret = {}
            for i, x in ipairs(self) do
                if i > 1 then
                    tinsert(ret, ',')
                end
                tinsert(ret, x)
            end
            return tconcat(ret)
        end,
    }

    ---try to consume a lua parameter list
    ---@param self parser
    ---@return node_parlist|nil
    parlist = function(self)
        local v = vararg(self)
        if v then
            local ret = N(nparlist, v.pos, mt)
            ret[1] = v
            return ret
        else
            v = namelist(self)
            if v then
                local p = range(v.pos.left)
                local ret = N(nparlist, p, mt)
                local idx = 0
                for _, x in ipairs(v) do
                    idx = idx + 1
                    ret[idx] = x
                end
                v = peek(self)
                if v and v.type == tcomma then
                    begintake(self)
                    v = vararg(self)
                    if v then
                        commit(self)
                        idx = idx + 1
                        ret[idx] = v
                    else
                        undo(self)
                    end
                end
                p.right = ret[idx].pos.right
                return ret
            end
        end
    end
end

do
    ---@class node_funcbody:node
    ---@field parameters node_parlist
    ---@field body node_block

    local mt = {
        ---@param self node_funcbody
        ---@return string
        __tostring = function(self)
            local ret = { '(' }
            if self.parameters then
                tinsert(ret, self.parameters)
            end
            tinsert(ret, ')', self.body, 'end')
            return tconcat(ret)
        end,
    }

    local tlparen = token.lparen
    local trparen = token.rparen
    local tkw_end = token.kw_end
    local nfuncbody = n.funcbody

    ---try to consume a lua function body
    ---@param self parser
    ---@return node_funcbody|nil
    funcbody = function(self)
        local lparen = peek(self)
        if lparen and lparen.type == tlparen then
            begintake(self)
            local pars = parlist(self)
            local tok = take(self)
            if tok and tok.type == trparen then
                local body = block(self)
                if body then
                    tok = take(self)
                    if tok and tok.type == tkw_end then
                        commit(self)
                        local ret = N(nfuncbody, range(lparen.pos.left, tok.pos.right), mt)
                        ret.parameters = pars
                        ret.body = body
                        return ret
                    end
                end
            end
            undo(self)
        end
    end
end

do
    ---@class node_varlist:node

    local nvarlist = n.varlist
    local tcomma = token.comma

    local mt = {
        ---@param self node_varlist
        ---@return string
        __tostring = function(self)
            local ret = {}
            for i, x in ipairs(self) do
                if i > 1 then
                    tinsert(ret, ',')
                end
                tinsert(ret, x)
            end
            return tconcat(ret)
        end,
    }

    ---try to consume a lua varlist
    ---@param self parser
    ---@return node_varlist|nil
    varlist = function(self)
        local v = var(self)
        if v then
            local p = range(v.pos.left)
            local ret = N(nvarlist, p, mt)
            ret[1] = v
            local idx = 1
            while true do
                local t = peek(self)
                if not t or t.type ~= tcomma then
                    break
                end
                begin(self)
                take(self)
                v = var(self)
                if v then
                    commit(self)
                    idx = idx + 1
                    ret[idx] = v
                else
                    undo(self)
                    break
                end
            end
            p.right = ret[idx].pos.right
            return ret
        end
    end
end

do
    ---@class node_namelist:node

    local nnamelist = n.namelist
    local tcomma = token.comma

    local mt = {
        ---@param self node_namelist
        ---@return string
        __tostring = function(self)
            local ret = {}
            for i, x in ipairs(self) do
                if i > 1 then
                    tinsert(ret, ',')
                end
                tinsert(ret, x)
            end
            return tconcat(ret)
        end,
    }

    ---try to consume a lua name list
    ---@param self parser
    ---@return node_namelist|nil
    namelist = function(self)
        local v = name(self)
        if v then
            local p = range(v.pos.left)
            local ret = N(nnamelist, p, mt)
            ret[1] = v
            local idx = 1
            while true do
                local t = peek(self)
                if not t or t.type ~= tcomma then
                    break
                end
                begin(self)
                take(self)
                v = name(self)
                if v then
                    commit(self)
                    idx = idx + 1
                    ret[idx] = v
                else
                    undo(self)
                    break
                end
            end
            p.right = ret[idx].pos.right
            return ret
        end
    end
end

do
    ---@class node_if:node
    ---@field conditions table
    ---@field bodies table

    local mt = {
        ---@param self node_if
        ---@return string
        __tostring = function(self)
            local ret = { 'if', self.conditions[1], 'then', self.bodies[1] }
            for i = 2, #self.conditions do
                tinsert(ret, 'elseif', self.conditions[i], 'then', self.bodies[i])
            end
            for i = #self.conditions + 1, #self.bodies do
                tinsert(ret, 'else', self.bodies[i])
            end
            tinsert(ret, 'end')
            return tconcat(ret)
        end,
    }

    local tkw_if = token.kw_if
    local tkw_then = token.kw_then
    local tkw_elseif = token.kw_elseif
    local tkw_else = token.kw_else
    local tkw_end = token.kw_end
    local nstat_if = n.stat_if

    ---try to consume a lua if statement
    ---@param self parser
    ---@return node_if|nil
    stat_if = function(self)
        local tok = peek(self)
        if tok and tok.type == tkw_if then
            local kw_if = begintake(self)
            local condition = expression(self)
            if condition then
                tok = take(self)
                if tok and tok.type == tkw_then then
                    local body = block(self)
                    if body then
                        local conditions, bodies = { condition }, { body }
                        local cidx, bidx = 1, 1
                        while true do
                            tok = peek(self)
                            if not tok or tok.type ~= tkw_elseif then
                                break
                            end
                            begintake(self)
                            condition = expression(self)
                            if condition then
                                tok = take(self)
                                if tok and tok.type == tkw_then then
                                    body = block(self)
                                    if body then
                                        commit(self)
                                        cidx = cidx + 1
                                        conditions[cidx] = condition
                                        bidx = bidx + 1
                                        bodies[bidx] = body
                                    else
                                        undo(self)
                                        break
                                    end
                                else
                                    undo(self)
                                    break
                                end
                            else
                                undo(self)
                                break
                            end
                        end

                        tok = peek(self)
                        if tok and tok.type == tkw_else then
                            begintake(self)
                            body = block(self)
                            if body then
                                commit(self)
                                bidx = bidx + 1
                                bodies[bidx] = body
                            else
                                undo(self)
                            end
                        end

                        tok = take(self)
                        if tok and tok.type == tkw_end then
                            commit(self)
                            local ret = N(nstat_if, range(kw_if.pos.left, bodies[bidx].pos.right), mt)
                            ret.conditions = conditions
                            ret.bodies = bodies
                            return ret
                        end
                    end
                end
            end
            undo(self)
        end
    end
end

do
    ---@class node_do:node
    ---@field body node_block

    local mt = {
        ---@param self node_do
        ---@return string
        __tostring = function(self)
            return tconcat { 'do', self.body, 'end' }
        end,
    }

    local tkw_do = token.kw_do
    local tkw_end = token.kw_end
    local nstat_do = n.stat_do

    ---try to consume a lue do...end statement
    ---@param self parser
    ---@return node_do|nil
    stat_do = function(self)
        local tok = peek(self)
        if tok and tok.type == tkw_do then
            local kw_do = begintake(self)
            local body = block(self)
            if body then
                tok = take(self)
                if tok and tok.type == tkw_end then
                    commit(self)
                    local ret = N(nstat_do, range(kw_do.pos.left, tok.pos.right), mt)
                    ret.body = body
                    return ret
                end
            end
            undo(self)
        end
    end
end

do
    ---@class node_for_iter:node
    ---@field names node_namelist
    ---@field iterators node_explist
    ---@field body node_block

    local mt = {
        ---@param self node_for_iter
        ---@return string
        __tostring = function(self)
            return tconcat { 'for', self.names, 'in', self.iterators, 'do', self.body, 'end' }
        end,
    }

    local tkw_for = token.kw_for
    local tkw_in = token.kw_in
    local tkw_do = token.kw_do
    local tkw_end = token.kw_end
    local nstat_for_iter = n.stat_for_iter

    ---try to consume a lua iterator for loop
    ---@param self parser
    ---@return node_for_iter|nil
    for_iter = function(self)
        local tok = peek(self)
        if tok and tok.type == tkw_for then
            local kw_for = begintake(self)
            local names = namelist(self)
            if names then
                tok = take(self)
                if tok and tok.type == tkw_in then
                    local iterators = explist(self)
                    if iterators then
                        tok = take(self)
                        if tok and tok.type == tkw_do then
                            local body = block(self)
                            if body then
                                tok = take(self)
                                if tok and tok.type == tkw_end then
                                    commit(self)
                                    local ret = N(nstat_for_iter, range(kw_for.pos.left, tok.pos.right), mt)
                                    names = names
                                    iterators = iterators
                                    body = body
                                    return ret
                                end
                            end
                        end
                    end
                end
            end
            undo(self)
        end
    end
end

do
    ---@class node_while:node
    ---@field body node_block
    ---@field condition node_expression

    local mt = {
        ---@param self node_while
        ---@return string
        __tostring = function(self)
            return tconcat { 'while', self.condition, 'do', self.body, 'end' }
        end,
    }

    local tkw_while = token.kw_while
    local tkw_do = token.kw_do
    local tkw_end = token.kw_end
    local nstat_while = n.stat_while

    ---try to consume a lua while statement
    ---@param self parser
    ---@return node_while|nil
    stat_while = function(self)
        local tok = peek(self)
        if tok and tok.type == tkw_while then
            local kw_while = begintake(self)
            local condition = expression(self)
            if condition then
                tok = take(self)
                if tok and tok.type == tkw_do then
                    local body = block(self)
                    if body then
                        tok = take(self)
                        if tok and tok.type == tkw_end then
                            commit(self)
                            local ret = N(nstat_while, range(kw_while.pos.left, tok.pos.right), mt)
                            ret.condition = condition
                            ret.body = body
                            return ret
                        end
                    end
                end
            end
            undo(self)
        end
    end
end

do
    ---@class node_repeat:node
    ---@field body node_block
    ---@field condition node_expression

    local mt = {
        ---@param self node_repeat
        ---@return string
        __tostring = function(self)
            return tconcat { 'repeat', self.body, 'until', self.condition }
        end,
    }

    local tkw_repeat = token.kw_repeat
    local tkw_until = token.kw_until
    local nstat_repeat = n.stat_repeat

    ---try to consume a lua repeat statement
    ---@param self parser
    ---@return node_repeat|nil
    stat_repeat = function(self)
        local tok = peek(self)
        if tok and tok.type == tkw_repeat then
            local kw_repeat = begintake(self)

            local body = block(self)
            if body then
                tok = take(self)
                if tok and tok.type == tkw_until then
                    local condition = expression(self)
                    if condition then
                        commit(self)
                        local ret = N(nstat_repeat, range(kw_repeat.pos.left, condition.pos.right), mt)
                        ret.body = body
                        ret.condition = condition
                        return ret
                    end
                end
            end
            undo(self)
        end
    end
end

do
    ---@class node_assign:node
    ---@field target node_varlist
    ---@field value node_explist

    local mt = {
        ---@param self node_assign
        ---@return string
        __tostring = function(self)
            return tconcat { self.target, '=', self.value }
        end,
    }

    local tassignment = token.assignment
    local nstat_assign = n.stat_assign

    ---try to consume a lua assignment statement
    ---@param self parser
    ---@return node_assign|nil
    assign = function(self)
        local target = varlist(self)
        if target then
            local tok = take(self)
            if tok and tok.type == tassignment then
                begin(self)
                local value = explist(self)
                if value then
                    commit(self)
                    local ret = N(nstat_assign, range(target.pos.left, value.pos.right), mt)
                    ret.target = target
                    ret.value = value
                    return ret
                end
                undo(self)
            end
        end
    end
end

do
    local nfunctioncall = n.functioncall

    ---try to consume a lua function call
    ---@param self parser
    ---@return node_functioncall|nil
    functioncall = function(self)
        begin(self)
        local ret = expression(self)
        if ret and ret.type == nfunctioncall then
            commit(self)
            return ret
        end
        undo(self)
    end
end

do
    ---@class node_for_num:node
    ---@field name node_name
    ---@field start node_expression
    ---@field finish node_expression
    ---@field increment node_expression|nil
    ---@field body node_block

    local mt = {
        ---@param s node_for_num
        ---@return string
        __tostring = function(s)
            local ret = { 'for', s.name, '=', s.start, ',', s.finish }
            if s.increment then
                tinsert(ret, ',', s.increment)
            end
            tinsert(ret, 'do', s.body, 'end')
            return tconcat(ret)
        end,
    }

    local tkw_for = token.kw_for
    local tassignment = token.assignment
    local tcomma = token.comma
    local tkw_do = token.kw_do
    local tkw_end = token.kw_end
    local nstat_for_num = n.stat_for_num

    ---try to consume a lua for loop
    ---@param self parser
    ---@return node_for_num|nil
    for_num = function(self)
        local kw_for = peek(self)
        if kw_for and kw_for.type == tkw_for then
            begintake(self)
            local varname = name(self)
            if varname then
                local tok = take(self)
                if tok and tok.type == tassignment then
                    local start = expression(self)
                    if start then
                        tok = take(self)
                        if tok and tok.type == tcomma then
                            local finish = expression(self)
                            if finish then
                                local increment = nil
                                tok = peek(self)
                                if tok and tok.type == tcomma then
                                    begintake(self)
                                    increment = expression(self)
                                    if increment then
                                        commit(self)
                                    else
                                        undo(self)
                                    end
                                end
                                tok = take(self)
                                if tok and tok.type == tkw_do then
                                    local body = block(self)
                                    tok = take(self)
                                    if tok and tok.type == tkw_end then
                                        commit(self)
                                        local ret = N(nstat_for_num, range(kw_for.pos.left, tok.pos.right), mt)
                                        ret.name = name
                                        ret.start = start
                                        ret.finish = finish
                                        ret.increment = increment
                                        ret.body = body
                                        return ret
                                    end
                                end
                            end
                        end
                    end
                end
            end
            undo(self)
        end
    end
end

do
    ---@class node_func:node
    ---@field name node_funcname
    ---@field body node_funcbody

    local tkw_function = token.kw_function
    local nstat_func = n.stat_func

    local mt = {
        ---@param s node_func
        ---@return string
        __tostring = function(s)
            return tconcat { 'function', s.name, s.body }
        end,
    }

    ---try to consume a lua function statement
    ---@param self parser
    ---@return node_func|nil
    func = function(self)
        local kw_function = peek(self)
        if kw_function and kw_function.type == tkw_function then
            begintake(self)
            local funcname = name(self)
            if funcname then
                local body = funcbody(self)
                if body then
                    commit(self)
                    local ret = N(nstat_func, range(kw_function.pos.left, body.pos.right), mt)
                    ret.name = funcname
                    ret.body = body
                    return ret
                end
            end
            undo(self)
        end
    end
end

do
    ---@class node_localfunc:node
    ---@field name node_name
    ---@field body node_funcbody

    local mt = {
        ---@param s node_localfunc
        ---@return string
        __tostring = function(s)
            return tconcat { 'local function', s.name, s.body }
        end,
    }

    local tkw_local = token.kw_local
    local tkw_function = token.kw_function
    local nstat_localfunc = n.stat_localfunc

    ---try to consume a lua local function definition
    ---@param self parser
    ---@return node_localfunc|nil
    localfunc = function(self)
        local kw_local = peek(self)
        if kw_local and kw_local.type == tkw_local then
            begintake(self)
            local kw_function = take(self)
            if kw_function and kw_function.type == tkw_function then
                local funcname = name(self)
                if funcname then
                    local body = funcbody(self)
                    if body then
                        commit(self)
                        local ret = N(nstat_localfunc, range(kw_local.pos.left, body.pos.right), mt)
                        ret.name = funcname
                        ret.body = body
                        return ret
                    end
                end
            end
            undo(self)
        end
    end
end

do
    ---@class node_goto:node
    ---@field label node_name

    local mt = {
        ---@param self node_goto
        ---@return string
        __tostring = function(self)
            return tconcat { 'goto', self.label }
        end,
    }

    local tkw_goto = token.kw_goto
    local nstat_goto = n.stat_goto

    ---try to consume a lua goto statement
    ---@param self parser
    ---@return node_goto|nil
    stat_goto = function(self)
        local kw_goto = peek(self)
        if kw_goto and kw_goto.type == tkw_goto then
            begintake(self)
            local lbl = name(self)
            if lbl then
                commit(self)
                local ret = N(nstat_goto, range(kw_goto.pos.left, lbl.pos.right), mt)
                ret.label = lbl
                return ret
            end
            undo(self)
        end
    end
end

do
    ---@class node_break:node

    local mt = {
        __tostring = function()
            return 'break'
        end,
    }

    local tkw_break = token.kw_break
    local nstat_break = n.stat_break

    ---try to consume a lua break statement
    ---@param self parser
    ---@return node_break|nil
    stat_break = function(self)
        local tok = peek(self)
        if tok and tok.type == tkw_break then
            take(self)
            return N(nstat_break, tok.pos, mt)
        end
    end
end

do
    ---@class node_label:node
    ---@field name string

    local mt = {
        ---@param self node_label
        ---@return string
        __tostring = function(self)
            return '::' .. self.name .. '::'
        end,
    }
    local tdoublecolon = token.doublecolon
    local nlabel = n.label

    ---try to consume a lua label
    ---@param self parser
    ---@return node_label|nil
    label = function(self)
        local left = peek(self)
        if not left or left.type ~= tdoublecolon then
            return
        end
        begintake(self)

        local nam = name(self)
        if not nam then
            undo(self)
            return
        end

        local right = take(self)
        if not right or right.type ~= tdoublecolon then
            undo(self)
            return
        end

        commit(self)
        local ret = N(nlabel, range(left.pos.left, right.pos.right), mt)
        ret.name = nam.value
        return ret
    end
end

do
    local precedence = {
        lor = 1,
        land = 2,
        comparison = 3,
        bor = 4,
        bxor = 5,
        band = 6,
        shift = 7,
        concat = 8,
        add = 9,
        mul = 10,
        unary = 11,
        exp = 12,
        atom = 13,
        literal = 14,
    }

    ---@class parselet
    ---@field precedence number
    ---@field right_associative boolean
    ---@field parse function

    local infix
    local fcall
    local atom
    local tableconstructor
    local prefix
    local functiondef
    local subexpression
    local nameaccess
    local rawaccess

    do
        ---@class node_table_rawaccess:node_expression
        ---@field table node_expression
        ---@field key node_expression

        local mt = {
            ---@param self node_table_rawaccess
            ---@return string
            __tostring = function(self)
                return tconcat { self.table, '[', self.key, ']' }
            end,
        }

        local nname = n.name
        local ntable_nameaccess = n.table_nameaccess
        local ntable_rawaccess = n.table_rawaccess
        local nfunctioncall = n.functioncall
        local nsubexpression = n.subexpression
        local trbracket = token.rbracket

        rawaccess = function(self, p, left, tok)
            if
                left.type == nname
                or left.type == ntable_nameaccess
                or left.type == ntable_rawaccess
                or left.type == nfunctioncall
                or left.type == nsubexpression
            then
                local l = left.pos.left
                begin(p)
                local exp = expression(p)
                if not exp then
                    undo(p)
                    return nil
                end
                tok = peek(p)
                if not tok or tok.type ~= trbracket then
                    undo(p)
                    return nil
                end
                take(p)
                commit(p)
                local ret = E(ntable_rawaccess, range(l, tok.pos.right), self.precedence, self.right_associative, mt)
                ret.table = left
                ret.key = exp
                return ret
            end
        end
    end

    do
        ---@class node_table_nameaccess:node_expression
        ---@field table node_expression
        ---@field key string

        local nname = n.name
        local ntable_nameaccess = n.table_nameaccess
        local ntable_rawaccess = n.table_rawaccess
        local nfunctioncall = n.functioncall
        local nsubexpression = n.subexpression
        local tname = token.name

        local mt = {
            ---@param self node_table_nameaccess
            ---@return string
            __tostring = function(self)
                return tconcat { self.table, '.', self.key }
            end,
        }

        ---parselet that consumes a named table access
        ---@param self parselet
        ---@param p parser
        ---@param left node_expression
        ---@param tok token
        ---@return node_table_nameaccess
        nameaccess = function(self, p, left, tok)
            if
                left.type == nname
                or left.type == ntable_nameaccess
                or left.type == ntable_rawaccess
                or left.type == nfunctioncall
                or left.type == nsubexpression
            then
                local l = left.pos.left
                tok = peek(p)
                if tok and tok.type == tname then
                    take(p)
                    local ret = E(ntable_nameaccess, range(l, tok.pos.right), self.precedence, self.right_associative, mt)
                    ret.table = left
                    ret.key = tok.value
                    return ret
                end
            end
        end
    end

    do
        ---@class node_subexpression:node_expression
        ---@field value node_expression

        local mt = {
            ---@param self node_subexpression
            ---@return string
            __tostring = function(self)
                return tconcat { '(', self.value, ')' }
            end,
        }

        local trparen = token.rparen
        local nsubexpression = n.subexpression

        ---parselet that consumes a subexpression
        ---@param self parselet
        ---@param p parser
        ---@param tok token
        ---@return node_subexpression|nil
        subexpression = function(self, p, tok)
            local left = tok.pos.left
            begin(p)
            local exp = expression(p)
            if not exp then
                undo(p)
                return nil
            end
            tok = peek(p)
            if not tok or tok.type ~= trparen then
                undo(p)
                return nil
            end
            take(p)
            commit(p)
            local ret = E(nsubexpression, range(left, tok.pos.right), self.precedence, self.right_associative, mt)
            ret.value = exp
            return ret
        end
    end

    do
        ---@class node_table_rawaccess:node_expression
        ---@field table node_expression
        ---@field key node_expression

        local mt = {
            ---@param self node_table_rawaccess
            ---@return string
            __tostring = function(self)
                return tconcat { self.table, '[', self.key, ']' }
            end,
        }

        local nname = n.name
        local ntable_nameaccess = n.table_nameaccess
        local ntable_rawaccess = n.table_rawaccess
        local nfunctioncall = n.functioncall
        local nsubexpression = n.subexpression
        local trbracket = token.rbracket

        functiondef = function(self, p, left, tok)
            if
                left.type == nname
                or left.type == ntable_nameaccess
                or left.type == ntable_rawaccess
                or left.type == nfunctioncall
                or left.type == nsubexpression
            then
                local l = left.pos.left
                begin(p)
                local exp = expression(p)
                if not exp then
                    undo(p)
                    return nil
                end
                tok = peek(p)
                if not tok or tok.type ~= trbracket then
                    undo(p)
                    return nil
                end
                take(p)
                commit(p)
                local ret = E(ntable_rawaccess, range(l, tok.pos.right), self.precedence, self.right_associative, mt)
                ret.table = left
                ret.key = exp
                return ret
            end
        end
    end

    do
        ---@class node_prefix:node_expression
        ---@field operand node_expression

        local token_node_mapping = {
            [token.kw_not] = n.lnot,
            [token.hash] = n.len,
            [token.dash] = n.neg,
            [token.tilde] = n.bnot,
        }

        local mt = {
            ---@param self node_prefix
            ---@return string
            __tostring = function(self)
                local ret = { n[self.type] }
                local idx = 1
                local paren
                if self.operand.precedence > self.precedence then
                    paren = false
                else
                    paren = true
                end
                if paren then
                    idx = idx + 1
                    ret[idx] = '('
                end
                idx = idx + 1
                ret[idx] = self.operand
                if paren then
                    idx = idx + 1
                    ret[idx] = ')'
                end
                return tconcat(ret)
            end,
        }

        ---parselet that consumes a prefix expression
        ---@param self parselet
        ---@param p parser
        ---@param tok token
        ---@return node_prefix|nil
        prefix = function(self, p, tok)
            local operand = expression(p, self.precedence - (self.right_associative and 1 or 0))
            if not operand then
                return nil
            end
            local ret = E(token_node_mapping[tok.type], range(tok.pos.left, operand.pos.right), self.precedence, self.right_associative, mt)
            ret.operand = operand
            return ret
        end
    end

    do
        ---@class node_table_constructor:node
        ---@field value node

        local trbrace = token.rbrace
        local ntableconstructor = n.tableconstructor

        local mt = {
            ---@param self node_table_constructor
            ---@return string
            __tostring = function(self)
                return tconcat { '{', self.value, '}' }
            end,
        }

        ---parselet that consumes a table constructor
        ---@param self parselet
        ---@param p parser
        ---@param tok token
        ---@return node_table_constructor|nil
        tableconstructor = function(self, p, tok)
            local fl = fieldlist(p)
                or setmetatable({}, {
                    __tostring = function()
                        return ''
                    end,
                })
            if peek(p) then
                local rbrace = take(p)
                if rbrace.type == trbrace then
                    local ret = E(ntableconstructor, range(tok.pos.left, rbrace.pos.right), self.precedence, self.right_associative, mt)
                    ret.value = fl
                    return ret
                end
            end
        end
    end

    do
        ---@class node_atom:node_expression
        ---@field value string

        local token_node_mapping = {
            [token.name] = n.name,
            [token.number] = n.number,
            [token.kw_nil] = n.val_nil,
            [token.kw_false] = n.val_false,
            [token.kw_true] = n.val_true,
            [token.tripledot] = n.vararg,
            [token.string] = n.string,
        }

        ---@param self node_atom
        ---@return string
        local function default__tostring(self)
            return self.value
        end

        local __tostring = {
            [n.name] = default__tostring,
            [n.number] = default__tostring,
            [n.val_nil] = default__tostring,
            [n.val_false] = default__tostring,
            [n.val_true] = default__tostring,
            [n.vararg] = default__tostring,
            ---@param self node_atom
            ---@return string
            [n.string] = function(self)
                return sescape(self.value)
            end,
        }

        local mt = {
            ---@param self node_atom
            ---@return string
            __tostring = function(self)
                return __tostring[self.type](self)
            end,
        }

        ---parselet to consume an expression atom
        ---@param self parselet
        ---@param _ parser
        ---@param tok token
        ---@return node_atom
        atom = function(self, _, tok)
            local ret = E(token_node_mapping[tok.type], tok.pos, self.precedence, self.right_associative, mt)
            ret.value = tok.value
            return ret
        end
    end

    do
        ---@class node_functioncall:node_expression
        ---@field left node
        ---@field args node
        ---@field self string

        local tlparen = token.lparen
        local trparen = token.rparen
        local tlbrace = token.lbrace
        local tname = token.name
        local tstring = token.string
        local tcolon = token.colon
        local ntableconstructor = n.tableconstructor
        local nstring = n.string
        local nname = n.name
        local ntable_nameaccess = n.table_nameaccess
        local ntable_rawaccess = n.table_rawaccess
        local nfunctioncall = n.functioncall
        local nsubexpression = n.subexpression
        local tostring = tostring

        local mt = {
            ---@param self node_functioncall
            ---@return string
            __tostring = function(self)
                local ret = { self.left }
                if self.self then
                    tinsert(ret, ':', self.self)
                end
                local paren = #self.args ~= 1 or (self.args[1].type ~= ntableconstructor and self.args[1].type ~= nstring)
                if paren then
                    tinsert(ret, '(')
                end
                tinsert(ret, self.args)
                if paren then
                    tinsert(ret, ')')
                end
                return tconcat(ret)
            end,
        }

        local mtempty = {
            __tostring = function()
                return ''
            end,
        }

        local mtnonempty = {
            __tostring = function(x)
                return tostring(x[1])
            end,
        }

        ---parselet to consume a function call
        ---@param self parselet
        ---@param p parser
        ---@param left node_expression
        ---@param tok token
        ---@return node_functioncall|nil
        fcall = function(self, p, left, tok)
            if
                left.type == nname
                or left.type == ntable_nameaccess
                or left.type == ntable_rawaccess
                or left.type == nfunctioncall
                or left.type == nsubexpression
            then
                local sname, arglist, right = false, nil, nil
                if tok.type == tlparen then
                    local args = explist(p) or setmetatable({}, mtempty)
                    if peek(p) then
                        local rparen = take(p)
                        if rparen.type == trparen then
                            arglist = args
                            right = rparen.pos.right
                        end
                    end
                elseif tok.type == tlbrace then
                    local arg = tableconstructor(self, p, tok)
                    if arg then
                        arglist = setmetatable({ arg }, mtnonempty)
                        right = arg.pos.right
                    end
                elseif tok.type == tstring then
                    local arg = atom(self, p, tok)
                    if arg then
                        arglist = setmetatable({ arg }, mtnonempty)
                        right = arg.pos.right
                    end
                elseif tok.type == tcolon then
                    if peek(p) then
                        local nm = take(p)
                        if nm.type == tname then
                            sname = nm.value

                            local next = peek(p)
                            if next then
                                take(p)
                                if next.type == tlparen then
                                    local args = explist(p) or setmetatable({}, mtempty)
                                    if peek(p) then
                                        local rparen = take(p)
                                        if rparen.type == trparen then
                                            arglist = args
                                            right = rparen.pos.right
                                        end
                                    end
                                elseif next.type == tlbrace then
                                    local arg = tableconstructor(self, p, next)
                                    if arg then
                                        arglist = setmetatable({ arg }, mtnonempty)
                                        right = arg.pos.right
                                    end
                                elseif next.type == tstring then
                                    local arg = atom(self, p, next)
                                    if arg then
                                        arglist = setmetatable({ arg }, mtnonempty)
                                        right = arg.pos.right
                                    end
                                end
                            end
                        end
                    end
                end
                if arglist then
                    local ret = E(nfunctioncall, range(left.pos.left, right), self.precedence, self.right_associative, mt)
                    ret.left = left
                    ret.args = arglist
                    ret.self = sname
                    return ret
                end
            end
        end
    end

    do
        ---@class node_infix:node_expression
        ---@field left node_expression
        ---@field right node_expression

        local token_node_mapping = {
            [token.kw_or] = n.lor,
            [token.kw_and] = n.land,
            [token.less] = n.lt,
            [token.greater] = n.gt,
            [token.lessequal] = n.leq,
            [token.greaterequal] = n.geq,
            [token.notequal] = n.neq,
            [token.equal] = n.eq,
            [token.pipe] = n.bor,
            [token.tilde] = n.bxor,
            [token.ampersand] = n.band,
            [token.lshift] = n.lshift,
            [token.rshift] = n.rshift,
            [token.doubledot] = n.concat,
            [token.plus] = n.add,
            [token.dash] = n.sub,
            [token.asterisk] = n.mul,
            [token.slash] = n.div,
            [token.doubleslash] = n.fdiv,
            [token.percent] = n.mod,
            [token.caret] = n.exp,
        }

        local mt = {
            ---@param self node_infix
            ---@return string
            __tostring = function(self)
                local ret = {}
                local idx = 0
                local paren = self.left.precedence < self.precedence or self.left.precedence == self.precedence and self.right_associative
                if paren then
                    idx = idx + 1
                    ret[idx] = '('
                end
                idx = idx + 1
                ret[idx] = self.left
                if paren then
                    idx = idx + 1
                    ret[idx] = ')'
                end
                idx = idx + 1
                ret[idx] = n[self.type]
                paren = self.right.precedence < self.precedence or self.right.precedence == self.precedence and not self.right_associative
                if paren then
                    idx = idx + 1
                    ret[idx] = '('
                end
                idx = idx + 1
                ret[idx] = self.right
                if paren then
                    idx = idx + 1
                    ret[idx] = ')'
                end
                return tconcat(ret)
            end,
        }

        ---parselet to consume an infix expression
        ---@param self parselet
        ---@param p parser
        ---@param left node_expression
        ---@param tok token
        ---@return node_infix|nil
        infix = function(self, p, left, tok)
            local right = expression(p, self.precedence - (self.right_associative and 1 or 0))
            if not right then
                return nil
            end
            local ret = E(token_node_mapping[tok.type], range(left.pos.left, right.pos.right), self.precedence, self.right_associative, mt)
            ret.left = left
            ret.right = right
            return ret
        end
    end

    local parselet = {
        infix = {
            [token.kw_or] = { precedence = precedence.lor, parse = infix },
            [token.kw_and] = { precedence = precedence.land, parse = infix },
            [token.less] = { precedence = precedence.comparison, parse = infix },
            [token.greater] = { precedence = precedence.comparison, parse = infix },
            [token.lessequal] = { precedence = precedence.comparison, parse = infix },
            [token.greaterequal] = { precedence = precedence.comparison, parse = infix },
            [token.notequal] = { precedence = precedence.comparison, parse = infix },
            [token.equal] = { precedence = precedence.comparison, parse = infix },
            [token.pipe] = { precedence = precedence.bor, parse = infix },
            [token.tilde] = { precedence = precedence.bxor, parse = infix },
            [token.ampersand] = { precedence = precedence.band, parse = infix },
            [token.lshift] = { precedence = precedence.shift, parse = infix },
            [token.rshift] = { precedence = precedence.shift, parse = infix },
            [token.doubledot] = { precedence = precedence.concat, parse = infix, right_associative = true },
            [token.plus] = { precedence = precedence.add, parse = infix },
            [token.dash] = { precedence = precedence.add, parse = infix },
            [token.asterisk] = { precedence = precedence.mul, parse = infix },
            [token.slash] = { precedence = precedence.mul, parse = infix },
            [token.doubleslash] = { precedence = precedence.mul, parse = infix },
            [token.percent] = { precedence = precedence.mul, parse = infix },
            [token.caret] = { precedence = precedence.exp, parse = infix, right_associative = true },
            [token.lparen] = { precedence = precedence.atom, parse = fcall },
            [token.lbrace] = { precedence = precedence.atom, parse = fcall },
            [token.string] = { precedence = precedence.atom, parse = fcall },
            [token.colon] = { precedence = precedence.atom, parse = fcall },
            [token.lbracket] = { precedence = precedence.atom, parse = rawaccess },
            [token.dot] = { precedence = precedence.atom, parse = nameaccess },
        },
        prefix = {
            [token.kw_not] = { precedence = precedence.unary, parse = prefix },
            [token.hash] = { precedence = precedence.unary, parse = prefix },
            [token.dash] = { precedence = precedence.unary, parse = prefix },
            [token.tilde] = { precedence = precedence.unary, parse = prefix },
            [token.lparen] = { precedence = precedence.literal, parse = subexpression },
            [token.name] = { precedence = precedence.literal, parse = atom },
            [token.number] = { precedence = precedence.literal, parse = atom },
            [token.kw_nil] = { precedence = precedence.literal, parse = atom },
            [token.kw_false] = { precedence = precedence.literal, parse = atom },
            [token.kw_true] = { precedence = precedence.literal, parse = atom },
            [token.tripledot] = { precedence = precedence.literal, parse = atom },
            [token.string] = { precedence = precedence.literal, parse = atom },
            [token.kw_function] = { precedence = precedence.literal, parse = functiondef },
            [token.lbrace] = { precedence = precedence.literal, parse = tableconstructor },
        },
    }

    ---gets the precedence of the next available token
    ---@param self parser
    ---@return number
    local function get_precedence(self)
        local next = peek(self)
        if next then
            local p = parselet.infix[next.type]
            if p then
                return p.precedence
            end
        end
        return 0
    end

    ---try to consume a lua expression
    ---@param self parser
    ---@param prec number|nil
    ---@return node_expression|nil
    expression = function(self, prec)
        prec = prec or 0
        local id = next_id(self)
        if prec == 0 then
            local item = self.cache[id]
            if item then
                take_until(self, item.last)
                return item.value
            elseif item ~= nil then
                return
            end
        end
        local tok = peek(self)
        if tok then
            local pfix = parselet.prefix[tok.type]
            if pfix then
                begin(self)
                take(self)
                local left = pfix:parse(self, tok)
                if not left then
                    if prec == 0 then
                        self.cache[id] = { last = next_id(self), value = false }
                        self.cache_mapping.push_back(id)
                    end
                    undo(self)
                    return
                end
                while prec < get_precedence(self) do
                    tok = peek(self)
                    if not tok then
                        commit(self)
                        if prec == 0 then
                            self.cache[id] = { last = next_id(), value = left }
                            self.cache_mapping.push_back(id)
                        end
                        return left
                    end
                    local ifix = parselet.infix[tok.type]
                    if not ifix then
                        commit(self)
                        if prec == 0 then
                            self.cache[id] = { last = next_id(), value = left }
                            self.cache_mapping.push_back(id)
                        end
                        return left
                    end
                    begin(self)
                    take(self)
                    local right = ifix:parse(self, left, tok)
                    if not right then
                        undo(self)
                        undo(self)
                        if prec == 0 then
                            self.cache[id] = { last = next_id(self), value = left }
                            self.cache_mapping.push_back(id)
                        end
                        return left
                    else
                        commit(self)
                        left = right
                    end
                end
                commit(self)
                if prec == 0 then
                    self.cache[id] = { last = next_id(self), value = left }
                    self.cache_mapping.push_back(id)
                end
                return left
            elseif prec == 0 then
                self.cache[id] = { last = next_id(self), value = false }
                self.cache_mapping.push_back(id)
            end
        elseif prec == 0 then
            self.cache[id] = { last = next_id(self), value = false }
            self.cache_mapping.push_back(id)
        end
    end
end

do
    ---@class node_attrib:node
    ---@field name string

    local mt = {
        ---@param self node_attrib
        ---@return string
        __tostring = function(self)
            return '<' .. self.name .. '>'
        end,
    }

    local tless = token.less
    local tname = token.name
    local tgreater = token.greater
    local nattrib = n.attrib

    ---try to consume a lua variable attribute
    ---@param self parser
    ---@return node_attrib|nil
    attrib = function(self)
        local less = peek(self)
        if not less or less.type ~= tless then
            return
        end
        begintake(self)

        local nm = take(self)
        if not nm or nm.type ~= tname then
            undo(self)
            return
        end

        local greater = take(self)
        if not greater or greater.type ~= tgreater then
            undo(self)
            return
        end

        commit(self)
        local ret = N(nattrib, range(less.pos.left, greater.pos.right), mt)
        ret.name = nm.value
        return ret
    end
end

do
    ---@class node_name:node
    ---@field value string

    local mt = {
        ---@param self node_name
        ---@return string
        __tostring = function(self)
            return self.value
        end,
    }

    local tname = token.name
    local nname = n.name

    ---try to consume a lua name
    ---@param self parser
    ---@return node_name|nil
    name = function(self)
        local tok = peek(self)
        if tok and tok.type == tname then
            take(self)
            local ret = N(nname, tok.pos, mt)
            ret.value = tok.value
            return ret
        end
    end
end

do
    ---@class node_attnamelist:node

    ---@class node_attname:node
    ---@field name node_name
    ---@field attrib node_attrib

    local mt = {
        ---@param self node_attnamelist
        ---@return string
        __tostring = function(self)
            local ret = {}
            for i, x in ipairs(self) do
                if i > 1 then
                    tinsert(ret, ',')
                end
                tinsert(ret, x.name)
                if x.attrib then
                    tinsert(ret, x.attrib)
                end
            end
            return tconcat(ret)
        end,
    }

    local nattname = n.attname
    local nattnamelist = n.attnamelist
    local tcomma = token.comma

    ---try to consume a lua name attribute list
    ---@param self parser
    ---@return node_attnamelist|nil
    attnamelist = function(self)
        local nm = name(self)
        if nm then
            local a = attrib(self)
            local tmp = N(nattname, range(nm.pos.left, (a and a.pos.right or nm.pos.right)))
            tmp.name, tmp.attrib = nm, a
            local ret = N(nattnamelist, range(nm.pos.left), mt)
            ret[1] = tmp
            local idx = 1
            while true do
                local t = peek(self)
                if not t or t.type ~= tcomma then
                    break
                end
                begin(self)
                take(self)
                nm = name(self)
                if nm then
                    a = attrib(self)
                    commit(self)
                    idx = idx + 1
                    local item = N(nattname, range(nm.pos.left, (a and a.pos.right or nm.pos.right)))
                    item.name, item.attrib = nm, a
                    ret[idx] = item
                else
                    undo(self)
                    break
                end
            end

            local last = ret[idx]
            ret.pos.right = (last.attrib and last.attrib or last.name).pos.right
            return ret
        end
    end
end

do
    ---@class node_explist:node

    local nexplist = n.explist
    local tcomma = token.comma

    local mt = {
        ---@param self node_explist
        ---@return string
        __tostring = function(self)
            local ret = {}
            for i, x in ipairs(self) do
                if i > 1 then
                    tinsert(ret, ',')
                end
                tinsert(ret, x)
            end
            return tconcat(ret)
        end,
    }

    ---try to consume an expression list
    ---@param self parser
    ---@return node_explist|nil
    explist = function(self)
        local v = expression(self)
        if v then
            local ret = N(nexplist, range(v.pos.left), mt)
            ret[1] = v
            local idx = 1
            while true do
                local t = peek(self)
                if not t or t.type ~= tcomma then
                    break
                end
                begin(self)
                take(self)
                v = expression(self)
                if v then
                    commit(self)
                    idx = idx + 1
                    ret[idx] = v
                else
                    undo(self)
                    break
                end
            end

            ret.pos.right = ret[idx].pos.right
            return ret
        end
    end
end

do
    ---@class node_localvar:node
    ---@field names node_attnamelist
    ---@field values node_explist|nil

    local mt = {
        ---@param self node_localvar
        ---@return string
        __tostring = function(self)
            local ret = { 'local', self.names }
            if self.values then
                tinsert(ret, '=', self.values)
            end
            return tconcat(ret)
        end,
    }

    local tkw_local = token.kw_local
    local nstat_localvar = n.stat_localvar
    local tassignment = token.assignment

    ---try to consume a lua local variable declaration
    ---@param self parser
    ---@return node_localvar|nil
    localvar = function(self)
        local tok = peek(self)
        if tok and tok.type == tkw_local then
            begintake(self)
            local names = attnamelist(self)
            if names then
                local position = range(tok.pos.left)
                local ret = N(nstat_localvar, position, mt)
                commit(self)
                tok = peek(self)
                if tok and tok.type == tassignment then
                    begintake(self)
                    ret.values = explist(self)
                    if ret.values then
                        commit(self)
                        position.right = ret.values.pos.right
                    else
                        undo(self)
                        position.right = names.pos.right
                    end
                else
                    position.right = names.pos.right
                end
                return ret
            end
            undo(self)
        end
    end
end
do
    ---@class node_empty:node

    local mt = {
        __tostring = function()
            return ';'
        end,
    }

    local tsemicolon = token.semicolon
    local nstat_empty = n.stat_empty

    ---try to consume a lua empty statement
    ---@param self parser
    ---@return node_empty|nil
    empty = function(self)
        local tok = peek(self)
        if tok and tok.type == tsemicolon then
            take(self)
            return N(nstat_empty, tok.pos, mt)
        end
    end
end

do
    ---@class node_retstat:node
    ---@field explist node_explist|nil

    local mt = {
        ---@param self node_retstat
        ---@return string
        __tostring = function(self)
            local ret = { 'return' }
            if self.explist then
                tinsert(ret, self.explist)
            end
            return tconcat(ret)
        end,
    }

    local tkw_return = token.kw_return
    local nretstat = n.retstat
    local tsemicolon = token.semicolon

    ---try to consume a lua return statement
    ---@param self parser
    ---@return node_retstat|nil
    retstat = function(self)
        local retkw = peek(self)
        if retkw and retkw.type == tkw_return then
            take(self)
            local p = range(retkw.pos.left)
            local ret = N(nretstat, p, mt)
            ret.explist = explist(self)
            local tok = peek(self)
            if tok and tok.type == tsemicolon then
                take(self)
                p.right = tok.pos.right
            else
                p.right = ret.explist and ret.explist.pos.right or retkw.pos.right
            end
            return ret
        end
    end
end

do
    ---try to consume a lua statement
    ---@param self parser
    ---@return node_localvar|node_functioncall|node_assign|node_if|node_func|node_for_iter|node_for_num|node_do|node_break|node_while|node_goto|node_empty|node_repeat|node_label
    stat = function(self)
        return localvar(self)
            or functioncall(self)
            or assign(self)
            or stat_if(self)
            or func(self)
            or localfunc(self)
            or for_iter(self)
            or for_num(self)
            or stat_do(self)
            or stat_break(self)
            or stat_while(self)
            or stat_goto(self)
            or empty(self)
            or stat_repeat(self)
            or label(self)
    end
end

do
    ---@class node_block:node

    local mt = {
        __tostring = function(self)
            local ret = {}
            for _, x in ipairs(self) do
                tinsert(ret, x)
            end
            return tconcat(ret)
        end,
    }

    local nblock = n.block

    ---consumes a lua block
    ---@param self parser
    ---@return node_block
    block = function(self)
        local ret = N(nblock, nil, mt)
        local idx = 0
        while true do
            local stmt = stat(self)
            if not stmt then
                break
            end
            idx = idx + 1
            ret[idx] = stmt
        end
        local rs = retstat(self)
        if rs then
            idx = idx + 1
            ret[idx] = rs
        end

        ret.pos = idx == 0 and range(pos(self), pos(self)) or range(ret[1].pos.left, ret[idx].pos.right)
        return ret
    end
end

do
    local nblock = n.block

    local empty_mt = {
        __tostring = function()
            return ''
        end,
    }
    ---try to parse a lua chunk
    ---@param self parser
    ---@return node_block
    chunk = function(self)
        if peek(self) then
            local cache = {}
            self.cache = cache
            local cache_mapping = deque()
            self.cache_mapping = cache_mapping
            self.on_flush = function(id)
                while true do
                    local f = self.cache_mapping.peek_front()
                    if not f or f >= id then
                        break
                    end
                    cache[f] = nil
                    self.cache_mapping.pop_front()
                end
            end
            local success, ret = pcall(block, self)
            self.on_flush = nil
            self.cache = nil
            self.cache_mapping = nil
            if not success then
                error(ret)
            end
            local nxt = self.la[self.la.size()] or nil
            if ret then
                if nxt then
                    error(tostring(nxt.pos.left) .. ':UNMATCHED_TOKEN: ' .. tostring(nxt))
                end
                return ret
            elseif nxt then
                error(tostring(nxt.pos.left) .. ':UNMATCHED_TOKEN: ' .. tostring(nxt))
            else
                error(tostring(nxt.pos.left) .. ':PARSE_FAILURE')
            end
        else
            return N(nblock, range(pos(self), pos(self)), empty_mt)
        end
    end
end

return parser
