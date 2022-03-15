local qamar = {}
local codepoints = require('toolshed.util.string').codepoints
local parser = require 'qamar.parser'
local tokenizer = require 'qamar.tokenizer'
local char_stream = require 'qamar.tokenizer.char_stream'

local function create_parser(str)
    return parser(tokenizer(char_stream(codepoints(str))))
end

function qamar.run()
    local txt = require('toolshed.util').read_file(vim.fn.stdpath 'data' .. '/site/pack/vrighter/opt/qamar.nvim/lua/qamar/parser/init.lua')
    local p = create_parser(txt)
    local tree = p.chunk()
    local roundtripstr = tostring(tree)
    print(roundtripstr)
    require('toolshed.util').write_file(vim.fn.stdpath 'data' .. '/site/pack/vrighter/opt/qamar.nvim/test.lua', roundtripstr)
end

return qamar
