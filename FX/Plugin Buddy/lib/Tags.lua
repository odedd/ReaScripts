
PB_Tags = OD_Settings:new({
    default = {
        -- Defineable in GUI
        favorites = {},
        tagInfo ={
            [1]={name='EQ', color=0x32a852ff, synonyms={'Equaliser'}, order = 1},
            [2]={name='Compressor', color=0x8a3cbaff, parentId=4, order = 2},
            [3]={name='Spectral Processor', color=0xb94bbdff, synonyms={'Resonance Surpressor'}, parentId=1, order = 1},
            [4]={name='Dynamics', color=0x3255a8ff, order = 2},
            [5]={name='Gate', color=0x65248cff, parentId=4, order = 1},
            [6]={name='Instruments', color=0xf5e042ff, order = 3},
            [7]={name='Multiband', color=0xe6bc9aff, parentId=2, order = 1}},
        taggedAssets = {
            ["1 /Library/Audio/Plug-Ins/VST3/FabFilter Pro-Q 4.vst3"] = {7,3},
            ["1 /Library/Audio/Plug-Ins/VST3/FabFilter Pro-Q 3.vst3"] = {1},
            ["1 /Library/Audio/Plug-Ins/VST3/FabFilter Pro-C 2.vst3"] = {2},
            ["1 /Library/Audio/Plug-Ins/VST3/FabFilter Pro-G.vst3"] = {5}
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
