
PB_Tags = OD_Settings:new({
    default = {
        -- Defineable in GUI
        favorites = {},
        tagInfo ={
            [1]={name='EQ', color=0xff0044ff},
            [2]={name='Spectral', color=0xff00ffff}},
        taggedAssets = {
            ["1 /Library/Audio/Plug-Ins/VST3/FabFilter Pro-Q 4.vst3"] = {1,2},
            ["1 /Library/Audio/Plug-Ins/VST3/FabFilter Pro-Q 3.vst3"] = {1}
        }
    },
    dfsetfile = Scr.dir .. Scr.no_ext .. ' tags.ini'
})

function PB_Tags:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

-- * local
