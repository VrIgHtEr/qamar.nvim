local string = setmetatable({}, { __index = string })

--- Iterate over characters of a string
---@param self string
---@return function Iterator
function string:chars()
    local i, max = 0, #self
    return function()
        if i < max then
            i = i + 1
            return self:sub(i, i)
        end
    end
end

---Iterate over bytes of a string
---@param self string
---@return function Iterator
function string:bytes()
    local i, max = 0, #self
    return function()
        if i < max then
            i = i + 1
            return self:byte(i)
        end
    end
end

---Iterate over UTF8 codepoints in a string
---@param self string
---@return function Iterator
function string:codepoints()
    local nxt, cache = string.bytes(self)
    return function()
        local c = cache or nxt()
        cache = nil
        if c == nil then
            return
        end
        if c <= 127 then
            return string.char(c)
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
        return string.char(unpack(ret))
    end
end

---Iterate over UTF8 codepoints in a string, while converting windows (\r\n) or mac (\r) newlines to linux format (\n)
---@param self string
---@return function Iterator
function string:filteredcodepoints()
    local codepoint, cache = string.codepoints(self)
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

---Returns an iterator that returns individual lines in a string, handling any format of newline
---@param self string
---@return function Iterator
function string:lines()
    local codepoints = string.filteredcodepoints(self)
    return function()
        local line = {}
        local i = 0
        for c in codepoints do
            if c == '\n' then
                return table.concat(line)
            end
            i = i + 1
            line[i] = c
        end
        if #line > 0 then
            return table.concat(line)
        end
    end
end

---Trims whitespace from either end of the string
---@param self string
---@return string
function string:trim()
    local from = self:match '^%s*()'
    return from > #self and '' or self:match('.*%S', from)
end

---Returns the Levenshtein distance between two strings
---@param self string
---@param B string
---@return number
function string:distance(B)
    local la, lb, x = self:len(), B:len(), {}
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
        local t, l, v = r - 1, r, self:sub(r, r)
        for c = 1, lb do
            if v ~= B:sub(c, c) then
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
function string:utf8()
    local index, max, nextvalid, nextindex = 0, string.len(self)

    ---@param left number
    ---@return string|nil
    ---@return number|nil
    ---@return number|nil
    local function find_codepoint(left)
        if left <= max then
            local c = string.byte(self, left, left)
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
                local ret = string.sub(self, left, right)
                for i = 2, cont_bytes + 1 do
                    c = string.byte(ret, i, i)
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
                local ret = string.sub(self, index, max)
                index = max
                return ret, false
            end
            if left > index then
                nextvalid, nextindex = codepoint, right
                return string.sub(self, index, left - 1), false
            end
            index = right
            return codepoint, true
        end
    end
end

function string:is_utf8()
    for _, x in string.utf8(self) do
        if not x then
            return false
        end
    end
    return true
end

function string:count(patt)
    local count = 0
    for _ in string.gmatch(self, patt) do
        count = count + 1
    end
    return count
end

local verbatim_newline_count = 3
local function escape_char(char)
    if char == '\\' then
        return '\\\\'
    elseif char == '\v' then
        return '\\v'
    elseif char == '\t' then
        return '\\t'
    elseif char == '\r' then
        return '\\r'
    elseif char == '\n' then
        return '\\n'
    elseif char == '\f' then
        return '\\f'
    elseif char == '\b' then
        return '\\b'
    elseif char == '\a' then
        return '\\a'
    else
        local b = string.byte(char)
        if b < 32 or b >= 127 then
            local ret = { '\\' }
            local i = 0
            local str = tostring(b)
            for _ = string.len(str), 2 do
                i = i + 1
                ret[i] = '0'
            end
            i = i + 1
            ret[i] = str
            return table.concat(ret)
        else
            return char
        end
    end
    return char
end

function string:escape()
    if string.is_utf8(self) and not string.find(self, '\r') then
        local count = string.count(self, '\n')
        for _ in string.gmatch(self, '\n') do
            count = count + 1
        end
        if count >= verbatim_newline_count then
            local term_parts = { ']', ']' }
            local idx = 2
            while string.find(self, table.concat(term_parts)) do
                table.insert(term_parts, idx, '=')
                idx = idx + 1
            end
            local close_term = table.concat(term_parts)
            term_parts[1], term_parts[#term_parts] = '[', '['
            local open_term = table.concat(term_parts)
            if string.sub(self, 1, 1) == '\n' then
                open_term = open_term .. '\n'
            end
            return open_term .. self .. close_term
        end
    end
    local ret, idx = {}, 0
    for data, utf8 in string.utf8(self) do
        if utf8 then
            idx = idx + 1
            ret[idx] = escape_char(data)
        else
            for i = 1, string.len(data) do
                idx = idx + 1
                ret[idx] = escape_char(string.sub(data, i, i))
            end
        end
    end
    local single, double = 0, 0
    for _, x in ipairs(ret) do
        if x == "'" then
            single = single + 1
        elseif x == '"' then
            double = double + 1
        end
    end
    if double >= single then
        single, double = "'", "\\'"
    else
        single, double = '"', '\\"'
    end
    for i, x in ipairs(ret) do
        if x == single then
            ret[i] = double
        end
    end
    idx = idx + 1
    ret[idx] = single
    return single .. table.concat(ret)
end

return string
