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
    plus = true,
    dash = true,
    asterisk = true,
    slash = true,
    percent = true,
    caret = true,
    hash = true,
    ampersand = true,
    tilde = true,
    pipe = true,
    lshift = true,
    rshift = true,
    doubleslash = true,
    equal = true,
    notequal = true,
    lessequal = true,
    greaterequal = true,
    less = true,
    greater = true,
    assignment = true,
    lparen = true,
    rparen = true,
    lbrace = true,
    rbrace = true,
    lbracket = true,
    rbracket = true,
    doublecolon = true,
    semicolon = true,
    colon = true,
    comma = true,
    dot = true,
    doubledot = true,
    tripledot = true,
}
do
    local names, index = {}, 0
    for k in pairs(types) do
        index = index + 1
        names[index], types[k] = k, index
    end
    for i, v in ipairs(names) do
        types[i] = v
    end
end

return types
