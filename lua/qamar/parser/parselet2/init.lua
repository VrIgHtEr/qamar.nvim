local token, precedence = require 'qamar.tokenizer.types', require 'qamar.parser.precedence'

return {
    infix = {
        [token.kw_or] = { precedence = precedence.lor, parse = require 'qamar.parser.parselet2.infix' },
        [token.kw_and] = { precedence = precedence.land, parse = require 'qamar.parser.parselet2.infix' },
        [token.less] = { precedence = precedence.comparison, parse = require 'qamar.parser.parselet2.infix' },
        [token.greater] = { precedence = precedence.comparison, parse = require 'qamar.parser.parselet2.infix' },
        [token.lessequal] = { precedence = precedence.comparison, parse = require 'qamar.parser.parselet2.infix' },
        [token.greaterequal] = { precedence = precedence.comparison, parse = require 'qamar.parser.parselet2.infix' },
        [token.notequal] = { precedence = precedence.comparison, parse = require 'qamar.parser.parselet2.infix' },
        [token.equal] = { precedence = precedence.comparison, parse = require 'qamar.parser.parselet2.infix' },
        [token.pipe] = { precedence = precedence.bor, parse = require 'qamar.parser.parselet2.infix' },
        [token.tilde] = { precedence = precedence.bxor, parse = require 'qamar.parser.parselet2.infix' },
        [token.ampersand] = { precedence = precedence.band, parse = require 'qamar.parser.parselet2.infix' },
        [token.lshift] = { precedence = precedence.shift, parse = require 'qamar.parser.parselet2.infix' },
        [token.rshift] = { precedence = precedence.shift, parse = require 'qamar.parser.parselet2.infix' },
        [token.doubledot] = { precedence = precedence.concat, parse = require 'qamar.parser.parselet2.infix', right_associative = true },
        [token.plus] = { precedence = precedence.add, parse = require 'qamar.parser.parselet2.infix' },
        [token.dash] = { precedence = precedence.add, parse = require 'qamar.parser.parselet2.infix' },
        [token.asterisk] = { precedence = precedence.mul, parse = require 'qamar.parser.parselet2.infix' },
        [token.slash] = { precedence = precedence.mul, parse = require 'qamar.parser.parselet2.infix' },
        [token.doubleslash] = { precedence = precedence.mul, parse = require 'qamar.parser.parselet2.infix' },
        [token.percent] = { precedence = precedence.mul, parse = require 'qamar.parser.parselet2.infix' },
        [token.caret] = { precedence = precedence.exp, parse = require 'qamar.parser.parselet2.infix', right_associative = true },
        [token.lparen] = { precedence = precedence.atom, parse = require 'qamar.parser.parselet2.functioncall' },
        [token.lbrace] = { precedence = precedence.atom, parse = require 'qamar.parser.parselet2.functioncall' },
        [token.string] = { precedence = precedence.atom, parse = require 'qamar.parser.parselet2.functioncall' },
        [token.colon] = { precedence = precedence.atom, parse = require 'qamar.parser.parselet2.functioncall' },
        [token.lbracket] = { precedence = precedence.atom, parse = require 'qamar.parser.parselet2.rawaccess' },
        [token.dot] = { precedence = precedence.atom, parse = require 'qamar.parser.parselet2.nameaccess' },
    },
    prefix = {
        [token.kw_not] = { precedence = precedence.unary, parse = require 'qamar.parser.parselet2.prefix' },
        [token.hash] = { precedence = precedence.unary, parse = require 'qamar.parser.parselet2.prefix' },
        [token.dash] = { precedence = precedence.unary, parse = require 'qamar.parser.parselet2.prefix' },
        [token.tilde] = { precedence = precedence.unary, parse = require 'qamar.parser.parselet2.prefix' },
        [token.lparen] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet2.subexpression' },
        [token.name] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet2.atom' },
        [token.number] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet2.atom' },
        [token.kw_nil] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet2.atom' },
        [token.kw_false] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet2.atom' },
        [token.kw_true] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet2.atom' },
        [token.tripledot] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet2.atom' },
        [token.string] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet2.atom' },
        [token.kw_function] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet2.functiondef' },
        [token.lbrace] = { precedence = precedence.literal, parse = require 'qamar.parser.parselet2.tableconstructor' },
    },
}
