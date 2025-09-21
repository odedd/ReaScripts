-- @description Scout
-- @author Oded Davidov
-- @version 1.1.7
-- @donation https://paypal.me/odedda
-- @link Product Page https://www.random.tools/l/scout-plus?utm_source=scout&utm_medium=script&utm_campaign=reapack
-- @license GNU GPL v3
-- @about
--   # Scout
--   A powerful search and organization tool for Reaper assets, providing a unified interface to quickly find, tag, rate, add notes, 
--   hide, and favorite items. 
--
--   Scout prioritizes speed and efficiency, helping you manage: FX, Actions, Projects, Project Templates, Track Templates, 
--   FX Chains, Tracks, Takes, Markers, Regions, Take Markers and QuickChain Presets - all without leaving the keyboard.
--
--   While Scout is full of features, Scout+ has even more! Be sure to check them out at https://odedd.gumroad.com/l/scout-plus.
-- @provides
--   [nomain] Resources/Fonts/**
--   [nomain] scout54.dat
--   [main] Odedd_Scout - Start in sleep mode.lua
-- @changelog
--   New setting - Clear search text when changing between Item and Filter search modes
--   New setting - Include group name in search
--   Ability to combine presets (secret option - to enable toggle 'allowCombinePresets' in the Odedd_Scout.ini file to true when scout is not running (NOT in sleep mode)) 
--   QuickTag window - allow selection with numpad enter 
--   Close QuickChain panel on wakeup if "reset filters on wakeup" is checked 
--   Ability to unhide hidden tags even if their parents are hidden (unless all tags are hidden by the "hide all tags" button)
--   New tag list context item - "Move to..."
r = reaper
DATA = _VERSION == 'Lua 5.4' and 'scout54'
if DATA == nil then
    r.MB('Reaper v7.x+ required to use this script', 'Scout', 0)
else
    DATA_PATH = debug.getinfo(1, 'S').source:match '@(.+[/\\])' .. DATA ..'.dat'
    dofile(DATA_PATH)
end