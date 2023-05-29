-- @description Stem Manager
-- @author Oded Davidov
-- @version 1.5
-- @donation: https://paypal.me/odedda
-- @license GNU GPL v3
-- @provides
--   [nomain]../../Resources/Fonts/Cousine-90deg.otf
--   [nomain]../../Resources/Fonts/Cousine-Regular.ttf
--   [nomain]../../Resources/Common/*
-- @about
--   # Stem Manager
--   Advanced stem rendering automator.
--   Stem Manager was designed with the goal of simplifying the process of stem creation with REAPER.
--   While REAPER's flexibility is unmatched, it is still quite cumbersome to create and render sets of tracks independently of signal flow, with emphasis on easy cross-project portability (do it once, then use it everywhere!).
--
--   This is where Stem Manager comes in.
-- @changelog
--   Added presets

local r = reaper
local p = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]
dofile(p .. '../../Resources/Common/Common.lua')

r.ClearConsole()

local scr, os_is = OD_Init()

local STATES = {
    SOLO_IN_PLACE = 'SIP',
    SOLO_IGNORE_ROUTING = 'SIR',
    MUTE = 'M',
    MUTE_SOLO_IN_PLACE = 'MSIP',
    MUTE_SOLO_IGNORE_ROUTING = 'MSIR'
}

local STATE_COLORS = {
    [STATES.SOLO_IN_PLACE] = {STATES.SOLO_IN_PLACE, STATES.SOLO_IN_PLACE},
    [STATES.SOLO_IGNORE_ROUTING] = {STATES.SOLO_IGNORE_ROUTING, STATES.SOLO_IGNORE_ROUTING},
    [STATES.MUTE] = {STATES.MUTE, STATES.MUTE},
    [STATES.MUTE_SOLO_IN_PLACE] = {STATES.MUTE, STATES.SOLO_IN_PLACE},
    [STATES.MUTE_SOLO_IGNORE_ROUTING] = {STATES.MUTE, STATES.SOLO_IGNORE_ROUTING},
    [' '] = {' ', ' '}
}

local STATE_LABELS = {
    [STATES.SOLO_IN_PLACE] = 'S',
    [STATES.SOLO_IGNORE_ROUTING] = 'S',
    [STATES.MUTE] = 'M',
    [STATES.MUTE_SOLO_IN_PLACE] = 'MS',
    [STATES.MUTE_SOLO_IGNORE_ROUTING] = 'MS'
}

local STATE_DESCRIPTIONS = {
    [STATES.SOLO_IN_PLACE] = {'solo in place', 'soloed in place'},
    [STATES.SOLO_IGNORE_ROUTING] = {'solo (ignore routing)', 'soloed (ignores routing)'},
    [STATES.MUTE] = {'mute', 'muted'},
    [STATES.MUTE_SOLO_IN_PLACE] = {'mute & solo in place', 'muted and soloed in place'},
    [STATES.MUTE_SOLO_IGNORE_ROUTING] = {'mute & solo (ignore routing)', 'muted and soloed (ignores routing)'}
}

local STATE_RPR_CODES = {
    [STATES.SOLO_IN_PLACE] = {
        ['I_SOLO'] = 2,
        ['B_MUTE'] = 0
    },
    [STATES.SOLO_IGNORE_ROUTING] = {
        ['I_SOLO'] = 1,
        ['B_MUTE'] = 0
    },
    [STATES.MUTE] = {
        ['I_SOLO'] = 0,
        ['B_MUTE'] = 1
    },
    [STATES.MUTE_SOLO_IN_PLACE] = {
        ['I_SOLO'] = 2,
        ['B_MUTE'] = 1
    },
    [STATES.MUTE_SOLO_IGNORE_ROUTING] = {
        ['I_SOLO'] = 1,
        ['B_MUTE'] = 1
    },
    [' '] = {
        ['I_SOLO'] = 0,
        ['B_MUTE'] = 0
    }
}

local RENDERACTION_RENDERQUEUE_NOTHING = 0
local RENDERACTION_RENDERQUEUE_OPEN = 1
local RENDERACTION_RENDERQUEUE_RUN = 2
local RENDERACTION_RENDER = 3

local RENDERACTION_DESCRIPTIONS = {
    [RENDERACTION_RENDER] = 'Render Immediately',
    [RENDERACTION_RENDERQUEUE_NOTHING] = 'Add to render queue',
    [RENDERACTION_RENDERQUEUE_OPEN] = 'Add to render queue and open it',
    [RENDERACTION_RENDERQUEUE_RUN] = 'Add to render queue and run it'
}

local WAITTIME_MIN = 2
local WAITTIME_MAX = 30

local SYNCMODE_OFF = -1
local SYNCMODE_MIRROR = 0
local SYNCMODE_SOLO = 1

local SYNCMODE_DESCRIPTIONS = {
    [SYNCMODE_MIRROR] = "Soloing or muting in REAPER affects stem",
    [SYNCMODE_SOLO] = "Soloing or muting in REAPER does not affect stem"
}

local REFLECT_ON_ADD_TRUE = 0
local REFLECT_ON_ADD_FALSE = 1

local REFLECT_ON_ADD_DESCRIPTIONS = {
    [REFLECT_ON_ADD_TRUE] = 'with current solos/mutes',
    [REFLECT_ON_ADD_FALSE] = 'without solos/mutes'
}

local SETTINGS_SOURCE_MASK = 0x10EB

local RB_CUSTOM_TIME = 0
local RB_ENTIRE_PROJECT = 1
local RB_TIME_SELECTION = 2
local RB_ALL_REGIONS = 3
local RB_SELECTED_ITEMS = 4
local RB_SELECTED_REGIONS = 5
local RB_REZOR_EDIT_AREAS = 6
local RB_ALL_MARKERS = 7
local RB_SELECTED_MARKERS = 8

local RENDER_SETTING_GROUPS_SLOTS = 9 -- TODO: make that user defineable

local applyPresetScript
local frameCount = 0

if OD_PrereqsOK({
    reaimgui_version = '0.7',
    reaper_version = 6.44,
    scripts = {["cfillion_Apply render preset.lua"] = r.GetResourcePath() .. "/Scripts/ReaTeam Scripts/Rendering/cfillion_Apply render preset.lua"}
}) then
    local app = {
        open = true,
        coPerform = nil,
        perform = {
            status = nil,
            pos = nil,
            total = nil
        },
        hint = {
            main = {},
            settings = {}
        }
    }

    local gui = {}
    do
        -- these needs to be temporarily created to be refered to from some of the gui vars
        local ctx = r.ImGui_CreateContext(scr.context_name .. '_MAIN')
        local cellSize = 25
        local font_vertical = r.ImGui_CreateFont(scr.dir .. '../../Resources/Fonts/Cousine-90deg.otf', 11)
        local font_default = r.ImGui_CreateFont(scr.dir .. '../../Resources/Fonts/Cousine-Regular.ttf', 16)
        local font_bold = r.ImGui_CreateFont(scr.dir .. '../../Resources/Fonts/Cousine-Regular.ttf', 16,
            r.ImGui_FontFlags_Bold())

        r.ImGui_Attach(ctx, font_default)
        r.ImGui_Attach(ctx, font_vertical)
        r.ImGui_Attach(ctx, font_bold)

        gui = {
            ctx = ctx,
            mainWindow = {},
            draw_list = r.ImGui_GetWindowDrawList(ctx),
            keyModCtrlCmd = (os_is.mac or os_is.mac_arm) and r.ImGui_Mod_Super() or r.ImGui_Mod_Ctrl(),
            notKeyModCtrlCmd = (os_is.mac or os_is.mac_arm) and r.ImGui_Mod_Ctrl() or r.ImGui_Mod_Super(),
            descModCtrlCmd = (os_is.mac or os_is.mac_arm) and 'cmd' or 'control',
            descModAlt = (os_is.mac or os_is.mac_arm) and 'opt' or 'alt',
            st = {
                fonts = {
                    default = font_default,
                    vertical = font_vertical,
                    bold = font_bold
                },
                col = {
                    warning = 0xf58e07FF,
                    ok = 0X55FF55FF,
                    critical = 0xDD0000FF,
                    error = 0xFF5555FF,
                    hint = 0xCCCCCCFF,
                    button = {
                        [r.ImGui_Col_Text()] = 0x000000ff,
                        [r.ImGui_Col_Button()] = 0x707070ff,
                        [r.ImGui_Col_ButtonHovered()] = 0x858585FF,
                        [r.ImGui_Col_ButtonActive()] = 0x9c9c9cFF
                    },
                    stemSyncBtn = {
                        [SYNCMODE_MIRROR] = {
                            inactive = {
                                [r.ImGui_Col_Text()] = 0xb5301fff,
                                [r.ImGui_Col_Button()] = 0x1e241eff,
                                [r.ImGui_Col_ButtonHovered()] = 0x293229FF,
                                [r.ImGui_Col_ButtonActive()] = 0x273827FF
                            },
                            active = {
                                [r.ImGui_Col_Text()] = 0x000000ff,
                                [r.ImGui_Col_Button()] = 0x3c9136ff,
                                [r.ImGui_Col_ButtonHovered()] = 0x45a33eFF,
                                [r.ImGui_Col_ButtonActive()] = 0x4eba47FF
                            }
                        },
                        [SYNCMODE_SOLO] = {
                            inactive = {
                                [r.ImGui_Col_Text()] = 0xb5301fff,
                                [r.ImGui_Col_Button()] = 0x1e2024FF,
                                [r.ImGui_Col_ButtonHovered()] = 0x292c32FF,
                                [r.ImGui_Col_ButtonActive()] = 0x272c38FF
                            },
                            active = {
                                [r.ImGui_Col_Text()] = 0x000000ff,
                                [r.ImGui_Col_Button()] = 0x365f91ff,
                                [r.ImGui_Col_ButtonHovered()] = 0x3e6ba3FF,
                                [r.ImGui_Col_ButtonActive()] = 0x477fbaFF
                            }
                        }
                    },
                    hasChildren = {
                        [STATES.SOLO_IN_PLACE] = {
                            [r.ImGui_Col_Text()] = 0x00000099
                        },
                        [STATES.SOLO_IGNORE_ROUTING] = {
                            [r.ImGui_Col_Text()] = 0x00000099
                        },
                        [STATES.MUTE_SOLO_IN_PLACE] = {
                            [r.ImGui_Col_Text()] = 0x00000099
                        },
                        [STATES.MUTE_SOLO_IGNORE_ROUTING] = {
                            [r.ImGui_Col_Text()] = 0x00000099
                        },
                        [STATES.MUTE] = {
                            [r.ImGui_Col_Text()] = 0x00000099
                        },
                        [' '] = {
                            [r.ImGui_Col_Text()] = 0xffffff22
                        }
                    },
                    render_setting_groups = {},
                    stemState = {
                        ['sync_0'] = {
                            [r.ImGui_Col_Text()] = 0x000000ff,
                            [r.ImGui_Col_Button()] = 0x1e241eff,
                            [r.ImGui_Col_ButtonHovered()] = 0x273827FF
                        },
                        ['sync_1'] = {
                            [r.ImGui_Col_Text()] = 0x000000ff,
                            [r.ImGui_Col_Button()] = 0x1e1f24FF,
                            [r.ImGui_Col_ButtonHovered()] = 0x272c38FF
                        },
                        [STATES.SOLO_IN_PLACE] = {
                            [r.ImGui_Col_Text()] = 0x000000ff,
                            [r.ImGui_Col_Button()] = 0xd6be42FF,
                            [r.ImGui_Col_ButtonHovered()] = 0xe3d382FF
                        },
                        [STATES.SOLO_IGNORE_ROUTING] = {
                            [r.ImGui_Col_Text()] = 0x000000ff,
                            [r.ImGui_Col_Button()] = 0x48ab9cFF,
                            [r.ImGui_Col_ButtonHovered()] = 0x7ac7bcFF
                        },
                        [STATES.MUTE] = {
                            [r.ImGui_Col_Text()] = 0x000000ff,
                            [r.ImGui_Col_Button()] = 0xa63f3fFF,
                            [r.ImGui_Col_ButtonHovered()] = 0xc35555FF
                        },
                        [' '] = {
                            [r.ImGui_Col_Text()] = 0x000000FF,
                            [r.ImGui_Col_Button()] = 0x00000000,
                            [r.ImGui_Col_ButtonHovered()] = 0xFFFFFF22
                        }
                    },
                    trackname = {
                        [r.ImGui_Col_HeaderHovered()] = 0xFFFFFF22,
                        [r.ImGui_Col_HeaderActive()] = 0xFFFFFF66
                    }
                },
                vars = {
                    mtrx = {
                        cellSize = cellSize,
                        table = {
                            [r.ImGui_StyleVar_IndentSpacing()] = {cellSize},
                            [r.ImGui_StyleVar_CellPadding()] = {0, 0},
                            [r.ImGui_StyleVar_ItemSpacing()] = {1, 0}
                        },

                        stemState = {
                            [r.ImGui_StyleVar_FramePadding()] = {0, -1}
                        }
                    }
                }
            },
            mtrxTbl = {
                drgState = nil
            },
            stWnd = {}, -- settings window states
            caWnd = {}, -- create action window states
            popups = {
                singleInput = {
                    status = ""
                }
            },
            tables = {
                horizontal = {
                    flags1 = r.ImGui_TableFlags_ScrollX() | r.ImGui_TableFlags_ScrollY() |
                        r.ImGui_TableFlags_BordersOuter() | r.ImGui_TableFlags_Borders() |
                        r.ImGui_TableFlags_NoHostExtendX() | r.ImGui_TableFlags_SizingFixedFit()
                }
            },
            treeflags = {
                base = r.ImGui_TreeNodeFlags_SpanFullWidth() | r.ImGui_TreeNodeFlags_FramePadding(),
                leaf = r.ImGui_TreeNodeFlags_FramePadding() | r.ImGui_TreeNodeFlags_SpanFullWidth() |
                    r.ImGui_TreeNodeFlags_DefaultOpen() | r.ImGui_TreeNodeFlags_Leaf() |
                    r.ImGui_TreeNodeFlags_NoTreePushOnOpen()
            },
            pushColors = function(self, key)
                for k, v in pairs(key) do
                    r.ImGui_PushStyleColor(self.ctx, k, v)
                end
            end,
            popColors = function(self, key)
                for k in pairs(key) do
                    r.ImGui_PopStyleColor(self.ctx)
                end
            end,
            pushStyles = function(self, key)
                for k, v in pairs(key) do
                    r.ImGui_PushStyleVar(self.ctx, k, v[1], v[2])
                end
            end,
            popStyles = function(self, key)
                for k in pairs(key) do
                    r.ImGui_PopStyleVar(self.ctx)
                end
            end,
            updateModKeys = function(self)
                self.modKeys = ('%s%s%s%s'):format(r.ImGui_IsKeyDown(self.ctx, r.ImGui_Mod_Shift()) and 's' or '',
                    r.ImGui_IsKeyDown(self.ctx, r.ImGui_Mod_Alt()) and 'a' or '',
                    r.ImGui_IsKeyDown(self.ctx, self.keyModCtrlCmd) and 'c' or '',
                    r.ImGui_IsKeyDown(self.ctx, self.notKeyModCtrlCmd) and 'x' or '')
                return self.modKeys
            end
        }

        r.ImGui_PushFont(ctx, gui.st.fonts.default)
        gui.TEXT_BASE_WIDTH, gui.TEXT_BASE_HEIGHT = r.ImGui_CalcTextSize(ctx, 'A'),
            r.ImGui_GetTextLineHeightWithSpacing(ctx)
        r.ImGui_PopFont(ctx)
        r.ImGui_PushFont(ctx, gui.st.fonts.vertical)
        gui.VERTICAL_TEXT_BASE_WIDTH, gui.VERTICAL_TEXT_BASE_HEIGHT = r.ImGui_CalcTextSize(ctx, 'A')
        gui.VERTICAL_TEXT_BASE_HEIGHT_OFFSET = -2
        r.ImGui_PopFont(ctx)
        gui.st.vars.mtrx.table[r.ImGui_StyleVar_FramePadding()] = {1, (cellSize - gui.TEXT_BASE_HEIGHT) / 2 + 2}
        -- iterate render setting group colors

        local base_color = 0xff66d6ff
        local lightnessSteps = .1
        local hueStep = 0.2

        for i = 1, RENDER_SETTING_GROUPS_SLOTS do
            local re, g, b, a = r.ImGui_ColorConvertU32ToDouble4(base_color)
            local h, s, v = r.ImGui_ColorConvertRGBtoHSV(re, g, b)
            local shiftedCol = {
                [r.ImGui_Col_Text()] = 0x000000ff,
                [r.ImGui_Col_Button()] = base_color,
                [r.ImGui_Col_ButtonHovered()] = 0xFFFFFF33,
                [r.ImGui_Col_ButtonActive()] = 0xFFFFFF88
            }
            table.insert(gui.st.col.render_setting_groups, shiftedCol)
            -- shift to next base color
            re, g, b = r.ImGui_ColorConvertHSVtoRGB((h + hueStep), s, v)
            base_color = r.ImGui_ColorConvertNative(r.ImGui_ColorConvertDouble4ToU32(re, g, b, a))
        end
    end

    local db = {
        stems = {},
        error = nil,
        renderPresets = {},
        getRenderPresets = function(self)
            self.renderPresets = {}
            local path = string.format('%s/reaper-render.ini', r.GetResourcePath())
            if not r.file_exists(path) then
                return presets
            end

            local file, err = assert(io.open(path, 'r'))

            local tokens = {}
            self.renderPresets = {}
            for line in file:lines() do
                tokens = tokenize(line)
                if (tokens[1] == '<RENDERPRESET' or tokens[1] == 'RENDERPRESET_OUTPUT') and not (tokens[2] == "") and
                    tokens[2] then
                    local name = tokens[2]
                    self.renderPresets[name] = self.renderPresets[name] or {}
                    self.renderPresets[name].name = name
                    self.renderPresets[name].filepattern = tokens[8] or self.renderPresets[name].filepattern
                    if tokens[6] then
                        self.renderPresets[name].settings = (tonumber(tokens[6]) & SETTINGS_SOURCE_MASK) |
                                                                (self.renderPresets[name].settings or 0)
                    end
                    if tokens[3] then
                        self.renderPresets[name].boundsflag = tonumber(tokens[3])
                    end
                end
            end
            file:close()
        end,
        resetStem = function(self, stemName)
            for i, track in ipairs(self.tracks) do
                self:setTrackStateInStem(track, stemName)
            end
        end,
        reflectTrackOnStem = function(self, stemName, track, persist)
            if persist == nil then
                persist = false
            end
            local found = false
            for state, v in pairs(STATE_RPR_CODES) do
                if v['I_SOLO'] == r.GetMediaTrackInfo_Value(track.object, 'I_SOLO') and v['B_MUTE'] ==
                    r.GetMediaTrackInfo_Value(track.object, 'B_MUTE') then
                    self:setTrackStateInStem(track, stemName, state, false, false)
                    found = true
                    break
                end
                if not found then
                else
                    self:setTrackStateInStem(track, stemName, nil, false, false)
                end
            end
            if persist then
                self:save()
            end
        end,
        reflectAllTracksOnStem = function(self, stemName)
            for i, track in ipairs(self.tracks) do
                self:reflectTrackOnStem(stemName, track)
            end
            self:save()
        end,
        reflectStemOnTrack = function(self, stemName, track)
            if not (r.GetMediaTrackInfo_Value(track.object, 'I_SOLO') ==
                STATE_RPR_CODES[track.stemMatrix[stemName] or ' ']['I_SOLO']) then
                r.SetMediaTrackInfo_Value(track.object, 'I_SOLO',
                    STATE_RPR_CODES[track.stemMatrix[stemName] or ' ']['I_SOLO'])
            end
            if not (r.GetMediaTrackInfo_Value(track.object, 'B_MUTE') ==
                STATE_RPR_CODES[track.stemMatrix[stemName] or ' ']['B_MUTE']) then
                r.SetMediaTrackInfo_Value(track.object, 'B_MUTE',
                    STATE_RPR_CODES[track.stemMatrix[stemName] or ' ']['B_MUTE'])
            end
        end,
        reflectStemOnAllTracks = function(self, stemName)
            -- first only solo/mute tracks
            for i, track in ipairs(self.tracks) do
                if track.stemMatrix[stemName] ~= ' ' and track.stemMatrix[stemName] ~= nil then
                    self:reflectStemOnTrack(stemName, track)
                end
            end
            -- and only then unmute previous tracks
            for i, track in ipairs(self.tracks) do
                if track.stemMatrix[stemName] == ' ' or track.stemMatrix[stemName] == nil then
                    self:reflectStemOnTrack(stemName, track)
                end
            end

        end,
        saveSoloState = -- save current projects solo state to a temporary variable,
        -- for use after stem syncing is turned off
        function(self)
            self.savedSoloStates = {}
            for i = 0, r.CountTracks(0) - 1 do
                local track = r.GetTrack(0, i)
                self.savedSoloStates[r.GetTrackGUID(track)] = {
                    ['solo'] = r.GetMediaTrackInfo_Value(track, 'I_SOLO'),
                    ['mute'] = r.GetMediaTrackInfo_Value(track, 'B_MUTE')
                }
            end
            self:save()
        end,
        recallSoloState = function(self)
            for i = 0, r.CountTracks(0) - 1 do
                local track = r.GetTrack(0, i)
                local trackGUID = r.GetTrackGUID(track)
                local savedState = self.savedSoloStates[trackGUID]
                if savedState then
                    if not (r.GetMediaTrackInfo_Value(track, 'I_SOLO') == savedState.solo) then
                        r.SetMediaTrackInfo_Value(track, 'I_SOLO', savedState.solo)
                    end
                    if not (r.GetMediaTrackInfo_Value(track, 'B_MUTE') == savedState.mute) then
                        r.SetMediaTrackInfo_Value(track, 'B_MUTE', savedState.mute)
                    end
                end
            end
        end,
        toggleStemSync = function(self, stem, toggleTo)
            -- if toggleTo is left blank, toggles according to current state
            -- find if the request came when another stem is soloed,
            -- otherwise, save project solo states (at a later point)
            -- if it did and it's turned off than recall solo states
            local syncingStemFound = false
            for k, st in pairs(self.stems) do
                syncingStemFound = syncingStemFound or (st.sync ~= SYNCMODE_OFF and st.sync ~= nil)
            end
            for k, st in pairs(self.stems) do
                if stem == st then
                    if toggleTo ~= SYNCMODE_OFF then
                        if not syncingStemFound then
                            self:saveSoloState()
                        end
                        self:reflectStemOnAllTracks(k)
                    elseif syncingStemFound then
                        self:recallSoloState()
                    end
                    st.sync = toggleTo
                else
                    -- set all other stems to not sync
                    st.sync = SYNCMODE_OFF
                end
            end
            self:save()
        end,
        setTrackStateInStem = function(self, track, stemName, state, persist, reflect)
            if persist == nil then
                persist = true
            end
            if reflect == nil then
                reflect = (self.stems[stemName].sync ~= SYNCMODE_OFF)
            end
            if state == ' ' then
                state = nil
            end
            track.stemMatrix[stemName] = state
            if reflect then
                self:reflectStemOnTrack(stemName, track)
            end
            if persist then
                self:save()
            end
        end,
        findSimilarStem = function(self, name, findSame)
            if findSame == nil then
                findSame = false
            end
            for k, v in pairs(self.stems) do
                if (k:upper() == name:upper()) and (findSame or (not (k == name))) then
                    return k
                end
            end
        end,
        addStem = function(self, name, copy)
            local persist = false
            -- if a stem exist with the same name but different case (e.g., drums / Drums)
            -- rename the added stem to the new one and dont create it
            local existingSimilarName = self:findSimilarStem(name)
            if not (existingSimilarName == nil) then
                -- look for all track with reference to the found stem and change their case
                for i, track in ipairs(self.tracks) do
                    for k, v in pairs(track.stemMatrix) do
                        if k == name then
                            track.stemMatrix[existingSimilarName] = v
                            track.stemMatrix[k] = nil
                        end
                    end
                end
            elseif not self.stems[name] then
                persist = true
                self.stemCount = (self.stemCount or 0) + 1
                self.stems[name] = {
                    order = self.stemCount,
                    sync = SYNCMODE_OFF,
                    render_setting_group = 1
                }
                -- get render setting group from last stem in list
                for k, v in pairsByOrder(self.stems) do
                    if v.order == self.stemCount - 1 then
                        self.stems[name].render_setting_group = v.render_setting_group
                    end
                end
                if copy then
                    self:reflectAllTracksOnStem(name)
                end
            end
            if persist then
                self:save()
            end
        end,
        removeStem = function(self, stemName)
            -- turn off sync if this stem is syncing
            if (self.stems[stemName].sync ~= SYNCMODE_OFF) and (self.stems[stemName].sync ~= nil) then
                self:toggleStemSync(self.stems[stemName], SYNCMODE_OFF)
            end
            -- remove any states related to the stem from tracks
            for i, track in ipairs(self.tracks) do
                self:setTrackStateInStem(track, stemName, nil, false)
            end
            -- reorder remaining stems
            for k, v in pairs(self.stems) do
                if v.order > self.stems[stemName].order then
                    self.stems[k].order = self.stems[k].order - 1
                end
            end
            -- remove stem
            self.stems[stemName] = nil
            self:save()
        end,
        reorderStem = function(self, stemName, newPos)
            local oldPos = self.stems[stemName].order
            for k, v in pairs(self.stems) do
                if (v.order >= newPos) and (v.order < oldPos) then
                    self.stems[k].order = self.stems[k].order + 1
                end
                if (v.order <= newPos) and (v.order > oldPos) then
                    self.stems[k].order = self.stems[k].order - 1
                end
            end
            self.stems[stemName].order = newPos
            self:save()
        end,
        renameStem = function(self, stemName, newName)
            if not (newName == stemName) then
                for i, track in ipairs(self.tracks) do
                    for k, v in pairs(track.stemMatrix) do
                        if k == stemName then
                            track.stemMatrix[newName] = v
                            track.stemMatrix[k] = nil
                        end
                    end
                end
                self.stems[newName] = self.stems[stemName]
                self.stems[stemName] = nil
                self:save()
            end
        end,
        save = function(self)
            -- persist track states
            for trackIdx = 0, r.CountTracks(0) - 1 do
                local rTrack = r.GetTrack(0, trackIdx)
                local foundTrackInfo = {}
                if self.tracks then
                    for i, track in ipairs(self.tracks) do
                        if rTrack == track.object then
                            foundTrackInfo = track
                        end
                    end
                end
                if foundTrackInfo.stemMatrix and not (foundTrackInfo.stemMatrix == '') then
                    local retval = r.GetSetMediaTrackInfo_String(rTrack, "P_EXT:" .. scr.context_name .. '_STEM_MATRIX',
                        pickle(foundTrackInfo.stemMatrix), true)
                else
                    r.GetSetMediaTrackInfo_String(rTrack, "P_EXT:" .. scr.context_name .. '_STEM_MATRIX', '', true)
                end
            end
            saveLongProjExtState(scr.context_name, 'STEMS', pickle(self.stems or {}))
            for k, v in pairs(self.savedSoloStates) do
                r.SetProjExtState(0, scr.context_name .. '_SAVED_SOLO_STATES', k, pickle(v))
            end
            r.MarkProjectDirty(0)
        end,
        sync = function(self, full)
            if app.debug then
                tim = os.clock()
            end
            self.cycles = self.cycles or 0
            if self.cycles == 0 then
                full = true
            end -- if first cycle, force full sync
            self.current_project = r.GetProjectStateChangeCount(0) -- if project changed, force full sync
            if self.current_project ~= self.previous_project then
                self.previous_project = self.current_project
                full = true
            end

            if full then
                if app.debug then
                    r.ShowConsoleMsg('FULL SYNC\n')
                end
                self.stems = unpickle(loadLongProjExtKey(scr.context_name, 'STEMS')) or {}
                self.prefSoloIP = select(2, r.get_config_var_string('soloip')) == '1'
            end

            self.trackChangeTracking = self.trackChangeTracking or ''
            self.tracks = self.tracks or {}
            self.stemToSync = nil
            self.error = nil
            self.stemCount = 0;

            -- load savedSoloStates
            if full then
                self.savedSoloStates = {}
                i = 0
                local retval, k, v = r.EnumProjExtState(0, scr.context_name .. '_SAVED_SOLO_STATES', i)
                while retval do
                    self.savedSoloStates[k] = unpickle(v)
                    i = i + 1
                    retval, k, v = r.EnumProjExtState(0, scr.context_name .. '_SAVED_SOLO_STATES', i)
                end
                self.savedSoloStates = self.savedSoloStates or {}
            end
            -- iterate stems, count them and mark them as the stem to sync if necessary
            for k, stem in pairs(self.stems or {}) do
                self.stemCount = self.stemCount + 1
                if stem.sync ~= SYNCMODE_OFF and stem.sync ~= nil then
                    self.stemToSync = k
                    self.syncMode = stem.sync
                end
            end
            local trackCount = r.CountTracks(0)
            self.lastTrackCount = self.lastTrackCount or trackCount

            if full or self.lastTrackCount ~= trackCount then
                self.lastTrackCount = trackCount
                self.tracks = {}
                for trackIdx = 0, trackCount - 1 do
                    local rTrack = r.GetTrack(0, trackIdx)
                    local _, name = r.GetSetMediaTrackInfo_String(rTrack, "P_NAME", "", false)
                    local folderDepth = r.GetMediaTrackInfo_Value(rTrack, "I_FOLDERDEPTH")
                    local hidden = (r.GetMediaTrackInfo_Value(rTrack, "B_SHOWINTCP") == 0)
                    local color = r.GetTrackColor(rTrack)
                    local _, rawStemMatrix = r.GetSetMediaTrackInfo_String(rTrack, "P_EXT:" .. scr.context_name ..
                        '_STEM_MATRIX', "", false)
                    local stemMatrix = unpickle(rawStemMatrix)
                    local trackInfo = {
                        object = rTrack,
                        name = name,
                        folderDepth = folderDepth,
                        color = color,
                        hidden = hidden,
                        stemMatrix = stemMatrix or {}
                    }
                    -- iterate tracks to create stems
                    if trackInfo then
                        table.insert(self.tracks, trackInfo)
                    end
                    for k, v in pairs(trackInfo.stemMatrix or {}) do
                        self:addStem(k, false)
                    end
                end
            end

            for i, track in ipairs(self.tracks) do
                -- if stem is syncing, sync it
                if (self.stemToSync) and (self.syncMode == SYNCMODE_MIRROR) then
                    self:reflectTrackOnStem(self.stemToSync, track)
                end
            end
            self.cycles = self.cycles + 1
            if app.debug then
                self.cumlativeTime = self.cumlativeTime and (self.cumlativeTime + (os.clock() - tim)) or
                                         (os.clock() - tim)
                if self.cycles / 10 == math.ceil(self.cycles / 10) then
                    r.ShowConsoleMsg(string.format("average over %d sync operations: %.10f\n", self.cycles,
                        self.cumlativeTime / self.cycles))
                end
            end
        end
    }

    local validators = {
        stem = {
            name = (function(origVal, val)
                if val == "" then
                    return "Can't be blank"
                end
                if not (origVal:upper() == val:upper()) then
                    for k, v in pairs(db.stems) do
                        if k:upper() == val:upper() then
                            return ('Stem %s already exists'):format(val)
                        end
                    end
                end
                return true
            end)
        }
    }
    
    local settings = {}

    local function getDefaultSettings(factory)
        if factory == nil then
            factory = false
        end
        local settings = {
            default = {
                renderaction = RENDERACTION_RENDER,
                overwrite_without_asking = false,
                wait_time = 5,
                reflect_on_add = REFLECT_ON_ADD_TRUE,
                syncmode = SYNCMODE_MIRROR,
                render_setting_groups = {},
                show_hidden_tracks = false
            }
        }

        local default_render_settings = {
            description = '',
            render_preset = nil,
            skip_empty_stems = true,
            put_in_folder = false,
            folder = '',
            override_filename = false,
            filename = '',
            make_timeSel = false,
            timeSelStart = 0,
            timeSelEnd = 0,
            select_regions = false,
            selected_regions = {},
            select_markers = false,
            selected_markers = {},
            run_actions = false,
            actions_to_run = {},
            run_actions_after = false,
            actions_to_run_after = {},
            ignore_warnings = false
        }
        for i = 1, RENDER_SETTING_GROUPS_SLOTS do
            table.insert(settings.default.render_setting_groups, deepcopy(default_render_settings))
        end

        if not factory then
            local loaded_ext_settings = table.load(scr.dfsetfile) or {} -- unpickle(r.GetExtState(scr.context_name, 'DEFAULT SETTINGS') or '')
            -- merge default settings from extstates with script defaults
            for k, v in pairs(loaded_ext_settings or {}) do
                if not (k == 'render_setting_groups') then
                    settings.default[k] = v
                else
                    for rgIdx, val in ipairs(v) do
                        for rgSetting, rgV in pairs(val or {}) do

                            if not settings.default.render_setting_groups[rgIdx] then -- if more render were saved than there are by default, create them by loading default vaules first
                                settings.default.render_setting_groups[rgIdx] = deepcopy(default_render_settings)
                            end
                            settings.default.render_setting_groups[rgIdx][rgSetting] = rgV
                        end
                    end
                end
            end
        end

        return settings
    end

    local function loadSettings()
        settings = getDefaultSettings()
        -- take merged updated default settings and merge project specific settings into them
        local loaded_project_settings = unpickle(loadLongProjExtKey(scr.context_name, 'PROJECT SETTINGS'))
        settings.project = deepcopy(settings.default)
        for k, v in pairs(loaded_project_settings or {}) do
            if not (k == 'render_setting_groups') then
                settings.project[k] = v
            else
                for rgIdx, val in ipairs(v) do
                    for rgSetting, rgV in pairs(val or {}) do
                        settings.project.render_setting_groups[rgIdx][rgSetting] = rgV
                    end
                end
            end
        end
    end

    local function saveSettings()
        table.save(settings.default, scr.dfsetfile)
        saveLongProjExtState(scr.context_name, 'PROJECT SETTINGS', pickle(settings.project))
        r.MarkProjectDirty(0)
    end

    local function updateSettings()
        for rgIdx, val in ipairs(settings.project.render_setting_groups) do
            for rgAIdx, command_id in pairs(settings.project.render_setting_groups[rgIdx].actions_to_run or {}) do
                if type(command_id) ~= "string" then
                    local named_command = reaper.ReverseNamedCommandLookup(command_id)
                    if named_command then
                        settings.project.render_setting_groups[rgIdx].actions_to_run[rgAIdx] = named_command
                    end
                end
            end
            for rgAIdx, command_id in pairs(settings.project.render_setting_groups[rgIdx].actions_to_run_after or {}) do
                if type(command_id) ~= "string" then
                    local named_command = reaper.ReverseNamedCommandLookup(command_id)
                    if named_command then
                        settings.project.render_setting_groups[rgIdx].actions_to_run_after[rgAIdx] = named_command
                    end
                end
            end
        end
        saveSettings()
    end

    local function sanitizeFilename(name)
        -- replace special characters that are reserved on Windows
        return name:gsub('[*\\:<>?/|"%c]+', '-')
    end

    local function createAction(actionName, cmd)
        local snActionName = sanitizeFilename(actionName)
        local filename = ('%s - %s'):format(scr.no_ext, snActionName)

        local outputFn = string.format('%s/%s.lua', scr.dir, filename)
        local code = ([[
local r = reaper
local context = '$context'
local script_name = '$scriptname'
local cmd = '$cmd'

function getScriptId(script_name)
  local file = io.open(r.GetResourcePath().."/".."reaper-kb.ini")
  if not file then return "" end
  local content = file:read("*a")
  file:close()
  local santizedSn = script_name:gsub("([^%w])", "%%%1")
  if content:find(santizedSn) then
    return content:match('[^\r\n].+(RS.+) "Custom: '..santizedSn)
  end
end

local cmdId = getScriptId(script_name)

if cmdId then
  if r.GetExtState(context, 'defer') ~= '1' then
    local intId = r.NamedCommandLookup('_'..cmdId)
    if intId ~= 0 then r.Main_OnCommand(intId,0) end
  end
  r.SetExtState(context, 'EXTERNAL COMMAND',cmd, false)
else 
  r.MB(script_name..' not installed', script_name,0) 
end]]):gsub('$(%w+)', {
            context = scr.context_name,
            scriptname = scr.basename,
            cmd = cmd
        })
        code = ('-- This file was created by %s on %s\n\n'):format(scr.name, os.date('%c')) .. code
        local file = assert(io.open(outputFn, 'w'))
        file:write(code)
        file:close()

        if r.AddRemoveReaScript(true, 0, outputFn, true) == 0 then
            return false
        end
        return true

    end

    -- used for preset name extraction.
    -- taken from cfillion_Apply Render Preset.lua
    function tokenize(line)
        local pos, tokens = 1, {}

        while pos do
            local tail, eat = nil, 1

            if line:sub(pos, pos) == '"' then
                pos = pos + 1 -- eat the opening quote
                tail = line:find('"%s', pos)
                eat = 2

                if not tail then
                    if line:sub(-1) == '"' then
                        tail = line:len()
                    else
                        error('missing closing quote')
                    end
                end
            else
                tail = line:find('%s', pos)
            end

            if pos <= line:len() then
                table.insert(tokens, line:sub(pos, tail and tail - 1))
            end

            pos = tail and tail + eat
        end

        return tokens
    end

    --------------------------------------------------------------------------------
    -- MAIN APP --------------------------------------------------------------------
    --------------------------------------------------------------------------------

    local function GetRegionManagerWindow()
        local title = r.JS_Localize('Region/Marker Manager', 'common')
        return r.JS_Window_Find(title, true)
    end

    local function OpenAndGetRegionManagerWindow()
        local title = r.JS_Localize('Region/Marker Manager', 'common')
        local manager = GetRegionManagerWindow()
        if not manager then
            r.Main_OnCommand(40326, 0) -- View: Show region/marker manager window
            manager = r.JS_Window_Find(title, true)
        end
        return manager
    end

    local function GetAllRegionsOrMarkers(m_type, close)
        if close == nil then
            close = true
        end
        local manager = OpenAndGetRegionManagerWindow()
        local lv = r.JS_Window_FindChildByID(manager, 1071)
        local cnt = r.JS_ListView_GetItemCount(lv)
        local t = {}
        if m_type == '' then
            m_type = nil
        end
        for i = 0, cnt - 1 do
            local matchstring = ("%s%%d+"):format(m_type and (m_type:upper()) or ".")
            for rId in r.JS_ListView_GetItemText(lv, i, 1):gmatch(matchstring) do
                t[#t + 1] = {
                    is_rgn = rId:sub(1, 1) == 'R',
                    id = rId,
                    name = r.JS_ListView_GetItemText(lv, i, 2),
                    selected = (r.JS_ListView_GetItemState(lv, i) ~= 0)
                }
            end
        end
        if close then
            r.Main_OnCommand(40326, 0)
        end -- View: Show region/marker manager window
        return t, lv
    end

    local function GetSelectedRegionsOrMarkers(m_type)
        local markeregions = GetAllRegionsOrMarkers(m_type)
        local selected_markeregions = {}
        for i, markeregion in ipairs(markeregions) do
            if markeregion.selected then
                table.insert(selected_markeregions, markeregion)
            end
        end
        return selected_markeregions
    end

    local function SelectRegionsOrMarkers(selection, close)
        if close == nil then
            close = true
        end
        local markeregions, lv = GetAllRegionsOrMarkers(nil, false)
        r.JS_ListView_SetItemState(lv, -1, 0x0, 0x2) -- unselect all items
        for _, markeregion_to_select in ipairs(selection) do
            for i, markeregion in ipairs(markeregions) do
                if markeregion.id == tostring(markeregion_to_select.id) then
                    r.JS_ListView_SetItemState(lv, i - 1, 0xF, 0x2) -- select item @ index
                end
            end
        end
        if close then
            r.Main_OnCommand(40326, 0)
        end -- View: Show region/marker manager window
    end

    local function GetAllRegions(close)
        return GetAllRegionsOrMarkers('R', close)
    end

    local function GetAllMarkers(close)
        return GetAllRegionsOrMarkers('M', close)
    end

    local function GetSelectedRegions()
        return GetSelectedRegionsOrMarkers('R')
    end

    local function GetSelectedMarkers()
        return GetSelectedRegionsOrMarkers('M')
    end

    local function SelectRegions(selection, close)
        SelectRegionsOrMarkers(selection, close)
    end

    local function SelectMarkers(selection, close)
        SelectRegionsOrMarkers(selection, close)
    end

    local function checkRenderGroupSettings(rsg)
        local checks = {}
        local ok = true
        presetName = rsg.render_preset
        if presetName and not db.renderPresets[presetName] then
            table.insert(checks, {
                passed = false,
                status = "Preset does not exist",
                severity = 'critical',
                hint = ("There's no render preset with the name '%s'."):format(presetName)
            })
            ok = ok and test
        elseif not presetName then
            table.insert(checks, {
                passed = false,
                status = "No render preset selected",
                severity = 'critical',
                hint = "A render preset must be selected."
            })
            ok = false
        else
            local preset = db.renderPresets[presetName]
            local test = preset.settings == 1
            table.insert(checks, {
                passed = test,
                status = ("Render preset source %s 'Master mix'"):format(test and 'is' or 'is not'),
                severity = (not test and 'warning' or nil),
                hint = test and "The render preset's source is set to 'Master mix'." or
                    "For the stems to be rendered correctly, the source must be set to 'Master mix'."
            })
            ok = ok and test

            test = ((rsg.override_filename == true) and string.find(rsg.filename, "$stem")) or
                       string.find(preset.filepattern, "$stem")
            table.insert(checks, {
                passed = test,
                status = ("$stem %s filename"):format(test and 'in' or "not in"),
                severity = (not test and 'warning' or nil),
                hint = test and "Stem name will be inserted wherever the $stem wildcard is used." or
                    "$stem wildcard not used in render preset. Fix by overriding the filename."
            })
            ok = ok and test

            if preset.boundsflag == RB_TIME_SELECTION and rsg.make_timeSel and not (rsg.timeSelEnd > rsg.timeSelStart) then
                table.insert(checks, {
                    passed = false,
                    status = "Illegal time selection",
                    severity = 'critical',
                    hint = "Please capture time selection, or uncheck 'make time selection before rendering'."
                })
                ok = false
            end
            if preset.boundsflag == RB_SELECTED_MARKERS then
                if not r.APIExists('JS_Localize') then
                    table.insert(checks, {
                        passed = false,
                        status = "js_ReaScriptAPI missing",
                        severity = ('critical'),
                        hint = "js_ReaScriptAPI extension is required for selecting markers."
                    })
                    ok = false
                end
                if rsg.select_markers and #rsg.selected_markers == 0 then
                    table.insert(checks, {
                        passed = false,
                        status = "No markers selected",
                        severity = 'critical',
                        hint = "Please select markers or uncheck 'Select markers before rendering'."
                    })
                    ok = false
                elseif rsg.select_markers then
                    -- check for markers that don't exist
                    local failed_exist = false
                    local failed_name = false
                    for i, mar in ipairs(rsg.selected_markers) do
                        local mIdx = 0
                        local found = false
                        while not failed_exist do
                            local retval, isrgn, _, _, name, markrgnindexnumber = r.EnumProjectMarkers2(0, mIdx)
                            if retval == 0 then
                                break
                            end
                            if (not isrgn) and mar.id == 'M' .. markrgnindexnumber then
                                if mar.name ~= name then
                                    failed_name = true
                                end
                                found = true
                                break
                            end
                            mIdx = mIdx + 1
                        end
                        if found and failed_name then
                            failed_name = true
                        end
                        if not found and not failed_exist then
                            failed_exist = true
                        end
                    end
                    table.insert(checks, {
                        passed = not failed_exist,
                        status = ("Selected marker(s) %sexist"):format(failed_exist and "don't " or ''),
                        severity = failed_exist and 'critical' or nil,
                        hint = failed_exist and
                            "Marker(s) selected in the setting group do not exist, or their ID had changed." or
                            "Selected markers exist in the project"
                    })
                    ok = ok and (not failed_exist)
                    if failed_name then
                        table.insert(checks, {
                            passed = false,
                            status = "Marker names changed",
                            severity = 'critical',
                            hint = "Please reselect markers."
                        })
                        ok = false
                    end
                end
            end
            if preset.boundsflag == RB_SELECTED_REGIONS then
                if not r.APIExists('JS_Localize') then
                    table.insert(checks, {
                        passed = false,
                        status = "js_ReaScriptAPI missing",
                        severity = 'critical',
                        hint = "js_ReaScriptAPI extension is required for selecting regions."
                    })
                    ok = false
                end
                if rsg.select_regions and #rsg.selected_regions == 0 then
                    table.insert(checks, {
                        passed = false,
                        status = "No regions selected",
                        severity = 'critical',
                        hint = "Please select regions or uncheck 'Select regions before rendering'."
                    })
                    ok = false
                elseif rsg.select_regions then
                    -- check for regions that don't exist
                    -- check for regions that are not mapped in region matrix
                    local failed_regionMatrix = false
                    local failed_exist = false
                    local failed_name = false
                    for i, reg in ipairs(rsg.selected_regions) do
                        local tIdx = 0
                        local rIdx = 0
                        local found = false
                        while not failed_exist do
                            local retval, isrgn, _, _, name, markrgnindexnumber = r.EnumProjectMarkers2(0, rIdx)
                            if retval == 0 then
                                break
                            end
                            if isrgn and reg.id == 'R' .. markrgnindexnumber then
                                found = true
                                if reg.name ~= name then
                                    failed_name = true
                                end
                                break
                            end
                            rIdx = rIdx + 1
                        end
                        if found and failed_name then
                            failed_name = true
                        end
                        if preset.settings == 9 or preset.settings == 137 then -- if render preset source is render matrix or render matrix via master
                            if not found and not failed_exist then
                                failed_exist = true
                            elseif (not failed_regionMatrix) and
                                not r.EnumRegionRenderMatrix(0, tonumber(reg.id:sub(2, -1)), 0) then
                                failed_regionMatrix = true
                            end
                        end
                    end
                    table.insert(checks, {
                        passed = not failed_exist,
                        status = ("Selected region(s) %sexist"):format(failed_exist and "don't " or ''),
                        severity = failed_exist and 'critical' or nil,
                        hint = failed_exist and
                            "Region(s) selected in the setting group do not exist, or their ID had changed." or
                            "Selected regions exist in the project"
                    })
                    ok = ok and (not failed_exist)
                    if (preset.settings == 9 or preset.settings == 137) and not failed_exist then -- if render preset source is render matrix or render matrix via master
                        table.insert(checks, {
                            passed = not failed_regionMatrix,
                            status = ("Region(s) %smapped in region matrix"):format(failed_regionMatrix and "not " or ''),
                            severity = failed_regionMatrix and 'critical' or nil,
                            hint = failed_regionMatrix and
                                "Unmapped regions are skipped. Assign tracks in region matrix (eg 'Master mix')." or
                                "All regions have tracks assigned in the region matrix."
                        })
                        ok = ok and (not failed_regionMatrix)
                    end
                    if failed_name then
                        table.insert(checks, {
                            passed = false,
                            status = "Region names changed",
                            severity = 'critical',
                            hint = "Please reselect regions."
                        })
                        ok = false
                    end
                end
            end
        end
        return ok, checks
    end

    local function doPerform()
        -- make sure we're up to date on everything
        db:sync()
        db:getRenderPresets()
        local idx = 0
        local laststemName = nil
        local save_marker_selection = false
        local save_time_selection = false
        local saved_markeregion_selection = {}
        local saved_filename = ''
        local saved_time_selection = {}
        local stems_to_render
        local foundAssignedTrack = {}
        local criticalErrorFound = {}

        app.render_cancelled = false
        app.current_renderaction = app.forceRenderAction or settings.project.renderaction
        app.perform.fullRender = (app.stem_to_render == nil) -- and app.renderGroupToRender == nil)
        -- determine stems to be rendered
        if app.stem_to_render then
            stems_to_render = {
                [app.stem_to_render] = db.stems[app.stem_to_render]
            }
        elseif app.renderGroupToRender then
            stems_to_render = {}
            for k, v in pairs(db.stems) do
                if v.render_setting_group == app.renderGroupToRender then
                    stems_to_render[k] = v
                end
            end
        else
            stems_to_render = deepcopy(db.stems)
        end
        coroutine.yield('Rendering stems', 0, 1)
        -- go over all stems to be rendered, in order to:
        --  - determine whether bounds should be be pre-saved
        --  - determine what stems should be skipped
        --  - get error messages for the entire render operation
        local included_render_groups = {}
        local stem_names_to_skip = {} -- for message
        for stemName, stem in pairs(stems_to_render) do
            local stem = db.stems[stemName]
            local rsg = settings.project.render_setting_groups[stem.render_setting_group]
            if rsg.select_markers or rsg.select_regions then
                save_marker_selection = true
            end
            if rsg.make_timeSel then
                save_time_selection = true
            end
            -- check if any track has a state in this stem
            foundAssignedTrack[stemName] = false
            for idx, track in ipairs(db.tracks) do
                foundAssignedTrack[stemName] = foundAssignedTrack[stemName] or
                                                   (track.stemMatrix[stemName] ~= ' ' and track.stemMatrix[stemName] ~=
                                                       nil)
            end
            if app.perform.fullRender and rsg.skip_empty_stems and not foundAssignedTrack[stemName] then
                table.insert(stem_names_to_skip, stemName)
                stems_to_render[stemName] = nil
            else
                included_render_groups[stem.render_setting_group] =
                    included_render_groups[stem.render_setting_group] or {}
                table.insert(included_render_groups[stem.render_setting_group], stemName)
            end
        end

        local errors = {}
        local criticalErrors = {}
        for rsgIdx, v in pairs(included_render_groups) do
            local rsg = settings.project.render_setting_groups[rsgIdx]
            local ok, checks = checkRenderGroupSettings(rsg)
            criticalErrorFound[rsgIdx] = false
            criticalErrors[rsgIdx] = {}
            errors[rsgIdx] = {}
            if not ok then
                for i, check in ipairs(checks) do
                    if not check.passed then
                        if check.severity == 'critical' then
                            criticalErrorFound[rsgIdx] = true
                            table.insert(criticalErrors[rsgIdx], check.status)
                        elseif not rsg.ignore_warnings then
                            table.insert(errors[rsgIdx], check.status)
                        end
                    end
                end
            end
        end

        app.render_count = 0
        for stemName, stem in pairs(stems_to_render) do
            if not criticalErrorFound[stem.render_setting_group] then
                app.render_count = app.render_count + 1
            end
        end
        -- assemble combined error message

        local skpMsg
        if #stem_names_to_skip > 0 then
            skpMsg =
                ('The following stems do not have any tracks with solo/mute states\nin them, so they will be skipped:\n - %s\n(This can be changed in the settings window - render "empty" stems):'):format(
                    table.concat(stem_names_to_skip, ', '))
        end

        local ceMsg
        for rsgIdx, statuses in pairs(criticalErrors) do
            if #statuses > 0 then
                local stems_in_rsg = {}
                for stemName, stem in pairsByOrder(stems_to_render) do
                    if stem.render_setting_group == rsgIdx then
                        table.insert(stems_in_rsg, stemName)
                    end
                end
                local stemNames = table.concat(stems_in_rsg, ', ')
                ceMsg = (ceMsg or '\n - ') .. stemNames .. ':\n'
                for i, status in ipairs(statuses) do
                    ceMsg = ceMsg .. '   * ' .. status .. '\n'
                end
            end
        end
        if ceMsg then
            ceMsg = 'The following stems cannot be rendered:' .. ceMsg
        end

        local eMsg
        for rsgIdx, statuses in pairs(errors) do
            if #statuses > 0 then
                local stems_in_rsg = {}
                for stemName, stem in pairsByOrder(stems_to_render) do
                    if stem.render_setting_group == rsgIdx then
                        table.insert(stems_in_rsg, stemName)
                    end
                end
                local stemNames = table.concat(stems_in_rsg, ', ')
                eMsg = (eMsg or '\n - ') .. stemNames .. ':\n'
                for i, status in ipairs(statuses) do
                    eMsg = eMsg .. '   * ' .. status .. '\n'
                end
            end
        end
        if eMsg then
            eMsg = 'The following stems will be rendered, but please see the following warnings:' .. eMsg
        end
        if skpMsg or ceMsg or eMsg then
            local msg = (ceMsg and ceMsg or '') .. (eMsg and (ceMsg and '\n\n' or '') .. eMsg or '') ..
                            (skpMsg and ((ceMsg or eMsg) and '\n\n' or '') .. skpMsg or '')
            local error_message_closed = false
            r.ImGui_OpenPopup(gui.ctx, scr.name .. '##error')
            while not error_message_closed do
                local ok = app.drawPopup(gui.ctx, 'msg', scr.name .. '##error', {
                    msg = msg,
                    showCancelButton = true
                })
                if ok then
                    error_message_closed = true
                elseif ok == false then
                    error_message_closed = true
                    app.render_count = 0
                end
                coroutine.yield('Errors found...', idx, app.perform.fullRender and db.stemCount or 1)
            end
        end

        if app.render_count > 0 then
            -- save marker selection, so that it can be restored later
            if save_marker_selection and r.APIExists('JS_Localize') then
                OpenAndGetRegionManagerWindow()
                coroutine.yield('Saving marker/region selection', 0, 1)
                saved_markeregion_selection = GetSelectedRegionsOrMarkers()
                r.Main_OnCommand(40326, 0) -- close region/marker manager
            end
            if save_time_selection then
                saved_time_selection = {r.GetSet_LoopTimeRange(0, 0, 0, 0, 0)}
            end
            if r.GetAllProjectPlayStates(0) & 1 then
                r.OnStopButton()
            end
            for stemName, stem in pairsByOrder(stems_to_render) do
                if not app.render_cancelled then
                    idx = idx + 1
                    -- TODO: CONSOLIDATE UNDO HISTORY?:
                    local stem = db.stems[stemName]
                    local rsg = settings.project.render_setting_groups[stem.render_setting_group]
                    if not criticalErrorFound[stem.render_setting_group] then
                        db:toggleStemSync(db.stems[stemName], SYNCMODE_SOLO)
                        coroutine.yield('Creating stem ' .. stemName, idx, app.render_count)
                        local render_preset = db.renderPresets[rsg.render_preset]
                        ApplyPresetByName = render_preset.name
                        applyPresetScript()
                        if render_preset.boundsflag == RB_SELECTED_MARKERS and rsg.select_markers then
                            -- window must be given an opportunity to open (therefore yielded) for the selection to work
                            OpenAndGetRegionManagerWindow()
                            coroutine.yield('Creating stem ' .. stemName .. ' (selecting markers)', idx,
                                app.render_count)
                            -- for some reason selecting in windows requires region manager window to remain open for some time
                            -- (this is a workaround until proper api support for selecting regions exists)
                            if os_is.win then
                                SelectMarkers(rsg.selected_markers, false)
                                local t = os.clock()
                                while (os.clock() - t < 0.5) do
                                    coroutine.yield('Creating stem ' .. stemName .. ' (selecting markers)', idx,
                                        app.render_count)
                                end
                                r.Main_OnCommand(40326, 0) -- close region/marker manager
                            else
                                SelectMarkers(rsg.selected_markers)
                            end
                        elseif render_preset.boundsflag == RB_SELECTED_REGIONS and rsg.select_regions then
                            -- window must be given an opportunity to open (therefore yielded) for the selection to work

                            OpenAndGetRegionManagerWindow()
                            coroutine.yield('Creating stem ' .. stemName .. ' (selecting regions)', idx,
                                app.render_count)
                            -- for some reason selecting in windows requires region manager window to remain open for some time
                            -- (this is a workaround until proper api support for selecting regions exists)
                            if os_is.win then
                                SelectRegions(rsg.selected_regions, false)
                                local t = os.clock()
                                while (os.clock() - t < 0.5) do
                                    coroutine.yield('Creating stem ' .. stemName .. ' (selecting regions)', idx,
                                        app.render_count)
                                end
                                r.Main_OnCommand(40326, 0) -- close region/marker manager
                            else
                                SelectRegions(rsg.selected_regions)
                            end
                        elseif render_preset.boundsflag == RB_TIME_SELECTION and rsg.make_timeSel then
                            r.GetSet_LoopTimeRange2(0, true, false, rsg.timeSelStart, rsg.timeSelEnd, 0) -- , boolean isLoop, number start, number end, boolean allowautoseek)
                        end
                        local folder = ''
                        if rsg.put_in_folder then
                            folder = rsg.folder and (rsg.folder:gsub('/%s*$', '') .. "/") or ""
                        end
                        local filename = render_preset.filepattern
                        if rsg.override_filename then
                            filename = (rsg.filename == nil or rsg.filename == '') and render_preset.filepattern or
                                           rsg.filename
                        end
                        local filenameInFolder = (folder .. filename):gsub('$stem', stemName)
                        _, saved_filename = r.GetSetProjectInfo_String(0, "RENDER_PATTERN", '', false)
                        r.GetSetProjectInfo_String(0, "RENDER_PATTERN", filenameInFolder, true)

                        if rsg.run_actions then
                            for aIdx, action in ipairs(rsg.actions_to_run or {}) do
                                action = (type(action) == 'string') and '_' .. action or action
                                local cmd = reaper.NamedCommandLookup(action)
                                if cmd then
                                    r.Main_OnCommand(cmd, 0)
                                end
                            end
                        end
                        if app.current_renderaction == RENDERACTION_RENDER then
                            if settings.project.overwrite_without_asking and RENDERACTION_RENDER then
                                local rv, target_list = r.GetSetProjectInfo_String(0, 'RENDER_TARGETS', '', false)
                                if rv then
                                    local targets = (target_list):split(';')
                                    for i, target in ipairs(targets) do
                                        if file_exists(target) then
                                            os.remove(target)
                                        end
                                    end
                                end
                            end
                            coroutine.yield('Rendering stem ' .. stemName, idx, app.render_count)

                            r.Main_OnCommand(42230, 0) -- render now
                            r.Main_OnCommand(40043, 0) -- go to end of project
                            coroutine.yield('Waiting...', idx, app.render_count) -- let a frame pass to start count at a correct place

                            local stopprojlen = select(2, r.get_config_var_string('stopprojlen'))
                            if stopprojlen == '1' then
                                r.SNM_SetIntConfigVar('stopprojlen', 0)
                            end
                            r.OnPlayButtonEx(0)
                            if stopprojlen == '1' then
                                r.SNM_SetIntConfigVar('stopprojlen', 1)
                            end
                            local moreStemsInLine = idx < app.render_count
                            if moreStemsInLine then
                                r.ImGui_OpenPopup(gui.ctx, scr.name .. '##wait')
                            end
                            local t = os.clock()
                            while not app.render_cancelled and (os.clock() - t < settings.project.wait_time + 1) and
                                moreStemsInLine do
                                local wait_left = math.ceil(settings.project.wait_time - (os.clock() - t))
                                if app.drawPopup(gui.ctx, 'msg', scr.name .. '##wait', {
                                    closeKey = r.ImGui_Key_Escape(),
                                    okButtonLabel = "Stop rendering",
                                    msg = ('Waiting for %d more second%s...'):format(wait_left,
                                        wait_left > 1 and 's' or '')
                                }) then
                                    app.render_cancelled = true
                                end
                                coroutine.yield('Waiting...', idx, app.render_count)
                            end
                            r.OnStopButtonEx(0)
                        else
                            r.Main_OnCommand(41823, 0) -- add to render queue
                        end
                        if rsg.run_actions_after then
                            for aIdx, action in ipairs(rsg.actions_to_run_after or {}) do
                                action = (type(action) == 'string') and '_' .. action or action
                                local cmd = reaper.NamedCommandLookup(action)
                                if cmd then
                                    r.Main_OnCommand(cmd, 0)
                                end
                            end
                        end
                    end
                    laststemName = stemName
                end
            end
            app.render_cancelled = false
            db:toggleStemSync(db.stems[laststemName], SYNCMODE_OFF)
            -- restore marker/region selection if it was saved
            if save_marker_selection and r.APIExists('JS_Localize') then
                OpenAndGetRegionManagerWindow()
                coroutine.yield('Restoring marker/region selection', 1, 1)
                if os_is.win then
                    -- for some reason selecting in windows requires region manager window to remain open for some time
                    -- (this is a workaround until proper api support for selecting regions exists)
                    SelectRegionsOrMarkers(saved_markeregion_selection, false)
                    local t = os.clock()
                    while (os.clock() - t < 0.5) do
                        coroutine.yield('Restoring marker/region selection', idx, app.render_count)
                    end
                    r.Main_OnCommand(40326, 0) -- close region/marker manager
                else
                    SelectRegionsOrMarkers(saved_markeregion_selection)
                end
            end
            if save_time_selection then
                r.GetSet_LoopTimeRange2(0, true, false, saved_time_selection[1], saved_time_selection[2], 0) -- , boolean isLoop, number start, number end, boolean allowautoseek)
            end
            r.GetSetProjectInfo_String(0, "RENDER_PATTERN", saved_filename, true)
            coroutine.yield('Done', 1, 1)
        else
            coroutine.yield('Done', 0, 1)
        end
        return
    end

    local function checkExternalCommand()
        local raw_cmd = r.GetExtState(scr.context_name, 'EXTERNAL COMMAND')
        local cmd, arg = raw_cmd:match('^([%w_]+)%s*(.*)$')
        if cmd ~= '' and cmd ~= nil then
            r.SetExtState(scr.context_name, 'EXTERNAL COMMAND', '', false)
            if cmd == 'sync' then
                if arg then
                    stemName = db:findSimilarStem(arg, true)
                end
                if stemName then
                    if db.stems[stemName] then
                        db:toggleStemSync(db.stems[stemName],
                            (db.stems[stemName].sync == SYNCMODE_SOLO) and SYNCMODE_OFF or SYNCMODE_SOLO)
                    end
                end
            elseif (cmd == 'add') or (cmd == 'render') then
                if arg then
                    stemName = db:findSimilarStem(arg, true)
                end
                if stemName then
                    if db.stems[stemName] then
                        app.forceRenderAction = (cmd == 'add') and RENDERACTION_RENDERQUEUE_OPEN or RENDERACTION_RENDER
                        app.stem_to_render = stemName
                        app.coPerform = coroutine.create(doPerform)
                    end
                end
            elseif (cmd == 'add_rg') or (cmd == 'render_rg') then
                local renderGroup = tonumber(arg)
                if renderGroup and renderGroup >= 1 and renderGroup <= RENDER_SETTING_GROUPS_SLOTS then
                    app.forceRenderAction = (cmd == 'add_rg') and RENDERACTION_RENDERQUEUE_OPEN or RENDERACTION_RENDER
                    app.renderGroupToRender = renderGroup
                    app.coPerform = coroutine.create(doPerform)
                end
            elseif cmd == 'add_all' then
                app.forceRenderAction = RENDERACTION_RENDERQUEUE_OPEN
                app.coPerform = coroutine.create(doPerform)
            elseif cmd == 'render_all' then
                app.forceRenderAction = RENDERACTION_RENDER
                app.coPerform = coroutine.create(doPerform)
            end
        end
    end

    function app.drawPopup(ctx, popupType, title, data)
        local data = data or {}
        local center = {gui.mainWindow.pos[1] + gui.mainWindow.size[1] / 2,
                        gui.mainWindow.pos[2] + gui.mainWindow.size[2] / 2} -- {r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
        if popupType == 'singleInput' then
            local okPressed = nil
            local initVal = data.initVal or ''
            local okButtonLabel = data.okButtonLabel or 'OK'
            local validation = data.validation or function(origVal, val)
                return true
            end
            local bottom_lines = 2

            r.ImGui_SetNextWindowSize(ctx, 350, 110)
            r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
            if r.ImGui_BeginPopupModal(ctx, title, false, r.ImGui_WindowFlags_AlwaysAutoResize()) then
                gui.popups.title = title

                if r.ImGui_IsWindowAppearing(ctx) then
                    r.ImGui_SetKeyboardFocusHere(ctx)
                    gui.popups.singleInput.value = initVal -- gui.popups.singleInput.stem.name
                    gui.popups.singleInput.status = ""
                end
                local width = select(1, r.ImGui_GetContentRegionAvail(ctx))
                r.ImGui_PushItemWidth(ctx, width)
                retval, gui.popups.singleInput.value = r.ImGui_InputText(ctx, '##singleInput',
                    gui.popups.singleInput.value)

                r.ImGui_SetItemDefaultFocus(ctx)
                r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeight(ctx) * bottom_lines) -
                    r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()))
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), gui.st.col.error)
                r.ImGui_Text(ctx, gui.popups.singleInput.status)
                r.ImGui_PopStyleColor(ctx)
                if r.ImGui_Button(ctx, okButtonLabel) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
                    gui.popups.singleInput.status = validation(initVal, gui.popups.singleInput.value)
                    if gui.popups.singleInput.status == true then
                        okPressed = true
                        r.ImGui_CloseCurrentPopup(ctx)
                    end
                end
                r.ImGui_SameLine(ctx)
                if r.ImGui_Button(ctx, 'Cancel') or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
                    okPressed = false
                    r.ImGui_CloseCurrentPopup(ctx)
                end
                r.ImGui_EndPopup(ctx)
            end
            return okPressed, gui.popups.singleInput.value
        elseif popupType == 'msg' then
            local okPressed = nil
            local msg = data.msg or ''
            local showCancelButton = data.showCancelButton or false
            local textWidth, textHeight = r.ImGui_CalcTextSize(ctx, msg)
            local okButtonLabel = data.okButtonLabel or 'OK'
            local cancelButtonLabel = data.cancelButtonLabel or 'Cancel'
            local bottom_lines = 1
            local closeKey = data.closeKey or r.ImGui_Key_Enter()
            local cancelKey = data.cancelKey or r.ImGui_Key_Escape()

            r.ImGui_SetNextWindowSize(ctx, math.max(220, textWidth) +
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()) * 4, textHeight + 90)
            r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)

            if r.ImGui_BeginPopupModal(ctx, title, false,
                r.ImGui_WindowFlags_NoResize() + r.ImGui_WindowFlags_NoDocking()) then
                gui.popups.title = title

                local width = select(1, r.ImGui_GetContentRegionAvail(ctx))
                r.ImGui_PushItemWidth(ctx, width)

                local windowWidth, windowHeight = r.ImGui_GetWindowSize(ctx);
                r.ImGui_SetCursorPos(ctx, (windowWidth - textWidth) * .5, (windowHeight - textHeight) * .5);

                r.ImGui_TextWrapped(ctx, msg)
                r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeight(ctx) * bottom_lines) -
                    r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()))

                local buttonTextWidth = r.ImGui_CalcTextSize(ctx, okButtonLabel) +
                                            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2

                if showCancelButton then
                    buttonTextWidth = buttonTextWidth + r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) +
                                          r.ImGui_CalcTextSize(ctx, cancelButtonLabel) +
                                          r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2
                end
                r.ImGui_SetCursorPosX(ctx, (windowWidth - buttonTextWidth) * .5);

                if r.ImGui_Button(ctx, okButtonLabel) or r.ImGui_IsKeyPressed(ctx, closeKey) then
                    okPressed = true
                    r.ImGui_CloseCurrentPopup(ctx)
                end

                if showCancelButton then
                    r.ImGui_SameLine(ctx)
                    if r.ImGui_Button(ctx, cancelButtonLabel) or r.ImGui_IsKeyPressed(ctx, cancelKey) then
                        okPressed = false
                        r.ImGui_CloseCurrentPopup(ctx)
                    end
                end

                r.ImGui_EndPopup(ctx)
            end
            return okPressed
        elseif popupType == 'stemActionsMenu' then
            if r.ImGui_BeginPopup(ctx, title) then
                if r.ImGui_Selectable(ctx, 'Rename', false, r.ImGui_SelectableFlags_DontClosePopups()) then
                    gui.popups.object = data.stemName;
                    r.ImGui_OpenPopup(ctx, 'Rename Stem')
                end
                local retval, newval = app.drawPopup(ctx, 'singleInput', 'Rename Stem', {
                    initVal = data.stemName,
                    okButtonLabel = 'Rename',
                    validation = validators.stem.name
                })
                if retval == true then
                    db:renameStem(data.stemName, newval)
                end
                if retval ~= nil then
                    gui.popups.object = nil;
                    r.ImGui_CloseCurrentPopup(ctx)
                end -- could be true (ok) or false (cancel)
                app.setHoveredHint('main', 'Rename stem')
                if r.ImGui_Selectable(ctx, 'Add to render queue', false) then
                    app.stem_to_render = data.stemName;
                    app.forceRenderAction = RENDERACTION_RENDERQUEUE_OPEN;
                    app.coPerform = coroutine.create(doPerform)
                end
                app.setHoveredHint('main', "Add this stem only to the render queue")
                if r.ImGui_Selectable(ctx, 'Render now', false) then
                    app.stem_to_render = data.stemName;
                    app.forceRenderAction = RENDERACTION_RENDER;
                    app.coPerform = coroutine.create(doPerform)
                end
                app.setHoveredHint('main', "Render this stem only")
                if r.ImGui_Selectable(ctx, 'Get states from tracks', false) then
                    db:reflectAllTracksOnStem(data.stemName)
                end
                app.setHoveredHint('main', "Get current solo/mute states from the project's tracks.")
                if r.ImGui_Selectable(ctx, 'Set states on tracks', false) then
                    db:reflectStemOnAllTracks(data.stemName)
                end
                app.setHoveredHint('main', "Set this stem's solo/mute states on the project's tracks.")
                if r.ImGui_Selectable(ctx, 'Clear states', false) then
                    db:resetStem(data.stemName)
                end
                app.setHoveredHint('main', "Clear current stem solo/mute states.")
                r.ImGui_Separator(ctx)
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), gui.st.col.critical)
                if r.ImGui_Selectable(ctx, 'Delete', false) then
                    db:removeStem(data.stemName)
                end
                r.ImGui_PopStyleColor(ctx)
                app.setHoveredHint('main', 'Delete stem')
                if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
                    r.ImGui_CloseCurrentPopup(ctx)
                end
                r.ImGui_EndPopup(ctx)
            end
        elseif popupType == 'renderPresetSelector' then
            local selectedPreset = nil
            -- r.ImGui_SetNextWindowSize(ctx,0,100)
            r.ImGui_SetNextWindowSizeConstraints(ctx, 0, 100, 1000, 250)
            if r.ImGui_BeginPopup(ctx, title) then
                gui.popups.title = title
                local presetCount = 0
                for i, preset in pairs(db.renderPresets) do
                    presetCount = presetCount + 1
                    if r.ImGui_Selectable(ctx, preset.name, false) then
                        selectedPreset = preset.name
                    end
                end
                if presetCount == 0 then
                    r.ImGui_Text(ctx,
                        "No render presets found.\nPlease create and add presets using\nREAPER's render window preset button.")
                end
                r.ImGui_EndPopup(ctx)
            end
            return not (selectedPreset == nil), selectedPreset
        end
        return false
    end

    -- only works with monospace (90 degree) fonts
    function verticalText(ctx, text)
        r.ImGui_PushFont(ctx, gui.st.fonts.vertical)
        local letterspacing = (gui.VERTICAL_TEXT_BASE_HEIGHT + gui.VERTICAL_TEXT_BASE_HEIGHT_OFFSET)
        local posX, posY = r.ImGui_GetCursorPosX(ctx), r.ImGui_GetCursorPosY(ctx) - letterspacing * #text
        text = text:reverse()
        for ci = 1, #text do
            r.ImGui_SetCursorPos(ctx, posX, posY + letterspacing * (ci - 1))
            r.ImGui_Text(ctx, text:sub(ci, ci))
        end
        r.ImGui_PopFont(ctx)
    end

    function app.drawBtn(btnType, data)
        local ctx = gui.ctx
        local cellSize = gui.st.vars.mtrx.cellSize
        local headerRowHeight = gui.st.vars.mtrx.headerRowHeight
        local modKeys = gui.modKeys
        local clicked = false
        if btnType == 'stemSync' then
            local stemSyncMode = data.stemSyncMode
            local generalSyncMode = data.generalSyncMode
            local isSyncing = ((stemSyncMode ~= SYNCMODE_OFF) and (stemSyncMode ~= nil))
            local displayedSyncMode = isSyncing and stemSyncMode or generalSyncMode -- if stem is syncing, show its mode, otherwise, show mode based on preferences+alt key
            local altSyncMode = (displayedSyncMode == SYNCMODE_SOLO) and SYNCMODE_SOLO or SYNCMODE_MIRROR
            local btnColor = isSyncing and gui.st.col.stemSyncBtn[displayedSyncMode].active or
                                 gui.st.col.stemSyncBtn[displayedSyncMode].inactive
            local circleColor = isSyncing and gui.st.col.stemSyncBtn[displayedSyncMode].active[r.ImGui_Col_Text()] or
                                    gui.st.col.stemSyncBtn[displayedSyncMode].active[r.ImGui_Col_Button()]
            local centerPosX, centerPosY = select(1, r.ImGui_GetCursorScreenPos(ctx)) + cellSize / 2,
                select(2, r.ImGui_GetCursorScreenPos(ctx)) + cellSize / 2
            r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) + 1)
            gui:pushColors(btnColor)
            if r.ImGui_Button(ctx, " ", cellSize, cellSize) then
                clicked = true
            end
            if r.ImGui_IsItemHovered(ctx) then
                r.ImGui_SetMouseCursor(ctx, 7)
            end
            r.ImGui_DrawList_AddCircle(gui.draw_list, centerPosX, centerPosY, 5, circleColor, 0, 2)
            gui:popColors(btnColor)
            if isSyncing then
                app.setHoveredHint('main', ("Stem is mirrored (%s). Click to stop mirroring."):format(
                    SYNCMODE_DESCRIPTIONS[displayedSyncMode]))
            else
                if modKeys == 'a' then
                    app.setHoveredHint('main', ("%s+click to mirror stem (%s)."):format(
                        gui.descModAlt:gsub("^%l", string.upper), SYNCMODE_DESCRIPTIONS[altSyncMode]))
                else
                    app.setHoveredHint('main',
                        ("Click to mirror stem (%s)."):format(SYNCMODE_DESCRIPTIONS[displayedSyncMode]))
                end
            end
        elseif btnType == 'stemActions' then
            local topLeftX, topLeftY = data.topLeftX, data.topLeftY
            local centerPosX, centerPosY = topLeftX + cellSize / 2, topLeftY + cellSize / 2
            local sz, radius = 4.5, 1.5
            local color = gui.st.col.button[r.ImGui_Col_Text()]
            gui:pushColors(gui.st.col.button)
            if r.ImGui_Button(ctx, '##stemActions', cellSize, cellSize) then
                r.ImGui_OpenPopup(ctx, '##stemActions')
            end
            gui:popColors(gui.st.col.button)
            r.ImGui_DrawList_AddCircleFilled(gui.draw_list, centerPosX - sz, centerPosY, radius, color, 8)
            r.ImGui_DrawList_AddCircleFilled(gui.draw_list, centerPosX, centerPosY, radius, color, 8)
            r.ImGui_DrawList_AddCircleFilled(gui.draw_list, centerPosX + sz, centerPosY, radius, color, 8)
            app.setHoveredHint('main', 'Stem actions')
        elseif btnType == 'addStem' then
            gui:pushColors(gui.st.col.button)
            r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) + 1)
            if r.ImGui_Button(ctx, '##addStem', cellSize, headerRowHeight) then
                clicked = true
            end
            gui:popColors(gui.st.col.button)
            local centerPosX = select(1, r.ImGui_GetCursorScreenPos(ctx)) + cellSize / 2
            local centerPosY = select(2, r.ImGui_GetCursorScreenPos(ctx)) - headerRowHeight / 2
            local color = gui.st.col.button[r.ImGui_Col_Text()] -- gui.st.col.stemSyncBtn.active[r.ImGui_Col_Text()] or gui.st.col.stemSyncBtn.active[r.ImGui_Col_Button()]
            r.ImGui_DrawList_AddLine(gui.draw_list, centerPosX - cellSize / 5, centerPosY, centerPosX + cellSize / 5,
                centerPosY, color, 2)
            r.ImGui_DrawList_AddLine(gui.draw_list, centerPosX, centerPosY - cellSize / 5, centerPosX,
                centerPosY + cellSize / 5, color, 2)
            if modKeys ~= "c" then
                app.setHoveredHint('main', ('Click to create a new stem %s.'):format(
                    REFLECT_ON_ADD_DESCRIPTIONS[settings.project.reflect_on_add]))
            else
                app.setHoveredHint('main',
                    ('%s+click to create a new stem %s.'):format(gui.descModCtrlCmd:gsub("^%l", string.upper),
                        REFLECT_ON_ADD_DESCRIPTIONS[(settings.project.reflect_on_add == REFLECT_ON_ADD_TRUE) and
                            REFLECT_ON_ADD_FALSE or REFLECT_ON_ADD_TRUE]))
            end
        elseif btnType == 'renderGroupSelector' then
            local stemName = data.stemName
            local stGrp = data.stGrp
            gui:pushColors(gui.st.col.render_setting_groups[stGrp])
            gui:pushStyles(gui.st.vars.mtrx.stemState)
            local origPosX, origPosY = r.ImGui_GetCursorPos(ctx)
            origPosY = origPosY + 1
            r.ImGui_SetCursorPosY(ctx, origPosY)
            local color = gui.st.col.render_setting_groups[stGrp][r.ImGui_Col_Button()]
            local topLeftX, topLeftY = r.ImGui_GetCursorScreenPos(ctx)
            r.ImGui_DrawList_AddRectFilled(gui.draw_list, topLeftX, topLeftY, topLeftX + cellSize, topLeftY + cellSize,
                color)
            r.ImGui_SetCursorPosY(ctx, origPosY)
            r.ImGui_Dummy(ctx, cellSize, cellSize)
            app.setHoveredHint('main',
                'Stem to be rendered by settings group ' .. stGrp .. '. Click arrows to change group.')
            if r.ImGui_IsItemHovered(ctx) then
                local description = settings.project.render_setting_groups[stGrp].description
                if description ~= nil and description ~= '' then
                    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(),
                        gui.st.col.render_setting_groups[stGrp][r.ImGui_Col_Button()])
                    r.ImGui_SetTooltip(ctx, description)
                    r.ImGui_PopStyleColor(ctx)
                end
                local centerX = r.ImGui_GetCursorScreenPos(ctx) + cellSize / 2
                local color = gui.st.col.render_setting_groups[stGrp][r.ImGui_Col_Text()]
                local sz = 5
                r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) - cellSize)
                local startY = select(2, r.ImGui_GetCursorScreenPos(ctx))
                r.ImGui_Button(ctx, '###up' .. stemName, cellSize, cellSize / 3)
                if r.ImGui_IsItemClicked(ctx) then
                    db.stems[stemName].render_setting_group = (stGrp == RENDER_SETTING_GROUPS_SLOTS) and 1 or stGrp + 1
                    db:save()
                end
                if r.ImGui_IsItemHovered(ctx) then
                    r.ImGui_SetMouseCursor(ctx, 7)
                end
                r.ImGui_DrawList_AddTriangleFilled(gui.draw_list, centerX, startY, centerX - sz * .5, startY + sz,
                    centerX + sz * .5, startY + sz, color)
                app.setHoveredHint('main', ('Change to setting group %d.'):format(
                    (stGrp == RENDER_SETTING_GROUPS_SLOTS) and 1 or stGrp + 1))
                sz = sz + 1
                r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) + cellSize / 3)
                local startY = select(2, r.ImGui_GetCursorScreenPos(ctx)) + cellSize / 3 - sz
                r.ImGui_Button(ctx, '###down' .. stemName, cellSize, cellSize / 3)
                if r.ImGui_IsItemClicked(ctx) then
                    db.stems[stemName].render_setting_group = (stGrp == 1) and RENDER_SETTING_GROUPS_SLOTS or stGrp - 1
                    db:save()
                end
                if r.ImGui_IsItemHovered(ctx) then
                    r.ImGui_SetMouseCursor(ctx, 7)
                end
                r.ImGui_DrawList_AddTriangleFilled(gui.draw_list, centerX - sz * .5, startY, centerX + sz * .5, startY,
                    centerX, startY + sz, color)
                app.setHoveredHint('main', ('Change to setting group %d.'):format(
                    (stGrp == 1) and RENDER_SETTING_GROUPS_SLOTS or stGrp - 1))
            end
            local textSizeX, textSizeY = r.ImGui_CalcTextSize(ctx, tostring(stGrp))
            r.ImGui_SetCursorPos(ctx, origPosX + (cellSize - textSizeX) / 2, origPosY + (cellSize - textSizeY) / 2)
            r.ImGui_Text(ctx, stGrp)
            gui:popColors(gui.st.col.render_setting_groups[stGrp])
            gui:popStyles(gui.st.vars.mtrx.stemState)
        elseif btnType == 'stemState' then
            local state = data.state
            local track = data.track
            local stemName = data.stemName
            local stem = db.stems[stemName]
            local color_state = ((state == ' ') and (stem.sync ~= SYNCMODE_OFF) and (stem.sync ~= nil)) and
                                    {'sync_' .. stem.sync, 'sync_' .. stem.sync} or STATE_COLORS[state]
            local curScrPos = {r.ImGui_GetCursorScreenPos(ctx)}
            curScrPos[2] = curScrPos[2] + 1
            local text_size = {r.ImGui_CalcTextSize(ctx, STATE_LABELS[state])}
            r.ImGui_SetCursorScreenPos(ctx, curScrPos[1], curScrPos[2])
            r.ImGui_Dummy(ctx, cellSize, cellSize)
            local col_a, col_b
            if r.ImGui_IsItemHovered(ctx, r.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem()) then
                col_a = gui.st.col.stemState[color_state[1]][r.ImGui_Col_ButtonHovered()]
                col_b = gui.st.col.stemState[color_state[2]][r.ImGui_Col_ButtonHovered()]
            else
                col_a = gui.st.col.stemState[color_state[1]][r.ImGui_Col_Button()]
                col_b = gui.st.col.stemState[color_state[2]][r.ImGui_Col_Button()]
            end
            r.ImGui_DrawList_AddRectFilled(gui.draw_list, curScrPos[1], curScrPos[2], curScrPos[1] + cellSize / 2,
                curScrPos[2] + cellSize, col_a)
            r.ImGui_DrawList_AddRectFilled(gui.draw_list, curScrPos[1] + cellSize / 2, curScrPos[2],
                curScrPos[1] + cellSize, curScrPos[2] + cellSize, col_b)
            r.ImGui_SetCursorScreenPos(ctx, curScrPos[1] + (cellSize - text_size[1]) / 2,
                curScrPos[2] + (cellSize - text_size[2]) / 2)
            r.ImGui_TextColored(ctx, gui.st.col.stemState[color_state[1]][r.ImGui_Col_Text()], STATE_LABELS[state])
            r.ImGui_SetCursorScreenPos(ctx, curScrPos[1], curScrPos[2])
            r.ImGui_InvisibleButton(ctx, '##' .. track.name .. state .. stemName, cellSize, cellSize)
            if r.ImGui_IsItemHovered(ctx, r.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem()) then
                r.ImGui_SetMouseCursor(ctx, 7)
                local defaultSolo = db.prefSoloIP and STATES.SOLO_IN_PLACE or STATES.SOLO_IGNORE_ROUTING
                local otherSolo = db.prefSoloIP and STATES.SOLO_IGNORE_ROUTING or STATES.SOLO_IN_PLACE
                local defaultMSolo = db.prefSoloIP and STATES.MUTE_SOLO_IN_PLACE or STATES.MUTE_SOLO_IGNORE_ROUTING
                local otherMSolo = db.prefSoloIP and STATES.MUTE_SOLO_IGNORE_ROUTING or STATES.MUTE_SOLO_IN_PLACE
                local currentStateDesc = (state ~= ' ') and ('Track is %s. '):format(STATE_DESCRIPTIONS[state][2]) or ''
                local stateSwitches = {
                    [''] = {
                        state = defaultSolo,
                        hint = ('%sClick to %s.'):format(currentStateDesc, (state == defaultSolo) and 'clear' or
                            STATE_DESCRIPTIONS[defaultSolo][1])
                    },
                    ['s'] = {
                        state = STATES.MUTE,
                        hint = ('%sShift+click to %s.'):format(currentStateDesc, (state == STATES.MUTE) and 'clear' or
                            STATE_DESCRIPTIONS[STATES.MUTE][1])
                    },
                    ['c'] = {
                        state = otherSolo,
                        hint = ('%s%s+click to %s.'):format(currentStateDesc,
                            gui.descModCtrlCmd:gsub("^%l", string.upper), (state == otherSolo) and 'clear' or
                                STATE_DESCRIPTIONS[otherSolo][1])
                    },
                    ['sa'] = {
                        state = defaultMSolo,
                        hint = ('%sShift+%s+click to %s.'):format(currentStateDesc, gui.descModAlt, (state ==
                            defaultMSolo) and 'clear' or STATE_DESCRIPTIONS[defaultMSolo][1])
                    },
                    ['sc'] = {
                        state = otherMSolo,
                        hint = ('%sShift+%s+click to %s.'):format(currentStateDesc, gui.descModCtrlCmd, (state ==
                            otherMSolo) and 'clear' or STATE_DESCRIPTIONS[otherMSolo][1])
                    },
                    ['a'] = {
                        state = ' ',
                        hint = ('%s%s'):format(currentStateDesc,
                            ('%s+click to clear.'):format(gui.descModAlt:gsub("^%l", string.upper)))
                    }
                }
                if stateSwitches[modKeys] then
                    app.setHint('main', stateSwitches[modKeys].hint)
                    if gui.mtrxTbl.drgState == nil and r.ImGui_IsMouseClicked(ctx, r.ImGui_MouseButton_Left()) then
                        gui.mtrxTbl.drgState = (state == stateSwitches[modKeys]['state']) and ' ' or
                                                   stateSwitches[modKeys]['state']
                    elseif gui.mtrxTbl.drgState and gui.mtrxTbl.drgState ~= state then
                        db:setTrackStateInStem(track, stemName, gui.mtrxTbl.drgState)
                    end
                end
            end
        end
        return clicked
    end

    app.drawCols = {}
    function app.drawCols.stemName(stemName)
        local ctx = gui.ctx
        local cellSize = gui.st.vars.mtrx.cellSize
        local headerRowHeight = gui.st.vars.mtrx.headerRowHeight
        local defPadding = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
        local topLeftX, topLeftY = r.ImGui_GetCursorScreenPos(ctx)
        local stem = db.stems[stemName]
        r.ImGui_PushID(ctx, stemName)
        r.ImGui_SetCursorPos(ctx, r.ImGui_GetCursorPosX(ctx) +
            (r.ImGui_GetContentRegionAvail(ctx) - gui.VERTICAL_TEXT_BASE_WIDTH) / 2,
            r.ImGui_GetCursorPosY(ctx) + headerRowHeight - defPadding)
        verticalText(ctx, stemName)
        if r.ImGui_IsMouseHoveringRect(ctx, topLeftX, topLeftY, topLeftX + cellSize, topLeftY + headerRowHeight) and
            not r.ImGui_IsPopupOpen(ctx, '', r.ImGui_PopupFlags_AnyPopup()) or r.ImGui_IsPopupOpen(ctx, '##stemActions') then
            r.ImGui_SetCursorScreenPos(ctx, topLeftX, topLeftY + 1)
            gui:popStyles(gui.st.vars.mtrx.table)
            app.drawBtn('stemActions', {
                topLeftX = topLeftX,
                topLeftY = topLeftY
            })
            app.drawPopup(ctx, 'stemActionsMenu', '##stemActions', {
                stemName = stemName
            })
            gui:pushStyles(gui.st.vars.mtrx.table)
        end
        r.ImGui_SetCursorScreenPos(ctx, topLeftX + 4, topLeftY + 4)
        r.ImGui_InvisibleButton(ctx, '##stemDrag', cellSize - 8, headerRowHeight - 6)
        if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_None()) then
            r.ImGui_SetDragDropPayload(ctx, 'STEM_COL', stemName)
            r.ImGui_Text(ctx, ('Move %s...'):format(stemName))
            r.ImGui_EndDragDropSource(ctx)
        end
        if r.ImGui_BeginDragDropTarget(ctx) then
            local payload
            rv, payload = r.ImGui_AcceptDragDropPayload(ctx, 'STEM_COL')
            if rv then
                db:reorderStem(payload, stem.order)
            end
            r.ImGui_EndDragDropTarget(ctx)
        end
        r.ImGui_PopID(ctx)
    end

    function app.drawMatrices(ctx, bottom_lines)
        local cellSize = gui.st.vars.mtrx.cellSize
        local childHeight = select(2, r.ImGui_GetContentRegionAvail(ctx)) -
                                (r.ImGui_GetFrameHeightWithSpacing(ctx) * bottom_lines +
                                    r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) * 2)
        local defPadding = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
        local modKeys = gui:updateModKeys()
        -- if r.ImGui_CollapsingHeader(ctx,"Stem Selection",false,r.ImGui_TreeNodeFlags_DefaultOpen()) then
        if r.ImGui_BeginChild(ctx, 'stemSelector', 0, childHeight) then
            r.ImGui_PushFont(ctx, gui.st.fonts.default)
            if gui.mtrxTbl.drgState and r.ImGui_IsMouseReleased(ctx, r.ImGui_MouseButton_Left()) then
                gui.mtrxTbl.drgState = nil
            end -- needs to stop dragging before drag affects released hovered item to prevent edge case
            gui:pushStyles(gui.st.vars.mtrx.table)
            gui:pushColors(gui.st.col.trackname)
            local trackListX, trackListY, trackListWidth, trackListHeight
            trackListWidth = r.ImGui_GetContentRegionAvail(ctx) -
                                 r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ScrollbarSize())
            if r.ImGui_BeginTable(ctx, 'table_scrollx', 1 + db.stemCount + 1, gui.tables.horizontal.flags1) then
                --- SETUP MATRIX TABLE
                local parent_open, depth, open_depth = true, 0, 0
                r.ImGui_TableSetupScrollFreeze(ctx, 1, 3)
                r.ImGui_TableSetupColumn(ctx, 'Track', r.ImGui_TableColumnFlags_NoHide(), width) -- Make the first column not hideable to match our use of TableSetupScrollFreeze()
                for stemName, tracks in pairsByOrder(db.stems) do
                    r.ImGui_TableSetupColumn(ctx, stemName, nil, cellSize)
                end
                --- STEM NAME ROW
                local maxletters = 0
                for k in pairs(db.stems) do
                    maxletters = math.max(maxletters, #k)
                end
                gui.st.vars.mtrx.headerRowHeight = math.max(cellSize * 3, (gui.VERTICAL_TEXT_BASE_HEIGHT +
                    gui.VERTICAL_TEXT_BASE_HEIGHT_OFFSET) * maxletters + defPadding * 4)
                local headerRowHeight = gui.st.vars.mtrx.headerRowHeight
                r.ImGui_TableNextRow(ctx)
                r.ImGui_TableNextColumn(ctx)
                -- STEM NAME ROW
                -- COL: TRACK/STEM CORNER HEADER ROW
                local x, y = r.ImGui_GetCursorPos(ctx)
                r.ImGui_Dummy(ctx, 230, 0) -- forces a minimum size to the track name col when no tracks exist
                local stemsTitleSizeX, stemsTitleSizeY = r.ImGui_CalcTextSize(ctx, 'Stems')
                r.ImGui_SetCursorPos(ctx, x + r.ImGui_GetContentRegionAvail(ctx) - stemsTitleSizeY,
                    y + headerRowHeight - defPadding)
                verticalText(ctx, 'Stems')
                r.ImGui_SetCursorPos(ctx, x + defPadding, y + (headerRowHeight) - stemsTitleSizeY - defPadding)
                r.ImGui_Text(ctx, 'Tracks')
                -- COL: STEM NAMES
                for k, stem in pairsByOrder(db.stems) do
                    if r.ImGui_TableNextColumn(ctx) then
                        app.drawCols.stemName(k)
                    end
                end
                r.ImGui_TableNextColumn(ctx)
                -- COL: ADD STEM BUTTON
                if app.drawBtn('addStem') then
                    if modKeys ~= "c" then
                        app.copyOnAddStem = (settings.project.reflect_on_add == REFLECT_ON_ADD_TRUE)
                    else
                        app.copyOnAddStem = (settings.project.reflect_on_add == REFLECT_ON_ADD_FALSE)
                    end
                    r.ImGui_OpenPopup(ctx, 'Add Stem')
                end
                gui:popStyles(gui.st.vars.mtrx.table)
                local retval, newval = app.drawPopup(ctx, 'singleInput', 'Add Stem', {
                    okButtonLabel = 'Add',
                    validation = validators.stem.name
                })
                if retval then
                    db:addStem(newval, app.copyOnAddStem)
                    app.copyOnAddStem = nil
                end
                gui:pushStyles(gui.st.vars.mtrx.table)
                -- RENDER GROUPS
                -- COL: TRACK NAME
                r.ImGui_TableNextRow(ctx, r.ImGui_TableRowFlags_Headers(), cellSize)
                if r.ImGui_TableNextColumn(ctx) then
                    r.ImGui_AlignTextToFramePadding(ctx)
                    r.ImGui_SetCursorPosX(ctx, r.ImGui_GetCursorPosX(ctx) + defPadding * 2)
                    r.ImGui_Text(ctx, 'Render Setting Groups')
                end
                -- COL: STEM RENDER GROUP
                for k, stem in pairsByOrder(db.stems) do
                    if r.ImGui_TableNextColumn(ctx) then
                        app.drawBtn('renderGroupSelector', {
                            stemName = k,
                            stGrp = stem.render_setting_group or 1
                        })
                    end
                end
                -- TRACK NAME & SYNC BUTTONS
                -- COL: TRACK NAME
                r.ImGui_TableNextRow(ctx, r.ImGui_TableRowFlags_Headers(), cellSize)
                if r.ImGui_TableNextColumn(ctx) then
                    trackListX, trackListY = select(1, r.ImGui_GetCursorScreenPos(ctx)),
                        select(2, r.ImGui_GetCursorScreenPos(ctx)) + cellSize + 1
                    trackListHeight = r.ImGui_GetCursorPosY(ctx) + select(2, r.ImGui_GetContentRegionAvail(ctx)) -
                                          cellSize - headerRowHeight - 2
                    r.ImGui_AlignTextToFramePadding(ctx)
                    r.ImGui_SetCursorPosX(ctx, r.ImGui_GetCursorPosX(ctx) + defPadding * 2)
                    r.ImGui_Text(ctx, 'Mirror stem')
                end
                -- COLS: STEM SYNC BUTTONS
                for k, stem in pairsByOrder(db.stems) do
                    r.ImGui_PushID(ctx, 'sync' .. k)
                    if r.ImGui_TableNextColumn(ctx) then
                        local syncMode = (modKeys == 'a') and
                                             ((settings.project.syncmode == SYNCMODE_MIRROR) and SYNCMODE_SOLO or
                                                 SYNCMODE_MIRROR) or settings.project.syncmode
                        if app.drawBtn('stemSync', {
                            stemSyncMode = stem.sync,
                            generalSyncMode = syncMode
                        }) then
                            db:toggleStemSync(stem, ((stem.sync == SYNCMODE_OFF) or (stem.sync == nil)) and syncMode or
                                SYNCMODE_OFF)
                        end
                    end
                    r.ImGui_PopID(ctx)
                end
                -- TRACK LIST
                local draw_list_w = r.ImGui_GetBackgroundDrawList(ctx)
                local last_open_track = nil
                local arrow_drawn = {}
                for i = 1, r.GetNumTracks() do
                    local track = db.tracks[i]
                    local depth_delta = math.max(track.folderDepth, -depth) -- prevent depth + delta being < 0
                    local is_folder = depth_delta > 0
                    local hide = (not settings.project.show_hidden_tracks) and track.hidden

                    if parent_open or depth <= open_depth then
                        if not hide then
                            arrow_drawn = {}
                            --- ROW
                            for level = depth, open_depth - 1 do
                                r.ImGui_TreePop(ctx);
                                open_depth = depth
                            end -- close previously open deeper folders

                            last_open_track = track
                            r.ImGui_TableNextRow(ctx, nil, cellSize)
                            -- these lines two solve an issue where upon scrolling the top row gets above the header row (happens from rows 2 onward)
                            r.ImGui_DrawList_PushClipRect(gui.draw_list, trackListX,
                                trackListY + (cellSize + 1) * (i - 1), trackListX + trackListWidth,
                                trackListY + (cellSize + 1) * (i - 1) + cellSize, false)
                            -- COL: TRACK COLOR + NAME
                            r.ImGui_TableNextColumn(ctx)
                            r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) + 1)
                            r.ImGui_ColorButton(ctx, 'color', r.ImGui_ColorConvertNative(track.color),
                                r.ImGui_ColorEditFlags_NoAlpha() | r.ImGui_ColorEditFlags_NoBorder() |
                                    r.ImGui_ColorEditFlags_NoTooltip(), cellSize, cellSize)
                            r.ImGui_SameLine(ctx)
                            local node_flags = is_folder and gui.treeflags.base or gui.treeflags.leaf
                            r.ImGui_PushID(ctx, i) -- Tracks might have the same name
                            parent_open = r.ImGui_TreeNode(ctx, track.name .. '  ', node_flags)
                            r.ImGui_PopID(ctx)
                            for k, stem in pairsByOrder(db.stems) do
                                if r.ImGui_TableNextColumn(ctx) then
                                    -- COL: STEM STATE
                                    app.drawBtn('stemState', {
                                        track = track,
                                        stemName = k,
                                        state = track.stemMatrix[k] or ' '
                                    })
                                end
                            end
                            r.ImGui_DrawList_PopClipRect(gui.draw_list)
                        end
                    elseif depth > open_depth then
                        --- HIDDEN SOLO STATES
                        local idx = 0
                        for k, stem in pairsByOrder(db.stems) do
                            idx = idx + 1
                            -- local state = track.stemMatrix[k] or ' '
                            if not arrow_drawn[k] then
                                local offsetX, offsetY = cellSize / 2, -1
                                if not (track.stemMatrix[k] == ' ') and not (track.stemMatrix[k] == nil) then
                                    if r.ImGui_TableSetColumnIndex(ctx, idx) then
                                        r.ImGui_SameLine(ctx)
                                        r.ImGui_Dummy(ctx, 0, 0)
                                        local sz = 5 -- ((last_open_track.stemMatrix[k] == nil) or (last_open_track.stemMatrix[k] == ' ' )) and (cellSize-4) or 6
                                        local posX = select(1, r.ImGui_GetCursorScreenPos(ctx)) -- +offsetX
                                        local posY = select(2, r.ImGui_GetCursorScreenPos(ctx)) - sz -- +offsetY
                                        local color =
                                            gui.st.col.hasChildren[(last_open_track.stemMatrix[k] or ' ')][r.ImGui_Col_Text()]
                                        r.ImGui_DrawList_AddRectFilled(gui.draw_list, posX, posY, posX + cellSize,
                                            posY + sz, color)
                                        if r.ImGui_IsMouseHoveringRect(ctx, posX, posY, posX + cellSize, posY + sz) then
                                            app.setHint('main',
                                                'This folder track has hidden children tracks that are soloed/muted.')
                                        end
                                        arrow_drawn[k] = true
                                    end
                                end
                            end
                        end
                    end
                    depth = depth + depth_delta
                    if (not hide) and is_folder and parent_open then
                        open_depth = depth
                    end
                end
                for level = 0, open_depth - 1 do
                    r.ImGui_TreePop(ctx)
                end
                r.ImGui_EndTable(ctx)
                gui:popColors(gui.st.col.trackname)
                gui:popStyles(gui.st.vars.mtrx.table)
            end
            r.ImGui_PopFont(ctx)
            r.ImGui_EndChild(ctx)
        end
    end

    function app.drawSettings()
        local ctx = gui.ctx
        local bottom_lines = 2
        local rv
        local x, y = r.ImGui_GetMousePos(ctx)
        local center = {gui.mainWindow.pos[1] + gui.mainWindow.size[1] / 2,
                        gui.mainWindow.pos[2] + gui.mainWindow.size[2] / 2} -- {r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
        local currentSettings
        local halfWidth = 230
        local itemWidth = halfWidth * 2
        local renderaction_list = ''
        local cP = r.EnumProjects(-1)
        local projectChanged
        if oldcP ~= cP then
            oldcP = cP
            projectChanged = true
        end
        gui.stWnd[cP] = gui.stWnd[cP] or {}
        for i = 0, #RENDERACTION_DESCRIPTIONS do
            renderaction_list = renderaction_list .. RENDERACTION_DESCRIPTIONS[i] .. '\0'
        end

        local reflect_on_add_list = ''
        for i = 0, #REFLECT_ON_ADD_DESCRIPTIONS do
            reflect_on_add_list = reflect_on_add_list .. REFLECT_ON_ADD_DESCRIPTIONS[i] .. '\0'
        end

        local syncmode_list = ''
        for i = 0, #SYNCMODE_DESCRIPTIONS do
            syncmode_list = syncmode_list .. SYNCMODE_DESCRIPTIONS[i] .. '\0'
        end

        local function setting(stType, text, hint, val, data, sameline)
            local data = data or {}
            local retval
            local widgetWidth
            if not sameline then
                r.ImGui_BeginGroup(ctx)
                r.ImGui_AlignTextToFramePadding(ctx)
                r.ImGui_PushTextWrapPos(ctx, halfWidth)
                r.ImGui_Text(ctx, text)
                r.ImGui_PopTextWrapPos(ctx)
                r.ImGui_SameLine(ctx)
                r.ImGui_SetCursorPosX(ctx, halfWidth)
                widgetWidth = itemWidth

            else
                r.ImGui_SameLine(ctx)
                r.ImGui_SetCursorPosX(ctx, r.ImGui_GetCursorPosX(ctx) -
                    r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemInnerSpacing()))
                widgetWidth = itemWidth - gui.TEXT_BASE_WIDTH * 2 -
                                  r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2
            end
            r.ImGui_PushItemWidth(ctx, widgetWidth)

            if stType == 'combo' then
                _, retval = r.ImGui_Combo(ctx, '##' .. text, val, data.list)
            elseif stType == 'checkbox' then
                _, retval = r.ImGui_Checkbox(ctx, '##' .. text, val)
            elseif stType == 'dragint' then
                _, retval = r.ImGui_DragInt(ctx, '##' .. text, val, data.step, data.min, data.max)
            elseif stType == 'button' then
                retval = r.ImGui_Button(ctx, data.label, widgetWidth)
            elseif stType == 'text' then
                _, retval = r.ImGui_InputText(ctx, '##' .. text, val)
            elseif stType == 'text_with_hint' then
                _, retval = r.ImGui_InputTextWithHint(ctx, '##' .. text, data.hint, val)
            end
            if not sameline then
                r.ImGui_EndGroup(ctx)
            end
            app.setHoveredHint('settings', hint)
            return retval, retval_b
        end

        local function setting_special(text, main_hint, stType, valA, valB, valC)
            local retChecked, retval_a, retval_b = valA, valB, valC
            retChecked = setting('checkbox', text, main_hint, retChecked)
            if retChecked then
                r.ImGui_SameLine(ctx)
                local widgetX = r.ImGui_GetCursorPosX(ctx) -
                                    r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemInnerSpacing())
                r.ImGui_SetCursorPosX(ctx, widgetX)
                if (stType == 'region' or stType == 'marker') and not r.APIExists('JS_Localize') then
                    r.ImGui_TextColored(ctx, gui.st.col.error,
                        ('js_ReaScriptAPI needed for selecting %ss.'):format(stType))
                else
                    local widgetWidth = itemWidth - gui.TEXT_BASE_WIDTH * 2 -
                                            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2
                    if stType == 'time_sel' then
                        local clicked = r.ImGui_Button(ctx, 'Capture time selection', widgetWidth)
                        app.setHoveredHint('settings',
                            'Make a time selection and click to capture its start and end positions.')

                        if clicked then
                            retval_a, retval_b = r.GetSet_LoopTimeRange(0, 0, 0, 0, 0) -- , boolean isLoop, number start, number end, boolean allowautoseek)
                        end
                        r.ImGui_SetCursorPosX(ctx, widgetX)
                        if r.ImGui_BeginChildFrame(ctx, '##timeselstart', widgetWidth / 2 -
                            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemInnerSpacing()) / 2,
                            r.ImGui_GetFrameHeight(ctx)) then
                            r.ImGui_Text(ctx, r.format_timestr_pos(retval_a, '', 5))
                            r.ImGui_EndChildFrame(ctx)
                        end
                        app.setHoveredHint('settings', "Time seleciton start.")
                        r.ImGui_SameLine(ctx)
                        r.ImGui_SetCursorPosX(ctx, r.ImGui_GetCursorPosX(ctx) -
                            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemInnerSpacing()))
                        if r.ImGui_BeginChildFrame(ctx, '##timeselend', r.ImGui_GetContentRegionAvail(ctx),
                            r.ImGui_GetFrameHeight(ctx)) then
                            r.ImGui_Text(ctx, r.format_timestr_pos(retval_b, '', 5))
                            r.ImGui_EndChildFrame(ctx)
                        end
                        app.setHoveredHint('settings', "Time seleciton end.")
                    elseif stType == 'actions' then
                        retval_a = retval_a or {}
                        r.ImGui_SetNextItemWidth(ctx, widgetWidth)
                        if r.ImGui_BeginListBox(ctx, '##' .. text, 0, r.ImGui_GetTextLineHeightWithSpacing(ctx) * 4) then
                            for i, action in ipairs(retval_a) do
                                local rv, name = getReaperActionNameOrCommandId(action)
                                if r.ImGui_Selectable(ctx, name .. '##' .. text .. i, gui.stWnd[cP][text] == i) then
                                    if gui.stWnd[cP][text] == i then
                                        gui.stWnd[cP][text] = nil
                                    else
                                        gui.stWnd[cP][text] = i
                                    end
                                end
                                if not rv then
                                    app.setHoveredHint('settings',
                                        'SWS not installed: showing Command ID instead of action names.')
                                end
                            end
                            r.ImGui_EndListBox(ctx)
                        end
                        r.ImGui_SameLine(ctx)
                        local framePaddingX, framePaddingY = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
                        r.ImGui_SetCursorPos(ctx, halfWidth, r.ImGui_GetCursorPosY(ctx) +
                            r.ImGui_GetTextLineHeightWithSpacing(ctx) + framePaddingY * 2)
                        if r.ImGui_Button(ctx, '+##add' .. text, gui.TEXT_BASE_WIDTH * 2 + framePaddingX) then
                            gui.stWnd[cP].action_target = text
                            r.PromptForAction(1, 0, 0)
                        end
                        app.setHoveredHint('settings',
                            "Add an action by highlighting it in REAPER's action window and clicking 'Select'.")
                        if gui.stWnd[cP].action_target == text then
                            local curAction = r.PromptForAction(0, 0, 0)
                            if curAction ~= 0 then
                                if curAction ~= -1 then
                                    table.insert(retval_a, curAction)
                                else
                                    r.PromptForAction(-1, 0, 0)
                                end
                            end
                        end
                        r.ImGui_SameLine(ctx)
                        r.ImGui_SetCursorPos(ctx, halfWidth, r.ImGui_GetCursorPosY(ctx) +
                            r.ImGui_GetTextLineHeightWithSpacing(ctx) * 2 + framePaddingY * 4)
                        if r.ImGui_Button(ctx, '-##remove' .. text, gui.TEXT_BASE_WIDTH * 2 + framePaddingX) then
                            if gui.stWnd[cP][text] then
                                table.remove(retval_a, gui.stWnd[cP][text])
                            end
                        end
                        app.setHoveredHint('settings', "Remove selected action.")

                    elseif stType == 'region' or stType == 'marker' then
                        if not r.APIExists('JS_Localize') then
                            r.ImGui_TextColored(ctx, gui.st.col.error,
                                ('js_ReaScriptAPI extension is required for selecting %ss.'):format(stType))
                        else
                            -- GetRegionManagerWindow is not very performant, so only do it once every 6 frames 
                            if gui.stWnd[cP].frameCount % 10 == 0 then
                                app.rm_window_open = GetRegionManagerWindow() ~= nil
                            end
                            if not app.rm_window_open then
                                local title = (('%s selected'):format((#retval_a > 0) and
                                                                          ((#retval_a > 1) and #retval_a .. ' %ss' or
                                                                              '1 %s') or "No %s"):format(stType))
                                local clicked = r.ImGui_Button(ctx, title, widgetWidth)
                                if clicked then
                                    if #retval_a > 0 and gui.modKeys == "a" then
                                        retval_a = {}
                                    else
                                        r.Main_OnCommand(40326, 0)
                                    end
                                end
                                if r.ImGui_IsItemHovered(ctx) and #retval_a > 0 then
                                    app.setHoveredHint('settings',
                                        ("Click to update selection. %s+click to clear."):format(
                                            gui.descModAlt:gsub("^%l", string.upper)))
                                    local markeregion_names = ''
                                    for i, markeregion in ipairs(retval_a) do
                                        markeregion_names = markeregion_names ..
                                                                markeregion.id:gsub(stType:sub(1, 1):upper(), '') ..
                                                                ': ' .. markeregion.name .. '\n'
                                    end
                                    r.ImGui_BeginTooltip(ctx)
                                    r.ImGui_Text(ctx, ('Selected %ss:'):format(stType))
                                    r.ImGui_Separator(ctx)
                                    r.ImGui_Text(ctx, markeregion_names)
                                    r.ImGui_EndTooltip(ctx)
                                else
                                    app.setHoveredHint('settings', ("Click to select %ss."):format(stType))
                                end
                            else
                                if r.ImGui_Button(ctx, ('Capture selected %ss'):format(stType), widgetWidth) then
                                    retval_a = GetSelectedRegionsOrMarkers(stType:sub(1, 1):upper())
                                end
                                app.setHint('settings',
                                    ("Select %s(s) in the %s manager and click button to capture the selection."):format(
                                        stType, stType))
                            end
                        end
                    end
                end
                --
            end
            return retChecked, retval_a, retval_b
        end

        --    r.ImGui_SetNextWindowSize(ctx, halfWidth*3+r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_ItemSpacing())*1.5+r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_WindowPadding()),0)
        r.ImGui_SetNextWindowSize(ctx, halfWidth * 3 + r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()), 0)
        r.ImGui_SetNextWindowPos(ctx, center[1], gui.mainWindow.pos[2] + 100, r.ImGui_Cond_Appearing(), 0.5)
        if r.ImGui_BeginPopupModal(ctx, 'Settings', false, r.ImGui_WindowFlags_AlwaysAutoResize()) then
            r.ImGui_PushFont(ctx, gui.st.fonts.default)
            if r.ImGui_IsWindowAppearing(ctx) or projectChanged then
                gui.stWnd[cP].frameCount = 0
                if gui.stWnd[cP].tS == nil then
                    loadSettings()
                    gui.stWnd[cP].tS = deepcopy(settings.project)
                end
                db:getRenderPresets()
                if r.APIExists('JS_Localize') then
                    local manager = GetRegionManagerWindow()
                    if manager then
                        r.Main_OnCommand(40326, 0)
                    end
                    app.rm_window_open = false
                end

                projectChanged = false
                gui.stWnd[cP].activeRSG = nil
                gui.stWnd[cP].action_target = nil
            end

            local buttonsX = itemWidth + r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2
            r.ImGui_PushFont(ctx, gui.st.fonts.bold)
            r.ImGui_Text(ctx, 'Project global settings')
            r.ImGui_PopFont(ctx)
            r.ImGui_Separator(ctx)

            gui.stWnd[cP].tS.renderaction = setting('combo', 'Render action',
                ("What should the default rendering mode be."):format(scr.name), gui.stWnd[cP].tS.renderaction, {
                    list = renderaction_list
                })
            if gui.stWnd[cP].tS.renderaction == RENDERACTION_RENDER then
                gui.stWnd[cP].tS.overwrite_without_asking = setting('checkbox', 'Always overwrite',
                    "Suppress REAPER's dialog asking whether files should be overwritten.",
                    gui.stWnd[cP].tS.overwrite_without_asking)
                gui.stWnd[cP].tS.wait_time = setting('dragint', 'Wait time between renders',
                    "Time to wait between renders to allow canceling and to let FX tails die down.",
                    gui.stWnd[cP].tS.wait_time, {
                        step = 0.1,
                        min = WAITTIME_MIN,
                        max = WAITTIME_MAX
                    })
            end

            gui.stWnd[cP].tS.reflect_on_add = setting('combo', 'New stems created',
                'What solo states will newly added stems have?', gui.stWnd[cP].tS.reflect_on_add, {
                    list = reflect_on_add_list
                })
            gui.stWnd[cP].tS.syncmode = setting('combo', 'Mirror mode',
                ("Mirror mode. %s-click the mirror button to trigger other behavior."):format(
                    gui.descModAlt:gsub("^%l", string.upper)), gui.stWnd[cP].tS.syncmode, {
                    list = syncmode_list
                })
            gui.stWnd[cP].tS.show_hidden_tracks = setting('checkbox', 'Show hidden tracks',
                "Show tracks that are hidden in the TCP?", gui.stWnd[cP].tS.show_hidden_tracks)

            r.ImGui_Text(ctx, '')
            r.ImGui_PushFont(ctx, gui.st.fonts.bold)
            r.ImGui_Text(ctx, 'Project render groups')
            r.ImGui_PopFont(ctx)
            app.setHoveredHint('settings',
                ("Each stem is associated to one of %d render groups with its own set of settings."):format(
                    RENDER_SETTING_GROUPS_SLOTS))
            r.ImGui_Separator(ctx)

            local availwidth = r.ImGui_GetContentRegionAvail(ctx)
            if r.ImGui_BeginTabBar(ctx, 'Render Group Settings') then
                for stGrp = 1, RENDER_SETTING_GROUPS_SLOTS do
                    if gui.stWnd[cP].activeRSG == stGrp then
                        r.ImGui_SetNextItemWidth(ctx, halfWidth * 3 / RENDER_SETTING_GROUPS_SLOTS)
                    end
                    if r.ImGui_BeginTabItem(ctx, stGrp .. '##settingGroup' .. stGrp, false) then
                        -- if tab has changed or is loaded for the first time
                        if gui.stWnd[cP].activeRSG ~= stGrp then
                            r.PromptForAction(-1, 0, 0)
                            gui.stWnd[cP].action_target = nil
                            gui.stWnd[cP].activeRSG = stGrp
                        end
                        app.setHoveredHint('settings', ("Settings for render group %d."):format(stGrp))
                        local rsg = gui.stWnd[cP].tS.render_setting_groups[stGrp]

                        rsg.description = setting('text', 'Description',
                            "Used as a reference for yourself. E.g., stems, submixes, mix etc...", rsg.description)
                        if rsg.render_preset == '' then
                            rsg.render_preset = nil
                        end
                        local preset = db.renderPresets[rsg.render_preset]
                        if setting('button', 'Render Preset',
                            ("A render preset to use for this render group. %s+click to clear."):format(
                                gui.descModAlt:gsub("^%l", string.upper)), nil, {
                                label = rsg.render_preset or 'Select...'
                            }) then
                            if gui.modKeys == 'a' then
                                rsg.render_preset = nil
                            else
                                db:getRenderPresets()
                                r.ImGui_OpenPopup(ctx, 'Stem Render Presets##stemRenderPresets')
                            end
                        end
                        local rv, presetName = app.drawPopup(ctx, 'renderPresetSelector',
                            'Stem Render Presets##stemRenderPresets')
                        if rv then
                            rsg.render_preset = presetName
                        end
                        if preset and preset.boundsflag == RB_TIME_SELECTION then
                            rsg.make_timeSel, rsg.timeSelStart, rsg.timeSelEnd =
                                setting_special('Make time selection', 'Make a time selection before rendering.',
                                    'time_sel', rsg.make_timeSel, rsg.timeSelStart, rsg.timeSelEnd)
                        elseif preset and preset.boundsflag == RB_SELECTED_REGIONS then
                            rsg.select_regions, rsg.selected_regions =
                                setting_special('Select regions', 'You may specify regions to select before rendering.',
                                    'region', rsg.select_regions, rsg.selected_regions)
                        elseif preset and preset.boundsflag == RB_SELECTED_MARKERS then
                            rsg.select_markers, rsg.selected_markers =
                                setting_special('Select markers', 'You may specify markers to select before rendering.',
                                    'marker', rsg.select_markers, rsg.selected_markers)
                        end
                        local hint = "Use a filename other than the preset. Use $stem for stem name. Wildcards are ok."
                        rsg.override_filename = setting('checkbox', 'Override filename', hint, rsg.override_filename)
                        if rsg.override_filename then
                            rsg.filename = setting('text_with_hint', 'Filename override', hint, rsg.filename, {
                                hint = (preset and preset.filepattern or '')
                            }, true)
                        end
                        local hint = "Subfolder will be inside the folder specified in the render preset."
                        rsg.put_in_folder = setting('checkbox', 'Save stems in subfolder', hint, rsg.put_in_folder)
                        if rsg.put_in_folder then
                            rsg.folder = setting('text', 'Subfolder', hint, rsg.folder, {}, true)
                        end
                        rsg.skip_empty_stems = not setting('checkbox', 'Render "empty" stems',
                            "Should stems with no defined solo/mute states be rendered?", not rsg.skip_empty_stems)
                        rsg.run_actions, rsg.actions_to_run =
                            setting_special('Pre render action(s)',
                                'You may specify one or more actions to run before rendering each stem.', 'actions',
                                rsg.run_actions, rsg.actions_to_run)
                        rsg.run_actions_after, rsg.actions_to_run_after =
                            setting_special('Post render action(s)',
                                'You may specify one or more actions to run after rendering each stem.', 'actions',
                                rsg.run_actions_after, rsg.actions_to_run_after)
                        r.ImGui_Spacing(ctx)

                        -- ignore_warnings
                        -- r.ShowConsoleMsg(gui.stWnd[cP].frameCount)
                        if gui.stWnd[cP].frameCount % 10 == 0 then
                            _, gui.stWnd[cP].checks = checkRenderGroupSettings(rsg)
                        end
                        local col_ok = gui.st.col.ok
                        local col_error = gui.st.col.error
                        local col_warning = gui.st.col.warning
                        local warnings = false
                        for i, check in ipairs(gui.stWnd[cP].checks) do
                            if not check.passed and check.severity == 'warning' then
                                warnings = true
                            end
                        end
                        r.ImGui_Text(ctx, '')

                        r.ImGui_AlignTextToFramePadding(ctx)
                        r.ImGui_PushFont(ctx, gui.st.fonts.bold)
                        r.ImGui_Text(ctx, 'Checklist:')
                        r.ImGui_PopFont(ctx)
                        if warnings then
                            r.ImGui_SameLine(ctx)
                            rv, rsg.ignore_warnings = r.ImGui_Checkbox(ctx,
                                "Don't show non critical (orange) errors before rendering", rsg.ignore_warnings)
                            app.setHoveredHint('settings',
                                "This means you're aware of the warnings and are OK with them :)")
                        end

                        r.ImGui_Separator(ctx)
                        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_DisabledAlpha(), 1)
                        r.ImGui_BeginDisabled(ctx)

                        for i, check in ipairs(gui.stWnd[cP].checks) do
                            if check.passed then
                                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), col_ok)
                            elseif check.severity == 'critical' then
                                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), col_error)
                            elseif check.severity == 'warning' then
                                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), col_warning)
                            end
                            -- r.ImGui_SetCursorPosX(ctx, r.ImGui_GetCursorPosX(ctx)+itemWidth+r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_ItemInnerSpacing()))
                            r.ImGui_Checkbox(ctx, check.status, check.passed)
                            r.ImGui_PopStyleColor(ctx)
                            app.setHoveredHint('settings', check.hint)
                        end
                        r.ImGui_EndDisabled(ctx)
                        r.ImGui_PopStyleVar(ctx)

                        r.ImGui_EndTabItem(ctx)
                    end
                    if stGrp ~= gui.stWnd[cP].activeRSG then
                        app.setHoveredHint('settings', ("Settings for render group %d."):format(stGrp))
                    end
                end
                r.ImGui_EndTabBar(ctx)
            end
            r.ImGui_Separator(ctx)
            r.ImGui_PopItemWidth(ctx)

            -- bottom

            -- r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeightWithSpacing(ctx) * bottom_lines))
            local status, col = app.getStatus('settings')
            if col then
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), gui.st.col[col])
            end
            r.ImGui_Spacing(ctx)
            r.ImGui_Text(ctx, status)
            app.setHint('settings', '')
            r.ImGui_Spacing(ctx)
            if col then
                r.ImGui_PopStyleColor(ctx)
            end

            if r.ImGui_Button(ctx, "Load default settings") then
                gui.stWnd[cP].tS = deepcopy(getDefaultSettings(gui.modKeys == 'a').default)
            end
            app.setHoveredHint('settings',
                ('Revert to saved default settings. %s+click to load factory settings.'):format(
                    gui.descModAlt:gsub("^%l", string.upper)))

            r.ImGui_SameLine(ctx)
            if r.ImGui_Button(ctx, "Save as default settings") then
                settings.project = deepcopy(gui.stWnd[cP].tS)
                settings.default = deepcopy(gui.stWnd[cP].tS)
                saveSettings()
                r.PromptForAction(-1, 0, 0)
                r.ImGui_CloseCurrentPopup(ctx)
            end
            app.setHoveredHint('settings', ('Default settings for new projects where %s is used.'):format(scr.name))

            r.ImGui_SameLine(ctx)
            r.ImGui_SetCursorPosX(ctx,
                r.ImGui_GetCursorPosX(ctx) + r.ImGui_GetContentRegionAvail(ctx) - r.ImGui_CalcTextSize(ctx, "  OK  ") -
                    r.ImGui_CalcTextSize(ctx, "Cancel") - r.ImGui_CalcTextSize(ctx, "Apply") -
                    r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) * 2 -
                    r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 6)

            if r.ImGui_Button(ctx, "  OK  ") then
                settings.project = deepcopy(gui.stWnd[cP].tS)
                saveSettings()
                r.PromptForAction(-1, 0, 0)
                r.ImGui_CloseCurrentPopup(ctx)
            end
            app.setHoveredHint('settings', ('Save settings for the current project and close the window.'):format(
                gui.descModAlt:gsub("^%l", string.upper)))
            r.ImGui_SameLine(ctx)
            if r.ImGui_Button(ctx, "Cancel") or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
                r.PromptForAction(-1, 0, 0)
                r.ImGui_CloseCurrentPopup(ctx)
            end
            app.setHoveredHint('settings', ('Close without saving.'):format(gui.descModAlt:gsub("^%l", string.upper)))
            r.ImGui_SameLine(ctx)

            if r.ImGui_Button(ctx, "Apply") then
                settings.project = deepcopy(gui.stWnd[cP].tS)
                saveSettings()
            end
            app.setHoveredHint('settings', ('Save settings for the current project.'):format(
                gui.descModAlt:gsub("^%l", string.upper)))
            gui.stWnd[cP].frameCount = (gui.stWnd[cP].frameCount == 120) and 0 or (gui.stWnd[cP].frameCount + 1)

            r.ImGui_PopFont(ctx)
            r.ImGui_EndPopup(ctx)
        end
    end

    function escape_pattern(text)
        return text:gsub("([^%w])", "%%%1")
    end

    function updateActionStatuses(actionList)
        local content = getContent(r.GetResourcePath() .. "/" .. "reaper-kb.ini")
        local statuses = {}
        for k, v in pairs(actionList) do
            for i in ipairs(v.actions) do
                local action_name = 'Custom: ' .. scr.no_ext .. ' - ' .. actionList[k].actions[i].title .. '.lua'
                actionList[k].actions[i].exists = (content:find(escape_pattern(action_name)) ~= nil)
            end
        end
    end

    function app.drawLoadWindow()
        local ctx = gui.ctx
        r.ImGui_OpenPopup(gui.ctx, scr.name .. '##loadStems')
        local msg = "Load settings and stems, removing current stems\nor load settings only and keep current stems?"
        local ok = app.drawPopup(gui.ctx, 'msg', scr.name .. '##loadStems', {
            msg = msg,
            showCancelButton = true,
            okButtonLabel = "Settings + Stems",
            cancelButtonLabel = "Settings Only"
        })
        if ok then
            rv, filename = reaper.GetUserFileNameForRead('', 'Select a stem preset file', 'stm')
            if rv then
                for stemName, stem in pairs(db.stems) do
                    db:removeStem(stemName)
                end
            end
            app.load = false
        elseif ok == false then
            app.load = false
        end

    end

    function app.drawCreateActionWindow()
        local ctx = gui.ctx
        local bottom_lines = 1
        local x, y = r.ImGui_GetMousePos(ctx)
        local _, paddingY = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding())

        local center = {gui.mainWindow.pos[1] + gui.mainWindow.size[1] / 2,
                        gui.mainWindow.pos[2] + gui.mainWindow.size[2] / 2} -- {r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
        local halfWidth = 200
        r.ImGui_SetNextWindowSize(ctx, halfWidth * 3, 700, r.ImGui_Cond_Appearing())
        r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
        local visible, open = r.ImGui_Begin(ctx, 'Create Actions', true)
        local appearing = false
        if gui.caWnd.old_visible ~= visible then
            appearing = visible
            gui.caWnd.old_visible = visible
        end
        if visible then
            if r.ImGui_IsWindowAppearing(ctx) or appearing then
                appearing = false
                gui.caWnd.actionList = {}
                gui.caWnd.actionList['General Actions'] = {
                    order = 1,
                    actions = {}
                }
                gui.caWnd.actionList['Render Group Actions'] = {
                    order = 2,
                    actions = {}
                }
                gui.caWnd.actionList['Stem Render Actions'] = {
                    order = 3,
                    actions = {}
                }
                gui.caWnd.actionList['Stem Toggle Actions'] = {
                    order = 4,
                    actions = {}
                }
                gui.caWnd.actionList['General Actions'].actions = {{
                    title = 'Render all stems now',
                    command = 'render_all'
                }, {
                    title = 'Add all stems to render queue',
                    command = 'add_all'
                }}
                for k, v in pairsByOrder(db.stems) do
                    table.insert(gui.caWnd.actionList['Stem Toggle Actions'].actions, {
                        title = ("Toggle '%s' mirroring"):format(k),
                        command = ("sync %s"):format(k)
                    })
                end
                for k, v in pairsByOrder(db.stems) do
                    table.insert(gui.caWnd.actionList['Stem Render Actions'].actions, {
                        title = ("Render '%s' now"):format(k),
                        command = ("render %s"):format(k)
                    })
                end
                for k, v in pairsByOrder(db.stems) do
                    table.insert(gui.caWnd.actionList['Stem Render Actions'].actions, {
                        title = ("Add '%s' to render queue"):format(k),
                        command = ("add %s"):format(k)
                    })
                end
                for i = 1, RENDER_SETTING_GROUPS_SLOTS do
                    table.insert(gui.caWnd.actionList['Render Group Actions'].actions, {
                        title = ("Render group %d now"):format(i),
                        command = ("render_rg %d"):format(i)
                    })
                end
                for i = 1, RENDER_SETTING_GROUPS_SLOTS do
                    table.insert(gui.caWnd.actionList['Render Group Actions'].actions, {
                        title = ("Add render group %d to render queue"):format(i),
                        command = ("add_rg %d"):format(i)
                    })
                end
                updateActionStatuses(gui.caWnd.actionList)
            end

            r.ImGui_TextWrapped(ctx,
                "Custom actions allow triggering the stem manager directly from within REAPER's action list.")
            r.ImGui_TextWrapped(ctx,
                "After clicking 'Create', a new custom action for triggering the relevant action will be added to the action list.")

            local childHeight = select(2, r.ImGui_GetContentRegionAvail(ctx)) - r.ImGui_GetFrameHeightWithSpacing(ctx) -
                                    paddingY
            if r.ImGui_BeginChild(ctx, '##ActionList', 0, childHeight) then
                for k, actionList in pairsByOrder(gui.caWnd.actionList) do
                    r.ImGui_Separator(ctx)
                    r.ImGui_Spacing(ctx)
                    if r.ImGui_TreeNode(ctx, k, r.ImGui_TreeNodeFlags_DefaultOpen()) then
                        for i, action in ipairs(actionList.actions) do
                            r.ImGui_PushID(ctx, i)
                            r.ImGui_AlignTextToFramePadding(ctx)
                            r.ImGui_Text(ctx, action.title)
                            r.ImGui_SameLine(ctx)
                            r.ImGui_SetCursorPosX(ctx, halfWidth * 2)
                            local disabled = false
                            if action.exists then
                                r.ImGui_BeginDisabled(ctx);
                                disabled = true
                            end
                            if r.ImGui_Button(ctx, action.exists and 'Action exists' or 'Create',
                                r.ImGui_GetContentRegionAvail(ctx), 0) then
                                createAction(action.title, action.command)
                                updateActionStatuses(gui.caWnd.actionList)
                            end
                            if disabled then
                                r.ImGui_EndDisabled(ctx)
                            end
                            r.ImGui_PopID(ctx)
                        end
                        r.ImGui_TreePop(ctx)
                    end
                end
                r.ImGui_Separator(ctx)
                r.ImGui_EndChild(ctx)
            end

            -- bottom
            r.ImGui_Separator(ctx)
            r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeight(ctx)) - paddingY)
            if r.ImGui_Button(ctx, "Close") or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
                app.show_action_window = false
            end

            r.ImGui_End(ctx)
        end
        if not open then
            app.show_action_window = false
        end
    end

    function app.drawHelp()
        local ctx = gui.ctx
        local bottom_lines = 2
        local x, y = r.ImGui_GetMousePos(ctx)
        local center = {gui.mainWindow.pos[1] + gui.mainWindow.size[1] / 2,
                        gui.mainWindow.pos[2] + gui.mainWindow.size[2] / 2} -- {r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
        r.ImGui_SetNextWindowSize(ctx, 800, 700, r.ImGui_Cond_Appearing())
        r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
        local visible, open = r.ImGui_Begin(ctx, 'Help', true)
        if visible then
            local help = ([[
|Introduction
$script was designed with the goal of simplifying the process of stem creation with REAPER.

While REAPER's flexibility is unmatched, it is still quite cumbersome to create and render sets of tracks independently of signal flow, with emphasis on easy cross-project portability (do it once, then use it everywhere!).

Almost every control of $script can be hovered, and a short explanation will show up at the bottom of the window.
|How does it work?
The main window contains a list of the project's tracks on the left-hand side, with "stems" on the top row.

Each stem is represented by the solo and mute states that create it in the project's tracks.

After defining the stems and clicking the render button at the bottom of the main window, $script first solos and mutes the tracks according to their required solo and mute states, as well as other optional steps that can be defined (more on that at the 'Settings' section), and either renders them or adds them in order to the render queue.

|Defining stems
Stems can be created by clicking the "+" button in the top row.
Hover over stem names and click the ellipses menu for more stem actions.
Stems can be reordered by dragging.

Each track's solo and mute states in a stem can be assigned by clicking and dragging the squares under the stem:

- Click to toggle $default_solo_state*
- Shift+click to toggle $mute_state
- $Mod_ctrlcmd+click to toggle $other_solo_state*
- Shift+$mod_alt+click to toggle $default_mute_solo_state*
- Shift+$mod_ctrlcmd+click to toggle $other_mute_solo_state*
- $Mod_alt+click to clear the track's state in the corresponding stem.

* The default solo behavior is determined by the solo behavior in: 
REAPER's settings -> Audio -> Mute/Solo -> Solos default to in-place solo. 
Updating this preference will update $script's behavior as well.

A small gray rectangle at the bottom of a stem means there are children tracks of this folder track which are hidden but have solo/mute states.
|Mirroring
Stems can be mirrored by REAPER's tracks by clicking the circle button under the stem's name.
When a stem is mirrored, the stem's tracks are soloed and muted in accordance with their state in the corresponding stem.
This allows listening to the stem as it will be rendered.

There are two mirror modes: 
1. Soloing or muting tracks in REAPER while in mirror mode affects the track's state in the stems inside $script.
2. Soloing or muting tracks in REAPER while in mirror mode DOES NOT affect $stem whatsoever.

The default behavior can be selected in the settings window.
The alternative behavior can always be triggered by $mod_alt+clicking the mirror button.

|Render Setting Groups
Not all stems serve the same purpose: 
Some need to be rendered by one render preset and other by another, some need to be rendered to a time selection and others to a region.

You can assign each stem 1 of $num_of_setting_groups "render setting groups", with each one having its own set of instructions for rendering.
More information in the settings section.

|Settings
The settings are saved with REAPER's project file.
Default settings can also be saved, and they will be loaded each time $script is launched in a new project. Settings can also be saved in a project template.

If for some reason you wish to revert to the original default settings, you may $mod_alt+click the "Load default settings" button and the settings will be reverted to their "factory" defaults. 

The settings window is divided into global and Render Group Settings.

The project global section lets you select

#New stem contents#
Whether new stems take on the project's current solo/mute states, or start off without solo/mute states.

#Render action#
$script can either render stems immediately when clicking 'Render' or add stems to the render queue.
When running the render queue, reaper opens a snapshot of the project before each render, which causes the project to reload for each stem.
Rendering directly means the project does not have to be reloaded for each stem.

#Always overwrite#
When checked, $script will automatically overwrite any existing file, suppressing REAPER's dialog asking whether the file should be overwritten or not. This is only available when the render action is set to "render immediately".

#Wait time between renders#
In case rendering immediately is selected, you can define an amount of time to wait between renders. This serves two purposes - 
- It allows canceling the render operation between renders.
- Some plugins, especially reverb tails, tend to "loop around" to the beginning of renders if they are not given the opportunity to die down. This helps mitigate the issue.

#New stems created#
When adding new stems they can either take on the current project's current solo/mute states or not.

#Stem mirror mode#
The default stem mirroring mode (see the Mirroring section for more information).

#Show hidden tracks#
By default, $script will hide tracks that are hidden in the TCP. This setting allows you to show hidden tracks in $script.


#Render Groups#
The render group section lets you define $num_of_setting_groups different sets of rules for rendering stems. 

The settings for each render group are:
#Description#
A short description for your own use. This is handy for remembering what each render group is used for (E.g., stems, submixes, mix etc...). When hovering the render setting group number in the main window, a small tool-tip will show the description for that group.

#Render Preset#
A render preset to be loaded before adding the stem to the render queue. Notice that the render preset's source should usually be set to "Master Mix", as that is usually the way in which soloed and muted tracks form... well... a master mix.

#Make time selection#
If the selected render preset's "bounds" setting is set to "Time selection", you can define a time selection to be made before rendering or adding the stem to the render queue. To do this, check the box, make a time selection in REAPER's timeline and click "Capture time selection".

#Select regions#
If the selected render preset's "bounds" setting is set to "Selected regions", you can define a set of regions to be selected before rendering or adding the stem to the render queue. To do this, check the box, click "No region selected", select one or more regions in the now opened Region/Marker Manager window, and click "Capture selected regions" back in $script's settings window. You can $mod_alt+click the button to clear the selection.

#Select markers#
If the selected render preset's "bounds" setting is set to "Selected markers", you can define a set of markers to be selected before rendering or adding the stem to the render queue. To do this, check the box, click "No marker selected", select one or more markers in the now opened Region/Marker Manager window, and click "Capture selected markers" back in $script's settings window. You can $mod_alt+click the button to clear the selection.

#Override filename#
Normally, files will be rendered according to their filename in the render preset. You may (and probably should) use the $stem wildcard to be replaced by the stem's name. You may also override the filename and $script will use that instead of the filename in the render preset. All of REAPER's usual wildcards can be used.

#Save stems in subfolder#
You can specify a subfolder for the stems. This will actually be added using the render window's filename field, so it is possible to use all available wildcards, as well as the $stem wildcard.

#Render stems without solo/mute states#
Stems without any defined solo or mute states will just play the mix as it is, so you will generally want to avoid adding them to the render queue, unless you intend on rendering the mix itself. If so, please make sure to check this option.

#Pre render action(s)#
This allows adding custom reaper actions to run before rendering. After checking the box, click the '+' button. This will open REAPER's Action's window, where you can select an action and click "select". The action will then be added to the action list in the render group's settings. Select an action and click the '-' button to remove it from the list.

#Post render action(s)#
This allows adding custom reaper actions to run after rendering. After checking the box, click the '+' button. This will open REAPER's Action's window, where you can select an action and click "select". The action will then be added to the action list in the render group's settings. Select an action and click the '-' button to remove it from the list.

#Checklist#
Several checks are made to make sure everything is in order.

|Custom actions
You can create custom actions, which allow triggering $script actions directly from REAPER's action list.
Keyboard shortcuts can then be assigned to those actions, which can be useful for quickly mirroring stems while not in stem manager.

|Portability
$script is made with portability in mind.

Stem names and settings are saved with REAPER projects (regular projects and templates alike).

Stem associations (i.e. the track's state in the stems) are saved with the tracks themselves, and so can be saved as part of track templates.

For example: 
A drums bus track can be saved with its association to the "drums" stem, a guitar bus track can be saved with its association to the "guitars" stem etc, and so when that track is loaded into a new project, the appropriate stem will be created (unless it already exists), and the track's solo state in it will be set.

Notice that the stem's render group settings are not saved in the track, but in the project, as stated before.

|Thank yous
This project was made with the help of the community of REAPER's users and script developers.

I'd like to personally thank X-Raym and thommazk for their great help and advice!

It is dependent on cfillion's work both on the incredible ReaImgui library, and his script 'cfilion_Apply render preset'.
]]):gsub('$([%w_]+)', {
                script = scr.name,
                default_solo_state = STATE_DESCRIPTIONS[db.prefSoloIP and STATES.SOLO_IN_PLACE or
                    STATES.SOLO_IGNORE_ROUTING][1],
                other_solo_state = STATE_DESCRIPTIONS[db.prefSoloIP and STATES.SOLO_IGNORE_ROUTING or
                    STATES.SOLO_IN_PLACE][1],
                mute_state = STATE_DESCRIPTIONS[STATES.MUTE][1],
                default_mute_solo_state = STATE_DESCRIPTIONS[db.prefSoloIP and STATES.MUTE_SOLO_IN_PLACE or
                    STATES.MUTE_SOLO_IGNORE_ROUTING][1],
                other_mute_solo_state = STATE_DESCRIPTIONS[db.prefSoloIP and STATES.MUTE_SOLO_IGNORE_ROUTING or
                    STATES.MUTE_SOLO_IN_PLACE][1],
                Mod_ctrlcmd = gui.descModCtrlCmd:gsub("^%l", string.upper),
                mod_ctrlcmd = gui.descModCtrlCmd:gsub("^%l", string.upper),
                mod_alt = gui.descModAlt,
                Mod_alt = gui.descModAlt:gsub("^%l", string.upper),
                num_of_setting_groups = RENDER_SETTING_GROUPS_SLOTS
            })

            local _, paddingY = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding())

            local childHeight = select(2, r.ImGui_GetContentRegionAvail(ctx)) - r.ImGui_GetFrameHeightWithSpacing(ctx) *
                                    bottom_lines - paddingY
            if r.ImGui_BeginChild(ctx, '##ActionList', 0, childHeight) then
                local i = 0
                for title, section in help:gmatch('|([^\r\n]+)([^|]+)') do
                    if r.ImGui_CollapsingHeader(ctx, title, false, (i == 0 and r.ImGui_TreeNodeFlags_DefaultOpen() or
                        r.ImGui_TreeNodeFlags_None()) | r.ImGui_Cond_Appearing()) then
                        for text, bold in section:gmatch('([^#]*)#?([^#]+)#?\n?\r?') do
                            if text then
                                r.ImGui_TextWrapped(ctx, text)
                            end
                            if bold then
                                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0xff8844ff)
                                r.ImGui_TextWrapped(ctx, bold)
                                r.ImGui_PopStyleColor(ctx)
                            end
                        end
                    end
                    i = i + 1
                end
                r.ImGui_EndChild(ctx)
            end
            r.ImGui_Separator(ctx)
            r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeight(ctx) * bottom_lines) -
                paddingY)
            r.ImGui_Text(ctx, 'While this script is free,')
            r.ImGui_SameLine(ctx)
            gui:pushColors(gui.st.col.render_setting_groups[3])
            if r.ImGui_SmallButton(ctx, 'donations') then
                if r.APIExists('CF_ShellExecute') then
                    r.CF_ShellExecute(scr.donation)
                else
                    local command
                    if os_is.mac then
                        command = 'open "%s"'
                    elseif os_is.win then
                        command = 'start "URL" /B "%s"'
                    elseif os_is.lin then
                        command = 'xdg-open "%s"'
                    end
                    if command then
                        os.execute(command:format(scr.donation))
                    end
                end
            end
            gui:popColors(gui.st.col.render_setting_groups[1])
            r.ImGui_SameLine(ctx)
            r.ImGui_Text(ctx, 'will be very much appreciated ;-)')
            if r.ImGui_Button(ctx, "Close") or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
                app.show_help = false
            end
            r.ImGui_End(ctx)
        end
        if not open then
            app.show_help = false
        end
    end

    function msg(msg, title, ctx)
        local ctx = ctx or gui.ctx
        local title = title or scr.name
        r.ImGui_OpenPopup(gui.ctx, title .. "##msg")
        return app.drawPopup(gui.ctx, 'msg', title .. "##msg", {
            msg = msg
        })
    end

    function app.getStatus(window)
        if window == 'main' then
            --  if db.error == 'no stemsFolder' then return "Stems folder not defined", 'error' end
            if app.coPerform then
                return app.perform.status
            end
            return app.hint.main.text, app.hint.main.color
        elseif window == 'settings' then
            return app.hint.settings.text, app.hint.settings.color
        end
    end

    function app.setHoveredHint(window, text, color, ctx)
        local ctx = ctx or gui.ctx
        if r.ImGui_IsItemHovered(ctx, r.ImGui_HoveredFlags_AllowWhenDisabled()) then
            app.setHint(window, text, color, ctx)
        end
    end

    function app.setHint(window, text, color, ctx)
        local ctx = ctx or gui.ctx
        color = color or 'hint'
        if (db.error or app.coPerform) and not (text == '') and text then
            app.hint[window] = {
                window = {}
            }
            if color then
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), gui.st.col[color])
            end
            r.ImGui_SetTooltip(ctx, text)
            if color then
                r.ImGui_PopStyleColor(ctx)
            end
        else
            app.hint[window] = {
                text = text,
                color = color
            }
        end
    end

    function app.drawBottom(ctx, bottom_lines)
        r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) -
            (r.ImGui_GetFrameHeightWithSpacing(ctx) * bottom_lines +
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) * 2))
        local status, col = app.getStatus('main')
        if col then
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), gui.st.col[col])
        end
        r.ImGui_Spacing(ctx)
        r.ImGui_Text(ctx, status)
        app.setHint('main', '')
        r.ImGui_Spacing(ctx)
        if col then
            r.ImGui_PopStyleColor(ctx)
        end
        if not app.coPerform then
            if r.ImGui_Button(ctx, RENDERACTION_DESCRIPTIONS[settings.project.renderaction]:gsub("^%l", string.upper),
                r.ImGui_GetContentRegionAvail(ctx)) then
                app.forceRenderAction = nil
                app.coPerform = coroutine.create(doPerform)
            end
        else
            r.ImGui_ProgressBar(ctx, (app.perform.pos or 0) / (app.perform.total or 1),
                r.ImGui_GetContentRegionAvail(ctx))
        end
    end

    function app.drawMainWindow(open)
        local ctx = gui.ctx
        r.ImGui_SetNextWindowSize(ctx, 700,
            math.min(1000, select(2, r.ImGui_Viewport_GetSize(r.ImGui_GetMainViewport(ctx)))), r.ImGui_Cond_Appearing())
        r.ImGui_SetNextWindowPos(ctx, 100, 100, r.ImGui_Cond_FirstUseEver())
        local visible, open = r.ImGui_Begin(ctx, scr.name .. ' v' .. scr.version .. "##mainWindow", true,
            r.ImGui_WindowFlags_MenuBar())
        gui.mainWindow = {
            pos = {r.ImGui_GetWindowPos(ctx)},
            size = {r.ImGui_GetWindowSize(ctx)}
        }
        db:sync()
        if visible then
            local bottom_lines = 2
            local rv2
            if r.ImGui_BeginMenuBar(ctx) then
                -- r.ImGui_SetCursorPosX(ctx, r.ImGui_GetContentRegionAvail(ctx)- r.ImGui_CalcTextSize(ctx,'Settings'))

                if reaper.ImGui_BeginMenu(ctx, 'File') then
                    -- rv,show_app.main_menu_bar =
                    --   ImGui.MenuItem(ctx, 'Main menu bar', nil, show_app.main_menu_bar)
                    rv, rv1 = reaper.ImGui_MenuItem(ctx, 'Save...', nil, nil)
                    app.setHoveredHint('main', "Save current stems and settings")

                    if reaper.ImGui_MenuItem(ctx, 'Load...', nil, nil) then
                        app.load = true
                    end
                    app.setHoveredHint('main', "Load stems and settings")
                    reaper.ImGui_EndMenu(ctx)
                end

                if r.ImGui_SmallButton(ctx, 'Settings') then
                    r.ImGui_OpenPopup(ctx, 'Settings')
                end
                r.ImGui_SameLine(ctx)
                if r.ImGui_SmallButton(ctx, 'Create Actions') then
                    app.show_action_window = not (app.show_action_window or false)
                end
                if r.ImGui_SmallButton(ctx, 'Help') then
                    app.show_help = not (app.show_help or false)
                end
                if r.ImGui_IsPopupOpen(ctx, 'Settings') then
                    app.drawSettings()
                end
                if app.show_help then
                    app.drawHelp()
                end
                if app.show_action_window then
                    app.drawCreateActionWindow()
                end
                if app.load then
                    app.drawLoadWindow()
                end

                r.ImGui_EndMenuBar(ctx)
            end
            if app.coPerform and coroutine.status(app.coPerform) == 'running' then
                r.ImGui_BeginDisabled(ctx)
            end
            app.drawMatrices(ctx, bottom_lines)
            if app.coPerform and coroutine.status(app.coPerform) == 'running' then
                r.ImGui_EndDisabled(ctx)
            end
            app.drawBottom(ctx, bottom_lines)
            r.ImGui_End(ctx)
        end
        return open
    end

    function checkPerform()
        if app.coPerform then
            if coroutine.status(app.coPerform) == "suspended" then
                retval, app.perform.status, app.perform.pos, app.perform.total =
                    coroutine.resume(app.coPerform, app.stem_to_render)
                if not retval then
                    r.ShowConsoleMsg(app.perform.status)
                end
            elseif coroutine.status(app.coPerform) == "dead" then
                app.stem_to_render = nil
                app.renderGroupToRender = nil
                app.coPerform = nil
                if app.render_count > 0 then
                    if app.current_renderaction == RENDERACTION_RENDERQUEUE_OPEN then
                        r.Main_OnCommand(40929, 0)
                    elseif (app.current_renderaction == RENDERACTION_RENDERQUEUE_RUN) and (app.perform.fullRender) then
                        r.Main_OnCommand(41207, 0)
                    end
                end
                app.current_renderaction = nil
            end
        end
    end

    function app.loop()
        r.DeleteExtState(scr.context_name, 'defer', false)
        checkPerform()
        r.ImGui_PushFont(gui.ctx, gui.st.fonts.default)
        app.open = app.drawMainWindow(open)
        r.ImGui_PopFont(gui.ctx)
        checkExternalCommand()
        if app.open then
            r.SetExtState(scr.context_name, 'defer', '1', false)
            r.defer(app.loop)
        else
            r.ImGui_DestroyContext(gui.ctx)
        end
    end

    loadSettings()
    updateSettings() -- fix format of actions saved pre v1.1.0
    r.defer(app.loop)
end
