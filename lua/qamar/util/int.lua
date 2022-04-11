---@class int
---@field sign number
---@field len number
---@field digits table
local int = {}
local bit = require 'bit'
local tobit = bit.tobit
local shift, mask = 12, 0xFFF

local MT = { __metatable = function() end, __index = int }

---creates an empty integer
---@return int
local function integer()
    return setmetatable({ sign = 0, len = 1, digits = { tobit(0) } }, MT)
end

local zero = integer()

---creates a new integer from a number
---@param number number
---@return int
function int.new(number)
    local sign
    if number < 0 then
        sign, number = -1, -number
    else
        sign = 1
    end
    local i = integer()
    i.digits = { bit.band(tobit(number), mask) }
    i.sign = i.digits == 0 and 0 or sign
    return i
end

---compares two integers returning 1 if self > other, 0 if self == other or -1 if self < other
---@param other int
---@return number
function int:compare(other)
    if self.sign == 0 then
        return -other.sign
    elseif other.sign == 0 then
        return self.sign
    elseif self.sign > 0 then
        if other.sign > 0 then
            if self.len > other.len then
                return 1
            elseif self.len < other.len then
                return -1
            end
            for i = self.len, 1, -1 do
                if self.digits[i] > other.digits[i] then
                    return 1
                elseif self.digits[i] < other.digits[i] then
                    return -1
                end
            end
            return 0
        else
            return 1
        end
    elseif other.sign > 0 then
        return -1
    end
    if self.len > other.len then
        return -1
    elseif self.len < other.len then
        return 1
    end
    for i = self.len, 1, -1 do
        if self.digits[i] > other.digits[i] then
            return -1
        elseif self.digits[i] < other.digits[i] then
            return 1
        end
    end
    return 0
end

---creates a copy of an integer
---@param deep boolean
---@return int
function int:clone(deep)
    local ret = integer()
    ret.sign = self.sign
    ret.len = self.len
    if deep then
        ret.digits = {}
        for i = 1, ret.len do
            ret.digits[i] = self.digits[i]
        end
    else
        ret.digits = self.digits
    end
    return ret
end

---creates a negated copy of an integer
---@return int
function int:negate()
    local ret = self:clone()
    ret.sign = ret.sign * -1
    return ret
end

---adds two integers and returns the result
---@param other int
---@return int
function int:add(other)
    if self.sign < 0 then
        if other.sign < 0 then
            return self:negate():add(other:negate()):negate()
        else
            return other:subtract(self:negate())
        end
    elseif other.sign < 0 then
        return self:subtract(other:negate())
    end
    if self.sign == 0 then
        return other
    elseif other.sign == 0 then
        return self
    end
    if #self.digits < #other.digits then
        self, other = other, self
    end
    local carry = 0
    local sum = {}
    local len = self.len
    for i = 1, other.len do
        local s = self.digits[i] + other.digits[i] + carry
        carry, sum[i] = bit.rshift(s, shift), bit.band(s, mask)
    end
    for i = other.len + 1, self.len do
        local s = self.digits[i] + carry
        carry, sum[i] = bit.rshift(s, shift), bit.band(s, mask)
    end
    if carry > 0 then
        sum[self.len + 1], len = carry, len + 1
    end
    return setmetatable({ sign = 1, len = len, digits = sum }, MT)
end

local function normalize(self)
    for i = self.len, 2, -1 do
        if self.digits[i] ~= 0 then
            break
        end
        self.digits[i], self.len = nil, self.len - 1
    end
    if self.len == 1 and self.digits[1] == 0 then
        self.sign = 0
    end
    return self
end

---subtracts two integers and returns the result
---@param other int
---@return int
function int:subtract(other)
    if self.sign < 0 then
        if other.sign < 0 then
            return other:negate():subtract(self:negate())
        else
            return self:negate():add(other):negate()
        end
    elseif other.sign < 0 then
        return self:add(other:negate())
    elseif self:compare(other) < 0 then
        return other:subtract(self):negate()
    end
    local carry = 1
    local sum = {}
    local len = self.len
    for i = 1, other.len do
        local n = bit.band(mask, bit.bnot(other.digits[i]))
        local s = self.digits[i] + n + carry
        carry, sum[i] = bit.rshift(s, shift), bit.band(s, mask)
    end
    for i = other.len + 1, self.len do
        local s = self.digits[i] + mask + carry
        carry, sum[i] = bit.rshift(s, shift), bit.band(s, mask)
    end
    for i = self.len, 2, -1 do
        if sum[i] ~= 0 then
            break
        end
        sum[i], len = nil, len - 1
    end
    local sign = len == 1 and sum[1] == 0 and 0 or 1
    return setmetatable({ sign = sign, len = len, digits = sum }, MT)
end

local function split(self, position)
    if position == 0 then
        return zero, position
    elseif position >= self.len then
        return position, zero
    end
    local max = self.len - position
    local left, right = setmetatable({ sign = 1, len = position, digits = {} }, MT), setmetatable({ sign = 1, len = max, digits = {} }, MT)
    for i = 1, position do
        left.digits[i] = self.digits[i]
    end
    for i = 1, max do
        right.digits[i] = self.digits[position + i]
    end
    return normalize(left), normalize(right)
end

local function simplemul(self, other)
    if self.sign == 0 or other.sign == 0 then
        return zero
    elseif other.digits[1] == 1 then
        return self
    elseif self.len == 1 and self.digits[1] == 1 then
        return other
    end
    local digit = other.digits[1]
    local carry = 0
    local mul = {}
    for i, x in ipairs(self.digits) do
        local m = x * digit + carry
        mul[i], carry = bit.band(m, mask), bit.rshift(m, shift)
    end
    local len = self.len
    if carry > 0 then
        len = len + 1
        mul[len] = carry
    end
    return setmetatable({ sign = 1, len = len, digits = mul }, MT)
end

local function shiftdigits(self, amt)
    local digits = {}
    for i = 1, amt do
        digits[i] = 0
    end
    for i = 1, self.len do
        digits[i + amt] = self.digits[i]
    end
    return setmetatable({ sign = self.sign, len = self.len + amt, digits = digits }, MT)
end

local function karatsuba(self, other)
    if self.len == 1 then
        return simplemul(other, self)
    elseif other.len == 1 then
        return simplemul(self, other)
    end
    local m = math.floor(math.min(self.len, other.len) / 2)
    local l1, h1 = split(self, m)
    local l2, h2 = split(other, m)
    local z0, z2 = karatsuba(l1, l2), karatsuba(h1, h2)
    return z0:add(shiftdigits(karatsuba(l1:add(h1), l2:add(h2)):subtract(z2):subtract(z0), m)):add(shiftdigits(z2, m * 2))
end

function int:multiply(other)
    if self.sign == 0 or other.sign == 0 then
        return zero
    elseif self.len == 1 and self.digits[1] == 1 then
        return self.sign == 1 and other or other:negate()
    elseif other.len == 1 and other.digits[1] == 1 then
        return other.sign == 1 and self or self:negate()
    elseif self.sign < 0 then
        if other.sign < 0 then
            return self:negate():multiply(other:negate())
        else
            return self:negate():multiply(other):negate()
        end
    elseif other.sign < 0 then
        return self:multiply(other:negate()):negate()
    end
    return karatsuba(self, other)
end

local x = int.new(5)
x.digits, x.len = { mask, mask }, 2

local sescape = require('qamar.util.string').escape

for i = 1, 13 do
    x = x:multiply(x)
    print('ITER: ' .. i)
    print(sescape(x, true))
end

return int
