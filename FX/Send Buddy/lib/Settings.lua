-- @noindex

SM_Settings = OD_Settings:new({
    default = {
-- User settings
        mouseScrollReversed = true,
        minSendVol = -100,
        maxSendVol = 12, -- TODO: Match with Reaper's max send volume?
        maxNumInserts = 4,
        followSelectedTrack = true,
        lastDockId = nil,
        
        -- Permanent settings
        sendWidth = 60,
        minFaderHeight = 100,
        scaleFactor = 2, -- fader scale factor above scaleLevel
        scaleLevel = -20,
        favorites = {
            'VST3: Pro-Q 3 (FabFilter)',
            'VST3: ValhallaVintageVerb (Valhalla DSP, LLC)'
        },
        groupPriority = {
            ["VST3"] = 1,
            ["VST3i"] = 2,
            ["VST"] = 3,
            ["VSTi"] = 4,
            ["AU"] = 5,
            ["AUi"] = 6,
            ["JS"] = 7,
            ["CLAP"] = 8,
            ["CLAPi"] = 9,
            ["LV2"] = 10,
            ["LV2i"] = 11
        }
    },
    dfsetfile = Scr.dfsetfile
})

function SM_Settings:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end


-- * local
