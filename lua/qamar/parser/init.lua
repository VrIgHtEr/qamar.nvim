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
    if type(node) ~= 'table' then node = {type = node} end
    return function()
        local ret = parser()
        if ret then
            ret.type = node.type
            ret.typename = n[node.type]
            if node.string then
                setmetatable(ret,{__tostring = node.string})
                print('$('..n[node.type] .. ')'..tostring(ret))
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
                print(left)return left
            end

            local infix = parselet.infix[token.type]
            if not infix then
                tokenizer.commit()
                print(left)
                print(left)return left
            end
            tokenizer.begin()
            tokenizer.take()
            local right = infix:parse(p, left, token)
            if not right then
                tokenizer.undo()
                tokenizer.undo()
                print(left)return left
            else
                tokenizer.commit()
                left = right
            end
        end

        tokenizer.commit()
        print(left)return left
    end

    p.fieldsep = wrap({type = n.fieldsep, string = function() return ',' end}, alt(t.comma, t.semicolon))

    p.field = alt(
    wrap({type = n.field_raw, string = function(self) return '['..tostring(self[2]) .. '] = '..tostring(self[5]) end}, seq(t.lbracket, p.expression, t.rbracket, t.assignment, p.expression)),
    wrap(n.field_name, seq(t.name, t.assignment, p.expression)),
    p.expression)

    p.fieldlist = wrap({type = n.fieldlist,stirng= function(self)
        local ret = {tostring(self[1])}
        for _,x in ipairs(self[2]) do
            table.insert(ret,', ')
            table.insert(ret,tostring(x))
        end
        return table.concat(ret)
    end}, seq(p.field, zom(seq(p.fieldsep, p.field)), opt(p.fieldsep)))

    p.tableconstructor = function()
        tokenizer.begin()
        local ret = p.expression()
        if ret and ret.type == n.tableconstructor then
            tokenizer.commit()
            return ret
        end
        tokenizer.undo()
    end

    p.namelist = wrap({type=n.namelist,string=function(self)
        local ret = {tostring(self[1])}
        for _,x in ipairs(self[2]) do
            table.insert(ret,', ')
            table.insert(ret,tostring(x))
        end
        return table.concat(ret)
    end}, seq(t.name, zom(seq(t.comma, t.name))))

    p.vararg = wrap({type=n.vararg, string=function()return'...'end}, alt(t.tripledot))

    p.parlist = wrap(n.parlist, alt(seq(p.namelist, opt(seq(t.comma, p.vararg))), p.vararg))

    p.parlist = alt(
    wrap({type=n.parlist,string=function(self)
        local ret = tostring(self[1])
        if self[2][1] then
            ret = ret .. ', ...'
        end
        return ret
    end}, seq(p.namelist, opt(seq(t.comma, p.vararg))))
    , p.vararg)

    p.explist = wrap({type=n.explist,string=function(self)
        local ret = {tostring(self[1])}
        for _,x in ipairs(self[2]) do
            table.insert(ret, ', ')
            table.insert(ret, tostring(x[2]))
        end
        return table.concat(ret)
    end}, seq(p.expression, zom(seq(t.comma, p.expression))))

    p.attrib = wrap(n.attrib, opt(seq(t.less, t.name, t.greater)))
    p.attnamelist = wrap(n.attnamelist, seq(t.name, p.attrib, zom(seq(t.comma, t.name, p.attrib))))

    p.retstat = wrap({type=n.retstat,string=function(self) return 'return '.. tostring(self[2]) end}, seq(t.kw_return, opt(p.explist), opt(t.semicolon)))

    p.label = wrap(n.label, seq(t.doublecolon, t.name, t.doublecolon))
    p.funcname = wrap(n.funcname, seq(t.name, zom(seq(t.dot, t.name)), opt(seq(t.colon, t.name))))
    p.args = wrap(n.args, alt(seq(t.lparen, p.explist, t.rparen), p.tableconstructor, t.string))

    p.block = wrap(
        {type = n.block, string = function(self)
            local ret = {}
            for i,x in ipairs(self[1]) do
                if i > 1 then table.insert(ret,' ') end
                table.insert(ret, tostring(x))
            end
            if #ret > 0 then table.insert(ret,' ') end
            table.insert(ret,tostring(self[2]))
            return table.concat(ret)
        end},
        seq(
            zom(function()
                return p.stat()
            end),
            opt(p.retstat)
        )
    )
    p.funcbody = wrap(n.funcbody, seq(t.lparen, opt(p.parlist), t.rparen, p.block, t.kw_end))
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

    p.varlist = wrap(n.varlist, seq(p.var, zom(seq(t.comma, p.var))))

    p.stat = alt(
        wrap(n.stat_empty, seq(t.semicolon)),
        wrap(n.stat_localvar, seq(t.kw_local, p.attnamelist, opt(seq(t.assignment, p.explist)))),
        wrap(n.stat_label, p.label),
        wrap(n.stat_break, seq(t.kw_break)),
        wrap(n.stat_goto, seq(t.kw_goto, t.name)),
        wrap(n.localfunc, seq(t.kw_local, t.kw_function, t.name, p.funcbody)),
        wrap(n.func, seq(t.kw_function, p.funcname, p.funcbody)),
        wrap(n.for_num, seq(t.kw_for, t.name, t.assignment, p.expression, t.comma, p.expression, opt(seq(t.comma, p.expression)), t.kw_do, p.block, t.kw_end)),
        wrap(n.stat_for_iter, seq(t.kw_for, p.namelist, t.kw_in, p.explist, t.kw_do, p.block, t.kw_end)),
        wrap(
            n.stat_if,
            seq(t.kw_if, p.expression, t.kw_then, p.block, zom(seq(t.kw_elseif, p.expression, t.kw_then, p.block)), opt(seq(t.kw_else, p.block)), t.kw_end)
        ),
        wrap(n.stat_do, seq(t.kw_do, p.block, t.kw_end)),
        wrap(n.stat_while, seq(t.kw_while, p.expression, t.kw_do, p.block, t.kw_end)),
        wrap(n.stat_repeat, seq(t.kw_repeat, p.block, t.kw_until, p.expression)),
        wrap(n.stat_assign, seq(p.varlist, t.assignment, p.explist)),
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
