local qamar = {}

local function inspect(c)
    return (vim.inspect(c):gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('\n%s*', ' '))
end

local function rpad(s, l)
    s = tostring(s)
    while #s < l do
        s = s .. ' '
    end
    return s
end

local function lpad(s, l)
    s = tostring(s)
    while #s < l do
        s = ' ' .. s
    end
    return s
end

function qamar.run()
    local ppp = require 'qamar.parser'(
        require 'qamar.tokenizer'(require 'qamar.tokenizer.char_stream'(require('toolshed.util.string').codepoints 'a+-b*-3^((4 or 7)+6)^7+4+(7+5)'))
    )
    local parsed = ppp.expression()
    print(parsed)
    print '---------------------------------------------------------------------'

    local string = require 'toolshed.util.string'
    local stream = require 'qamar.tokenizer.char_stream'
    local tokenizer = require 'qamar.tokenizer'
    local token_names = require 'qamar.tokenizer.types'

    local s = require('toolshed.util').read_file(vim.fn.stdpath 'data' .. '/site/pack/vrighter/opt/qamar.nvim/lua/qamar/tokenizer/char_stream.lua')
    local t = tokenizer(stream(string.filteredcodepoints(s)))
    t.begin()
    while t.peek() do
        local x = t.take()
        print(
            rpad(token_names[x.type], 15)
                .. ' '
                .. lpad(x.pos.left.row, 5)
                .. ','
                .. rpad(x.pos.left.col, 5)
                .. ' - '
                .. lpad(x.pos.right.row, 5)
                .. ','
                .. rpad(x.pos.right.col, 5)
                .. ' '
                .. inspect(x.value)
        )
    end
end

return qamar
