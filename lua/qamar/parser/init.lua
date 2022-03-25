local parselet, t, n = require 'qamar.parser.parselet', require 'qamar.tokenizer.types', require 'qamar.parser.types'
local prec = require 'qamar.parser.precedence'
local tconcat, tinsert = require('qamar.util.table').tconcat, require('qamar.util.table').tinsert
local alt, seq, opt, zom =
    require('qamar.tokenizer').combinators.alt,
    require('qamar.tokenizer').combinators.seq,
    require('qamar.tokenizer').combinators.opt,
    require('qamar.tokenizer').combinators.zom

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

local function wrap(node, parser)
    if type(node) ~= 'table' then
        node = { type = node }
    end
    return function(self)
        local ret = parser(self)
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

local function get_precedence(tokenizer)
    local next = tokenizer:peek()
    if next then
        local infix = parselet.infix[next.type]
        if infix then
            return infix.precedence
        end
    end
    return 0
end

local M = {}

function M:expression(precedence)
    precedence = precedence or 0

    local token = self:peek()
    if token then
        local prefix = parselet.prefix[token.type]
        if not prefix then
            return
        end
        self:begin()
        self:take()
        local left = prefix:parse(self, token)
        if not left then
            self:undo()
            return
        end
        while precedence < get_precedence(self) do
            token = self:peek()
            if not token then
                self:commit()
                return left
            end
            local infix = parselet.infix[token.type]
            if not infix then
                self:commit()
                return left
            end
            self:begin()
            self:take()
            local right = infix:parse(self, left, token)
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
end

function M:name()
    local tok = self:peek()
    if tok and tok.type == t.name then
        local ret = self:expression(prec.literal)
        if ret and ret.type == n.name then
            return ret
        end
    end
end

function M:field_raw()
    local tok = self:peek()
    if tok and tok.type == t.lbracket then
        self:begin()
        local left = self:take().pos.left
        local key = self:expression()
        if key then
            tok = self:take()
            if tok and tok.type == t.rbracket then
                tok = self:take()
                if tok and tok.type == t.assignment then
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

function M:field_name()
    local key = self:peek()
    if key and key.type == t.name then
        self:begin()
        local left = self:take().pos.left
        local tok = self:take()
        if tok and tok.type == t.assignment then
            local value = self:expression()
            if value then
                self:commit()
                return setmetatable({ key = key.value, value = value, type = n.field_name, pos = { left = left, right = value.pos.right } }, mt.field_name)
            end
        end
        self:undo()
    end
end

M.field = alt(M.field_raw, M.field_name, M.expression)

function M:fieldlist()
    local f = M.field(self)
    if f then
        local pos = { left = f.pos.left, right = f.pos.right }
        local ret, idx = setmetatable({ f, type = n.fieldlist, pos = pos }, mt.fieldlist), 2
        while true do
            local tok = self:peek()
            if tok and (tok.type == t.comma or tok.type == t.semicolon) then
                self:begin()
                self:take()
                f = M.field(self)
                if not f then
                    self:undo()
                    break
                end
                ret[idx], idx = f, idx + 1
                self:commit()
            else
                break
            end
        end
        local tok = self:peek()
        if tok and (tok.type == t.comma or tok.type == t.semicolon) then
            self:take()
        end
        return ret
    end
end

function M:tableconstructor()
    local tok = self:peek()
    if tok and tok.type == t.lbrace then
        local ret = M.expression(self, prec.literal)
        if ret and ret.type == n.tableconstructor then
            return ret
        end
    end
end

M.namelist = wrap({
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
}, seq(M.name, zom(seq(t.comma, M.name))))

M.vararg = wrap({
    type = n.vararg,
    string = function()
        return '...'
    end,
}, function(self)
    local tok = self:peek()
    if tok and tok.type == t.tripledot then
        local ret = M.expression(self, prec.literal)
        if ret and ret.type == n.vararg then
            return ret
        end
    end
end)
M.parlist = alt(
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
    }, seq(M.namelist, opt(seq(t.comma, M.vararg)))),
    wrap(n.parlist, seq(M.vararg))
)
M.explist = wrap({
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
}, seq(M.expression, zom(seq(t.comma, M.expression))))

M.attrib = wrap({
    type = n.attrib,
    string = function(self)
        return self[1] and (tconcat { '<', self[2], '>' }) or ''
    end,
}, opt(seq(t.less, M.name, t.greater)))

M.attnamelist = wrap({
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
}, seq(M.name, M.attrib, zom(seq(t.comma, M.name, M.attrib))))

M.retstat = wrap({
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
}, seq(t.kw_return, opt(M.explist), opt(t.semicolon)))

M.label = wrap({
    type = n.label,
    rewrite = function(self)
        return { self[2] }
    end,
    string = function(self)
        return tconcat { '::', self[1], '::' }
    end,
}, seq(t.doublecolon, M.name, t.doublecolon))

