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

local function print_call_stack()
    local level = 1
    print 'STACK TRACE:'
    while true do
        level = level + 1
        local info = debug.getinfo(level, 'Sn')
        if not info then
            break
        end
        local line = { '    ', tostring(level), ': ', info.what }
        if info.what == 'Lua' then
            table.insert(line, ' ')
            table.insert(line, info.source)
            table.insert(line, ':')
            table.insert(line, tostring(info.linedefined))
            table.insert(line, ':')
            table.insert(line, tostring(info.name))
        end
        print(table.concat(line))
    end
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

local parselet = require 'qamar.parser.parselet2'

local function get_precedence(self)
    local next = self:peek()
    if next then
        local infix = parselet.infix[next.type]
        if infix then
            return infix.precedence
        end
    end
    return 0
end

function parser:expression(precedence)
    precedence = precedence or 0

    local tok = self:peek()
    if not tok then
        return
    end
    local prefix = parselet.prefix[tok.type]
    if not prefix then
        return
    end
    self:begin()
    self:take()
    local left = prefix:parse(self, tok)
    if not left then
        self:undo()
        return
    end
    while precedence < get_precedence(self) do
        tok = self:peek()
        if not tok then
            self:commit()
            return left
        end
        local infix = parselet.infix[tok.type]
        if not infix then
            self:commit()
            return left
        end
        self:begin()
        self:take()
        local right = infix:parse(self, left, tok)
        if not right then
            self:undo()
            self:undo()
            return left
        else
            self:commit()
            left = right
        end
    end
    self:commit()
    return left
end

local precedence = require 'qamar.parser.precedence'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local mt = {
    field_raw = {
        __tostring = function(self)
            return tconcat { '[', self.key, ']', '=', self.value }
        end,
    },
    field_name = {
        __tostring = function(self)
            return tconcat { self.key, '=', self.value }
        end,
    },
    fieldlist = {
        __tostring = function(self)
            local ret, idx = {}, 1
            for i, x in ipairs(self) do
                if i > 1 then
                    ret[idx], idx = ',', idx + 1
                end
                ret[idx], idx = x, idx + 1
            end
            return tconcat(ret)
        end,
    },
}

local function wrap(node, parser_func)
    if type(node) ~= 'table' then
        node = { type = node }
    end
    return function(self)
        local ret = parser_func(self)
        if ret then
            ret.type = node.type
            ret.typename = n[node.type]
            if node.rewrite then
                local x = node.rewrite(ret)
                for i = 1, #ret do
                    ret[i] = nil
                end
                for i = 1, #x do
                    ret[i] = x[i]
                end
            end
            if node.string then
                setmetatable(ret, { __tostring = node.string })
            end
        end
        return ret
    end
end

function parser:name()
    local tok = self:peek()
    if tok and tok.type == token.name then
        local ret = self:expression(precedence.literal)
        if ret and ret.type == n.name then
            return ret
        end
    end
end

function parser:field_raw()
    local tok = self:peek()
    if tok and tok.type == token.lbracket then
        self:begin()
        local left = self:take().pos.left
        local key = self:expression()
        if key then
            tok = self:take()
            if tok and tok.type == token.rbracket then
                tok = self:take()
                if tok and tok.type == token.assignment then
                    local value = self:expression()
                    if value then
                        self:commit()
                        return setmetatable({ key = key, value = value, pos = { left = left, right = value.pos.right }, type = n.field_raw }, mt.field_raw)
                    end
                end
            end
        end
        self:undo()
    end
end

function parser:field_name()
    local key = self:peek()
    if key and key.type == token.name then
        self:begin()
        local left = self:take().pos.left
        local tok = self:take()
        if tok and tok.type == token.assignment then
            local value = self:expression()
            if value then
                self:commit()
                return setmetatable({ key = key.value, value = value, type = n.field_name, pos = { left = left, right = value.pos.right } }, mt.field_name)
            end
        end
        self:undo()
    end
end

parser.field = alt(parser.field_raw, parser.field_name, parser.expression)

function parser:fieldlist()
    local field = self:field()
    if field then
        local pos = { left = field.pos.left, right = field.pos.right }
        local ret, idx = setmetatable({ field, type = n.fieldlist, pos = pos }, mt.fieldlist), 2
        while true do
            local tok = self:peek()
            if tok and (tok.type == token.comma or tok.type == token.semicolon) then
                self:begin()
                self:take()
                field = self:field()
                if not field then
                    self:undo()
                    break
                end
                ret[idx], idx = field, idx + 1
                self:commit()
            else
                break
            end
        end
        local tok = self:peek()
        if tok and (tok.type == token.comma or tok.type == token.semicolon) then
            self:take()
        end
        return ret
    end
end

function parser:tableconstructor()
    local tok = self:peek()
    if tok and tok.type == token.lbrace then
        local ret = self:expression(precedence.literal)
        if ret and ret.type == n.tableconstructor then
            return ret
        end
    end
