-- @noindex

local p = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]
dofile(p .. 'Helpers/Strings.lua')
dofile(p .. 'Helpers/Tables.lua')
dofile(p .. 'Helpers/Math.lua')
dofile(p .. 'Helpers/Files.lua')
dofile(p .. 'Helpers/Colors.lua')