M.funcname = wrap({
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
}, seq(M.name, zom(seq(t.dot, M.name)), opt(seq(t.colon, M.name))))

local stat

M.block = wrap(
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
        zom(function(...)
            return stat(...)
        end),
        opt(M.retstat)
    )
)

M.funcbody = wrap({
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
}, seq(t.lparen, opt(M.parlist), t.rparen, M.block, t.kw_end))

M.functiondef = function(self)
    local tok = self:peek()
    if tok and tok.type == t.kw_function then
        local ret = M.expression(self, prec.literal)
        if ret and ret.type == n.functiondef then
            return ret
        end
    end
end

M.var = function(self)
    self:begin(prec.atom)
    local ret = M.expression(self)
    if ret and (ret.type == n.name or ret.type == n.table_nameaccess or ret.type == n.table_rawaccess) then
        self:commit()
        return ret
    end
    self:undo()
end

M.varlist = wrap({
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
}, seq(M.var, zom(seq(t.comma, M.var))))

stat = alt(
    wrap({
        type = n.stat_empty,
        string = function()
            return ';'
        end,
    }, seq(t.semicolon)),
    wrap({
        type = n.stat_localvar,
        string = function(self)
            local ret = { 'local', self[2] }
            if self[3][1] then
                tinsert(ret, '=', self[3][2])
            end
            return tconcat(ret)
        end,
    }, seq(t.kw_local, M.attnamelist, opt(seq(t.assignment, M.explist)))),
    wrap(n.stat_label, M.label),
    wrap({
        type = n.stat_break,
        string = function()
            return 'break'
        end,
    }, seq(t.kw_break)),
    wrap({
        type = n.stat_goto,
        rewrite = function(self)
            return { self[2] }
        end,
        string = function(self)
            return tconcat { 'goto', self[1] }
        end,
    }, seq(t.kw_goto, M.name)),
    wrap({
        type = n.localfunc,
        rewrite = function(self)
            return { self[3], self[4] }
        end,
        string = function(self)
            return tconcat { 'local function', self[1], self[2] }
        end,
    }, seq(t.kw_local, t.kw_function, M.name, M.funcbody)),
    wrap({
        type = n.func,
        rewrite = function(self)
            return { self[2], self[3] }
        end,
        string = function(self)
            return tconcat { 'function', self[1], self[2] }
        end,
    }, seq(t.kw_function, M.funcname, M.funcbody)),
    wrap({
        type = n.for_num,
        string = function(self)
            local ret = { 'for', self[2], '=', self[4], ',', self[6] }
            if self[7][1] then
                tinsert(ret, ',', self[7][2])
            end
            tinsert(ret, 'do', self[9], 'end')
            return tconcat(ret)
        end,
    }, seq(t.kw_for, M.name, t.assignment, M.expression, t.comma, M.expression, opt(seq(t.comma, M.expression)), t.kw_do, M.block, t.kw_end)),
    wrap({
        type = n.stat_for_iter,
        rewrite = function(self)
            return { self[2], self[4], self[6] }
        end,
        string = function(self)
            return tconcat { 'for', self[1], 'in', self[2], 'do', self[3], 'end' }
        end,
    }, seq(t.kw_for, M.namelist, t.kw_in, M.explist, t.kw_do, M.block, t.kw_end)),
    wrap({
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
    }, seq(t.kw_if, M.expression, t.kw_then, M.block, zom(seq(t.kw_elseif, M.expression, t.kw_then, M.block)), opt(seq(t.kw_else, M.block)), t.kw_end)),
    wrap({
        type = n.stat_do,
        rewrite = function(self)
            return { self[2] }
        end,
        string = function(self)
            return tconcat { 'do', self[1], 'end' }
        end,
    }, seq(t.kw_do, M.block, t.kw_end)),
    wrap({
        type = n.stat_while,
        rewrite = function(self)
            return { self[2], self[4] }
        end,
        string = function(self)
            return tconcat { 'while', self[1], 'do', self[2], 'end' }
        end,
    }, seq(t.kw_while, M.expression, t.kw_do, M.block, t.kw_end)),
    wrap({
        type = n.stat_repeat,
        rewrite = function(self)
            return { self[2], self[4] }
        end,
        string = function(self)
            return tconcat { 'repeat', self[1], 'until', self[2] }
        end,
    }, seq(t.kw_repeat, M.block, t.kw_until, M.expression)),
    wrap({
        type = n.stat_assign,
        rewrite = function(self)
            return { self[1], self[3] }
        end,
        string = function(self)
            return tconcat { self[1], '=', self[2] }
        end,
    }, seq(M.varlist, t.assignment, M.explist)),
    function(self)
        self:begin()
        local ret = M.expression(self)
        if ret and ret.type == n.functioncall then
            self:commit()
            return ret
        end
        self:undo()
    end
)
M.stat = stat

M.chunk = wrap(n.chunk, function(self)
    if self:peek() then
        local ret = M.block(self)
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

return M
