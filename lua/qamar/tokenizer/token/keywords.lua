local ret = {
    'and',
    'break',
    'do',
    'else',
    'elseif',
    'end',
    'false',
    'for',
    'function',
    'goto',
    'if',
    'in',
    'local',
    'nil',
    'not',
    'or',
    'repeat',
    'return',
    'then',
    'true',
    'until',
    'while',
}
table.sort(ret, function(a, b)
    local al, bl = a:len(), b:len()
    if al ~= bl then
        return al > bl
    end
    return a < b
end)
for i, x in ipairs(ret) do
    ret[x] = i
end
return ret
