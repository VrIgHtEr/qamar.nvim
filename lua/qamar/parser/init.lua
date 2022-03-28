local cfg = require 'qamar.config'
local deque, tokenizer = require 'qamar.util.deque', require 'qamar.tokenizer'
local tokentypes = require 'qamar.tokenizer.types'

local parser = {}

local MT = {
    __metatable = function() end,
    __index = parser,
    __tostring = function(self)
        local ret = {}
        for i = 1, self.la.size() do
            local line = { cfg.space() .. ((i - 1 == self.t.index) and '==> ' or '    ') }
            local x = self.la[i] or 'EOF'
            if x.type then
                table.insert(line, tokentypes[x.type])
                table.insert(line, ' ')
            end
            table.insert(line, vim.inspect(x.value))
            table.insert(ret, table.concat(line))
        end
        if self.t.index == self.la.size() then
            table.insert(ret, cfg.space())
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
    cfg.trace('BEGIN:' .. self.tc, 1)
    self.tc = self.tc + 1
    self.ts[self.tc] = self.t:copy()
end

function parser:undo()
    self.t, self.ts[self.tc], self.tc = self.ts[self.tc], nil, self.tc - 1
    cfg.trace('UNDO:' .. self.tc, 1)
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
    cfg.trace('COMMIT:' .. self.tc, 1)
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

return parser
