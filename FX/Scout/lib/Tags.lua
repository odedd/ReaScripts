-- @noindex
PB_Tags = OD_Settings:new({
    default = {
        -- Defineable in GUI
        favorites = {},
        tagInfo = {},
        taggedAssets = {}
    },
    initial = {
        tagInfo = {
            [1] = { name = 'EQ', synonyms = { 'Equaliser' }, order = 1, parentId = TAGS_ROOT_PARENT },
            [2] = { name = 'Compressor', parentId = 4, order = 2 },
            [3] = { name = 'Spectral Processor', synonyms = { 'Resonance Surpressor' }, parentId = 1, order = 1 },
            [4] = { name = 'Dynamics', order = 2, parentId = TAGS_ROOT_PARENT },
            [5] = { name = 'Gate', parentId = 4, order = 1 },
            [6] = { name = 'Instruments', order = 3, parentId = TAGS_ROOT_PARENT },
            [7] = { name = 'Multiband', parentId = 2, order = 1 }
        },
        taggedAssets = {
            ["1 /Library/Audio/Plug-Ins/VST3/FabFilter Pro-Q 4.vst3"] = { 7, 3 },
            ["1 /Library/Audio/Plug-Ins/VST3/FabFilter Pro-Q 3.vst3"] = { 1 },
            ["1 /Library/Audio/Plug-Ins/VST3/FabFilter Pro-C 2.vst3"] = { 2 },
            ["1 /Library/Audio/Plug-Ins/VST3/FabFilter Pro-G.vst3"] = { 5 }
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
