local deque, token = require 'qamar.util.deque', require 'qamar.tokenizer.token'

local emptyfunc = function() end
local M = {}
local MT = {
    __index = M,
    __metatable = emptyfunc,
    __tostring = function(self)
        local ret = {}
        for i = 1, self.la.size() do
            local line = { (i - 1 == self.t.index) and '==> ' or '    ' }
            table.insert(line, (vim.inspect(self.la[i]):gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('\n%s*', ' ')))
            table.insert(ret, table.concat(line))
        end
        if self.t.index == self.la.size() then
            table.insert(ret, '==>')
        end
        return table.concat(ret, '\n')
    end,
}

local function copy_transaction(self)
    return { copy = self.copy, index = self.index, pos = self.pos }
end

function M.new(stream)
    do
        local pos = stream:pos()
        if pos.file_byte == 0 then
            if stream:peek() == '#' and stream:peek(1) == '!' then
                while true do
                    local t = stream:peek()
                    if not t then
                        break
                    end
                    stream:take()
                    if stream:pos().row > 1 then
                        break
                    end
                end
            end
        end
    end
    return setmetatable({
        stream = stream,
        tokenid = 0,
        la = deque(),
        ts = {},
        tc = 0,
        on_flush = nil,
        t = {

            index = 0,
            pos = stream:pos(),
            copy = copy_transaction,
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
        if self.on_flush then
            self.on_flush(self.tokenid)
        end
    end
end

function M:commit()
    self.ts[self.tc], self.tc = nil, self.tc - 1
    self:normalize()
end

function M:fill(amt)
    while self.la.size() < amt do
        local c = token(self.stream)
        if c then
            c.id = self.tokenid
            self.tokenid = self.tokenid + 1
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
    return self.la[idx] or false
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
        end
        ret[i] = c
        self.t.pos = c.pos.right
        self.t.index = self.t.index + 1
    end
    self:normalize()
    return #ret > 1 and ret or (#ret == 1 and ret[1] or nil)
end

function M:pos()
    return self.t.pos
end

function M:next_id()
    local x = self:peek()
    return x and x.id or self.tokenid
end

function M:take_until(id)
    while true do
        local x = self:peek()
        if not x or x.id >= id then
            return
        end
        self:take()
    end
end

M.combinators = {
    alt = function(...)
        local args = { ... }
        return function(self)
            local ret, right = nil, nil
            local left = self:peek() and self:peek().pos.left
            for _, x in ipairs(args) do
                self:begin()
                local T = type(x)
                if T == 'number' then
                    local tok = self:peek()
                    T = (tok and tok.type == x) and self:take() or nil
                elseif T == 'function' then
                    T = x(self)
                else
                    T = nil
                end
                if T ~= nil then
                    if not right or self.t.pos.file_char > right then
                        T.pos = { left = left, right = self.t.pos }
                        ret, right = T, self.t.pos.file_char
                    end
                end
                self:undo()
            end
            if ret then
                while self.t.pos.file_char < right do
                    self:take()
                end
                return ret
            end
        end
    end,

    opt = function(x)
        return function(self)
            if not self:peek() then
                return setmetatable({ pos = { left = self.t.pos, right = self.t.pos } }, {
                    __tostring = function()
                        return ''
                    end,
                })
            end
            local left = self:peek().pos.left
            local T = type(x)
            if T == 'number' then
                local tok = self:peek()
                T = (tok and tok.type == x) and self:take() or nil
            elseif T == 'function' then
                T = x(self)
            else
                return nil
            end
            if T == nil then
                return setmetatable({ pos = { left = self.t.pos, right = self.t.pos } }, {
                    __tostring = function()
                        return ''
                    end,
                })
            end
            T.pos = { left = left, right = self.t.pos }
            return T
        end
    end,

    zom = function(x)
        return function(self)
            local ret = { pos = { left = self:peek() and self:peek().pos.left or self.t.pos } }
            local T = type(x)
            while self:peek() do
                local v
                if T == 'number' then
                    local tok = self:peek()
                    v = (tok and tok.type == x) and self:take() or nil
                elseif T == 'function' then
                    v = x(self)
                else
                    v = nil
                end
                if v == nil then
                    if not ret.pos.right then
                        ret.pos.right = self.t.pos
                    end
                    return ret
                end
                table.insert(ret, v)
                ret.pos.right = v.pos.right
            end
            if not self:peek() then
                return ret
            end
        end
    end,

    seq = function(...)
        local args = { ... }
        return function(self)
            local ret = { pos = { left = self:peek() and self:peek().pos.left or self.t.pos } }
            self:begin()
            for _, x in ipairs(args) do
                local T = type(x)
                if T == 'function' then
                    T = x(self)
                elseif T == 'number' then
                    local tok = self:peek()
                    T = (tok and tok.type == x) and self:take() or nil
                else
                    T = nil
                end
                if T == nil then
                    self:undo()
                    return nil
                end
                table.insert(ret, T)
            end
            self:commit()
            ret.pos.right = #ret == 0 and ret.pos.left or ret[#ret].pos.right
            return ret
        end
    end,
}

function M:on_flush(func)
    self.on_flush = func
end

return M
