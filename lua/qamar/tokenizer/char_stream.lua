local string, deque = require 'qamar.util.string', require 'qamar.util.deque'
local position = require 'qamar.util.position'

---@class char_transaction
---@field index number
---@field row number
---@field col number
---@field byte number
---@field file_char number
---@field file_byte number

---@class char_stream
---@field input function()
---@field la deque
---@field ts table
---@field tc number
---@field skip_ws_ctr number
---@field t char_transaction

local function nullfunc() end
local concat = table.concat
local slen = string.len
local sutf8 = string.utf8
local setmetatable = setmetatable
local sescape = require('qamar.util.string').escape

---@type char_stream
local M = {}
local MT = {
    __index = M,
    __metatable = nullfunc,
    __tostring = function(self)
        local ret = {}
        local idx = 0
        for i = 1, self.la.size() do
            local line = { (i - 1 == self.t.index) and '==> ' or '    ' }
            local c = self.la[i]
            line[2] = sescape(c, true)
            idx = idx + 1
            ret[idx] = concat(line)
        end
        if self.t.index == self.la.size() then
            idx = idx + 1
            ret[idx] = '==>'
        end
        return concat(ret, '\n')
    end,
}

---creates a copy of a transaction
---@param self char_transaction
---@return char_transaction
local function transaction_copy(self)
    return {
        index = self.index,
        file_char = self.file_char,
        row = self.row,
        col = self.col,
        byte = self.byte,
        file_byte = self.file_byte,
    }
end

---creates a new parser
---@param input function():string|nil
---@return char_stream|nil
---@return string|nil
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
        },
    }, MT)
end

---begins a new transaction, must be followed by a matching call to undo or commit
function M:begin()
    self.tc = self.tc + 1
    self.ts[self.tc] = transaction_copy(self.t)
end

---undoes a transaction. must be paired with a preceding call to begin
function M:undo()
    self.t, self.ts[self.tc], self.tc = self.ts[self.tc], nil, self.tc - 1
end

---discards all consumed tokens if there are no pending transactions
---@param self char_stream
local function normalize(self)
    if self.tc == 0 then
        for _ = 1, self.t.index do
            self.la.pop_front()
        end
        self.t.index = 0
    end
end
M.normalize = normalize

---commits a transaction. must be paired with a preceding call to begin
---@return nil
function M:commit()
    self.ts[self.tc], self.tc = nil, self.tc - 1
    return normalize(self)
end

---ensures the internal buffer contains at least 'amt' items, unless the end of stream has been reached
---@param self char_stream
---@param amt number
local function fill(self, amt)
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
M.fill = fill

---gets the Nth token (zero based) in the internal buffer.
---N defaults to 0
---@param self char_stream
---@param N number|nil
---@return string|nil
local function peek(self, N)
    N = N == nil and 0 or N
    local idx = self.t.index + N + 1
    fill(self, idx)
    return self.la[idx] or nil
end
M.peek = peek

---consumes N characters from the stream
---@param self char_stream
---@param N number
---@return string|nil
local function take(self, N)
    N = N == nil and 1 or N
    local idx = self.t.index + N
    fill(self, idx)
    local ret = {}
    for i = 1, N do
        local c = self.la[self.t.index + 1]
        if not c then
            break
        else
            local off = slen(c)
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
    normalize(self)
    return #ret > 0 and concat(ret) or nil
end
M.take = take

---gets the stream's current position
---@return position
function M:pos()
    local t = self.t
    return position(t.row, t.col, t.byte, t.file_char, t.file_byte)
end

---tries to consume a specified string. consumes nothing if the string does not match
---@param s string
---@return string|nil
function M:try_consume_string(s)
    local i = 0
    for x in sutf8(s) do
        local c = peek(self, i)
        if c ~= x then
            return
        end
        i = i + 1
    end
    return take(self, i)
end

---consumes any subsequent whitespace characters
function M:skipws()
    if self.skip_ws_ctr == 0 then
        while true do
            local c = peek(self)
            if c ~= ' ' and c ~= '\f' and c ~= '\n' and c ~= '\r' and c ~= '\t' and c ~= '\v' then
                break
            end
            take(self)
        end
    end
end

---suspends automatic skipping of whitespace characters. must be paired with a call to resume_skip_ws
function M:suspend_skip_ws()
    self.skip_ws_ctr = self.skip_ws_ctr + 1
end

---resumes automatic skipping of whitespace characters. must be paired with a preceding call to suspend_skip_ws
function M:resume_skip_ws()
    if self.skip_ws_ctr > 0 then
        self.skip_ws_ctr = self.skip_ws_ctr - 1
    end
end

local ascii = string.byte

---tries to match and consume an alpha or underscore character
---@param self char_stream
---@return string|nil
M.alpha = function(self)
    local tok = peek(self)
    if tok then
        local byte = ascii(tok)
        if byte >= 97 and byte <= 122 or byte >= 65 and byte <= 90 or byte == 95 then
            take(self)
            return tok
        end
    end
end

---tries to match and consume a numeric character
---@param self char_stream
---@return string|nil
M.numeric = function(self)
    local tok = peek(self)
    if tok then
        local byte = ascii(tok)
        if byte >= 48 and byte <= 57 then
            return take(self)
        end
    end
end

---tries to match and consume an alphanumeric or underscore character
---@param self char_stream
---@return string|nil
M.alphanumeric = function(self)
    local tok = peek(self)
    if tok then
        local byte = ascii(tok)
        if byte >= 97 and byte <= 122 or byte >= 65 and byte <= 90 or byte >= 48 and byte <= 57 or byte == 95 then
            return take(self)
        end
    end
end

return M
