local token = require 'qamar.tokenizer.types'
local s = require 'qamar.tokenizer.char_stream'

local MT = {
    __tostring = function(self)
        return self.value
    end,
}

local hex_start_parser = s.combinators.alt('0x', '0X')
local hex_digit_parser, hex_exponent_parser, decimal_exponent_parser =
    s.combinators.alt(s.NUMERIC, 'a', 'b', 'c', 'd', 'e', 'f', 'A', 'B', 'C', 'D', 'E', 'F'), s.combinators.alt('p', 'P'), s.combinators.alt('e', 'E')
local sign_parser = s.combinators.alt('-', '+')

return function(self)
    self:begin()
    self:skipws()
    self:suspend_skip_ws()
    local function fail()
        self:resume_skip_ws()
        self:undo()
    end
    local pos = self:pos()
    local val = hex_start_parser(self)
    local ret = {}
    local idx = 0
    local digitparser, exponentparser
    if val then
        idx = idx + 1
        ret[idx] = val:lower()
        digitparser, exponentparser = hex_digit_parser, hex_exponent_parser
    else
        digitparser, exponentparser = s.NUMERIC, decimal_exponent_parser
    end

    val = digitparser(self)
    if not val then
        return fail()
    end
    while val ~= nil do
        idx = idx + 1
        ret[idx] = val:lower()
        val = digitparser(self)
    end

    val = self:try_consume_string '.'
    if val then
        idx = idx + 1
        ret[idx] = val
        val = digitparser(self)
        if not val then
            return fail()
        end
        while val ~= nil do
            idx = idx + 1
            ret[idx] = val:lower()
            val = digitparser(self)
        end
    end

    val = exponentparser(self)
    if val then
        idx = idx + 1
        ret[idx] = val
        local sign = sign_parser(self)
        val = self:numeric()
        if sign and not val then
            return fail()
        end
        while val ~= nil do
            idx = idx + 1
            ret[idx] = val:lower()
            val = digitparser(self)
        end
    end

    self:resume_skip_ws()
    self:commit()
    return setmetatable({
        value = table.concat(ret),
        type = token.number,
        pos = {
            left = pos,
            right = self:pos(),
        },
    }, MT)
end
