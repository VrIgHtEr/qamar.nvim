return {
    config = function()
        table.insert(package.loaders, 2, require 'qamar.loader')

        --[[        nnoremap(
            '<leader>cr',
            ":mes clear<cr>:lua local to_unload = {} for k in pairs(package.loaded) do if k == 'qamar' or (#k >= 6 and k:sub(1, 6) == 'qamar.') then table.insert(to_unload, k) end end for _, k in ipairs(to_unload) do package.loaded[k] = nil end require'qamar'.run()<cr>",
            'silent',
            'test run qamar'
        )]]
    end,
}
