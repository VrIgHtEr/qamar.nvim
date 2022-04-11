---@class node_table_constructor:node
---@field value node

local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local N = require 'qamar.parser.node_expression'
local range = require 'qamar.util.range'

local setmetatable = setmetatable
local trbrace = token.rbrace
local ntableconstructor = node.tableconstructor
local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local pfieldlist
pfieldlist = function(self)
    pfieldlist = require('qamar.parser.production.fieldlist').parser
    return pfieldlist(self)
end

local MT = {
    ---@param self node_table_constructor
    ---@return string
    __tostring = function(self)
        return tconcat { '{', self.value, '}' }
    end,
}

---parselet that consumes a table constructor
---@param self parselet
---@param parser parser
---@param tok token
---@return node_table_constructor|nil
return function(self, parser, tok)
    local fieldlist = pfieldlist(parser) or setmetatable({}, {
        __tostring = function()
            return ''
        end,
    })
    if peek(parser) then
        local rbrace = take(parser)
        if rbrace.type == trbrace then
            local ret = N(ntableconstructor, range(tok.pos.left, rbrace.pos.right), self.precedence, self.right_associative, MT)
            ret.value = fieldlist
            return ret
        end
    end
end
