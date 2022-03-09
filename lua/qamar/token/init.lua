local deque = require 'qamar.deque'
local token_names = require 'qamar.token.token_names'

local function new_transaction()
    local ret
    ret = {
        index = 0,
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
        require 'qamar.token.comment',
        require 'qamar.token.symbol',
        require 'qamar.token.keyword',
        require 'qamar.token.number',
        require 'qamar.token.name',
        require 'qamar.token.string',
    }
    local function input()
        if tokenizers then
            for _, x in ipairs(tokenizers) do
                local ret = x(buffer)
                if ret then
                    ret.name = token_names[ret.type]
                    return ret
                end
            end
            buffer.skipws()
            if buffer.peek() ~= '' then
                error('invalid token on line ' .. buffer.pos().row .. ', col ' .. buffer.pos().col)
            else
                tokenizers = nil
                return false
            end
        else
            return false
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
            if c then
                la.push_back(c)
            elseif la.size() == 0 or la[la.size()] then
                la.push_back(false)
                break
            end
        end
    end

    function tokenizer.peek(skip)
        skip = skip == nil and 0 or skip
        local idx = t.index + skip + 1
        ensure_filled(idx)
        return la[idx] or false
    end

    function tokenizer.take(amt)
        amt = amt == nil and 1 or amt
        local idx = t.index + amt
        ensure_filled(idx)
        local ret = {}
        for i = 1, amt do
            local c = la[t.index + 1]
            if not c then
                break
            else
                ret[i] = c
            end
            t.index = t.index + 1
        end
        normalize_la()
        return #ret > 1 and ret or (#ret == 1 and ret[1] or nil)
    end

    return setmetatable(tokenizer, {
        __tostring = function()
            local ret = {}
            print('SIZE: ' .. la.size())
            for i = 1, la.size() do
                local line = { (i - 1 == t.index) and '==> ' or '    ' }
                local c = la[i]
                table.insert(line, vim.inspect(c):gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('\n', ' '))
                table.insert(ret, table.concat(line))
            end
            if t.index == la.size() then
                table.insert(ret, '==>')
            end
            return table.concat(ret, '\n')
        end,
    })
end
