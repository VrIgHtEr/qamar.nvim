---@class token_transaction
---@field index number
---@field pos position

---@class tokenizer
---@field stream char_stream
---@field tokenid number
---@field la deque
--tokenid = 0,
--la = deque(),
--ts = {},
--tc = 0,
--t = {
--    index = 0,
--    pos = stpos(stream),
--},

local deque, tokenizer = require 'qamar.util.deque', require 'qamar.tokenizer'
local tokentypes = require 'qamar.tokenizer.types'
local concat = table.concat
local setmetatable = setmetatable

local parser = {}

local MT = {
    __metatable = function() end,
    __index = parser,
    __tostring = function(self)
        local ret = {}
        local idx = 0
        for i = 1, self.la.size() do
            local line = { ((i - 1 == self.t.index) and '==> ' or '    ') }
            local index = 1
            local x = self.la[i] or 'EOF'
            if x.type then
                index = index + 1
                line[index] = tokentypes[x.type]
                index = index + 1
                line[index] = ' '
            end
            index = index + 1
            line[index] = vim.inspect(x.value)
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

local st = require 'qamar.tokenizer.char_stream'
local stpos = st.pos
local stpeek = st.peek
local sttake = st.take

local function copy_transaction(self)
    return { index = self.index, pos = self.pos }
end

local initialized = false
function parser:chunk()
    if not initialized then
        parser.chunk, initialized = require 'qamar.parser.production.chunk', true
    end
    return parser.chunk(self)
end

function parser.new(stream)
    local pos = stpos(stream)
    if pos.file_byte == 0 then
        if stpeek(stream) == '#' and stpeek(stream, 1) == '!' then
            while true do
                local t = stpeek(stream)
                if not t then
                    break
                end
                sttake(stream)
                if stpos(stream).row > 1 then
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
            pos = stpos(stream),
        },
    }, MT)
end

local function begin(self)
    self.tc = self.tc + 1
    self.ts[self.tc] = copy_transaction(self.t)
end
parser.begin = begin

local function undo(self)
    self.t, self.ts[self.tc], self.tc = self.ts[self.tc], nil, self.tc - 1
end
parser.undo = undo

local function normalize(self)
    if self.tc == 0 then
        for _ = 1, self.t.index do
            self.la.pop_front()
        end
        self.t.index = 0
    end
end
parser.normalize = normalize

local function commit(self)
    self.ts[self.tc], self.tc = nil, self.tc - 1
    return normalize(self)
end
parser.commit = commit

local function fill(self, amt)
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
parser.fill = fill

local function peek(self, skip)
    skip = skip == nil and 0 or skip
    local idx = self.t.index + skip + 1
    fill(self, idx)
    return self.la[idx] or false
end
parser.peek = peek

local function take(self, amt)
    amt = amt == nil and 1 or amt
    local idx = self.t.index + amt
    fill(self, idx)
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
    normalize(self)
    return #ret > 1 and ret or (#ret == 1 and ret[1] or nil)
end
parser.take = take

function parser:begintake(amt)
    begin(self)
    return take(self, amt)
end

function parser:pos()
    return self.t.pos
end

function parser:next_id()
    local x = peek(self)
    return x and x.id or self.tokenid
end

function parser:take_until(id)
    while true do
        local x = peek(self)
        if not x or x.id >= id then
            return
        end
        take(self)
    end
end

return parser
