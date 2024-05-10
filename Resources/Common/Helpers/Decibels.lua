-- @noindex

-- Code by X-Raym
-- https://github.com/ReaTeam/ReaScripts-Templates/blob/master/Values/X-Raym_Val%20to%20dB%20-%20dB%20to%20Val.lua

function OD_dBFromValue(val) return 20*math.log(val, 10) end
function OD_ValFromdB(dB_val) return 10^(dB_val/20) end