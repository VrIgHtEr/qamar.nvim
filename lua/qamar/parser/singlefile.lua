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
---@field cache_mapping deque
---@field on_flush function
local parser = {}

local deque = require 'qamar.util.deque'
local tokenizer = require 'qamar.tokenizer'
local char_stream = require 'qamar.tokenizer.char_stream'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local range = require 'qamar.util.range'
local N = require 'qamar.parser.node'
local utf8 = require('qamar.util.string').utf8
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert
local stpos = char_stream.pos
local stpeek = char_stream.peek
local sttake = char_stream.take
local concat = table.concat
local setmetatable = setmetatable
local ipairs = ipairs
local spos = parser.pos

local label
local expression
local attrib
local name
local attnamelist
local explist
local localvar
local empty
local retstat
local stat_break = require 'qamar.parser.production.stat.break'
local stat_goto = require 'qamar.parser.production.stat.goto'
local localfunc = require 'qamar.parser.production.stat.localfunc'
local func = require 'qamar.parser.production.stat.func'
local for_num = require 'qamar.parser.production.stat.for_num'
local functioncall = require 'qamar.parser.production.stat.functioncall'
local assign = require 'qamar.parser.production.stat.assign'
local stat_repeat = require 'qamar.parser.production.stat.repeat'
local stat_while = require 'qamar.parser.production.stat.while'
local for_iter = require 'qamar.parser.production.stat.for_iter'
local stat_do = require 'qamar.parser.production.stat.do'
local stat_if = require 'qamar.parser.production.stat.if'
local stat
local block

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
                line[index] = token[x.type]
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

---creates a copy of a token_transaction
---@param self parser_transaction
---@return parser_transaction
local function copy_transaction(self)
    return { index = self.index, pos = self.pos }
end

local chunk
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
---skip defaults to 0
---@param self parser
---@param skip number|nil
---@return token
local function peek(self, skip)
    skip = skip == nil and 0 or skip
    local idx = self.t.index + skip + 1
    fill(self, idx)
    return self.la[idx] or nil
end
parser.peek = peek

---consumes N tokens from the token cache.
---skip defaults to 1
---@param self parser
---@param skip number|nil
---@return token|table
local function take(self, skip)
    skip = skip == nil and 1 or skip
    local idx = self.t.index + skip
    fill(self, idx)
    local ret = {}
    for i = 1, skip do
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
---@self parser
---@return position
local function pos(self)
    return self.t.pos
end
parser.pos = pos

---gets the next available token id
---@return number
local function next_id(self)
    local x = peek(self)
    return x and x.id or self.tokenid
end
parser.next_id = next_id

---consumes tokens until one with the specified id or larger is encountered
---@param self parser
---@param id number
local function take_until(self, id)
    while true do
        local x = peek(self)
        if not x or x.id >= id then
            return
        end
        take(self)
    end
end
parser.take_until = take_until

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
        self.on_flush(next_id(self))
    end
end
parser.commit = commit

---begins a new parser transaction and consumes the next token
---@param self parser
---@param amt number
---@return token|nil
local function begintake(self, amt)
    begin(self)
    return take(self, amt)
end
parser.begintake = begintake

do
    ---@class node_label:node
    ---@field name string

    local mt = {
        ---@param self node_label
        ---@return string
        __tostring = function(self)
            return '::' .. self.name .. '::'
        end,
    }
    local tdoublecolon = token.doublecolon
    local nlabel = n.label

    ---try to consume a lua label
    ---@param self parser
    ---@return node_label|nil
    label = function(self)
        local left = peek(self)
        if not left or left.type ~= tdoublecolon then
            return
        end
        begintake(self)

        local nam = name(self)
        if not nam then
            undo(self)
            return
        end

        local right = take(self)
        if not right or right.type ~= tdoublecolon then
            undo(self)
            return
        end

        commit(self)
        local ret = N(nlabel, range(left.pos.left, right.pos.right), mt)
        ret.name = nam.value
        return ret
    end
end

