local types = require 'qamar.tokenizer.types'

return function(buffer)
    buffer.begin()
    buffer.skipws()
    local pos = buffer.pos()
    buffer.suspend_skip_ws()
    local ret = {}
    local t = buffer.alpha()
    if t == nil then
        buffer.undo()
        buffer.resume_skip_ws()
        return nil
    end
    while true do
        table.insert(ret, t)
        t = buffer.alphanumeric()
        if t == nil then
            break
        end
    end
    ret = table.concat(ret)
    buffer.commit()
    buffer.resume_skip_ws()
    return {
        value = ret,
        type = types.name,
        pos = {
            left = pos,
            right = buffer.pos(),
        },
    }
end
