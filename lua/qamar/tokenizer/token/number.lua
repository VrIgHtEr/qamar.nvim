local types = require 'qamar.tokenizer.types'

return function(buffer)
    buffer.begin()
    buffer.skipws()
    buffer.suspend_skip_ws()
    local function fail()
        buffer.resume_skip_ws()
        buffer.undo()
    end
    local pos = buffer.pos()
    local val = buffer.combinators.alt('0x', '0X')()
    local ret = {}
    local digitparser, exponentparser
    if val then
        table.insert(ret, val:lower())
        digitparser, exponentparser =
            buffer.combinators.alt(buffer.numeric, 'a', 'b', 'c', 'd', 'e', 'f', 'A', 'B', 'C', 'D', 'E', 'F'), buffer.combinators.alt('p', 'P')
    else
        digitparser, exponentparser = buffer.numeric, buffer.combinators.alt('e', 'E')
    end

    val = digitparser()
    if not val then
        return fail()
    end
    while val ~= nil do
        table.insert(ret, val:lower())
        val = digitparser()
    end

    val = buffer.try_consume_string '.'
    if val then
        table.insert(ret, val)
        val = digitparser()
        if not val then
            return fail()
        end
        while val ~= nil do
            table.insert(ret, val:lower())
            val = digitparser()
        end
    end

    val = exponentparser()
    if val then
        table.insert(ret, val)
        local sign = buffer.combinators.alt('-', '+')()
        val = buffer.numeric()
        if sign and not val then
            return fail()
        end
        while val ~= nil do
            table.insert(ret, val:lower())
            val = digitparser()
        end
    end

    buffer.resume_skip_ws()
    buffer.commit()
    return {
        value = table.concat(ret),
        type = types.number,
        pos = {
            left = pos,
            right = buffer.pos(),
        },
    }
end