do
    local parselet = require 'qamar.parser.parselet'

    ---gets the precedence of the next available token
    ---@param self parser
    ---@return number
    local function get_precedence(self)
        local next = peek(self)
        if next then
            local infix = parselet.infix[next.type]
            if infix then
                return infix.precedence
            end
        end
        return 0
    end

    ---try to consume a lua expression
    ---@param self parser
    ---@param precedence number|nil
    ---@return node_expression|nil
    expression = function(self, precedence)
        precedence = precedence or 0
        local id = next_id(self)
        if precedence == 0 then
            local item = self.cache[id]
            if item then
                take_until(self, item.last)
                return item.value
            elseif item ~= nil then
                return
            end
        end
        local tok = peek(self)
        if tok then
            local prefix = parselet.prefix[tok.type]
            if prefix then
                begin(self)
                take(self)
                local left = prefix:parse(self, tok)
                if not left then
                    if precedence == 0 then
                        self.cache[id] = { last = next_id(self), value = false }
                        self.cache_mapping.push_back(id)
                    end
                    undo(self)
                    return
                end
                while precedence < get_precedence(self) do
                    tok = peek(self)
                    if not tok then
                        commit(self)
                        if precedence == 0 then
                            self.cache[id] = { last = next_id(), value = left }
                            self.cache_mapping.push_back(id)
                        end
                        return left
                    end
                    local infix = parselet.infix[tok.type]
                    if not infix then
                        commit(self)
                        if precedence == 0 then
                            self.cache[id] = { last = next_id(), value = left }
                            self.cache_mapping.push_back(id)
                        end
                        return left
                    end
                    begin(self)
                    take(self)
                    local right = infix:parse(self, left, tok)
                    if not right then
                        undo(self)
                        undo(self)
                        if precedence == 0 then
                            self.cache[id] = { last = next_id(self), value = left }
                            self.cache_mapping.push_back(id)
                        end
                        return left
                    else
                        commit(self)
                        left = right
                    end
                end
                commit(self)
                if precedence == 0 then
                    self.cache[id] = { last = next_id(self), value = left }
                    self.cache_mapping.push_back(id)
                end
                return left
            elseif precedence == 0 then
                self.cache[id] = { last = next_id(self), value = false }
                self.cache_mapping.push_back(id)
            end
        elseif precedence == 0 then
            self.cache[id] = { last = next_id(self), value = false }
            self.cache_mapping.push_back(id)
        end
    end
end

do
    ---@class node_attrib:node
    ---@field name string

    local mt = {
        ---@param self node_attrib
        ---@return string
        __tostring = function(self)
            return '<' .. self.name .. '>'
        end,
    }

    local tless = token.less
    local tname = token.name
    local tgreater = token.greater
    local nattrib = n.attrib

    ---try to consume a lua variable attribute
    ---@param self parser
    ---@return node_attrib|nil
    attrib = function(self)
        local less = peek(self)
        if not less or less.type ~= tless then
            return
        end
        begintake(self)

        local nm = take(self)
        if not nm or nm.type ~= tname then
            undo(self)
            return
        end

        local greater = take(self)
        if not greater or greater.type ~= tgreater then
            undo(self)
            return
        end

        commit(self)
        local ret = N(nattrib, range(less.pos.left, greater.pos.right), mt)
        ret.name = nm.value
        return ret
    end
end

do
    ---@class node_name:node
    ---@field value string

    local mt = {
        ---@param self node_name
        ---@return string
        __tostring = function(self)
            return self.value
        end,
    }

    local tname = token.name
    local nname = n.name

    ---try to consume a lua name
    ---@param self parser
    ---@return node_name|nil
    name = function(self)
        local tok = peek(self)
        if tok and tok.type == tname then
            take(self)
            local ret = N(nname, tok.pos, mt)
            ret.value = tok.value
            return ret
        end
    end
end

