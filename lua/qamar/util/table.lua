local M = {}
local string = require 'qamar.util.string'
local function isalphanum(c)
    if
        c == 'a'
        or c == 'b'
        or c == 'c'
        or c == 'd'
        or c == 'e'
        or c == 'f'
        or c == 'g'
        or c == 'h'
        or c == 'i'
        or c == 'j'
        or c == 'k'
        or c == 'l'
        or c == 'm'
        or c == 'n'
        or c == 'o'
        or c == 'p'
        or c == 'q'
        or c == 'r'
        or c == 's'
        or c == 't'
        or c == 'u'
        or c == 'v'
        or c == 'w'
        or c == 'x'
        or c == 'y'
        or c == 'z'
        or c == 'A'
        or c == 'B'
        or c == 'C'
        or c == 'D'
        or c == 'E'
        or c == 'F'
        or c == 'G'
        or c == 'H'
        or c == 'I'
        or c == 'J'
        or c == 'K'
        or c == 'L'
        or c == 'M'
        or c == 'N'
        or c == 'O'
        or c == 'P'
        or c == 'Q'
        or c == 'R'
        or c == 'S'
        or c == 'T'
        or c == 'U'
        or c == 'V'
        or c == 'W'
        or c == 'X'
        or c == 'Y'
        or c == 'Z'
        or c == '_'
        or c == '0'
        or c == '1'
        or c == '2'
        or c == '3'
        or c == '4'
        or c == '5'
        or c == '6'
        or c == '7'
        or c == '8'
        or c == '9'
    then
        return true
    else
        return false
    end
end
M.tconcat = function(self)
    local prevalpha = false
    local ret = {}
    local i = 0
    for _, x in ipairs(self) do
        x = string.trim(tostring(x))
        if x ~= '' then
            if prevalpha and isalphanum(x:sub(1, 1)) then
                i = i + 1
                ret[i] = ' '
            end
            i = i + 1
            ret[i] = x
            prevalpha = isalphanum(x:sub(x:len(), x:len()))
        end
    end
    return table.concat(ret)
end

M.tinsert = function(tbl, ...)
    local idx = #tbl
    local args = { ... }
    for i = 1, #args do
        idx = idx + 1
        tbl[idx] = args[i]
    end
    return tbl
end

return setmetatable(M, { __index = table })