end

parser.namelist = wrap({
    type = n.namelist,
    rewrite = function(self)
        local ret = { self[1] }
        if self[2][1] then
            for _, x in ipairs(self[2]) do
                tinsert(ret, x[2])
            end
        end
        return ret
    end,
    string = function(self)
        local ret = {}
        for i, x in ipairs(self) do
            if i > 1 then
                tinsert(ret, ',')
            end
            tinsert(ret, x)
        end
        return tconcat(ret)
    end,
}, seq(parser.name, zom(seq(token.comma, parser.name))))

parser.vararg = wrap({
    type = n.vararg,
    string = function()
        return '...'
    end,
}, function(self)
    local tok = self:peek()
    if tok and tok.type == token.tripledot then
        local ret = self:expression(precedence.literal)
        if ret and ret.type == n.vararg then
            return ret
        end
    end
end)

parser.parlist = alt(
    wrap({
        type = n.parlist,
        rewrite = function(self)
            local ret = { self[1] }
            if self[2][1] then
                tinsert(ret, self[2][2])
            end
            return ret
        end,
        string = function(self)
            local ret = {}
            for i, x in ipairs(self) do
                if i > 1 then
                    tinsert(ret, ',')
                end
                tinsert(ret, x)
            end
            return tconcat(ret)
        end,
    }, seq(parser.namelist, opt(seq(token.comma, parser.vararg)))),
    wrap(n.parlist, seq(parser.vararg))
)

parser.explist = wrap({
    type = n.explist,
    rewrite = function(self)
        local ret = { self[1] }
        if self[2][1] then
            for _, x in ipairs(self[2]) do
                tinsert(ret, x[2])
            end
        end
        return ret
    end,
    string = function(self)
        local ret = {}
        for i, x in ipairs(self) do
            if i > 1 then
                tinsert(ret, ',')
            end
            tinsert(ret, x)
        end
        return tconcat(ret)
    end,
}, seq(parser.expression, zom(seq(token.comma, parser.expression))))

parser.attrib = wrap({
    type = n.attrib,
    string = function(self)
        return self[1] and (tconcat { '<', self[2], '>' }) or ''
    end,
}, opt(seq(token.less, parser.name, token.greater)))

parser.attnamelist = wrap({
    type = n.attnamelist,
    rewrite = function(self)
        local ret = { { self[1], self[2] } }
        if self[3][1] then
            for _, x in ipairs(self[3]) do
                tinsert(ret, { x[2], x[3] })
            end
        end
        return ret
    end,
    string = function(self)
        local ret = {}
        for i, x in ipairs(self) do
            if i > 1 then
                tinsert(ret, ',')
            end
            tinsert(ret, x[1], x[2])
        end
        return tconcat(ret)
    end,
}, seq(parser.name, parser.attrib, zom(seq(token.comma, parser.name, parser.attrib))))

parser.retstat = wrap({
    type = n.retstat,
    rewrite = function(self)
        return { self[2] }
    end,
    string = function(self)
        local ret = { 'return' }
        if self[1].type then
            tinsert(ret, self[1])
        end
        return tconcat(ret)
    end,
}, seq(token.kw_return, opt(parser.explist), opt(token.semicolon)))

parser.label = wrap({
    type = n.label,
    rewrite = function(self)
        return { self[2] }
    end,
    string = function(self)
        return tconcat { '::', self[1], '::' }
    end,
}, seq(token.doublecolon, parser.name, token.doublecolon))

parser.funcname = wrap({
    type = n.funcname,
    string = function(self)
        local ret = { self[1] }
        for _, x in ipairs(self[2]) do
            tinsert(ret, '.', x[2])
        end
        if self[3][1] then
            tinsert(ret, ':', self[3][2])
        end
        return tconcat(ret)
    end,
}, seq(parser.name, zom(seq(token.dot, parser.name)), opt(seq(token.colon, parser.name))))

parser.block = wrap(
    {
        type = n.block,
        string = function(self)
            local ret = {}
            for _, x in ipairs(self[1]) do
                tinsert(ret, x)
            end
            tinsert(ret, self[2])
            return tconcat(ret)
        end,
    },
    seq(
        zom(function(self)
            return self:stat()
        end),
        opt(parser.retstat)
    )
)

parser.funcbody = wrap({
    type = n.funcbody,
    rewrite = function(self)
        return { self[2], self[4] }
    end,
    string = function(self)
        local ret = { '(' }
        if self[1][1] then
            tinsert(ret, self[1][1])
        end
        tinsert(ret, ')', self[2], 'end')
        return tconcat(ret)
    end,
}, seq(token.lparen, opt(parser.parlist), token.rparen, parser.block, token.kw_end))

function parser:functiondef()
    local tok = self:peek()
    if tok and tok.type == token.kw_function then
        local ret = self:expression(precedence.literal)
        if ret and ret.type == n.functiondef then
            return ret
        end
    end
