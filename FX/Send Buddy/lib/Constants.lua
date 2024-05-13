-- @noindex

-- ! CONSTANTS
DB_SCALE = math.log(10.0) * 0.05

APP_PAGE = {
    ['MIXER'] = {width = 500, minHeight = 407, windowFlags = r.ImGui_WindowFlags_None(), giveFocus = true},
    ['SEARCH_SEND'] = {width = 900, height = 409, minHeight = 409, windowFlags = r.ImGui_WindowFlags_None()},
    ['SEARCH_FX'] = {width = 900, height = 409, minHeight = 409, windowFlags = r.ImGui_WindowFlags_None()},
    ['NO_SENDS'] = {width = 500, height = 500*3/4, minHeight = 500*3/4, windowFlags = r.ImGui_WindowFlags_None(), giveFocus = true},
    ['NO_TRACK'] = {width = 500, height = 500*3/4, minHeight = 500*3/4, windowFlags = r.ImGui_WindowFlags_None(), giveFocus = true},
    ['CLOSE'] = 'close',
}

ICONS = {
    ['GEAR'] = 'G',
    ['HMMM'] = 'H',
    ['LEFT'] = 'L',
    ['POLARITY'] = 'O',
    ['PLUS'] = 'P',
    ['RIGHT'] = 'R',
    ['STAR'] = 'S',
    ['UNDO'] = 'U',
    ['CLOSE'] = 'X',
}

ASSETS = {
    ['TRACK'] = 0,
    ['PLUGIN'] = 1,
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
RECEIVES_GROUP = 'Existing receiving tracks'
TRACKS_GROUP = 'Existing tracks'
