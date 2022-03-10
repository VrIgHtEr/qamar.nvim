local types = require 'qamar.token.types'

local keywords = {}
for x in pairs(require 'qamar.token.keyword_list') do
    table.insert(keywords, x)
end

return function(buffer)
    buffer.begin()
    buffer.skipws()
    local pos = buffer.pos()
    local ret = buffer.combinators.alt(unpack(keywords))()
    if ret then
        buffer.begin()
        buffer.suspend_skip_ws()
        local next = buffer.alphanumeric()
        buffer.resume_skip_ws()
        buffer.undo()
        if not next then
            buffer.commit()
            buffer.resume_skip_ws()
            return {
                value = ret,
                type = types['kw_' .. ret],
                pos = {
                    left = pos,
                    right = buffer.pos(),
                },
            }
        end
    end
    buffer.undo()
end
