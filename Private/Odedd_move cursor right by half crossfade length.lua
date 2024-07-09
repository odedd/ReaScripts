-- @noindex
-- @description Move cursor left by half crossfade length
local _, crossfadeLength = reaper.get_config_var_string("defsplitxfadelen")
crossfadeLength = tonumber(crossfadeLength)
local curpos = reaper.GetCursorPosition()
reaper.SetEditCurPos( curpos + crossfadeLength/2, false, false )