end

function parser:var()
    self:begin()
    local ret = self:expression(precedence.atom)
    if ret and (ret.type == n.name or ret.type == n.table_nameaccess or ret.type == n.table_rawaccess) then
        self:commit()
        return ret
    end
    self:undo()
end

parser.varlist = wrap({
    type = n.varlist,
    rewrite = function(self)
        local ret = { self[1] }
        if self[2][1] then
            for _, x in ipairs(self[2]) do
                tinsert(ret, x[2])
            end
        end
        return ret
    end,
    string = function(self)
        local ret = {}
        for i, x in ipairs(self) do
            if i > 1 then
                tinsert(ret, ',')
            end
            tinsert(ret, x)
        end
        return tconcat(ret)
    end,
}, seq(parser.var, zom(seq(token.comma, parser.var))))

parser.stat = alt(
    wrap({
        type = n.stat_empty,
        string = function()
            return ';'
        end,
    }, seq(token.semicolon)),

    wrap({
        type = n.stat_localvar,
        string = function(self)
            local ret = { 'local', self[2] }
            if self[3][1] then
                tinsert(ret, '=', self[3][2])
            end
            return tconcat(ret)
        end,
    }, seq(token.kw_local, parser.attnamelist, opt(seq(token.assignment, parser.explist)))),

    wrap(n.stat_label, parser.label),

    wrap({
        type = n.stat_break,
        string = function()
            return 'break'
        end,
    }, seq(token.kw_break)),

    wrap({
        type = n.stat_goto,
        rewrite = function(self)
            return { self[2] }
        end,
        string = function(self)
            return tconcat { 'goto', self[1] }
        end,
    }, seq(token.kw_goto, parser.name)),

    wrap({
        type = n.localfunc,
        rewrite = function(self)
            return { self[3], self[4] }
        end,
        string = function(self)
            return tconcat { 'local function', self[1], self[2] }
        end,
    }, seq(token.kw_local, token.kw_function, parser.name, parser.funcbody)),

    wrap({
        type = n.func,
        rewrite = function(self)
            return { self[2], self[3] }
        end,
        string = function(self)
            return tconcat { 'function', self[1], self[2] }
        end,
    }, seq(token.kw_function, parser.funcname, parser.funcbody)),

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
    ),

    wrap({
        type = n.stat_for_iter,
        rewrite = function(self)
            return { self[2], self[4], self[6] }
        end,
        string = function(self)
            return tconcat { 'for', self[1], 'in', self[2], 'do', self[3], 'end' }
        end,
    }, seq(token.kw_for, parser.namelist, token.kw_in, parser.explist, token.kw_do, parser.block, token.kw_end)),

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
    ),

    wrap({
        type = n.stat_do,
        rewrite = function(self)
            return { self[2] }
        end,
        string = function(self)
            return tconcat { 'do', self[1], 'end' }
        end,
    }, seq(token.kw_do, parser.block, token.kw_end)),

    wrap({
        type = n.stat_while,
        rewrite = function(self)
            return { self[2], self[4] }
        end,
        string = function(self)
            return tconcat { 'while', self[1], 'do', self[2], 'end' }
        end,
    }, seq(token.kw_while, parser.expression, token.kw_do, parser.block, token.kw_end)),

    wrap({
        type = n.stat_repeat,
        rewrite = function(self)
            return { self[2], self[4] }
        end,
        string = function(self)
            return tconcat { 'repeat', self[1], 'until', self[2] }
        end,
    }, seq(token.kw_repeat, parser.block, token.kw_until, parser.expression)),

    wrap({
        type = n.stat_assign,
        rewrite = function(self)
            return { self[1], self[3] }
        end,
        string = function(self)
            return tconcat { self[1], '=', self[2] }
        end,
    }, seq(parser.varlist, token.assignment, parser.explist)),

    function(self)
        self:begin()
        local ret = self:expression()
        if ret and ret.type == n.functioncall then
            self:commit()
            return ret
        end
        self:undo()
    end
)

parser.chunk = wrap(n.chunk, function(self)
    if self:peek() then
        local ret = self:block()
        local peek = self:peek()
        if ret then
            if peek then
                error('UNMATCHED TOKEN: ' .. tostring(peek) .. ' at line ' .. peek.pos.left.row .. ', col ' .. peek.pos.left.col)
            end
            return ret
        elseif peek then
            error('UNMATCHED TOKEN: ' .. tostring(peek) .. ' at line ' .. peek.pos.left.row .. ', col ' .. peek.pos.left.col)
        else
            error('PARSE_FAILURE' .. ' at line ' .. peek.pos.left.row .. ', col ' .. peek.pos.left.col)
        end
    else
        return setmetatable({}, {
            __tostring = function()
                return ''
            end,
        })
    end
end)

return parser
