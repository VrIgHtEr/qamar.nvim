local types = {
    comment = 0,
    name = 0,
    string = 0,
    number = 0,
    kw_and = 0,
    kw_false = 0,
    kw_local = 0,
    kw_then = 0,
    kw_break = 0,
    kw_for = 0,
    kw_nil = 0,
    kw_true = 0,
    kw_do = 0,
    kw_function = 0,
    kw_not = 0,
    kw_until = 0,
    kw_else = 0,
    kw_goto = 0,
    kw_or = 0,
    kw_while = 0,
    kw_elseif = 0,
    kw_if = 0,
    kw_repeat = 0,
    kw_end = 0,
    kw_in = 0,
    kw_return = 0,
    plus = 0,
    dash = 0,
    asterisk = 0,
    slash = 0,
    percent = 0,
    caret = 0,
    hash = 0,
    ampersand = 0,
    tilde = 0,
    pipe = 0,
    lshift = 0,
    rshift = 0,
    doubleslash = 0,
    equal = 0,
    notequal = 0,
    lessequal = 0,
    greaterequal = 0,
    less = 0,
    greater = 0,
    assignment = 0,
    lparen = 0,
    rparen = 0,
    lbrace = 0,
    rbrace = 0,
    lbracket = 0,
    rbracket = 0,
    doublecolon = 0,
    semicolon = 0,
    colon = 0,
    comma = 0,
    dot = 0,
    doubledot = 0,
    tripledot = 0,
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
