local token = require 'qamar.tokenizer.types'

local keywords = require 'qamar.tokenizer.token.keywords'

local MT = {
    __tostring = function(self)
        return self.value
    end,
}
return function(stream)
    stream.begin()
    stream.skipws()
    local pos = stream.pos()
    local ret = stream.combinators.alt(unpack(keywords))()
    if ret then
        stream.begin()
        stream.suspend_skip_ws()
        local next = stream.alphanumeric()
        stream.resume_skip_ws()
        stream.undo()
        if not next then
            stream.commit()
            stream.resume_skip_ws()
            return setmetatable({
                value = ret,
                type = token['kw_' .. ret],
                pos = {
                    left = pos,
                    right = stream.pos(),
                },
            }, MT)
        end
    end
    stream.undo()
end
