local string, deque = require 'toolshed.util.string', require 'qamar.deque'

local function new_transaction()
    local ret
    ret = {
        index = 0,
        fileIndex = 0,
        row = 0,
        col = 0,
        copy = function(self)
            local r = {}
            for k, v in pairs(self) do
                r[k] = v
            end
            return r
        end,
    }
    return ret
end

---comment Create a buffered iterator reader
---@param input function An iterator which provides utf-8 codepoints
local buffer = function(input)
    if type(input) ~= 'function' then
        return nil, 'expected a function as input'
    end
    do
        local _input = input
        input = function()
            if not _input then
                return ''
            end
            local ret = _input()
            if ret == nil then
                _input = nil
                return ''
            elseif type(ret) ~= 'string' or ret == '' then
                error 'iterator must return non-empty string or nil'
            end
            return ret
        end
    end

    local la = deque()
    local ts, tc = {}, 0
    local t = new_transaction()

    local buffer = {}

    function buffer.begin()
        table.insert(ts, t)
        tc = tc + 1
        t = t:copy()
    end

    function buffer.undo()
        t = table.remove(ts)
        tc = tc - 1
    end

    local function normalize_la()
        if tc == 0 then
            for _ = 1, t.index do
                la.pop_front()
            end
            t.index = 0
        end
    end

    function buffer.commit()
        table.remove(ts)
        tc = tc - 1
        normalize_la()
    end

    local function ensure_filled(amt)
        while la.size() < amt do
            local c = input()
            if c ~= '' then
                la.push_back(c)
            elseif la.size() == 0 or la[la.size()] ~= '' then
                la.push_back ''
                break
            end
        end
    end

    function buffer.peek(skip)
        skip = skip == nil and 0 or skip
        local idx = t.index + skip + 1
        ensure_filled(idx)
        return la[idx] or ''
    end

    function buffer.take(amt)
        amt = amt == nil and 1 or amt
        local idx = t.index + amt
        ensure_filled(idx)
        local ret = {}
        for i = 1, amt do
            local c = la[t.index + 1]
            if c == '' then
                break
            else
                ret[i] = c
            end
            t.index = t.index + 1
        end
        normalize_la()
        return #ret > 0 and table.concat(ret) or nil
    end

    function buffer.try_consume_string(s)
        local i = 0
        for x in string.codepoints(s) do
            local c = buffer.peek(i)
            if c ~= x then
                return false
            end
            i = i + 1
        end
        return buffer.take(i)
    end

    function buffer.skipws()
        while true do
            local c = buffer.peek()
            if c ~= ' ' and c ~= '\t' and c ~= '\r' and c ~= '\n' then
                break
            end
            buffer.take()
        end
    end

    return buffer
end

return buffer
