local string = setmetatable({}, { __index = string })
local sub = string.sub
local char = string.char
local ascii = string.byte
local match = string.match
local len = string.len
local find = string.find
local gmatch = string.gmatch
local concat = table.concat
local insert = table.insert
local ipairs = ipairs

--- Iterate over characters of a string
---@param self string
---@return function Iterator
function string:chars()
    local i, max = 0, #self
    return function()
        if i < max then
            i = i + 1
            return sub(self, i, i)
        end
    end
end

---Iterate over bytes of a string
---@param self string
---@return function Iterator
local function bytes(self)
    local i, max = 0, #self
    return function()
        if i < max then
            i = i + 1
            return ascii(self, i)
        end
    end
end
string.bytes = bytes

---Iterate over UTF8 codepoints in a string
---@param self string
---@return function Iterator
local function codepoints(self)
    local nxt, cache = bytes(self)
    return function()
        local c = cache or nxt()
        cache = nil
        if c == nil then
            return
        end
        if c <= 127 then
            return char(c)
        end
        assert(c >= 194 and c <= 244, 'invalid byte in utf-8 sequence: ' .. tostring(c))
        local ret = { c }
        local i = 1
        c = nxt()
        assert(c, 'unexpected eof in utf-8 string')
        assert(c >= 128 and c <= 191, 'expected multibyte sequence: ' .. tostring(c))
        i = i + 1
        ret[i] = c
        local count = 2
        while true do
            cache = nxt()
            if not cache or cache < 128 or cache > 191 then
                break
            end
            count = count + 1
            if count > 4 then
                error 'multibyte sequence too long in utf-8 string'
            end
            i = i + 1
            ret[i] = cache
        end
        return char(unpack(ret))
    end
end
string.codepoints = codepoints

---Iterate over UTF8 codepoints in a string, while converting windows (\r\n) or mac (\r) newlines to linux format (\n)
---@param self string
---@return function Iterator
local function filteredcodepoints(self)
    local codepoint, cache = codepoints(self)
    return function()
        local cp = cache or codepoint()
        cache = nil
        if cp == '\r' then
            cache = codepoint()
            if cache == '\n' then
                cache = nil
            end
            return '\n'
        elseif cp then
            return cp
        end
    end
end
string.filteredcodepoints = filteredcodepoints

---Returns an iterator that returns individual lines in a string, handling any format of newline
---@param self string
---@return function Iterator
function string:lines()
    local points = filteredcodepoints(self)
    return function()
        local line = {}
        local i = 0
        for c in points do
            if c == '\n' then
                return concat(line)
            end
            i = i + 1
            line[i] = c
        end
        if #line > 0 then
            return concat(line)
        end
    end
end

---Trims whitespace from either end of the string
---@param self string
---@return string
function string:trim()
    local from = match(self, '^%s*()')
    return from > len(self) and '' or match(self, '.*%S', from)
end

---Returns the Levenshtein distance between two strings
---@param self string
---@param B string
---@return number
function string:distance(B)
    local la, lb, x = len(self), len(B), {}
    if la == 0 then
        return lb
    end
    if lb == 0 then
        return la
    end
    if la < lb then
        self, la, B, lb = B, lb, self, la
    end
    for i = 1, lb do
        x[i] = i
    end
    for r = 1, la do
        local t, l, v = r - 1, r, sub(self, r, r)
        for c = 1, lb do
            if v ~= sub(B, c, c) then
                if x[c] < t then
                    t = x[c]
                end
                if l < t then
                    t = l
                end
                t = t + 1
            end
            x[c], l, t = t, t, x[c]
        end
    end
    return x[lb]
end

---returns an iterator that returns valid utf-8 codepoints in a string but also returns and flags invalid data by returning true as a second parameter
---@param self string
---@return function
local function utf8(self)
    local index, max, nextvalid, nextindex = 0, len(self)

    ---@param left number
    ---@return string|nil
    ---@return number|nil
    ---@return number|nil
    local function find_codepoint(left)
        if left <= max then
            local c = ascii(self, left, left)
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
                local ret = sub(self, left, right)
                for i = 2, cont_bytes + 1 do
                    c = ascii(ret, i, i)
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
                local ret = sub(self, index, max)
                index = max
                return ret, false
            end
            if left > index then
                nextvalid, nextindex = codepoint, right
                return sub(self, index, left - 1), false
            end
            index = right
            return codepoint, true
        end
    end
end
string.utf8 = utf8

local function is_utf8(self)
    for _, x in utf8(self) do
        if not x then
            return false
        end
    end
    return true
end
string.is_utf8 = is_utf8

function string:count(patt)
    local count = 0
    for _ in gmatch(self, patt) do
        count = count + 1
    end
    return count
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
        local b = ascii(c)
        if b < 32 or b >= 127 then
            local ret = { '\\' }
            local i = 0
            local str = tostring(b)
            for _ = len(str), 2 do
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

function string:escape(disallow_verbatim)
    local S = nil
    if not disallow_verbatim and is_utf8(self) and not find(self, '\r') then
        local term_parts = { ']', ']' }
        local idx = 2
        while find(self, concat(term_parts)) do
            insert(term_parts, idx, '=')
            idx = idx + 1
        end
        local close_term = concat(term_parts)
        term_parts[1], term_parts[#term_parts] = '[', '['
        local open_term = concat(term_parts)
        if sub(self, 1, 1) == '\n' then
            open_term = open_term .. '\n'
        end
        S = open_term .. self .. close_term
    end
    local ret, idx = {}, 0
    for data, u in utf8(self) do
        if u then
            idx = idx + 1
            ret[idx] = escape_char(data)
        else
            for i = 1, len(data) do
                idx = idx + 1
                ret[idx] = escape_char(sub(data, i, i))
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
    return S and len(S) < len(S2) and S or S2
end

return string
