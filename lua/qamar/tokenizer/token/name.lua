local token = require 'qamar.tokenizer.types'

return function(stream)
    stream.begin()
    stream.skipws()
    local pos = stream.pos()
    stream.suspend_skip_ws()
    local ret = {}
    local t = stream.alpha()
    if t == nil then
        stream.undo()
        stream.resume_skip_ws()
        return nil
    end
    while true do
        table.insert(ret, t)
        t = stream.alphanumeric()
        if t == nil then
            break
        end
    end
    ret = table.concat(ret)
    stream.commit()
    stream.resume_skip_ws()
    return {
        value = ret,
        type = token.name,
        pos = {
            left = pos,
            right = stream.pos(),
        },
    }
end