do
    ---@class node_attnamelist:node

    ---@class node_attname:node
    ---@field name node_name
    ---@field attrib node_attrib

    local mt = {
        ---@param self node_attnamelist
        ---@return string
        __tostring = function(self)
            local ret = {}
            for i, x in ipairs(self) do
                if i > 1 then
                    tinsert(ret, ',')
                end
                tinsert(ret, x.name)
                if x.attrib then
                    tinsert(ret, x.attrib)
                end
            end
            return tconcat(ret)
        end,
    }

    local nattname = n.attname
    local nattnamelist = n.attnamelist
    local tcomma = token.comma

    ---try to consume a lua name attribute list
    ---@param self parser
    ---@return node_attnamelist|nil
    attnamelist = function(self)
        local nm = name(self)
        if nm then
            local a = attrib(self)
            local tmp = N(nattname, range(nm.pos.left, (a and a.pos.right or nm.pos.right)))
            tmp.name, tmp.attrib = nm, a
            local ret = N(nattnamelist, range(nm.pos.left), mt)
            ret[1] = tmp
            local idx = 1
            while true do
                local t = peek(self)
                if not t or t.type ~= tcomma then
                    break
                end
                begin(self)
                take(self)
                nm = name(self)
                if nm then
                    a = attrib(self)
                    commit(self)
                    idx = idx + 1
                    local item = N(nattname, range(nm.pos.left, (a and a.pos.right or nm.pos.right)))
                    item.name, item.attrib = nm, a
                    ret[idx] = item
                else
                    undo(self)
                    break
                end
            end

            local last = ret[idx]
            ret.pos.right = (last.attrib and last.attrib or last.name).pos.right
            return ret
        end
    end
end

do
    ---@class node_explist:node

    local nexplist = n.explist
    local tcomma = token.comma

    local mt = {
        ---@param self node_explist
        ---@return string
        __tostring = function(self)
            local ret = {}
            for i, x in ipairs(self) do
                if i > 1 then
                    tinsert(ret, ',')
                end
                tinsert(ret, x)
            end
            return tconcat(ret)
        end,
    }

    ---try to consume an expression list
    ---@param self parser
    ---@return node_explist|nil
    explist = function(self)
        local v = expression(self)
        if v then
            local ret = N(nexplist, range(v.pos.left), mt)
            ret[1] = v
            local idx = 1
            while true do
                local t = peek(self)
                if not t or t.type ~= tcomma then
                    break
                end
                begin(self)
                take(self)
                v = expression(self)
                if v then
                    commit(self)
                    idx = idx + 1
                    ret[idx] = v
                else
                    undo(self)
                    break
                end
            end

            ret.pos.right = ret[idx].pos.right
            return ret
        end
    end
end

do
    ---@class node_localvar:node
    ---@field names node_attnamelist
    ---@field values node_explist|nil

    local mt = {
        ---@param self node_localvar
        ---@return string
        __tostring = function(self)
            local ret = { 'local', self.names }
            if self.values then
                tinsert(ret, '=', self.values)
            end
            return tconcat(ret)
        end,
    }

    local tkw_local = token.kw_local
    local nstat_localvar = n.stat_localvar
    local tassignment = token.assignment

    ---try to consume a lua local variable declaration
    ---@param self parser
    ---@return node_localvar|nil
    localvar = function(self)
        local tok = peek(self)
        if tok and tok.type == tkw_local then
            begintake(self)
            local names = attnamelist(self)
            if names then
                local position = range(tok.pos.left)
                local ret = N(nstat_localvar, position, mt)
                commit(self)
                tok = peek(self)
                if tok and tok.type == tassignment then
                    begintake(self)
                    ret.values = explist(self)
                    if ret.values then
                        commit(self)
                        position.right = ret.values.pos.right
                    else
                        undo(self)
                        position.right = names.pos.right
                    end
                else
                    position.right = names.pos.right
                end
                return ret
            end
            undo(self)
        end
    end
end
do
    ---@class node_empty:node

    local mt = {
        __tostring = function()
            return ';'
        end,
    }

    local tsemicolon = token.semicolon
    local nstat_empty = n.stat_empty

    ---try to consume a lua empty statement
    ---@param self parser
    ---@return node_empty|nil
    empty = function(self)
        local tok = peek(self)
        if tok and tok.type == tsemicolon then
            take(self)
            return N(nstat_empty, tok.pos, mt)
        end
    end
