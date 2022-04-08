local function nullfunc() end
local setmetatable = setmetatable
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local concat = table.concat
local insert = table.insert
local tsort = table.sort
local tconcat
local tinsert

local n = require 'qamar.parser.types'
local token = require 'qamar.tokenizer.types'
local tcomment = token.comment

local slen = string.len
local sbyte = string.byte
local schar = string.char
local ssub = string.sub
local sfind = string.find
local slower = string.lower
local smatch = string.match
local sescape
local sutf8
local strim

do
    ---Trims whitespace from either end of the string
    ---@param self string
    ---@return string
    strim = function(self)
        local from = smatch(self, '^%s*()')
        return from > slen(self) and '' or smatch(self, '.*%S', from)
    end

    ---returns an iterator that returns valid utf-8 codepoints in a string but also returns and flags invalid data by returning true as a second parameter
    ---@param self string
    ---@return function
    sutf8 = function(self)
        local index, max, nextvalid, nextindex = 0, slen(self)

        ---@param left number
        ---@return string|nil
        ---@return number|nil
        ---@return number|nil
        local function find_codepoint(left)
            if left <= max then
                local c = sbyte(self, left, left)
                local cont_bytes
                if c < 128 then
                    cont_bytes = 0
                elseif c >= 0xc0 and c <= 0xdf then
                    cont_bytes = 1
                elseif c >= 0xe0 and c <= 0xef then
                    cont_bytes = 2
                elseif c >= 0xf0 and c <= 0xf7 then
                    cont_bytes = 3
                else
                    return find_codepoint(left + 1)
                end
                local right = left + cont_bytes
                if right <= max then
                    local ret = ssub(self, left, right)
                    for i = 2, cont_bytes + 1 do
                        c = sbyte(ret, i, i)
                        if c < 0x80 or c > 0xbf then
                            return find_codepoint(left + 1)
                        end
                    end
                    return ret, left, right
                end
            end
        end

        ---iterator returned by string:utf8
        ---    is_utf8 == true:  data is a valid utf-8 codepoint
        ---
        ---    is_utf8 == false: data is a raw string up to the next valid utf-8 codepoint
        ---@return string|nil data dsfdafsd
        ---@return boolean is_utf8
        return function()
            if nextindex then
                index, nextindex = nextindex, nil
                return nextvalid, true
            elseif index < max then
                index = index + 1
                local codepoint, left, right = find_codepoint(index)
                if not codepoint then
                    local ret = ssub(self, index, max)
                    index = max
                    return ret, false
                end
                if left > index then
                    nextvalid, nextindex = codepoint, right
                    return ssub(self, index, left - 1), false
                end
                index = right
                return codepoint, true
            end
        end
    end

    local function is_utf8(self)
        for _, x in sutf8(self) do
            if not x then
                return false
            end
        end
        return true
    end

    local function escape_char(c)
        if c == '\\' then
            return '\\\\'
        elseif c == '\v' then
            return '\\v'
        elseif c == '\t' then
            return '\\t'
        elseif c == '\r' then
            return '\\r'
        elseif c == '\n' then
            return '\\n'
        elseif c == '\f' then
            return '\\f'
        elseif c == '\b' then
            return '\\b'
        elseif c == '\a' then
            return '\\a'
        else
            local b = sbyte(c)
            if b < 32 or b >= 127 then
                local ret = { '\\' }
                local i = 0
                local str = tostring(b)
                for _ = slen(str), 2 do
                    i = i + 1
                    ret[i] = '0'
                end
                i = i + 1
                ret[i] = str
                return concat(ret)
            else
                return c
            end
        end
        return c
    end

    sescape = function(self)
        local S = nil
        if is_utf8(self) and not sfind(self, '\r') then
            local term_parts = { ']', ']' }
            local idx = 2
            while sfind(self, concat(term_parts)) do
                insert(term_parts, idx, '=')
                idx = idx + 1
            end
            local close_term = concat(term_parts)
            term_parts[1], term_parts[#term_parts] = '[', '['
            local open_term = concat(term_parts)
            if ssub(self, 1, 1) == '\n' then
                open_term = open_term .. '\n'
            end
            S = open_term .. self .. close_term
        end
        local ret, idx = {}, 0
        for data, u in sutf8(self) do
            if u then
                idx = idx + 1
                ret[idx] = escape_char(data)
            else
                for i = 1, slen(data) do
                    idx = idx + 1
                    ret[idx] = escape_char(ssub(data, i, i))
                end
            end
        end
        local a, b = 0, 0
        for _, x in ipairs(ret) do
            if x == "'" then
                a = a + 1
            elseif x == '"' then
                b = b + 1
            end
        end
        if b >= a then
            a, b = "'", "\\'"
        else
            a, b = '"', '\\"'
        end
        for i, x in ipairs(ret) do
            if x == a then
                ret[i] = b
            end
        end
        idx = idx + 1
        ret[idx] = a
        local S2 = a .. concat(ret)
        return S and slen(S) < slen(S2) and S or S2
    end
end

do
    local function isalphanum(tok)
        local byte = sbyte(tok)
        return byte >= 97 and byte <= 122 or byte >= 65 and byte <= 90 or byte >= 48 and byte <= 57 or byte == 95
    end

    tconcat = function(self)
        local prevalpha = false
        local ret = {}
        local i = 0
        for _, x in ipairs(self) do
            x = strim(tostring(x))
            if x ~= '' then
                if prevalpha and isalphanum(ssub(x, 1, 1)) then
                    i = i + 1
                    ret[i] = ' '
                end
                i = i + 1
                ret[i] = x
                prevalpha = isalphanum(ssub(x, slen(x), slen(x)))
            end
        end
        return concat(ret)
    end

    tinsert = function(tbl, ...)
        local idx = #tbl
        local args = { ... }
        for i = 1, #args do
            idx = idx + 1
            tbl[idx] = args[i]
        end
        return tbl
    end
end

local N
do
    ---@class node
    ---@field pos range
    ---@field type number
    local mt = {}

    local MTMT = {
        __index = mt,
    }
    setmetatable(mt, MTMT)

    ---creates a new node object
    ---@param type number
    ---@param pos range
    ---@param MT table|nil
    ---@return node
    N = function(type, pos, MT)
        return setmetatable({ type = type, pos = pos }, MT and setmetatable(MT, MTMT) or mt)
    end
end

local T
do
    ---@class token
    ---@field value string
    ---@field type number
    ---@field pos range
    ---@field id number

    local mt = {
        __metatable = nullfunc,
        ---@param self token
        ---@return string
        __tostring = function(self)
            return self.value
        end,
    }

    ---creates a new token
    ---@param type number
    ---@param value string
    ---@param pos range
    ---@param MT table|nil
    ---@return token
    T = function(type, value, pos, MT)
        return setmetatable({
            type = type,
            value = value,
            pos = pos,
        }, MT or mt)
    end
end

local position
do
    ---@class position
    ---@field row number
    ---@field col number
    ---@field byte number
    ---@field file_char number
    ---@field file_byte number
    local MT = {
        __metatable = nullfunc,
        __tostring = function(self)
            return self.row .. ':' .. self.col
        end,
    }

    ---create a new position object
    ---@param row number
    ---@param col number
    ---@param byte number
    ---@param file_char number
    ---@param file_byte number
    ---@return position
    position = function(row, col, byte, file_char, file_byte)
        return setmetatable({
            row = row,
            col = col,
            byte = byte,
            file_char = file_char,
            file_byte = file_byte,
        }, MT)
    end
end

local range
do
    ---@class range
    ---@field left position
    ---@field right position
    local MT = {
        __metatable = nullfunc,
        __tostring = function(self)
            return self.left .. ' - ' .. self.right
        end,
    }

    ---create a new range object
    ---@param left position
    ---@param right position
    ---@return range
    range = function(left, right)
        return setmetatable({
            left = left,
            right = right,
        }, MT)
    end
end

local deque
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

local char_stream
do
    ---@class char_transaction
    ---@field index number
    ---@field row number
    ---@field col number
    ---@field byte number
    ---@field file_char number
    ---@field file_byte number

    ---@class char_stream
    ---@field input function()
    ---@field la deque
    ---@field ts table
    ---@field tc number
    ---@field skip_ws_ctr number
    ---@field t char_transaction

    ---@type char_stream
    char_stream = {}
    local MT = {
        __index = char_stream,
        __metatable = nullfunc,
        __tostring = function(self)
            local ret = {}
            local idx = 0
            for i = 1, self.la.size() do
                local line = { (i - 1 == self.t.index) and '==> ' or '    ' }
                local c = self.la[i]
                line[2] = vim.inspect(c)
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

    ---creates a copy of a transaction
    ---@param self char_transaction
    ---@return char_transaction
    local function transaction_copy(self)
        return {
            index = self.index,
            file_char = self.file_char,
            row = self.row,
            col = self.col,
            byte = self.byte,
            file_byte = self.file_byte,
        }
    end

    ---creates a new parser
    ---@param input function():string|nil
    ---@return char_stream|nil
    ---@return string|nil
    function char_stream.new(input)
        if type(input) ~= 'function' then
            return nil, 'expected a function as input'
        end
        do
            local _input = input
            input = function()
                if _input then
                    local ret = _input()
                    if ret then
                        return ret
                    end
                    _input = nil
                end
            end
        end
        return setmetatable({
            input = input,
            la = deque(),
            ts = {},
            tc = 0,
            skip_ws_ctr = 0,
            t = {
                index = 0,
                file_char = 0,
                row = 1,
                col = 1,
                byte = 0,
                file_byte = 0,
            },
        }, MT)
    end

    ---begins a new transaction, must be followed by a matching call to undo or commit
    function char_stream:begin()
        self.tc = self.tc + 1
        self.ts[self.tc] = transaction_copy(self.t)
    end

    ---undoes a transaction. must be paired with a preceding call to begin
    function char_stream:undo()
        self.t, self.ts[self.tc], self.tc = self.ts[self.tc], nil, self.tc - 1
    end

    ---discards all consumed tokens if there are no pending transactions
    ---@param self char_stream
    local function normalize(self)
        if self.tc == 0 then
            for _ = 1, self.t.index do
                self.la.pop_front()
            end
            self.t.index = 0
        end
    end
    char_stream.normalize = normalize

    ---commits a transaction. must be paired with a preceding call to begin
    ---@return nil
    function char_stream:commit()
        self.ts[self.tc], self.tc = nil, self.tc - 1
        return normalize(self)
    end

    ---ensures the internal buffer contains at least 'amt' items, unless the end of stream has been reached
    ---@param self char_stream
    ---@param amt number
    local function fill(self, amt)
        while self.la.size() < amt do
            local c = self.input()
            if c then
                self.la.push_back(c)
            elseif self.la.size() == 0 or self.la[self.la.size()] then
                self.la.push_back(false)
                break
            end
        end
    end
    char_stream.fill = fill

    ---gets the Nth token (zero based) in the internal buffer.
    ---N defaults to 0
    ---@param self char_stream
    ---@param amt number|nil
    ---@return string|nil
    local function peek(self, amt)
        amt = amt == nil and 0 or amt
        local idx = self.t.index + amt + 1
        fill(self, idx)
        return self.la[idx] or nil
    end
    char_stream.peek = peek

    ---consumes N characters from the stream
    ---@param self char_stream
    ---@param amt number
    ---@return string|nil
    local function take(self, amt)
        amt = amt == nil and 1 or amt
        local idx = self.t.index + amt
        fill(self, idx)
        local ret = {}
        for i = 1, amt do
            local c = self.la[self.t.index + 1]
            if not c then
                break
            else
                local off = slen(c)
                self.t.file_char, self.t.file_byte = self.t.file_char + 1, self.t.file_byte + off
                if c == '\n' then
                    self.t.row, self.t.col, self.t.byte = self.t.row + 1, 1, 0
                else
                    self.t.col, self.t.byte = self.t.col + 1, self.t.byte + off
                end
                ret[i] = c
            end
            self.t.index = self.t.index + 1
        end
        normalize(self)
        return #ret > 0 and concat(ret) or nil
    end
    char_stream.take = take

    ---gets the stream's current position
    ---@return position
    function char_stream:pos()
        local t = self.t
        return position(t.row, t.col, t.byte, t.file_char, t.file_byte)
    end

    ---tries to consume a specified string. consumes nothing if the string does not match
    ---@param s string
    ---@return string|nil
    function char_stream:try_consume_string(s)
        local i = 0
        for x in sutf8(s) do
            local c = peek(self, i)
            if c ~= x then
                return
            end
            i = i + 1
        end
        return take(self, i)
    end

    ---consumes any subsequent whitespace characters
    function char_stream:skipws()
        if self.skip_ws_ctr == 0 then
            while true do
                local c = peek(self)
                if c ~= ' ' and c ~= '\f' and c ~= '\n' and c ~= '\r' and c ~= '\t' and c ~= '\v' then
                    break
                end
                take(self)
            end
        end
    end

    ---suspends automatic skipping of whitespace characters. must be paired with a call to resume_skip_ws
    function char_stream:suspend_skip_ws()
        self.skip_ws_ctr = self.skip_ws_ctr + 1
    end

    ---resumes automatic skipping of whitespace characters. must be paired with a preceding call to suspend_skip_ws
    function char_stream:resume_skip_ws()
        if self.skip_ws_ctr > 0 then
            self.skip_ws_ctr = self.skip_ws_ctr - 1
        end
    end

    local ascii = string.byte

    ---tries to match and consume an alpha or underscore character
    ---@param self char_stream
    ---@return string|nil
    char_stream.alpha = function(self)
        local tok = peek(self)
        if tok then
            local byte = ascii(tok)
            if byte >= 97 and byte <= 122 or byte >= 65 and byte <= 90 or byte == 95 then
                take(self)
                return tok
            end
        end
    end

    ---tries to match and consume a numeric character
    ---@param self char_stream
    ---@return string|nil
    char_stream.numeric = function(self)
        local tok = peek(self)
        if tok then
            local byte = ascii(tok)
            if byte >= 48 and byte <= 57 then
                return take(self)
            end
        end
    end

    ---tries to match and consume an alphanumeric or underscore character
    ---@param self char_stream
    ---@return string|nil
    char_stream.alphanumeric = function(self)
        local tok = peek(self)
        if tok then
            local byte = ascii(tok)
            if byte >= 97 and byte <= 122 or byte >= 65 and byte <= 90 or byte >= 48 and byte <= 57 or byte == 95 then
                return take(self)
            end
        end
    end
end
local stpos = char_stream.pos
local stpeek = char_stream.peek
local sttake = char_stream.take
local stbegin = char_stream.begin
local stundo = char_stream.undo
local stskipws = char_stream.skipws
local stcommit = char_stream.commit
local sttry_consume_string = char_stream.try_consume_string
local stsuspend_skip_ws = char_stream.suspend_skip_ws
local stresume_skip_ws = char_stream.resume_skip_ws
local stnumeric = char_stream.numeric
local stalphanumeric = char_stream.alphanumeric
local stalpha = char_stream.alpha

local tokenizer
do
    local comment, name, keyword, number, string_token, symbol

    do
        ---tries to match and consume a lua comment
        ---@param self char_stream
        ---@return token
        comment = function(self)
            stbegin(self)
            stskipws(self)
            stsuspend_skip_ws(self)
            local pos = stpos(self)
            local cmnt = sttry_consume_string(self, '--')
            if not cmnt then
                stresume_skip_ws(self)
                stundo(self)
                return nil
            end
            local ret = string_token(self, true)
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
        local function p(self)
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
            local ret = p(self)
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
        string_token = function(self, disallow_short_form)
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
            return T(tstring, concat(ret), range(pos, stpos(self)), MT)
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
        local function p(self)
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
            local ret = p(self)
            if ret then
                stcommit(self)
                return T(symbols[ret], ret, range(pos, stpos(self)))
            end
            stundo(self)
        end
    end

    local tokenizers = {
        comment,
        name,
        keyword,
        number,
        string_token,
        symbol,
    }

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

---creates a copy of a token_transaction
---@param self parser_transaction
---@return parser_transaction
local function copy_transaction(self)
    return { index = self.index, pos = self.pos }
end

local chunk

local parse_from_stream
do
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
    ---creates a new parser
    ---@param stream char_stream
    ---@return node_block
    parse_from_stream = function(stream)
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
end

---parses a lua chunk
---@param str string
---@return node_block
function parser.parse(str)
    return parse_from_stream(char_stream.new(sutf8(str)))
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
---N defaults to 0
---@param self parser
---@param amt number|nil
---@return token
local function peek(self, amt)
    amt = amt == nil and 0 or amt
    local idx = self.t.index + amt + 1
    fill(self, idx)
    return self.la[idx] or nil
end
parser.peek = peek

---consumes N tokens from the token cache.
---N defaults to 1
---@param self parser
---@param amt number|nil
---@return token|table
local function take(self, amt)
    amt = amt == nil and 1 or amt
    local idx = self.t.index + amt
    fill(self, idx)
    local ret = {}
    for i = 1, amt do
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
---@param self parser
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
---@param id number
function parser:take_until(id)
    while true do
        local x = peek(self)
        if not x or x.id >= id then
            return
        end
        take(self)
    end
end

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
---@param amt parser
---@return token|nil
function parser:begintake(amt)
    begin(self)
    return take(self, amt)
end

---------------------------------------------------------------
local block

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

    local st, rst
    st = function(self)
        st = require 'qamar.parser.production.stat'
        return st(self)
    end
    rst = function(self)
        rst = require 'qamar.parser.production.retstat'
        return rst(self)
    end
    local nblock = n.block

    ---consumes a lua block
    ---@param self parser
    ---@return node_block
    block = function(self)
        local ret = N(nblock, nil, mt)
        local idx = 0
        while true do
            local stat = st(self)
            if not stat then
                break
            end
            idx = idx + 1
            ret[idx] = stat
        end
        local retstat = rst(self)
        if retstat then
            idx = idx + 1
            ret[idx] = retstat
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
