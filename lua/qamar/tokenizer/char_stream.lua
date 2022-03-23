local string, deque = require 'qamar.util.string', require 'qamar.util.deque'

return function(input)
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

    local char_stream, la, ts, tc, skip_ws_ctr, t =
        {}, deque(), {}, 0, 0, {
            index = 0,
            file_char = 0,
            row = 1,
            col = 1,
            byte = 0,
            file_byte = 0,
            copy = function(self)
                local r = {}
                for k, v in pairs(self) do
                    r[k] = v
                end
                return r
            end,
        }

    function char_stream.begin()
        tc = tc + 1
        ts[tc] = t:copy()
    end

    function char_stream.undo()
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

    function char_stream.commit()
        ts[tc], tc = nil, tc - 1
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

    function char_stream.peek(skip)
        skip = skip == nil and 0 or skip
        local idx = t.index + skip + 1
        ensure_filled(idx)
        return la[idx] or nil
    end

    function char_stream.take(amt)
        amt = amt == nil and 1 or amt
        local idx = t.index + amt
        ensure_filled(idx)
        local ret = {}
        for i = 1, amt do
            local c = la[t.index + 1]
            if not c then
                break
            else
                local off = c:len()
                t.file_char, t.file_byte = t.file_char + 1, t.file_byte + off
                if c == '\n' then
                    t.row, t.col, t.byte = t.row + 1, 1, 0
                else
                    t.col, t.byte = t.col + 1, t.byte + off
                end
                ret[i] = c
            end
            t.index = t.index + 1
        end
        normalize_la()
        return #ret > 0 and table.concat(ret) or nil
    end

    function char_stream.pos()
        return { file_char = t.file_char, row = t.row, col = t.col, file_byte = t.file_byte, byte = t.byte }
    end

    function char_stream.try_consume_string(s)
        local i = 0
        for x in string.codepoints(s) do
            local c = char_stream.peek(i)
            if c ~= x then
                return
            end
            i = i + 1
        end
        return char_stream.take(i)
    end

    function char_stream.skipws()
        if skip_ws_ctr == 0 then
            while true do
                local c = char_stream.peek()
                if c ~= ' ' and c ~= '\f' and c ~= '\n' and c ~= '\r' and c ~= '\t' and c ~= '\v' then
                    break
                end
                char_stream.take()
            end
        end
    end

    function char_stream.suspend_skip_ws()
        skip_ws_ctr = skip_ws_ctr + 1
    end

    function char_stream.resume_skip_ws()
        if skip_ws_ctr > 0 then
            skip_ws_ctr = skip_ws_ctr - 1
        end
    end

    char_stream.combinators = {
        alt = function(...)
            local args = { ... }
            return function()
                local ret, right = nil, nil
                for _, x in ipairs(args) do
                    char_stream.begin()
                    char_stream.skipws()
                    local T = type(x)
                    if T == 'string' then
                        T = char_stream.try_consume_string(x)
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
                    char_stream.undo()
                end
                if ret then
                    while t.file_char < right do
                        char_stream.take()
                    end
                    return ret
                end
            end
        end,

        opt = function(x)
            return function()
                local T = type(x)
                char_stream.skipws()
                if not char_stream.peek() then
                    return {}
                end
                if T == 'string' then
                    T = char_stream.try_consume_string(x)
                elseif T == 'function' then
                    T = x()
                else
                    return nil
                end
                if T == nil then
                    return {}
                end
            end
        end,

        zom = function(x)
            return function()
                local ret = {}
                local T = type(x)
                while char_stream.peek() do
                    char_stream.skipws()
                    local v
                    if T == 'string' then
                        v = char_stream.try_consume_string(x)
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
                if not char_stream.peek() then
                    return ret
                end
            end
        end,

        seq = function(...)
            local args = { ... }
            return function()
                local ret = {}
                char_stream.begin()
                for _, x in ipairs(args) do
                    char_stream.skipws()
                    local T = type(x)
                    if T == 'function' then
                        T = x()
                    elseif T == 'string' then
                        T = char_stream.try_consume_string(x)
                    else
                        T = nil
                    end
                    if T == nil then
                        char_stream.undo()
                        return nil
                    end
                    table.insert(ret, T)
                end
                char_stream.commit()
                return ret
            end
        end,
    }

    function char_stream.alpha()
        return char_stream.combinators.alt(
            '_',
            'a',
            'b',
            'c',
            'd',
            'e',
            'f',
            'g',
            'h',
            'i',
            'j',
            'k',
            'l',
            'm',
            'n',
            'o',
            'p',
            'q',
            'r',
            's',
            't',
            'u',
            'v',
            'w',
            'x',
            'y',
            'z',
            'A',
            'B',
            'C',
            'D',
            'E',
            'F',
            'G',
            'H',
            'I',
            'J',
            'K',
            'L',
            'M',
            'N',
            'O',
            'P',
            'Q',
            'R',
            'S',
            'T',
            'U',
            'V',
            'W',
            'X',
            'Y',
            'Z'
        )()
    end

    function char_stream.numeric()
        return char_stream.combinators.alt('0', '1', '2', '3', '4', '5', '6', '7', '8', '9')()
    end

    function char_stream.alphanumeric()
        return char_stream.combinators.alt(char_stream.alpha, char_stream.numeric)()
    end

    return setmetatable(char_stream, {
        __tostring = function()
            local ret = {}
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
