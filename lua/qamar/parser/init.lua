local parselet, t, n = require 'qamar.parser.parselet', require 'qamar.tokenizer.types', require 'qamar.parser.types'
local prec = require 'qamar.parser.precedence'
local tconcat, tinsert = require('qamar.util.table').tconcat, require('qamar.util.table').tinsert

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

local function get_precedence(tokenizer)
    local next = tokenizer.peek()
    if next then
        local infix = parselet.infix[next.type]
        if infix then
            return infix.precedence
        end
    end
    return 0
end
local function wrap(node, parser)
    if type(node) ~= 'table' then
        node = { type = node }
    end
    return function()
        local ret = parser()
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
return function(tokenizer)
    local p = { tokenizer = tokenizer }
    local alt, seq, opt, zom = tokenizer.combinators.alt, tokenizer.combinators.seq, tokenizer.combinators.opt, tokenizer.combinators.zom

    function p.expression(precedence)
        precedence = precedence or 0

        local token = tokenizer.peek()
        if not token then
            return
        end
        local prefix = parselet.prefix[token.type]
        if not prefix then
            return
        end
        tokenizer.begin()
        tokenizer.take()
        local left = prefix:parse(p, token)
        if not left then
            tokenizer.undo()
            return
        end
        while precedence < get_precedence(tokenizer) do
            token = tokenizer.peek()
            if not token then
                tokenizer.commit()
                return left
            end
            local infix = parselet.infix[token.type]
            if not infix then
                tokenizer.commit()
                return left
            end
            tokenizer.begin()
            tokenizer.take()
            local right = infix:parse(p, left, token)
            if not right then
                tokenizer.undo()
                tokenizer.undo()
                return left
            else
                tokenizer.commit()
                left = right
            end
        end
        tokenizer.commit()
        return left
    end

    p.name = function()
        local tok = tokenizer.peek()
        if tok and tok.type == t.name then
            local ret = p.expression(prec.literal)
            if ret and ret.type == n.name then
                return ret
            end
        end
    end

    do
        local function field_raw()
            local tok = tokenizer.peek()
            if tok and tok.type == t.lbracket then
                tokenizer.begin()
                local left = tokenizer.take().pos.left
                local key = p.expression()
                if key then
                    tok = tokenizer.take()
                    if tok and tok.type == t.rbracket then
                        tok = tokenizer.take()
                        if tok and tok.type == t.assignment then
                            local value = p.expression()
                            if value then
                                tokenizer.commit()
                                return setmetatable(
                                    { key = key, value = value, pos = { left = left, right = value.pos.right }, type = n.field_raw },
                                    mt.field_raw
                                )
                            end
                        end
                    end
                end
                tokenizer.undo()
            end
        end

        local function field_name()
            local key = tokenizer.peek()
            if key and key.type == t.name then
                tokenizer.begin()
                local left = tokenizer.take().pos.left
                local tok = tokenizer.take()
                if tok and tok.type == t.assignment then
                    local value = p.expression()
                    if value then
                        tokenizer.commit()
                        return setmetatable(
                            { key = key.value, value = value, type = n.field_name, pos = { left = left, right = value.pos.right } },
                            mt.field_name
                        )
                    end
                end
                tokenizer.undo()
            end
        end

        p.field = alt(field_raw, field_name, p.expression)
    end

    p.fieldlist = function()
        local field = p.field()
        if field then
            local pos = { left = field.pos.left, right = field.pos.right }
            local ret, idx = setmetatable({ field, type = n.fieldlist, pos = pos }, mt.fieldlist), 2
            while true do
                local tok = tokenizer.peek()
                if tok and (tok.type == t.comma or tok.type == t.semicolon) then
                    tokenizer.begin()
                    tokenizer.take()
                    field = p.field()
                    if not field then
                        tokenizer.undo()
                        break
                    end
                    ret[idx], idx = field, idx + 1
                    tokenizer.commit()
                else
                    break
                end
            end
            local tok = tokenizer.peek()
            if tok and (tok.type == t.comma or tok.type == t.semicolon) then
                tokenizer.take()
            end
            return ret
        end
    end

    p.tableconstructor = function()
        local tok = tokenizer.peek()
        if tok and tok.type == t.lbrace then
            local ret = p.expression(prec.literal)
            if ret and ret.type == n.tableconstructor then
                return ret
            end
        end
    end

    p.namelist = wrap({
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
    }, seq(p.name, zom(seq(t.comma, p.name))))

    p.vararg = wrap({
        type = n.vararg,
        string = function()
            return '...'
        end,
    }, function()
        local tok = tokenizer.peek()
        if tok and tok.type == t.tripledot then
            local ret = p.expression(prec.literal)
            if ret and ret.type == n.vararg then
                return ret
            end
        end
    end)
    p.parlist = alt(
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
        }, seq(p.namelist, opt(seq(t.comma, p.vararg)))),
        wrap(n.parlist, seq(p.vararg))
    )
    p.explist = wrap({
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
    }, seq(p.expression, zom(seq(t.comma, p.expression))))
    p.attrib = wrap({
        type = n.attrib,
        string = function(self)
            return self[1] and (tconcat { '<', self[2], '>' }) or ''
        end,
    }, opt(seq(t.less, p.name, t.greater)))
    p.attnamelist = wrap({
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
    }, seq(p.name, p.attrib, zom(seq(t.comma, p.name, p.attrib))))
    p.retstat = wrap({
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
    }, seq(t.kw_return, opt(p.explist), opt(t.semicolon)))
    p.label = wrap({
        type = n.label,
        rewrite = function(self)
            return { self[2] }
        end,
        string = function(self)
            return tconcat { '::', self[1], '::' }
        end,
    }, seq(t.doublecolon, p.name, t.doublecolon))
    p.funcname = wrap({
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
    }, seq(p.name, zom(seq(t.dot, p.name)), opt(seq(t.colon, p.name))))
    p.block = wrap(
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
            zom(function()
                return p.stat()
            end),
            opt(p.retstat)
        )
    )
    p.funcbody = wrap({
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
    }, seq(t.lparen, opt(p.parlist), t.rparen, p.block, t.kw_end))
    p.functiondef = function()
        local tok = tokenizer.peek()
        if tok and tok.type == t.kw_function then
            local ret = p.expression(prec.literal)
            if ret and ret.type == n.functiondef then
                return ret
            end
        end
    end
    p.var = function()
        tokenizer.begin(prec.atom)
        local ret = p.expression()
        if ret and (ret.type == n.name or ret.type == n.table_nameaccess or ret.type == n.table_rawaccess) then
            tokenizer.commit()
            return ret
        end
        tokenizer.undo()
    end
    p.varlist = wrap({
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
    }, seq(p.var, zom(seq(t.comma, p.var))))
    p.stat = alt(
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
        }, seq(t.kw_local, p.attnamelist, opt(seq(t.assignment, p.explist)))),
        wrap(n.stat_label, p.label),
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
        }, seq(t.kw_goto, p.name)),
        wrap({
            type = n.localfunc,
            rewrite = function(self)
                return { self[3], self[4] }
            end,
            string = function(self)
                return tconcat { 'local function', self[1], self[2] }
            end,
        }, seq(t.kw_local, t.kw_function, p.name, p.funcbody)),
        wrap({
            type = n.func,
            rewrite = function(self)
                return { self[2], self[3] }
            end,
            string = function(self)
                return tconcat { 'function', self[1], self[2] }
            end,
        }, seq(t.kw_function, p.funcname, p.funcbody)),
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
        }, seq(t.kw_for, p.name, t.assignment, p.expression, t.comma, p.expression, opt(seq(t.comma, p.expression)), t.kw_do, p.block, t.kw_end)),
        wrap({
            type = n.stat_for_iter,
            rewrite = function(self)
                return { self[2], self[4], self[6] }
            end,
            string = function(self)
                return tconcat { 'for', self[1], 'in', self[2], 'do', self[3], 'end' }
            end,
        }, seq(t.kw_for, p.namelist, t.kw_in, p.explist, t.kw_do, p.block, t.kw_end)),
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
        }, seq(
            t.kw_if,
            p.expression,
            t.kw_then,
            p.block,
            zom(seq(t.kw_elseif, p.expression, t.kw_then, p.block)),
            opt(seq(t.kw_else, p.block)),
            t.kw_end
        )),
        wrap({
            type = n.stat_do,
            rewrite = function(self)
                return { self[2] }
            end,
            string = function(self)
                return tconcat { 'do', self[1], 'end' }
            end,
        }, seq(t.kw_do, p.block, t.kw_end)),
        wrap({
            type = n.stat_while,
            rewrite = function(self)
                return { self[2], self[4] }
            end,
            string = function(self)
                return tconcat { 'while', self[1], 'do', self[2], 'end' }
            end,
        }, seq(t.kw_while, p.expression, t.kw_do, p.block, t.kw_end)),
        wrap({
            type = n.stat_repeat,
            rewrite = function(self)
                return { self[2], self[4] }
            end,
            string = function(self)
                return tconcat { 'repeat', self[1], 'until', self[2] }
            end,
        }, seq(t.kw_repeat, p.block, t.kw_until, p.expression)),
        wrap({
            type = n.stat_assign,
            rewrite = function(self)
                return { self[1], self[3] }
            end,
            string = function(self)
                return tconcat { self[1], '=', self[2] }
            end,
        }, seq(p.varlist, t.assignment, p.explist)),
        function()
            tokenizer.begin()
            local ret = p.expression()
            if ret and ret.type == n.functioncall then
                tokenizer.commit()
                return ret
            end
            tokenizer.undo()
        end
    )
    p.chunk = wrap(n.chunk, function()
        if tokenizer.peek() then
            local ret = p.block()
            local peek = tokenizer.peek()
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
    return p
end
