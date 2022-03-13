local deque, token = require 'qamar.util.deque', require 'qamar.tokenizer.token'

return function(stream)
    local tokenizer, la, ts, tc, t =
        {}, deque(), {}, 0, {
            index = 0,
            file_char = 0,
            copy = function(self)
                local r = {}
                for k, v in pairs(self) do
                    r[k] = v
                end
                return r
            end,
        }

    function tokenizer.begin()
        tc = tc + 1
        ts[tc] = t:copy()
    end

    function tokenizer.undo()
        t, ts[tc], tc = ts[tc], nil, tc - 1
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
        ts[tc], tc = nil, tc - 1
        normalize_la()
    end

    local function ensure_filled(amt)
        while la.size() < amt do
            local c = token(stream)
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
                t.file_char = c.pos.right.file_char
            end
            t.index = t.index + 1
        end
        normalize_la()
        return #ret > 1 and ret or (#ret == 1 and ret[1] or nil)
    end

    tokenizer.combinators = {
        alt = function(...)
            local args = { ... }
            return function()
                local ret, right = nil, nil
                for _, x in ipairs(args) do
                    tokenizer.begin()
                    local T = type(x)
                    if T == 'number' then
                        local tok = tokenizer.peek()
                        T = (tok and tok.type == x) and tokenizer.take() or nil
                    elseif T == 'function' then
                        T = x()
                    else
                        T = nil
                    end
                    if T ~= nil then
                        if not right or t.file_char > right then
                            ret, right = T, t.file_char
                        end
                    end
                    tokenizer.undo()
                end
                if ret then
                    while t.file_char < right do
                        tokenizer.take()
                    end
                    return ret
                end
            end
        end,

        opt = function(x)
            return function()
                if not tokenizer.peek() then
                    return {}
                end
                local T = type(x)
                if T == 'number' then
                    local tok = tokenizer.peek()
                    T = (tok and tok.type == x) and tokenizer.take() or nil
                elseif T == 'function' then
                    T = x()
                else
                    return nil
                end
                if T == nil then
                    return {}
                end
                return T
            end
        end,

        zom = function(x)
            return function()
                local ret = {}
                local T = type(x)
                while tokenizer.peek() do
                    local v
                    if T == 'number' then
                        local tok = tokenizer.peek()
                        v = (tok and tok.type == x) and tokenizer.take() or nil
                    elseif T == 'function' then
                        v = x()
                    else
                        v = nil
                    end
                    if v == nil then
                        return ret
                    end
                    table.insert(ret, v)
                end
                if not tokenizer.peek() then
                    return ret
                end
            end
        end,

        seq = function(...)
            local args = { ... }
            return function()
                local ret = {}
                tokenizer.begin()
                for _, x in ipairs(args) do
                    local T = type(x)
                    if T == 'function' then
                        T = x()
                    elseif T == 'number' then
                        local tok = tokenizer.peek()
                        T = (tok and tok.type == x) and tokenizer.take() or nil
                    else
                        T = nil
                    end
                    if T == nil then
                        tokenizer.undo()
                        return nil
                    end
                    table.insert(ret, T)
                end
                tokenizer.commit()
                return ret
            end
        end,
    }
    return setmetatable(tokenizer, {
        __tostring = function()
            local ret = {}
            for i = 1, la.size() do
                local line = { (i - 1 == t.index) and '==> ' or '    ' }
                table.insert(line, (vim.inspect(la[i]):gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('\n%s*', ' ')))
                table.insert(ret, table.concat(line))
            end
            if t.index == la.size() then
                table.insert(ret, '==>')
            end
            return table.concat(ret, '\n')
        end,
    })
end
