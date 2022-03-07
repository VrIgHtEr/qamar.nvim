local string = require 'toolshed.util.string'

local function new_transaction()
    local ret
    ret = {
        index = 0,
        fileIndex = 0,
        row = 0,
        col = 0,
        copy = function()
            local r = {}
            for k, v in pairs(ret) do
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
            local ret = _input()
            if ret == nil then
                return ''
            elseif type(ret) ~= 'string' or ret == '' then
                error 'iterator must return non-empty string or nil'
            end
            return ret
        end
    end
    local lookahead = {}
    local transactions = {}
    local closed = false
    local s = new_transaction()

    local function hasNoTransactions()
        return #transactions == 0
    end

    local function lookaheadBufferSize()
        return #lookahead
    end

    local function normalizeLookaheadBuffer()
        if hasNoTransactions() and s.index > 0 then
            local available = lookaheadBufferSize() - s.index
            for i = 0, available - 1 do
                lookahead[i + 1] = lookahead[s.index + i + 1]
            end
            local newsize = lookaheadBufferSize() - s.index
            s.index = 0
            while #lookahead > newsize do
                table.remove(lookahead)
            end
        end
    end

    local function populateLookaheadBuffer(targetSize)
        while lookaheadBufferSize() < targetSize do
            local next = input()
            if next ~= '' then
                table.insert(lookahead, next)
            else
                if #lookahead == 0 or lookahead[#lookahead] ~= '' then
                    table.insert(lookahead, '')
                end
                break
            end
        end
    end

    local function updateRowCol(c)
        if c == '\n' then
            s.row, s.col = s.row + 1, 0
        else
            s.col = s.col + 1
        end
    end

    local ret = {}
    function ret.location()
        return { fileIndex = s.fileIndex, row = s.row, col = s.col }
    end

    function ret.begin()
        normalizeLookaheadBuffer()
        table.insert(transactions, s)
        s = s.copy()
    end

    function ret.undo()
        if hasNoTransactions() then
            error 'no transactions to roll back'
        end
        s = table.remove(transactions)
        normalizeLookaheadBuffer()
    end

    function ret.commit()
        if hasNoTransactions() then
            error 'no transactions to roll back'
        end
        table.remove(transactions)
        normalizeLookaheadBuffer()
    end

    function ret.peek(skip)
        if skip == nil then
            skip = 0
        end
        normalizeLookaheadBuffer()
        local targetIndex = s.index + skip
        if targetIndex < lookaheadBufferSize() then
            return lookahead[targetIndex + 1]
        else
            populateLookaheadBuffer(targetIndex + 1)
            if targetIndex >= lookaheadBufferSize() then
                return ''
            else
                return lookahead[targetIndex + 1]
            end
        end
    end

    function ret.take(amt)
        if amt == nil then
            if hasNoTransactions() then
                if s.index < lookaheadBufferSize() then
                    local c = lookahead[s.index + 1]
                    if c == '' then
                        return ''
                    end
                    s.index, s.fileIndex = s.index + 1, s.fileIndex + 1
                    updateRowCol(c)
                    return c
                else
                    local c = input()
                    if c ~= '' then
                        s.fileIndex = s.fileIndex + 1
                        updateRowCol(c)
                        return c
                    else
                        return ''
                    end
                end
            elseif s.index < lookaheadBufferSize() then
                local c = lookahead[s.index + 1]
                if c == '' then
                    return ''
                end
                updateRowCol(c)
                s.index, s.fileIndex = s.index + 1, s.fileIndex + 1
                return c
            else
                local c = input()
                if c ~= '' then
                    updateRowCol(c)
                    table.insert(lookahead, c)
                    s.index, s.fileIndex = s.index + 1, s.fileIndex + 1
                    return c
                else
                    table.insert(lookahead, '')
                    return ''
                end
            end
        else
            if ret.peek(amt - 1) ~= '' then
                return false
            end
            for _ = 1, amt do
                ret.take()
            end
            return true
        end
    end

    function ret.takech(amt)
        if ret.peek(amt - 1) ~= '' then
            local r = {}
            for _ = amt, 1, -1 do
                table.insert(r, ret.take())
            end
            return table.concat(r)
        end
    end

    function ret.takeUntil(fileIndex)
        while s.fileIndex < fileIndex do
            if ret.peek() == '' then
                return false
            end
            ret.take()
        end
        return true
    end

    function ret.isEof()
        return ret.peek() == ''
    end

    function ret.close()
        if not closed then
            lookahead, s.index, closed = { '' }, 0, true
        end
    end

    function ret.skipws()
        while true do
            local c = ret.peek()
            if c ~= ' ' and c ~= '\t' and c ~= '\r' and c ~= '\n' then
                break
            end
            ret.take()
        end
    end

    function ret.tryConsumeString(str, predicate)
        if str:len() == 0 then
            return true
        end
        local loc = 0
        for c in string.codepoints(str) do
            local x = ret.peek(loc)
            loc = loc + 1
            if x ~= c then
                return false
            end
        end
        if predicate ~= nil and not predicate(loc) then
            return false
        end
        ret.take(loc)
        return true
    end

    return setmetatable(ret, {
        __metatable = function() end,
        __tostring = function()
            local sb = {}
            for i = 0, lookaheadBufferSize() - 1 do
                table.insert(sb '\n')
                table.insert(sb, i == s.index and '==> ' or '    ')
                local st = lookahead[i + 1]
                if st == nil then
                    table.insert(sb, '~~ EOF ~~')
                elseif st >= 32 and st < 127 then
                    table.insert(sb, "'")
                    table.insert(sb, st)
                    table.insert(sb, "'")
                else
                    table.insert(sb, st)
                end
            end
            if s.index == lookaheadBufferSize() then
                table.insert(sb, '\n')
                table.insert(sb, '==> ')
            end
            table.insert(sb, '\n')
            return table.concat(sb)
        end,
    })
end

return buffer
