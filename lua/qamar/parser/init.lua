local parselet, t, n = require 'qamar.parser.parselet', require 'qamar.tokenizer.types', require 'qamar.parser.types'
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
        tokenizer.begin()
        local token = tokenizer.take()
        if not token then
            tokenizer.undo()
            return
        end
        local prefix = parselet.prefix[token.type]
        if not prefix then
            tokenizer.undo()
            return
        end
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
    p.fieldsep = wrap({
        type = n.fieldsep,
        string = function()
            return ','
        end,
    }, function()
        local ret = alt(t.comma, t.semicolon)()
        if ret then
            ret = { pos = ret.pos, value = ret.value }
        end
        return ret
    end)
    p.field = alt(
        wrap({
            type = n.field_raw,
            string = function(self)
                return tconcat { '[', self[2], ']', '=', self[5] }
            end,
        }, seq(t.lbracket, p.expression, t.rbracket, t.assignment, p.expression)),
        wrap({
            type = n.field_name,
            string = function(self)
                return tconcat { self[1], '=', self[3] }
            end,
        }, seq(t.name, t.assignment, p.expression)),
        p.expression
    )
    p.fieldlist = wrap({
        type = n.fieldlist,
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
    }, seq(p.field, zom(seq(p.fieldsep, p.field)), opt(p.fieldsep)))
    p.tableconstructor = function()
        tokenizer.begin()
        local ret = p.expression()
        if ret and ret.type == n.tableconstructor then
            tokenizer.commit()
            return ret
        end
        tokenizer.undo()
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
    }, seq(t.name, zom(seq(t.comma, t.name))))
    p.vararg = wrap({
        type = n.vararg,
        string = function()
            return '...'
        end,
    }, alt(t.tripledot))
    p.parlist = alt(
        wrap({
            type = n.parlist,
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
        }, seq(p.namelist, opt(seq(t.comma, p.vararg)))),
        p.vararg
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
    }, opt(seq(t.less, t.name, t.greater)))
    p.attnamelist = wrap({
        type = n.attnamelist,
        rewrite = function(self)
            local ret = { { self[1], self[2] } }
            if self[2][1] then
                for _, x in ipairs(self[2]) do
                    table.remove(x, 1)
                    tinsert(ret, x)
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
    }, seq(t.name, p.attrib, zom(seq(t.comma, t.name, p.attrib))))
    p.retstat = wrap({
        type = n.retstat,
        string = function(self)
            local ret = { 'return' }
            if self[2].type then
                tinsert(ret, self[2])
            end
            return tconcat(ret)
        end,
    }, seq(t.kw_return, opt(p.explist), opt(t.semicolon)))
    p.label = wrap({
        type = n.label,
        string = function(self)
            return tconcat { '::', self[2], '::' }
        end,
    }, seq(t.doublecolon, t.name, t.doublecolon))
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
    }, seq(t.name, zom(seq(t.dot, t.name)), opt(seq(t.colon, t.name))))
    p.args = alt(
        wrap({
            type = n.args,
            string = function(self)
                return tostring(self[2])
            end,
        }, seq(t.lparen, p.explist, t.rparen)),
        p.tableconstructor,
        wrap({
            type = n.args,
            string = function(self)
                return self.value
            end,
        }, alt(t.string))
    )
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
        string = function(self)
            local ret = { '(' }
            if self[2][1] then
                tinsert(ret, self[2][1])
            end
            tinsert(ret, ')', self[4], 'end')
            return tconcat(ret)
        end,
    }, seq(t.lparen, opt(p.parlist), t.rparen, p.block, t.kw_end))
    p.functiondef = function()
        tokenizer.begin()
        local ret = p.expression()
        if ret and ret.type == n.functiondef then
            tokenizer.commit()
            return ret
        end
        tokenizer.undo()
    end
    p.var = function()
        tokenizer.begin()
        local ret = p.expression()
        if ret and (ret.type == n.name or ret.type == n.table_nameaccess or ret.type == n.table_rawaccess) then
            tokenizer.commit()
            return ret
        end
        tokenizer.undo()
    end
    p.varlist = wrap({
        type = n.varlist,
        string = function(self)
            local ret = { self[1] }
            for _, x in ipairs(self[2]) do
                tinsert(ret, ',', x[2])
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
            string = function(self)
                return tconcat { 'goto', self[2] }
            end,
        }, seq(t.kw_goto, t.name)),
        wrap({
            type = n.localfunc,
            string = function(self)
                return tconcat { 'local function', self[3], self[4] }
            end,
        }, seq(t.kw_local, t.kw_function, t.name, p.funcbody)),
        wrap({
            type = n.func,
            string = function(self)
                return tconcat { 'function', self[2], self[3] }
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
        }, seq(t.kw_for, t.name, t.assignment, p.expression, t.comma, p.expression, opt(seq(t.comma, p.expression)), t.kw_do, p.block, t.kw_end)),
        wrap({
            type = n.stat_for_iter,
            string = function(self)
                return tconcat { 'for', self[2], 'in', self[4], 'do', self[6], 'end' }
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
            string = function(self)
                return tconcat { 'do', self[2], 'end' }
            end,
        }, seq(t.kw_do, p.block, t.kw_end)),
        wrap({
            type = n.stat_while,
            string = function(self)
                return tconcat { 'while', self[2], 'do', self[4], 'end' }
            end,
        }, seq(t.kw_while, p.expression, t.kw_do, p.block, t.kw_end)),
        wrap({
            type = n.stat_repeat,
            string = function(self)
                return tconcat { 'repeat', self[2], 'until', self[4] }
            end,
        }, seq(t.kw_repeat, p.block, t.kw_until, p.expression)),
        wrap({
            type = n.stat_assign,
            string = function(self)
                return tconcat { self[1], '=', self[3] }
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
            return ret and not tokenizer.peek() and ret or nil
        end
    end)
    return p
end
