local types = {
    comment = true,
    name = true,
    string = true,
    number = true,
    kw_and = true,
    kw_false = true,
    kw_local = true,
    kw_then = true,
    kw_break = true,
    kw_for = true,
    kw_nil = true,
    kw_true = true,
    kw_do = true,
    kw_function = true,
    kw_not = true,
    kw_until = true,
    kw_else = true,
    kw_goto = true,
    kw_or = true,
    kw_while = true,
    kw_elseif = true,
    kw_if = true,
    kw_repeat = true,
    kw_end = true,
    kw_in = true,
    kw_return = true,
    add = true,
    sub = true,
    mul = true,
    div = true,
    mod = true,
    exp = true,
    len = true,
    bitand = true,
    bitnot = true,
    bitor = true,
    lshift = true,
    rshift = true,
    fdiv = true,
    eq = true,
    neq = true,
    leq = true,
    geq = true,
    lt = true,
    gt = true,
    assign = true,
    lparen = true,
    rparen = true,
    lbrace = true,
    rbrace = true,
    lbracket = true,
    rbracket = true,
    label = true,
    semicolon = true,
    colon = true,
    comma = true,
    dot = true,
    concat = true,
    vararg = true,
}
do
    local names = {}
    local index = 0
    for k in pairs(types) do
        index = index + 1
        names[index], types[k] = k, index
    end
    for i, v in ipairs(names) do
        types[i] = v
    end
end

return types
