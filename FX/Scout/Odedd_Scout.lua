-- @description Scout
-- @author Oded Davidov
-- @version 1.0.3
-- @donation https://paypal.me/odedda
-- @link Product Page https://www.random.tools/l/scout-plus
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
-- @changelog
--   Double firings of some magic words fixed
r = reaper
DATA = _VERSION == 'Lua 5.4' and 'scout54'
if DATA == nil then
    r.MB('Reaper v7.x+ required to use this script', 'Scout', 0)
else
    DATA_PATH = debug.getinfo(1, 'S').source:match '@(.+[/\\])' .. DATA ..'.dat'
    dofile(DATA_PATH)
end