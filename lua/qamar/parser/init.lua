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

local function wrap(type, parser)
    return function()
        local ret = parser()
        if ret then
            ret.type = type
            ret.typename = n[type]
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

    p.fieldsep = wrap(n.fieldsep, alt(t.comma, t.semicolon))
    p.field = wrap(n.field, alt(seq(t.lbracket, p.expression, t.rbracket, t.assignment, p.expression), seq(t.name, t.assignment, p.expression), p.expression))
    p.fieldlist = wrap(n.fieldlist, seq(p.field, zom(seq(p.fieldsep, p.field)), opt(p.fieldsep)))
    p.tableconstructor = function()
        local ret = p.expression()
        return ret and ret.type == n.tableconstructor and ret or nil
    end
    p.namelist = wrap(n.namelist, seq(t.name, zom(seq(t.comma, t.name))))
    p.parlist = wrap(n.parlist, alt(seq(p.namelist, opt(seq(t.comma, t.tripledot))), t.tripledot))
    p.explist = wrap(n.explist, seq(p.expression, zom(seq(t.comma, p.expression))))
    p.attrib = wrap(n.attrib, opt(seq(t.less, t.name, t.greater)))
    p.attnamelist = wrap(n.attnamelist, seq(t.name, p.attrib, zom(seq(t.comma, t.name, p.attrib))))
    p.retstat = wrap(n.retstat, seq(t.kw_return, opt(p.explist), opt(t.semicolon)))
    p.label = wrap(n.label, seq(t.doublecolon, t.name, t.doublecolon))
    p.funcname = wrap(n.funcname, seq(t.name, zom(seq(t.dot, t.name)), opt(seq(t.colon, t.name))))
    p.args = wrap(n.args, alt(seq(t.lparen, p.explist, t.rparen), p.tableconstructor, t.string))

    p.block = wrap(
        n.block,
        seq(
            zom(function()
                return p.stat()
            end),
            opt(p.retstat)
        )
    )
    p.funcbody = wrap(n.funcbody, seq(t.lparen, opt(p.parlist), t.rparen, p.block, t.kw_end))
    p.functiondef = function()
        local ret = p.expression()
        return ret and ret.type == n.functiondef and ret or nil
    end

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
        wrap(n.stat_repeat, seq(t.kw_repeat, p.block, t.kw_until, p.expression))
    )

    p.chunk = wrap(n.chunk, function()
        if tokenizer.peek() then
            local ret = p.block()
            return ret and not tokenizer.peek() and ret or nil
        end
    end)

    return p
end
