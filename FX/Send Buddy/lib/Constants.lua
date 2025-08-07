-- @noindex
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
ImGui = require 'imgui' '0.9.1'

-- ! CONSTANTS
DB_SCALE = math.log(10.0) * 0.05
FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()

SEND_TYPE = {
    ['SEND'] = 0,
    ['RECV'] = -1,
    ['HW'] = 1,
}

VOL_TYPE = {
    ['TRIM'] = 0,
    ['UI'] = 1,
}

APP_PAGE = {
    ['MIXER'] = {width = 609, minHeight = 409, windowFlags = ImGui.WindowFlags_None, giveFocus = true},
    ['SEARCH_SEND'] = {width = 900, height = 409, minHeight = 409, windowFlags = ImGui.WindowFlags_None},
    ['SEARCH_FX'] = {width = 900, height = 409, minHeight = 409, windowFlags = ImGui.WindowFlags_None},
    ['NO_TRACK'] = {width = 409, height = 409*3/4, minHeight = 409*3/4, windowFlags = ImGui.WindowFlags_None, giveFocus = true},
    ['CLOSE'] = 'close',
}

ASSETS = {
    ['TRACK'] = 0,
    ['PLUGIN'] = 1,
    ['FX_CHAIN'] = 2,
    ['TRACK_TEMPLATE'] = 3,
}

NUM_CHANNELS = 128
SRC_CHANNELS = {}
SRC_CHANNELS[-1] = {
    order = -1,
    numChannels = 0,
    group = "None",
    label = 'None'
}

MINIMIZATION_STYLE = {
    ['PT'] = 0,
    ['TRIM'] = 1,
}

SOLO_STATES = {
    ['NONE'] = 0,
    ['SOLO'] = 2,
    ['SOLO_DEFEAT'] = 3,
}

SEND_MODE = {
    [0] = 'post',
    [1] = 'preFX',
    [3] = 'postFX'
}

AUTO_MODE = {
    ['TRACK'] = -1,
    ['TRIM_READ'] = 0,
    ['READ'] = 1,
    ['TOUCH'] = 2,
    ['LATCH'] = 4,
    ['LATCH_PREVIEW'] = 5,
    ['WRITE'] = 3,

}

SEND_LISTEN_MODES = {
    ['NONE'] = -1,
    ['NORMAL'] = 0,
    ['RETURN_ONLY'] = 1
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

OUTPUT_CHANNEL_NAMES = {}
-- output channel names
for i = 0, NUM_CHANNELS - 1 do
    table.insert(OUTPUT_CHANNEL_NAMES, r.GetOutputChannelName(i) or ('Output '..(i+1)))
end

PLUGIN = {
    INTERNAL = { 'Video Processor', 'Container' },
}
FAVORITE_GROUP = 'Favorite'
RECEIVES_GROUP = 'Tracks with receives'
TRACKS_GROUP = 'Other tracks'
TRACK_TEMPLATES_GROUP = 'Track Templates'
FX_CHAINS_GROUP = 'FX Chains'
ALL_TRACKS_GROUP = 'All tracks'