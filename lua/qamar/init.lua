local qamar = {}

function qamar.run()
    local ppp = require 'qamar.parser'(
        require 'qamar.tokenizer'(require 'qamar.tokenizer.char_stream'(require('toolshed.util.string').codepoints 'a+-b*-3^((4 or 7)+6)^7+4+(7+5)'))
    )
    local parsed = ppp.expression()
    print(parsed)
    print '---------------------------------------------------------------------'
    ppp = require 'qamar.parser'(
        require 'qamar.tokenizer'(require 'qamar.tokenizer.char_stream'(require('toolshed.util.string').codepoints 'cedric.dingli.mamo:bla'))
    )
    repeat
        parsed = ppp.funcname()
        print(vim.inspect(parsed))
        print '---------------------------------------------------------------------'
    until parsed == nil
end

return qamar
