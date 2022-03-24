local tokenizers = {
    require 'qamar.tokenizer.token.comment',
    require 'qamar.tokenizer.token.name',
    require 'qamar.tokenizer.token.keyword',
    require 'qamar.tokenizer.token.number',
    require 'qamar.tokenizer.token.string',
    require 'qamar.tokenizer.token.symbol',
}
local token = require 'qamar.tokenizer.types'

return function(self)
    ::restart::
    if self:peek() then
        for _, x in ipairs(tokenizers) do
            local ret = x(self)
            if ret then
                if ret.type == token.comment then
                    goto restart
                end
                return ret
            end
        end
        self:skipws()
        if self:peek() then
            local preview = {}
            self:begin()
            for i = 1, 30 do
                local t = self:take()
                if not t then
                    break
                end
                preview[i] = t
            end
            self:undo()
            error('invalid token on line ' .. self:pos().row .. ', col ' .. self:pos().col .. ' ' .. vim.inspect(table.concat(preview)))
        end
    end
end
