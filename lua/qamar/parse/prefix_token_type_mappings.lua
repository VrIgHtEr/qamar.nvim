local token_types = require 'qamar.token.types'
local nodetypes = require 'qamar.parse.types'
return {
    [token_types.name] = nodetypes.name,
    [token_types.number] = nodetypes.number,
    [token_types.kw_not] = nodetypes.lnot,
    [token_types.len] = nodetypes.len,
    [token_types.sub] = nodetypes.neg,
    [token_types.bitnot] = nodetypes.bnot,
}
