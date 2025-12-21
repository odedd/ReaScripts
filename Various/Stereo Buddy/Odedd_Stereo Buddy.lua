-- @description Stereo Buddy
-- @author Oded Davidov
-- @version 1.0.6
-- @donation https://paypal.me/odedda
-- @link Product Page https://www.random.tools/l/stereo-buddy?utm_source=stereo-buddy&utm_medium=script&utm_campaign=reapack
-- @license GNU GPL v3
-- @about
--   # Stereo Buddy
--   A simple but powerful utility for analyzing the content of media items in Reaper.
--   It can detect silent items, stereophonic items containing monophonic signals, as well as those that are panned to the left or right.
--   It will then either delete or mute the silent items, and convert the fake-stereo items into monophonic ones, optionally panning them,
--   taking into account the pan law's effect on the item's level and compensating accordingly.
-- @provides
--   [nomain] Resources/Fonts/**
--   [nomain] stereobuddy54.dat
-- @changelog
--   More reliable activation server + window activation fix

r = reaper
DATA = _VERSION == 'Lua 5.4' and 'stereobuddy54'
if DATA == nil then
    r.MB('Reaper v7.x+ required to use this script', 'Scout', 0)
else
    DATA_PATH = debug.getinfo(1, 'S').source:match '@(.+[/\\])' .. DATA ..'.dat'
    dofile(DATA_PATH)
end