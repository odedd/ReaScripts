-- @noindex

SM_Settings = OD_Settings:new({
    default = {
        -- remain_opened = false,
        mouseScrollReversed = true,
        minSendVol = -100,
        maxSendVol = 12,
        sendWidth = 60,
        maxNumInserts = 10,
        faderHeight = 240,
        followSelectedTrack = true,
        scaleFactor = 2,
        scaleLevel = -20,
        maxSearchResults = 20,
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
