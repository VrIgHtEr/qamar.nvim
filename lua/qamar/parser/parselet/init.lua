local token, precedence = require 'qamar.tokenizer.types', require 'qamar.parser.precedence'

---@class parselet
---@field precedence number
---@field right_associative boolean
---@field parse function

return {
    infix = {
        [token.kw_or] = { precedence = precedence.lor, parse = require 'qamar.parser.parselet.infix' },
        [token.kw_and] = { precedence = precedence.land, parse = require 'qamar.parser.parselet.infix' },
        [token.less] = { precedence = precedence.comparison, parse = require 'qamar.parser.parselet.infix' },
        [token.greater] = { precedence = precedence.comparison, parse = require 'qamar.parser.parselet.infix' },
        [token.lessequal] = { precedence = precedence.comparison, parse = require 'qamar.parser.parselet.infix' },
        [token.greaterequal] = { precedence = precedence.comparison, parse = require 'qamar.parser.parselet.infix' },
        [token.notequal] = { precedence = precedence.comparison, parse = require 'qamar.parser.parselet.infix' },
        [token.equal] = { precedence = precedence.comparison, parse = require 'qamar.parser.parselet.infix' },
        [token.pipe] = { precedence = precedence.bor, parse = require 'qamar.parser.parselet.infix' },
        [token.tilde] = { precedence = precedence.bxor, parse = require 'qamar.parser.parselet.infix' },
        [token.ampersand] = { precedence = precedence.band, parse = require 'qamar.parser.parselet.infix' },
        [token.lshift] = { precedence = precedence.shift, parse = require 'qamar.parser.parselet.infix' },
        [token.rshift] = { precedence = precedence.shift, parse = require 'qamar.parser.parselet.infix' },
        [token.doubledot] = { precedence = precedence.concat, parse = require 'qamar.parser.parselet.infix', right_associative = true },
        [token.plus] = { precedence = precedence.add, parse = require 'qamar.parser.parselet.infix' },
        [token.dash] = { precedence = precedence.add, parse = require 'qamar.parser.parselet.infix' },
        [token.asterisk] = { precedence = precedence.mul, parse = require 'qamar.parser.parselet.infix' },
        [token.slash] = { precedence = precedence.mul, parse = require 'qamar.parser.parselet.infix' },
        [token.doubleslash] = { precedence = precedence.mul, parse = require 'qamar.parser.parselet.infix' },
        [token.percent] = { precedence = precedence.mul, parse = require 'qamar.parser.parselet.infix' },
        [token.caret] = { precedence = precedence.exp, parse = require 'qamar.parser.parselet.infix', right_associative = true },
        [token.lparen] = { precedence = precedence.atom, parse = require 'qamar.parser.parselet.functioncall' },
        [token.lbrace] = { precedence = precedence.atom, parse = require 'qamar.parser.parselet.functioncall' },
        [token.string] = { precedence = precedence.atom, parse = require 'qamar.parser.parselet.functioncall' },
        [token.colon] = { precedence = precedence.atom, parse = require 'qamar.parser.parselet.functioncall' },
        [token.lbracket] = { precedence = precedence.atom, parse = require 'qamar.parser.parselet.rawaccess' },
        [token.dot] = { precedence = precedence.atom, parse = require 'qamar.parser.parselet.nameaccess' },
    },
    prefix = {
        [token.kw_not] = { precedence = precedence.unary, parse = require 'qamar.parser.parselet.prefix' },
        [token.hash] = { precedence = precedence.unary, parse = require 'qamar.parser.parselet.prefix' },
        [token.dash] = { precedence = precedence.unary, parse = require 'qamar.parser.parselet.prefix' },
        [token.tilde] = { precedence = precedence.unary, parse = require 'qamar.parser.parselet.prefix' },
        [token.lparen] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet.subexpression' },
        [token.name] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet.atom' },
        [token.number] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet.atom' },
        [token.kw_nil] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet.atom' },
        [token.kw_false] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet.atom' },
        [token.kw_true] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet.atom' },
        [token.tripledot] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet.atom' },
        [token.string] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet.atom' },
        [token.kw_function] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet.functiondef' },
        [token.lbrace] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet.tableconstructor' },
    },
}
