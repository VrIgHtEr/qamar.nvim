local deque, token = require 'qamar.util.deque', require 'qamar.tokenizer.token'

return function(stream)
    local tokenizer, la, ts, tc, index = {}, deque(), {}, 0, 0

    function tokenizer.begin()
        table.insert(ts, index)
        tc = tc + 1
    end

    function tokenizer.undo()
        index = table.remove(ts)
        tc = tc - 1
    end

    local function normalize_la()
        if tc == 0 then
            for _ = 1, index do
                la.pop_front()
            end
            index = 0
        end
    end

    function tokenizer.commit()
        table.remove(ts)
        tc = tc - 1
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
        local idx = index + skip + 1
        ensure_filled(idx)
        return la[idx] or false
    end

    function tokenizer.take(amt)
        amt = amt == nil and 1 or amt
        local idx = index + amt
        ensure_filled(idx)
        local ret = {}
        for i = 1, amt do
            local c = la[index + 1]
            if not c then
                break
            else
                ret[i] = c
            end
            index = index + 1
        end
        normalize_la()
        return #ret > 1 and ret or (#ret == 1 and ret[1] or nil)
    end

    return setmetatable(tokenizer, {
        __tostring = function()
            local ret = {}
            for i = 1, la.size() do
                local line = { (i - 1 == index) and '==> ' or '    ' }
                table.insert(line, (vim.inspect(la[i]):gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('\n%s*', ' ')))
                table.insert(ret, table.concat(line))
            end
            if index == la.size() then
                table.insert(ret, '==>')
            end
            return table.concat(ret, '\n')
        end,
    })
end
