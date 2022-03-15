local token = require 'qamar.tokenizer.types'

local MT = {__tostring = function(self)return self.value end}
return function(stream)
    stream.begin()
    stream.skipws()
    stream.suspend_skip_ws()
    local function fail()
        stream.resume_skip_ws()
        stream.undo()
    end
    local pos = stream.pos()
    local val = stream.combinators.alt('0x', '0X')()
    local ret = {}
    local digitparser, exponentparser
    if val then
        table.insert(ret, val:lower())
        digitparser, exponentparser =
            stream.combinators.alt(stream.numeric, 'a', 'b', 'c', 'd', 'e', 'f', 'A', 'B', 'C', 'D', 'E', 'F'), stream.combinators.alt('p', 'P')
    else
        digitparser, exponentparser = stream.numeric, stream.combinators.alt('e', 'E')
    end

    val = digitparser()
    if not val then
        return fail()
    end
    while val ~= nil do
        table.insert(ret, val:lower())
        val = digitparser()
    end

    val = stream.try_consume_string '.'
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
        local sign = stream.combinators.alt('-', '+')()
        val = stream.numeric()
        if sign and not val then
            return fail()
        end
        while val ~= nil do
            table.insert(ret, val:lower())
            val = digitparser()
        end
    end

    stream.resume_skip_ws()
    stream.commit()
    return setmetatable({
        value = table.concat(ret),
        type = token.number,
        pos = {
            left = pos,
            right = stream.pos(),
        },
    },MT)
end
