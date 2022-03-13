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
    ppp = create_parser 'cedric.dingli.mamo:cedric'
    repeat
        parsed = ppp.funcname()
        print(vim.inspect(parsed))
        print '---------------------------------------------------------------------'
    until parsed == nil
end

return qamar
