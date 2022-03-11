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
