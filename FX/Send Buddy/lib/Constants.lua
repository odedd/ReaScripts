-- @noindex
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
ImGui = require 'imgui' '0.9.1'

-- ! CONSTANTS
DB_SCALE = math.log(10.0) * 0.05

SEND_TYPE = {
    ['SEND'] = 0,
    ['RECV'] = -1,
    ['HW'] = 1,
}

SEND_TYPE_NAMES = {
    [SEND_TYPE.SEND] = 'SENDS',
    [SEND_TYPE.RECV] = 'RECEIVES',
    [SEND_TYPE.HW] = 'HARDWARE'

}
APP_PAGE = {
    ['MIXER'] = {width = 409, minHeight = 409, windowFlags = ImGui.WindowFlags_None, giveFocus = true},
    ['SEARCH_SEND'] = {width = 900, height = 409, minHeight = 409, windowFlags = ImGui.WindowFlags_None},
    ['SEARCH_FX'] = {width = 900, height = 409, minHeight = 409, windowFlags = ImGui.WindowFlags_None},
    ['NO_SENDS'] = {width = 409, height = 409*3/4, minHeight = 409*3/4, windowFlags = ImGui.WindowFlags_None, giveFocus = true},
    ['NO_TRACK'] = {width = 409, height = 409*3/4, minHeight = 409*3/4, windowFlags = ImGui.WindowFlags_None, giveFocus = true},
    ['CLOSE'] = 'close',
}

ICONS = {
    ['DOCK_DOWN'] = 'D',
    ['UNDOCK'] = 'E',
    ['GEAR'] = 'G',
    ['HEADPHONES'] = 'H',
    ['LEFT'] = 'L',
    ['POLARITY'] = 'O',
    ['PLUS'] = 'P',
    ['RIGHT'] = 'R',
    ['STAR'] = 'S',
    ['TRASH'] = 'T',
    ['UNDO'] = 'U',
    ['ENVELOPE'] = 'V',
    ['ARROW_RIGHT'] = 'W',
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

SOLO_STATES = {
    ['NONE'] = 0,
    ['SOLO'] = 2,
    ['SOLO_DEFEAT'] = 3,
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
    -- Mono
    table.insert(OUTPUT_CHANNEL_NAMES, r.GetOutputChannelName(i) or ('Output '..(i+1)))
end

PLUGIN = {
    INTERNAL = { 'Video Processor', 'Container' },
}
FAVORITE_GROUP = 'Favorite'
RECEIVES_GROUP = 'Tracks with receives'
TRACKS_GROUP = 'Other tracks'