end

do
    ---@class node_retstat:node
    ---@field explist node_explist|nil

    local mt = {
        ---@param self node_retstat
        ---@return string
        __tostring = function(self)
            local ret = { 'return' }
            if self.explist then
                tinsert(ret, self.explist)
            end
            return tconcat(ret)
        end,
    }

    local tkw_return = token.kw_return
    local nretstat = n.retstat
    local tsemicolon = token.semicolon

    ---try to consume a lua return statement
    ---@param self parser
    ---@return node_retstat|nil
    retstat = function(self)
        local retkw = peek(self)
        if retkw and retkw.type == tkw_return then
            take(self)
            local p = range(retkw.pos.left)
            local ret = N(nretstat, p, mt)
            ret.explist = explist(self)
            local tok = peek(self)
            if tok and tok.type == tsemicolon then
                take(self)
                p.right = tok.pos.right
            else
                p.right = ret.explist and ret.explist.pos.right or retkw.pos.right
            end
            return ret
        end
    end
end

do
    ---try to consume a lua statement
    ---@param self parser
    ---@return node_localvar|node_functioncall|node_assign|node_if|node_func|node_for_iter|node_for_num|node_do|node_break|node_while|node_goto|node_empty|node_repeat|node_label
    stat = function(self)
        return localvar(self)
            or functioncall(self)
            or assign(self)
            or stat_if(self)
            or func(self)
            or localfunc(self)
            or for_iter(self)
            or for_num(self)
            or stat_do(self)
            or stat_break(self)
            or stat_while(self)
            or stat_goto(self)
            or empty(self)
            or stat_repeat(self)
            or label(self)
    end
end

do
    ---@class node_block:node

    local mt = {
        __tostring = function(self)
            local ret = {}
            for _, x in ipairs(self) do
                tinsert(ret, x)
            end
            return tconcat(ret)
        end,
    }

    local nblock = n.block

    ---consumes a lua block
    ---@param self parser
    ---@return node_block
    block = function(self)
        local ret = N(nblock, nil, mt)
        local idx = 0
        while true do
            local stmt = stat(self)
            if not stmt then
                break
            end
            idx = idx + 1
            ret[idx] = stmt
        end
        local rs = retstat(self)
        if rs then
            idx = idx + 1
            ret[idx] = rs
        end

        ret.pos = idx == 0 and range(pos(self), pos(self)) or range(ret[1].pos.left, ret[idx].pos.right)
        return ret
    end
end

do
    local nblock = n.block

    local empty_mt = {
        __tostring = function()
            return ''
        end,
    }
    ---try to parse a lua chunk
    ---@param self parser
    ---@return node_block
    chunk = function(self)
        if peek(self) then
            local cache = {}
            self.cache = cache
            local cache_mapping = deque()
            self.cache_mapping = cache_mapping
            self.on_flush = function(id)
                while true do
                    local f = self.cache_mapping.peek_front()
                    if not f or f >= id then
                        break
                    end
                    cache[f] = nil
                    self.cache_mapping.pop_front()
                end
            end
            local success, ret = pcall(block, self)
            self.on_flush = nil
            self.cache = nil
            self.cache_mapping = nil
            if not success then
                error(ret)
            end
            local nxt = self.la[self.la.size()] or nil
            if ret then
                if nxt then
                    error(tostring(nxt.pos.left) .. ':UNMATCHED_TOKEN: ' .. tostring(nxt))
                end
                return ret
            elseif nxt then
                error(tostring(nxt.pos.left) .. ':UNMATCHED_TOKEN: ' .. tostring(nxt))
            else
                error(tostring(nxt.pos.left) .. ':PARSE_FAILURE')
            end
        else
            return N(nblock, range(spos(self), spos(self)), empty_mt)
        end
    end
end
return parser
