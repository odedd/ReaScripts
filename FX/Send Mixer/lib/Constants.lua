-- @noindex

-- ! CONSTANTS
DB_SCALE = math.log(10.0) * 0.05

APP_PAGE = {
    ['MIXER'] = {width = 400, windowFlags = r.ImGui_WindowFlags_AlwaysAutoResize()},
    ['SEARCH_SEND'] = {width = 900, windowFlags = r.ImGui_WindowFlags_None()},
    ['SEACH_FX'] = {width = 900, windowFlags = r.ImGui_WindowFlags_None()}
}

ICONS = {
    ['BACK'] = 'B',
    ['GEAR'] = 'G',
    ['PLUS'] = 'P',
    ['STAR'] = 'S',
}

NUM_CHANNELS = 128
SRC_CHANNELS = {}
SRC_CHANNELS[-1] = {
    order = -1,
    numChannels = 0,
    group = "None",
    label = 'None'
}
for i = 0, NUM_CHANNELS - 1 do
    -- Stereo
    if i < NUM_CHANNELS - 1 then
        SRC_CHANNELS[i] = {
            order = i,
            numChannels = 2,
            group = "Stereo Source",
            label = (i + 1) .. '/' .. (i + 2)
        }
    end
    -- Mono
    SRC_CHANNELS[i + 1024] = {
        order = i + 1024,
        numChannels = 1,
        group = "Mono Source",
        label = tostring(i + 1)
    }
end
-- Multichannel
for numChannels = 4, NUM_CHANNELS, 2 do
    -- local numChannels = j * 2
    for i = 0, NUM_CHANNELS - numChannels do
        SRC_CHANNELS[numChannels * 512 + i] = {
            order = numChannels * 512 + i,
            numChannels = numChannels,
            group = numChannels .. " channels",
            label = (i + 1) .. '/' .. (i + numChannels)
        }
    end
end

PLUGIN = {
    INTERNAL = { 'Video Processor', 'Container' },
}
FAVORITE_GROUP = 'Favorite'
