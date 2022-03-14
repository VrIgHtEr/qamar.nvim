local qamar = {}
local codepoints = require('toolshed.util.string').codepoints
local parser = require 'qamar.parser'
local tokenizer = require 'qamar.tokenizer'
local char_stream = require 'qamar.tokenizer.char_stream'

local function create_parser(str)
    return parser(tokenizer(char_stream(codepoints(str))))
end

function qamar.run()
    local ppp = create_parser 'a+-b*-3^((4 or 7)+6)^7+4+(7+5)'
    local parsed = ppp.expression()
    print(parsed)
    print '---------------------------------------------------------------------'
    ppp = create_parser 'local x1<close> = 7 + 2 if x1 == 3 then return x1 + 7, 5 end return x1 / 2'
    repeat
        parsed = ppp.chunk()
        print(vim.inspect(parsed))
        print '---------------------------------------------------------------------'
    until parsed == nil

    local txt = require('toolshed.util').read_file(vim.fn.stdpath 'data' .. '/site/pack/vrighter/opt/qamar.nvim/lua/qamar/parser/init.lua')
    ppp = create_parser(txt)
    parsed = ppp.chunk()
    print(vim.inspect(parsed))
end

return qamar
