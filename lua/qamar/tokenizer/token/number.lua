local token = require 'qamar.tokenizer.types'
local s = require 'qamar.tokenizer.char_stream'

local MT = {
    __tostring = function(self)
        return self.value
    end,
}

local function hex_start_parser(self)
    return self:try_consume_string '0x' or self:try_consume_string '0X'
end

local function hex_digit_parser(self)
    local tok = self:peek()
    if tok then
        local b = tok:byte()
        if b >= 48 and b <= 57 or b >= 97 and b <= 102 or b >= 65 and b <= 70 then
            return self:take()
        end
    end
end

local function hex_exponent_parser(self)
    local tok = self:peek()
    if tok and (tok == 'p' or tok == 'P') then
        return self:take()
    end
end

local function decimal_exponent_parser(self)
    local tok = self:peek()
    if tok and (tok == 'e' or tok == 'E') then
        return self:take()
    end
end

local function sign_parser(self)
    local tok = self:peek()
    if tok and (tok == '-' or tok == '+') then
        return self:take()
    end
end

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
