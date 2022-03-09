local deque, string = require 'qamar.deque', require 'toolshed.util.string'

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

return function(buffer)
    local tokenizers = {
        require 'qamar.token.symbol',
        require 'qamar.token.keyword',
        require 'qamar.token.number',
        require 'qamar.token.name',
        require 'qamar.token.string',
    }
    local input
    do
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

    local tokenizer = {}

    function tokenizer.begin()
        table.insert(ts, t)
        tc = tc + 1
        t = t:copy()
    end

    function tokenizer.undo()
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

    function tokenizer.commit()
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

    function tokenizer.peek(skip)
        skip = skip == nil and 0 or skip
        local idx = t.index + skip + 1
        ensure_filled(idx)
        return la[idx] or ''
    end

    function tokenizer.take(amt)
        amt = amt == nil and 1 or amt
        local idx = t.index + amt
        ensure_filled(idx)
        local ret = {}
        for i = 1, amt do
            local c = la[t.index + 1]
            if c == '' then
                break
            else
                t.fileIndex = t.fileIndex + 1
                if c == '\n' then
                    t.row, t.col = t.row + 1, 0
                else
                    t.col = t.col + 1
                end
                ret[i] = c
            end
            t.index = t.index + 1
        end
        normalize_la()
        return #ret > 0 and table.concat(ret) or nil
    end

    function tokenizer.pos()
        return { fileIndex = t.fileIndex, row = t.row, col = t.col }
    end

    function tokenizer.try_consume_string(s)
        local i = 0
        for x in string.codepoints(s) do
            local c = tokenizer.peek(i)
            if c ~= x then
                return
            end
            i = i + 1
        end
        return tokenizer.take(i)
    end

    function tokenizer.skipws()
        while true do
            local c = tokenizer.peek()
            if c ~= ' ' and c ~= '\f' and c ~= '\n' and c ~= '\r' and c ~= '\t' and c ~= '\v' then
                break
            end
            tokenizer.take()
        end
    end

    return setmetatable(tokenizer, {
        __tostring = function()
            local ret = {}
            print('SIZE: ' .. la.size())
            for i = 1, la.size() do
                local line = { (i - 1 == t.index) and '==> ' or '    ' }
                local c = la[i]
                table.insert(line, vim.inspect(c))
                table.insert(ret, table.concat(line))
            end
            if t.index == la.size() then
                table.insert(ret, '==>')
            end
            return table.concat(ret, '\n')
        end,
    })
end
