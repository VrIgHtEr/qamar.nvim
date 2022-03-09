local ret = {}
for i, name in ipairs(require 'qamar.token.token_names') do
    ret[name] = i
end
return ret
