local string, deque = require 'qamar.util.string', require 'qamar.util.deque'

local function emptyfunc() end

local M = {}
local MT = {
    __index = M,
    __metatable = emptyfunc,
    __tostring = function(self)
        local ret = {}
        local idx = 0
        for i = 1, self.la.size() do
            local line = { (i - 1 == self.t.index) and '==> ' or '    ' }
            local c = self.la[i]
            line[2] = vim.inspect(c)
            idx = idx + 1
            ret[idx] = table.concat(line)
        end
        if self.t.index == self.la.size() then
            idx = idx + 1
            ret[idx] = '==>'
        end
        return table.concat(ret, '\n')
    end,
}

local function transaction_copy(self)
    return {
        index = self.index,
        file_char = self.file_char,
        row = self.row,
        col = self.col,
        byte = self.byte,
        file_byte = self.file_byte,
        copy = transaction_copy,
    }
end

function M.new(input)
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
    return setmetatable({
        input = input,
        la = deque(),
        ts = {},
        tc = 0,
        skip_ws_ctr = 0,
        t = {
            index = 0,
            file_char = 0,
            row = 1,
            col = 1,
            byte = 0,
            file_byte = 0,
            copy = transaction_copy,
        },
    }, MT)
end

function M:begin()
    self.tc = self.tc + 1
    self.ts[self.tc] = self.t:copy()
end

function M:undo()
    self.t, self.ts[self.tc], self.tc = self.ts[self.tc], nil, self.tc - 1
end

function M:normalize()
    if self.tc == 0 then
        for _ = 1, self.t.index do
            self.la.pop_front()
        end
        self.t.index = 0
    end
end

function M:commit()
    self.ts[self.tc], self.tc = nil, self.tc - 1
    self:normalize()
end

function M:fill(amt)
    while self.la.size() < amt do
        local c = self.input()
        if c then
            self.la.push_back(c)
        elseif self.la.size() == 0 or self.la[self.la.size()] then
            self.la.push_back(false)
            break
        end
    end
end

function M:peek(skip)
    skip = skip == nil and 0 or skip
    local idx = self.t.index + skip + 1
    self:fill(idx)
    return self.la[idx] or nil
end

function M:take(amt)
    amt = amt == nil and 1 or amt
    local idx = self.t.index + amt
    self:fill(idx)
    local ret = {}
    for i = 1, amt do
        local c = self.la[self.t.index + 1]
        if not c then
            break
        else
            local off = c:len()
            self.t.file_char, self.t.file_byte = self.t.file_char + 1, self.t.file_byte + off
            if c == '\n' then
                self.t.row, self.t.col, self.t.byte = self.t.row + 1, 1, 0
            else
                self.t.col, self.t.byte = self.t.col + 1, self.t.byte + off
            end
            ret[i] = c
        end
        self.t.index = self.t.index + 1
    end
    self:normalize()
    return #ret > 0 and table.concat(ret) or nil
end

function M:pos()
    return { file_char = self.t.file_char, row = self.t.row, col = self.t.col, file_byte = self.t.file_byte, byte = self.t.byte }
end

function M:try_consume_string(s)
    local i = 0
    for x in string.utf8(s) do
        local c = self:peek(i)
        if c ~= x then
            return
        end
        i = i + 1
    end
    return self:take(i)
end

function M:skipws()
    if self.skip_ws_ctr == 0 then
        while true do
            local c = self:peek()
            if c ~= ' ' and c ~= '\f' and c ~= '\n' and c ~= '\r' and c ~= '\t' and c ~= '\v' then
                break
            end
            self:take()
        end
    end
end

function M:suspend_skip_ws()
    self.skip_ws_ctr = self.skip_ws_ctr + 1
end

function M:resume_skip_ws()
    if self.skip_ws_ctr > 0 then
        self.skip_ws_ctr = self.skip_ws_ctr - 1
    end
end

M.ALPHA = function(self)
    local tok = self:peek()
    if tok then
        local byte = string.byte(tok)
        if byte >= 97 and byte <= 122 or byte >= 65 and byte <= 90 or byte == 95 then
            self:take()
            return tok
        end
    end
end

M.NUMERIC = function(self)
    local tok = self:peek()
    if tok then
        local byte = string.byte(tok)
        if byte >= 48 and byte <= 57 then
            return self:take()
        end
    end
end

M.ALPHANUMERIC = function(self)
    local tok = self:peek()
    if tok then
        local byte = string.byte(tok)
        if byte >= 97 and byte <= 122 or byte >= 65 and byte <= 90 or byte >= 48 and byte <= 57 or byte == 95 then
            return self:take()
        end
    end
end
M.alpha = M.ALPHA
M.numeric = M.NUMERIC
M.alphanumeric = M.ALPHANUMERIC

return M
