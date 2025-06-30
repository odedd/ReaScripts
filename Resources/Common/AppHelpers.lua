-- @noindex
local p = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]
dofile(p .. 'Helpers/App/App.lua')
dofile(p .. 'Helpers/App/Gui.lua')
dofile(p .. 'Helpers/App/Icons.lua')
dofile(p .. 'Helpers/App/Settings.lua')
