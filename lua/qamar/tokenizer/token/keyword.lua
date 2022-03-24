local token = require 'qamar.tokenizer.types'

local keywords = require 'qamar.tokenizer.token.keywords'

local MT = {
    __tostring = function(self)
        return self.value
    end,
}

local parser = require('qamar.tokenizer.char_stream').combinators.alt(unpack(keywords))

return function(self)
    self:begin()
    self:skipws()
    local pos = self:pos()
    local ret = parser(self)
    if ret then
        self:begin()
        self:suspend_skip_ws()
        local next = self:alphanumeric()
        self:resume_skip_ws()
        self:undo()
        if not next then
            self:commit()
            self:resume_skip_ws()
            return setmetatable({
                value = ret,
                type = token['kw_' .. ret],
                pos = {
                    left = pos,
                    right = self:pos(),
                },
            }, MT)
        end
    end
    self:undo()
end
