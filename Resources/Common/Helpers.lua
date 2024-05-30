-- @noindex

local p = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]
dofile(p .. 'Helpers/Strings.lua')
dofile(p .. 'Helpers/Tables.lua')
dofile(p .. 'Helpers/Decibels.lua')
dofile(p .. 'Helpers/Math.lua')
dofile(p .. 'Helpers/Files.lua')
dofile(p .. 'Helpers/Colors.lua')
dofile(p .. 'Helpers/Bitwise.lua')
dofile(p .. 'Helpers/Log.lua')
dofile(p .. 'Helpers/Links.lua')
dofile(p .. 'Helpers/Keyboard.lua')
dofile(p .. 'Helpers/Versions.lua')
dofile(p .. 'Helpers/Screen.lua')