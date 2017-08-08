-- example of how to load the vim-bindings file into your hammerspoon init

-- put vim_bindings.lua in your ~/.hammerspoon/ directory
Vim = require('vim_bindings')

local v = Vim:new()
-- v:setDebug(true) -- uncomment this if you want some things printed to the hammerspoon console
v:start()

