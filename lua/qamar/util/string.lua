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
        c = nxt()
        assert(c, 'unexpected eof in utf-8 string')
        assert(c >= 128 and c <= 191, 'expected multibyte sequence: ' .. tostring(c))
        table.insert(ret, c)
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
            table.insert(ret, cache)
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
        for c in codepoints do
            if c == '\n' then
                return table.concat(line)
            end
            table.insert(line, c)
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

    ---@param left string
    ---@return string|nil
    ---@return number|nil
    ---@return number|nil
    local function find_codepoint(left)
        if left <= max then
            local c = string.byte(string.sub(self, left, left))
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
                local ret = string.sub(left, right)
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

    ---@return string
    ---@return boolean
    return function()
        if nextindex then
            index, nextindex = nextindex, nil
            return nextvalid, false
        elseif index < max then
            index = index + 1
            local codepoint, left, right = find_codepoint(index)
            if not codepoint then
                local ret = string.sub(self, index, max)
                index = max
                return ret, true
            end
            if left > index then
                nextvalid, nextindex = codepoint, right
                return string.sub(self, index, left - 1), true
            end
            index = right
            return codepoint, false
        end
    end
end

return string
