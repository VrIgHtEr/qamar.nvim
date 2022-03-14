local types = {
    name = '$name',
    lnot = 'not',
    bnot = '~',
    neg = '-',
    lor = 'or',
    land = 'and',
    lt = '<',
    gt = '>',
    leq = '<=',
    geq = '>=',
    neq = '~=',
    eq = '==',
    bor = '|',
    bxor = '~',
    band = '&',
    lshift = '<<',
    rshift = '>>',
    concat = '..',
    add = '+',
    sub = '-',
    mul = '*',
    div = '/',
    fdiv = '//',
    mod = '%',
    exp = '^',
    len = '#',
    number = '$number',
    fieldsep = '$fieldsep',
    field = '$field',
    fieldlist = '$fieldlist',
    tableconstructor = '$tableconstructor',
    namelist = '$namelist',
    parlist = '$parlist',
    explist = '$explist',
    attrib = '$attrib',
    attnamelist = '$attnamelist',
    retstat = '$retstat',
    label = '$label',
    funcname = '$funcname',
    subexpression = '$subexpression',
    args = '$args',
    block = '$block',
    chunk = '$chunk',
    funcbody = '$funcbody',
    functiondef = '$functiondef',
    val_nil = 'nil',
    val_false = 'false',
    val_true = 'true',
    vararg = '...',
    string = '$string',
    stat_localvar = '$stat_localvar',
    stat_label = '$label',
    stat_break = 'break',
    stat_goto = '$goto',
    stat_localfunc = '$localfunc',
    stat_func = '$func',
    stat_for_num = '$for_num',
    stat_for_iter = '$for_iter',
    stat_if = '$if',
    stat_repeat = '$repeat',
    stat_while = '$while',
    stat_do = '$do',
    stat_empty = '$do',
}

do
    local names, index = {}, 0
    for k, v in pairs(types) do
        index = index + 1
        names[index], types[k] = v, index
    end
    for i, v in ipairs(names) do
        types[i] = v
    end
end
return types
