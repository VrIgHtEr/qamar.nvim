---@class parser_transaction
---@field index number
---@field pos position

---@class parser
---@field stream char_stream
---@field tokenid number
---@field la deque
---@field ts table
---@field tc number
---@field t parser_transaction
---@field cache table
---@field on_flush function
local parser = {}

local deque, tokenizer = require 'qamar.util.deque', require 'qamar.tokenizer'
local tokentypes = require 'qamar.tokenizer.types'
local concat = table.concat
local setmetatable = setmetatable
local sescape = require('qamar.util.string').escape

local MT = {
    __metatable = function() end,
    __index = parser,
    ---@param self parser
    ---@return string
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
            line[index] = sescape(x.value, true)
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

---creates a copy of a token_transaction
---@param self parser_transaction
---@return parser_transaction
local function copy_transaction(self)
    return { index = self.index, pos = self.pos }
end

local chunk
---tries to parse a lua chunk
---@return node
chunk = function(self)
    chunk = require('qamar.parser.production.chunk').parser
    return chunk(self)
end

---creates a new parser
---@param stream char_stream
---@return node_block
local function parse_from_stream(stream)
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

    return chunk(setmetatable({
        stream = stream,
        tokenid = 0,
        la = deque(),
        ts = {},
        tc = 0,
        t = {
            index = 0,
            pos = stpos(stream),
        },
    }, MT))
end

local char_stream = require 'qamar.tokenizer.char_stream'
local utf8 = require('qamar.util.string').utf8

---parses a lua chunk
---@param str string
---@return node_block
function parser.parse(str)
    return parse_from_stream(char_stream.new(utf8(str)))
end

---discards any consumed cached tokens if there are no pending transactions
---@param self parser
local function normalize(self)
    if self.tc == 0 then
        for _ = 1, self.t.index do
            self.la.pop_front()
        end
        self.t.index = 0
    end
end
parser.normalize = normalize

---fills the parser's token buffer to contain N items, unless the end of the stream has been reached
---@param self any
---@param amt number
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

---gets the Nth (zero based) token from the token cache
---N defaults to 0
---@param self parser
---@param N number|nil
---@return token
local function peek(self, N)
    N = N == nil and 0 or N
    local idx = self.t.index + N + 1
    fill(self, idx)
    return self.la[idx] or nil
end
parser.peek = peek

---consumes N tokens from the token cache.
---N defaults to 1
---@param self parser
---@param N number|nil
---@return token|table
local function take(self, N)
    N = N == nil and 1 or N
    local idx = self.t.index + N
    fill(self, idx)
    local ret = {}
    for i = 1, N do
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

---gets the rightmost position in the token stream
---@return position
function parser:pos()
    return self.t.pos
end

---gets the next available token id
---@return number
local function next_id(self)
    local x = peek(self)
    return x and x.id or self.tokenid
end
parser.next_id = next_id

---consumes tokens until one with the specified id or larger is encountered
---@param id number
function parser:take_until(id)
    while true do
        local x = peek(self)
        if not x or x.id >= id then
            return
        end
        take(self)
    end
end

---begins a new parser transaction. must be paired with a subsequent call to undo or normalize
---@param self parser
local function begin(self)
    self.tc = self.tc + 1
    self.ts[self.tc] = copy_transaction(self.t)
end
parser.begin = begin

---undoes a parser transaction. must be paired with a preceding call to begin
---@param self parser
local function undo(self)
    self.t, self.ts[self.tc], self.tc = self.ts[self.tc], nil, self.tc - 1
end
parser.undo = undo

---commits a parser transaction. must be paired with a preceding call to begin
---@param self parser
local function commit(self)
    self.ts[self.tc], self.tc = nil, self.tc - 1
    normalize(self)
    if self.tc == 0 and self.on_flush then
        self.on_flush()
    end
end
parser.commit = commit

---begins a new parser transaction and consumes the next token
---@param amt parser
---@return token|nil
function parser:begintake(amt)
    begin(self)
    return take(self, amt)
end

return parser
