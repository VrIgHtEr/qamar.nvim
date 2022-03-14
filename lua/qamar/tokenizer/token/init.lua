local tokenizers = {
    require 'qamar.tokenizer.token.comment',
    require 'qamar.tokenizer.token.symbol',
    require 'qamar.tokenizer.token.keyword',
    require 'qamar.tokenizer.token.number',
    require 'qamar.tokenizer.token.name',
    require 'qamar.tokenizer.token.string',
}
local token = require 'qamar.tokenizer.types'

local tokens_to_skip = {
    [token.whitespace] = true,
    [token.comment] = true,
}

return function(stream)
    ::restart::
    if stream.peek() then
        for _, x in ipairs(tokenizers) do
            local ret = x(stream)
            if ret then
                if tokens_to_skip[ret.type] then
                    goto restart
                end
                return ret
            end
        end
        stream.skipws()
        if stream.peek() then
            error('invalid token on line ' .. stream.pos().row .. ', col ' .. stream.pos().col)
        end
    end
end
