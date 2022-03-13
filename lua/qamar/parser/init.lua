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
        print('PARSING: ' .. n[type])
        local ret = parser()
        if ret then
            ret.type = type
            print('SUCCESS: ' .. n[type])
        else
            print('fail: ' .. n[type])
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
    p.tableconstructor = wrap(n.tableconstructor, seq(t.lbrace, p.fieldlist, t.rbrace))
    p.namelist = wrap(n.namelist, seq(t.name, zom(seq(t.comma, t.name))))
    p.parlist = wrap(n.parlist, alt(seq(p.namelist, opt(seq(t.comma, t.tripledot))), t.tripledot))
    p.explist = wrap(n.explist, seq(p.expression, zom(seq(t.comma, t.expression))))
    p.attrib = wrap(n.attrib, opt(seq(t.less, t.name, t.greater)))
    p.attnamelist = wrap(n.attnamelist, seq(t.name, p.attrib, zom(seq(t.comma, t.name, p.attrib))))
    p.retstat = wrap(n.retstat, seq(t.kw_return, opt(p.explist), opt(t.semicolon)))
    p.label = wrap(n.label, seq(t.doublecolon, t.name, t.doublecolon))
    p.funcname = wrap(n.funcname, seq(t.name, zom(seq(t.dot, t.name)), opt(seq(t.colon, t.name))))

    return p
end
