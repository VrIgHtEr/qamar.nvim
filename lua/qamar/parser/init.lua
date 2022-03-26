local deque, tokenizer = require 'qamar.util.deque', require 'qamar.tokenizer'

local parser = {}

local MT = {
    __metatable = function() end,
    __index = parser,
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

function parser.new(stream)
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

    return setmetatable({
        stream = stream,
        tokenid = 0,
        la = deque(),
        ts = {},
        tc = 0,
        t = {
            index = 0,
            pos = stream:pos(),
            copy = function(self)
                local r = {}
                for k, v in pairs(self) do
                    r[k] = v
                end
                return r
            end,
        },
    }, MT)
end

function parser:begin()
    self.tc = self.tc + 1
    self.ts[self.tc] = self.t:copy()
end

function parser:undo()
    self.t, self.ts[self.tc], self.tc = self.ts[self.tc], nil, self.tc - 1
end

function parser:normalize()
    if self.tc == 0 then
        for _ = 1, self.t.index do
            self.la.pop_front()
        end
        self.t.index = 0
    end
end

function parser:commit()
    self.ts[self.tc], self.tc = nil, self.tc - 1
    self:normalize()
end

function parser:fill(amt)
    while self.la.size() < amt do
        local c = tokenizer(self.stream)
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

function parser:peek(skip)
    skip = skip == nil and 0 or skip
    local idx = self.t.index + skip + 1
    self:fill(idx)
    return self.la[idx] or false
end

function parser:take(amt)
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

function parser:begintake(amt)
    self:begin()
    return self:take(amt)
end

function parser:pos()
    return self.t.pos
end

function parser:next_id()
    local x = self:peek()
    return x and x.id or self.tokenid
end

function parser:take_until(id)
    while true do
        local x = self:peek()
        if not x or x.id >= id then
            return
        end
        self:take()
    end
end

local alt = function(...)
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
end

local opt = function(x)
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
end

local zom = function(x)
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
end

local seq = function(...)
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
end

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

parser.expression = require 'qamar.parser.production.expression'
parser.name = require 'qamar.parser.production.name'
parser.field_raw = require 'qamar.parser.production.field.raw'
parser.field_name = require 'qamar.parser.production.field.name'
parser.fieldlist = require 'qamar.parser.production.fieldlist'
parser.field = require 'qamar.parser.production.field'
parser.tableconstructor = require 'qamar.parser.production.tableconstructor'
parser.vararg = require 'qamar.parser.production.vararg'
parser.attrib = require 'qamar.parser.production.attrib'
parser.namelist = require 'qamar.parser.production.namelist'
parser.explist = require 'qamar.parser.production.explist'
parser.label = require 'qamar.parser.production.label'
parser.functiondef = require 'qamar.parser.production.functiondef'
parser.block = require 'qamar.parser.production.block'
parser.var = require 'qamar.parser.production.var'
parser.parlist = require 'qamar.parser.production.parlist'
parser.attnamelist = require 'qamar.parser.production.attnamelist'
parser.varlist = require 'qamar.parser.production.varlist'
parser.retstat = require 'qamar.parser.production.retstat'
parser.funcname = require 'qamar.parser.production.funcname'
parser.funcbody = require 'qamar.parser.production.funcbody'
parser.stat = require 'qamar.parser.production.stat'
parser.chunk = require 'qamar.parser.production.chunk'
--[[
wrap({
    type = n.localfunc,
    rewrite = function(self)
        return { self[3], self[4] }
    end,
    string = function(self)
        return tconcat { 'local function', self[1], self[2] }
    end,
}, seq(token.kw_local, token.kw_function, parser.name, parser.funcbody))

wrap({
    type = n.func,
    rewrite = function(self)
        return { self[2], self[3] }
    end,
    string = function(self)
        return tconcat { 'function', self[1], self[2] }
    end,
}, seq(token.kw_function, parser.funcname, parser.funcbody))

wrap(
    {
        type = n.for_num,
        string = function(self)
            local ret = { 'for', self[2], '=', self[4], ',', self[6] }
            if self[7][1] then
                tinsert(ret, ',', self[7][2])
            end
            tinsert(ret, 'do', self[9], 'end')
            return tconcat(ret)
        end,
    },
    seq(
        token.kw_for,
        parser.name,
        token.assignment,
        parser.expression,
        token.comma,
        parser.expression,
        opt(seq(token.comma, parser.expression)),
        token.kw_do,
        parser.block,
        token.kw_end
    )
)

wrap({
    type = n.stat_for_iter,
    rewrite = function(self)
        return { self[2], self[4], self[6] }
    end,
    string = function(self)
        return tconcat { 'for', self[1], 'in', self[2], 'do', self[3], 'end' }
    end,
}, seq(token.kw_for, parser.namelist, token.kw_in, parser.explist, token.kw_do, parser.block, token.kw_end))

wrap(
    {
        type = n.stat_if,
        string = function(self)
            local ret = { 'if', self[2], 'then', self[4] }
            for _, x in ipairs(self[5]) do
                tinsert(ret, 'elseif', x[2], 'then', x[4])
            end
            if self[6][1] then
                tinsert(ret, 'else', self[6][2])
            end
            tinsert(ret, 'end')
            return tconcat(ret)
        end,
    },
    seq(
        token.kw_if,
        parser.expression,
        token.kw_then,
        parser.block,
        zom(seq(token.kw_elseif, parser.expression, token.kw_then, parser.block)),
        opt(seq(token.kw_else, parser.block)),
        token.kw_end
    )
)

wrap({
    type = n.stat_do,
    rewrite = function(self)
        return { self[2] }
    end,
    string = function(self)
        return tconcat { 'do', self[1], 'end' }
    end,
}, seq(token.kw_do, parser.block, token.kw_end))

wrap({
    type = n.stat_while,
    rewrite = function(self)
        return { self[2], self[4] }
    end,
    string = function(self)
        return tconcat { 'while', self[1], 'do', self[2], 'end' }
    end,
}, seq(token.kw_while, parser.expression, token.kw_do, parser.block, token.kw_end))

wrap({
    type = n.stat_repeat,
    rewrite = function(self)
        return { self[2], self[4] }
    end,
    string = function(self)
        return tconcat { 'repeat', self[1], 'until', self[2] }
    end,
}, seq(token.kw_repeat, parser.block, token.kw_until, parser.expression))

wrap({
    type = n.stat_assign,
    rewrite = function(self)
        return { self[1], self[3] }
    end,
    string = function(self)
        return tconcat { self[1], '=', self[2] }
    end,
}, seq(parser.varlist, token.assignment, parser.explist))

local expressionstatement = function(self)
    self:begin()
    local ret = self:expression()
    if ret and ret.type == n.functioncall then
        self:commit()
        return ret
    end
    self:undo()
end
]]

return parser
