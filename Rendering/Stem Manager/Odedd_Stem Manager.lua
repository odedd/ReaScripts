-- @description Stem Manager
-- @author Oded Davidov
-- @version 0.4.3
-- @donation: https://paypal.me/odedda
-- @license GNU GPL v3
-- @provides
--   [nomain]../../Resources/Fonts/Cousine-90deg.otf
--   [nomain]../../Resources/Fonts/Cousine-Regular.ttf
-- @about
--   # Stem Manager
--   Advanced stem rendering automator.
--   Stem Manager was designed with the goal of simplifying the process of stem creation with REAPER.
--   While REAPER's flexibility is unmatched, it is still quite cumbersome to create and render sets of tracks independently of signal flow, with emphasis on easy cross-project portability (do it once, then use it everywhere!).
--
--   This is where Stem Manager comes in.
-- @changelog
--   Under the hood

reaper.ClearConsole()
local STATES             = {
  SOLO_IN_PLACE             = 'SIP',
  SOLO_IGNORE_ROUTING       = 'SIR',
  MUTE                      = 'M',
  MUTE_SOLO_IN_PLACE        = 'MSIP',
  MUTE_SOLO_IGNORE_ROUTING  = 'MSIR'}

local STATE_COLORS          = {
  [STATES.SOLO_IN_PLACE]             = {STATES.SOLO_IN_PLACE,STATES.SOLO_IN_PLACE},
  [STATES.SOLO_IGNORE_ROUTING]       = {STATES.SOLO_IGNORE_ROUTING,STATES.SOLO_IGNORE_ROUTING},
  [STATES.MUTE]                      = {STATES.MUTE,STATES.MUTE},
  [STATES.MUTE_SOLO_IN_PLACE]        = {STATES.MUTE,STATES.SOLO_IN_PLACE},
  [STATES.MUTE_SOLO_IGNORE_ROUTING]  = {STATES.MUTE,STATES.SOLO_IGNORE_ROUTING},
  [' ']                              = {' ',' '}}

local STATE_LABELS       = {
  [STATES.SOLO_IN_PLACE]              = 'S',
  [STATES.SOLO_IGNORE_ROUTING]        = 'S',
  [STATES.MUTE]                       = 'M',
  [STATES.MUTE_SOLO_IN_PLACE]         = 'MS',
  [STATES.MUTE_SOLO_IGNORE_ROUTING]   = 'MS'}

local STATE_DESCRIPTIONS = {
  [STATES.SOLO_IN_PLACE]       = {'solo in place', 'soloed in place'},
  [STATES.SOLO_IGNORE_ROUTING] = {'solo (ignore routing)', 'soloed (ignores routing)'},
  [STATES.MUTE]                = {'mute', 'muted'},
  [STATES.MUTE_SOLO_IN_PLACE]       = {'mute & solo in place', 'muted and soloed in place'},
  [STATES.MUTE_SOLO_IGNORE_ROUTING] = {'mute & solo (ignore routing)', 'muted and soloed (ignores routing)'}}

local STATE_RPR_CODES    = {
  [STATES.SOLO_IN_PLACE]            = {['I_SOLO']=2,['B_MUTE']=0},
  [STATES.SOLO_IGNORE_ROUTING]      = {['I_SOLO']=1,['B_MUTE']=0},
  [STATES.MUTE]                     = {['I_SOLO']=0,['B_MUTE']=1},
  [STATES.MUTE_SOLO_IN_PLACE]       = {['I_SOLO']=2,['B_MUTE']=1},
  [STATES.MUTE_SOLO_IGNORE_ROUTING] = {['I_SOLO']=1,['B_MUTE']=1},
  [' ']                             = {['I_SOLO']=0,['B_MUTE']=0}}

local RENDERACTION_RENDERQUEUE_NOTHING  = 0
local RENDERACTION_RENDERQUEUE_OPEN     = 1
local RENDERACTION_RENDERQUEUE_RUN      = 2
local RENDERACTION_RENDER               = 3

local RENDERACTION_DESCRIPTIONS = { 
  [RENDERACTION_RENDER] = 'Render Immediately',
  [RENDERACTION_RENDERQUEUE_NOTHING] = 'Add to render queue',
  [RENDERACTION_RENDERQUEUE_OPEN] = 'Add to render queue and open it',
  [RENDERACTION_RENDERQUEUE_RUN]  = 'Add to render queue and run it'}

local WAITTIME_MIN = 2
local WAITTIME_MAX = 30

local SYNCMODE_OFF    = -1
local SYNCMODE_MIRROR = 0
local SYNCMODE_SOLO   = 1

local SYNCMODE_DESCRIPTIONS = {
  [SYNCMODE_MIRROR] = "affects stem",
  [SYNCMODE_SOLO]   = "does not affect stem"}

local REFLECT_ON_ADD_TRUE = 0
local REFLECT_ON_ADD_FALSE = 1

local REFLECT_ON_ADD_DESCRIPTIONS = { 
  [REFLECT_ON_ADD_TRUE]           = 'with current solos/mutes',
  [REFLECT_ON_ADD_FALSE]          = 'without solos/mutes'}


local SETTINGS_SOURCE_MASK  = 0x10EB

local RB_CUSTOM_TIME = 0
local RB_ENTIRE_PROJECT = 1
local RB_TIME_SELECTION = 2
local RB_ALL_REGIONS = 3
local RB_SELECTED_ITEMS = 4
local RB_SELECTED_REGIONS = 5
local RB_REZOR_EDIT_AREAS = 6
local RB_ALL_MARKERS = 7
local RB_SELECTED_MARKERS = 8

local RENDER_SETTING_GROUPS_SLOTS = 9

local r                  = reaper
local scr                = {}
local cur_os             = r.GetOS()
local os_is              = {win     = cur_os:lower():match("win") and true or false,
                            mac     = cur_os:lower():match("osx") or
                                    cur_os:lower():match("macos") and true or false,
                            mac_arm = cur_os:lower():match("macos") and true or false,
                            lin     = cur_os:lower():match("other") and true or false}

local applyPresetScript
local frameCount = 0

function getContent(path)
  local file = io.open(path)
  if not file then return "" end
  local content = file:read("*a")
  file:close()
  return content
end

function findContentKey(content, key, self)
  if self then
    for match in content:gmatch("%-%- @(.-)\n") do
      local key, val = match:match("(.-) (.+)") 
      if val then scr[key:lower()] = val end
    end
    return
  else
    content = content:match(key .. "[:=].-\n")
  end
  return content and content:gsub(key.. "[:=]%s?", "") or false
end

scr.path, scr.secID, scr.cmdID = select(2, r.get_action_context())
scr.dir = scr.path:match(".+[\\/]")
scr.basename = scr.path:match("^.+[\\/](.+)$")
scr.no_ext = scr.basename:match("(.+)%.")
findContentKey(getContent(scr.path), "", true)
scr.namespace   = "Odedd"
scr.name        = scr.description
scr.context_name       = scr.namespace:gsub(' ', '_') .. '_' .. scr.name:gsub(' ', '_')
r.ver = tonumber(r.GetAppVersion():match("[%d%.]+"))

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

local function prereqCheck ()
  local errors = {}
  
  local apply_render_preset_script_path = r.GetResourcePath() .. '/Scripts/ReaTeam Scripts/Rendering/cfillion_Apply render preset.lua'
  local reaimgui_script_path = r.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua'
  local reaimgui_version = '0.7'
  local min_reaper_version = 6.44

  if r.ver < min_reaper_version then
    table.insert(errors, 'This script is designed to work with REAPER v'..min_reaper_version..'+')
  end
  if file_exists(apply_render_preset_script_path) then
    applyPresetScript = loadfile(apply_render_preset_script_path)
  else
    table.insert(errors, 'This script requires "cfillion_Apply render preset.lua".\nPlease install it via ReaPack.')
  end
  if file_exists(reaimgui_script_path) then 
    local verCheck = loadfile(reaimgui_script_path)
    local status, err = pcall(verCheck(),reaimgui_version)
    if not status then 
      table.insert(errors, ('ReaImgui version must be %s or above.\nPlease update via ReaPack.'):format(reaimgui_version)) 
    elseif not r.ImGui_ColorConvertU32ToDouble4 then
      table.insert(errors, "ReaImGui error.\nPlease reinstall it via ReaPack.\n\nIf you already installed it, remember to restart reaper.")
    end
  else
    table.insert(errors, 'This script requires ReaImgui.\nPlease install it via ReaPack.')
  end
  
  return errors
end

local errors = prereqCheck()
if #errors > 0 then
  r.MB(table.concat(errors,'\n------------\n'), scr.name,0)
end

if next(errors) == nil then
  
  local app               = {
    open      = true,
    coPerform = nil,
    perform   = {
      status = nil,
      pos    = nil,
      total  = nil
    },
    hint      = {main    = {},
                settings = {}}
  }
  
  --- color functions
  
  local function hslToRgb(h, s, l)
      if s == 0 then return l, l, l end
      local function to(p, q, t)
          if t < 0 then t = t + 1 end
          if t > 1 then t = t - 1 end
          if t < .16667 then return p + (q - p) * 6 * t end
          if t < .5 then return q end
          if t < .66667 then return p + (q - p) * (.66667 - t) * 6 end
          return p
      end
      local q = l < .5 and l * (1 + s) or l + s - l * s
      local p = 2 * l - q
      return to(p, q, h + .33334), to(p, q, h), to(p, q, h - .33334)
  end
  
  local function rgbToHsl(r, g, b)
      local max, min = math.max(r, g, b), math.min(r, g, b)
      local b = max + min
      local h = b / 2
      if max == min then return 0, 0, h end
      local s, l = h, h
      local d = max - min
      s = l > .5 and d / (2 - b) or d / b
      if max == r then h = (g - b) / d + (g < b and 6 or 0)
      elseif max == g then h = (b - r) / d + 2
      elseif max == b then h = (r - g) / d + 4
      end
      return h * .16667, s, l
  end
  
  local gui               = {}
  do
    -- these needs to be temporarily created to be refered to from some of the gui vars
    local ctx          = r.ImGui_CreateContext(scr.context_name .. '_MAIN')
    local cellSize     = 25
    local font_vertical = r.ImGui_CreateFont(scr.dir..'../../Resources/Fonts/Cousine-90deg.otf', 11)
    local font_default = r.ImGui_CreateFont(scr.dir..'../../Resources/Fonts/Cousine-Regular.ttf', 16)
    
    r.ImGui_AttachFont(ctx, font_default)
    r.ImGui_AttachFont(ctx, font_vertical)

    gui = {
      ctx           = ctx,
      mainWindow    = {},
      draw_list     = r.ImGui_GetWindowDrawList(ctx),
      keyModCtrlCmd = (os_is.mac or os_is.mac_arm) and r.ImGui_Key_ModSuper() or r.ImGui_Key_ModCtrl(),
      notKeyModCtrlCmd = (os_is.mac or os_is.mac_arm) and r.ImGui_Key_ModCtrl() or r.ImGui_Key_ModSuper(),
      descModCtrlCmd= (os_is.mac or os_is.mac_arm) and 'cmd' or 'control',
      descModAlt    = (os_is.mac or os_is.mac_arm) and 'opt' or 'alt',      
      st            = {
        fonts = {
          default  = font_default,
          vertical = font_vertical},
        col   = {
          warning           = 0xf58e07FF,
          ok                = 0X55FF55FF,
          critical          = 0xDD0000FF,
          error             = 0xFF5555FF,
          hint              = 0xCCCCCCFF,
          button    = {
            [r.ImGui_Col_Text()]          = 0x000000ff,
            [r.ImGui_Col_Button()]        = 0x707070ff,
            [r.ImGui_Col_ButtonHovered()] = 0x858585FF,
            [r.ImGui_Col_ButtonActive()]  = 0x9c9c9cFF},
          stemSyncBtn       = {
            [SYNCMODE_MIRROR] = {
                inactive = {[r.ImGui_Col_Text()]          = 0xb5301fff,
                          [r.ImGui_Col_Button()]        = 0x1e241eff,
                          [r.ImGui_Col_ButtonHovered()] = 0x293229FF,
                          [r.ImGui_Col_ButtonActive()]  = 0x273827FF},
                active   = {[r.ImGui_Col_Text()]          = 0x000000ff,
                            [r.ImGui_Col_Button()]        = 0x3c9136ff,
                            [r.ImGui_Col_ButtonHovered()] = 0x45a33eFF,
                            [r.ImGui_Col_ButtonActive()]  = 0x4eba47FF}},
            [SYNCMODE_SOLO] = {
              inactive = {[r.ImGui_Col_Text()]          = 0xb5301fff,
                          [r.ImGui_Col_Button()]        = 0x1e2024FF,
                          [r.ImGui_Col_ButtonHovered()] = 0x292c32FF,
                          [r.ImGui_Col_ButtonActive()]  = 0x272c38FF},
              active   = {[r.ImGui_Col_Text()]          = 0x000000ff,
                          [r.ImGui_Col_Button()]        = 0x365f91ff,
                          [r.ImGui_Col_ButtonHovered()] = 0x3e6ba3FF,
                          [r.ImGui_Col_ButtonActive()]  = 0x477fbaFF}}},
          hasChildren       = {
            [STATES.SOLO_IN_PLACE]            = {[r.ImGui_Col_Text()] = 0x00000099},
            [STATES.SOLO_IGNORE_ROUTING]      = {[r.ImGui_Col_Text()] = 0x00000099},
            [STATES.MUTE_SOLO_IN_PLACE]       = {[r.ImGui_Col_Text()] = 0x00000099},
            [STATES.MUTE_SOLO_IGNORE_ROUTING] = {[r.ImGui_Col_Text()] = 0x00000099},
            [STATES.MUTE]                     = {[r.ImGui_Col_Text()] = 0x00000099},
            [' ']                             = {[r.ImGui_Col_Text()] = 0xffffff22}},
          render_setting_groups = {},
          stemState         = {
            ['sync_0']                    = {[r.ImGui_Col_Text()]          = 0x000000ff,
                                            [r.ImGui_Col_Button()]        = 0x1e241eff,
                                            [r.ImGui_Col_ButtonHovered()] = 0x273827FF},
            ['sync_1']                    = {[r.ImGui_Col_Text()]          = 0x000000ff,
                                            [r.ImGui_Col_Button()]        = 0x1e1f24FF,
                                            [r.ImGui_Col_ButtonHovered()] = 0x272c38FF},
            [STATES.SOLO_IN_PLACE]       = {[r.ImGui_Col_Text()]          = 0x000000ff,
                                            [r.ImGui_Col_Button()]        = 0xd6be42FF,
                                            [r.ImGui_Col_ButtonHovered()] = 0xe3d382FF},
            [STATES.SOLO_IGNORE_ROUTING] = {[r.ImGui_Col_Text()]          = 0x000000ff,
                                            [r.ImGui_Col_Button()]        = 0x48ab9cFF,
                                            [r.ImGui_Col_ButtonHovered()] = 0x7ac7bcFF},
            [STATES.MUTE]                = {[r.ImGui_Col_Text()]          = 0x000000ff,
                                            [r.ImGui_Col_Button()]        = 0xa63f3fFF,
                                            [r.ImGui_Col_ButtonHovered()] = 0xc35555FF},
            [' ']                        = {[r.ImGui_Col_Text()]          = 0x000000FF,
                                            [r.ImGui_Col_Button()]        = 0x00000000,
                                            [r.ImGui_Col_ButtonHovered()] = 0xFFFFFF22}},
          trackname         = {[r.ImGui_Col_HeaderHovered()] = 0xFFFFFF22,
                               [r.ImGui_Col_HeaderActive()]  = 0xFFFFFF66}},
        vars  = {
          mtrx = {
            cellSize  = cellSize,
            table     = {[r.ImGui_StyleVar_IndentSpacing()] = {cellSize},
                         [r.ImGui_StyleVar_CellPadding()]   = {0, 0},
                         [r.ImGui_StyleVar_ItemSpacing()]   = {1, 0}},
  
            stemState = {[r.ImGui_StyleVar_FramePadding()] = {0, -1}}}}},
      mtrxTbl       = {
        drgState = nil
      },
      stWnd = {}, --settings window states
      caWnd = {}, --create action window states
      popups        = {
        singleInput = {status = ""}},
      tables        = {
        horizontal = {
          flags1      = r.ImGui_TableFlags_ScrollX() |
                  r.ImGui_TableFlags_ScrollY() |
                  r.ImGui_TableFlags_BordersOuter() |
                  r.ImGui_TableFlags_Borders() |
                  r.ImGui_TableFlags_NoHostExtendX() |
                  r.ImGui_TableFlags_SizingFixedFit()}},
      treeflags     = {
        base = r.ImGui_TreeNodeFlags_SpanFullWidth() | r.ImGui_TreeNodeFlags_FramePadding(),
        leaf = r.ImGui_TreeNodeFlags_FramePadding() |
                r.ImGui_TreeNodeFlags_SpanFullWidth() |
                r.ImGui_TreeNodeFlags_DefaultOpen() |
                r.ImGui_TreeNodeFlags_Leaf() |
                r.ImGui_TreeNodeFlags_NoTreePushOnOpen()},
      pushColors    = function(self, key)
        for k, v in pairs(key) do
          r.ImGui_PushStyleColor(self.ctx, k, v)
        end
      end,
      popColors     = function(self, key)
        for k in pairs(key) do
          r.ImGui_PopStyleColor(self.ctx)
        end
      end,
      pushStyles    = function(self, key)
        for k, v in pairs(key) do
          r.ImGui_PushStyleVar(self.ctx, k, v[1], v[2])
        end
      end,
      popStyles     = function(self, key)
        for k in pairs(key) do
          r.ImGui_PopStyleVar(self.ctx)
        end
      end,
      updateModKeys = function (self)
        self.modKeys = ('%s%s%s%s'):format(
                            r.ImGui_IsKeyDown(self.ctx, r.ImGui_Key_ModShift())  and 's' or '',
                            r.ImGui_IsKeyDown(self.ctx, r.ImGui_Key_ModAlt())    and 'a' or '',
                            r.ImGui_IsKeyDown(self.ctx, self.keyModCtrlCmd)       and 'c' or '',
                            r.ImGui_IsKeyDown(self.ctx, self.notKeyModCtrlCmd)    and 'x' or '')
        return self.modKeys
      end
    }
  
    r.ImGui_PushFont(ctx, gui.st.fonts.default)
    gui.TEXT_BASE_WIDTH, gui.TEXT_BASE_HEIGHT = r.ImGui_CalcTextSize(ctx, 'A'), r.ImGui_GetTextLineHeightWithSpacing(ctx)
    r.ImGui_PopFont(ctx)
    r.ImGui_PushFont(ctx, gui.st.fonts.vertical)
    gui.VERTICAL_TEXT_BASE_WIDTH, gui.VERTICAL_TEXT_BASE_HEIGHT = r.ImGui_CalcTextSize(ctx, 'A')
    gui.VERTICAL_TEXT_BASE_HEIGHT_OFFSET = -2
    r.ImGui_PopFont(ctx)
    gui.st.vars.mtrx.table[r.ImGui_StyleVar_FramePadding()]   ={1,(cellSize-gui.TEXT_BASE_HEIGHT) / 2+2}
    -- iterate render setting group colors
    
    local base_color = 0xff66d6ff
    local lightnessSteps = .1
    local hueStep = 0.2
        
    for i=1, RENDER_SETTING_GROUPS_SLOTS do
      local re,g,b,a = r.ImGui_ColorConvertU32ToDouble4(base_color)
      local h,s,v = r.ImGui_ColorConvertRGBtoHSV(re,g,b)
      local shiftedCol = {[r.ImGui_Col_Text()] = 0x000000ff,
                          [r.ImGui_Col_Button()] = base_color,
                          [r.ImGui_Col_ButtonHovered()] = 0xFFFFFF33,
                          [r.ImGui_Col_ButtonActive()] = 0xFFFFFF88}
      table.insert(gui.st.col.render_setting_groups,shiftedCol)
      --shift to next base color
      re,g,b = r.ImGui_ColorConvertHSVtoRGB((h+hueStep),s,v)
      base_color =  r.ImGui_ColorConvertNative( r.ImGui_ColorConvertDouble4ToU32(re,g,b,a))
    end
  end
  
  local db         = {
    stems                  = {},
    error                  = nil,
    renderPresets          = {},
    getRenderPresets       = function(self)
      self.renderPresets = {}
      local path         = string.format('%s/reaper-render.ini', r.GetResourcePath())
      if not r.file_exists(path) then
        return presets
      end
  
      local file, err    = assert(io.open(path, 'r'))
  
      local tokens       = {}
      self.renderPresets = {}
      for line in file:lines() do
        tokens = tokenize(line)
        if not (tokens[2] == "") and tokens[2] then
          local name = tokens[2]
          self.renderPresets[name] = self.renderPresets[name] or {}
          self.renderPresets[name].name = name
          self.renderPresets[name].filepattern=tokens[8] or self.renderPresets[name].filepattern
          if tokens[6] then self.renderPresets[name].settings = (tonumber(tokens[6]) & SETTINGS_SOURCE_MASK) | ( self.renderPresets[name].settings or 0) end
          if tokens[3] then self.renderPresets[name].boundsflag = tonumber(tokens[3]) end
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
      if persist == nil then persist = false end
      local found = false
      for state,v in pairs(STATE_RPR_CODES) do
        if  v['I_SOLO'] == r.GetMediaTrackInfo_Value(track.object, 'I_SOLO') 
        and v['B_MUTE'] == r.GetMediaTrackInfo_Value(track.object, 'B_MUTE') then
          self:setTrackStateInStem(track, stemName, state,false,false)
          found = true
          break
        end
        if not found then else self:setTrackStateInStem(track, stemName, nil,false,false) end
      end
      if persist then self:save() end
    end,
    reflectAllTracksOnStem = function(self, stemName)
      for i, track in ipairs(self.tracks) do
        self:reflectTrackOnStem(stemName, track)
      end
      self:save()
    end,
    reflectStemOnTrack = function(self, stemName, track)
      if not (r.GetMediaTrackInfo_Value(track.object, 'I_SOLO') == STATE_RPR_CODES[track.stemMatrix[stemName] or ' ']['I_SOLO'])
      then    r.SetMediaTrackInfo_Value(track.object, 'I_SOLO',    STATE_RPR_CODES[track.stemMatrix[stemName] or ' ']['I_SOLO']) end
      if not (r.GetMediaTrackInfo_Value(track.object, 'B_MUTE') == STATE_RPR_CODES[track.stemMatrix[stemName] or ' ']['B_MUTE'])
      then    r.SetMediaTrackInfo_Value(track.object, 'B_MUTE',    STATE_RPR_CODES[track.stemMatrix[stemName] or ' ']['B_MUTE']) end
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
        local track                                 = r.GetTrack(0, i)
        self.savedSoloStates[r.GetTrackGUID(track)] = {
          ['solo'] = r.GetMediaTrackInfo_Value(track, 'I_SOLO'),
          ['mute'] = r.GetMediaTrackInfo_Value(track, 'B_MUTE'),
        }
      end
      self:save()
    end,
    recallSoloState = function(self)
      for i = 0, r.CountTracks(0) - 1 do
        local track      = r.GetTrack(0, i)
        local trackGUID  = r.GetTrackGUID(track)
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
            if not syncingStemFound then self:saveSoloState() end
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
      if findSame == nil then findSame = false end
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
              track.stemMatrix[k]                   = nil
            end
          end
        end
      elseif not self.stems[name] then
        persist          = true
        self.stemCount   = (self.stemCount or 0) + 1
        self.stems[name] = {order = self.stemCount, sync = SYNCMODE_OFF, render_setting_group = 1}
        if copy then self:reflectAllTracksOnStem(name) end
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
      for k,v in pairs(self.stems) do
        if v.order > self.stems[stemName].order then
          self.stems[k].order = self.stems[k].order -1
        end
      end
      -- remove stem
      self.stems[stemName] = nil
      self:save()
    end,
    reorderStem = function(self, stemName, newPos)
      local oldPos = self.stems[stemName].order
      for k,v in pairs(self.stems) do
        if (v.order >= newPos) and (v.order < oldPos) then self.stems[k].order = self.stems[k].order + 1 end
        if (v.order <= newPos) and (v.order > oldPos) then self.stems[k].order = self.stems[k].order - 1 end
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
              track.stemMatrix[k]       = nil
            end
          end
        end
        self.stems[newName]  = self.stems[stemName]
        self.stems[stemName] = nil
        self:save()
      end
    end,
    save  = function(self)
      -- persist track states
      for trackIdx = 0, r.CountTracks(0) - 1 do
        local rTrack         = r.GetTrack(0, trackIdx)
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
      saveLongProjExtState('STEMS', pickle(self.stems or {}))
      for k, v in pairs(self.savedSoloStates) do
        r.SetProjExtState(0, scr.context_name .. '_SAVED_SOLO_STATES', k, pickle(v))
      end
      r.MarkProjectDirty(0)
    end,
    sync = function(self, full)
      if app.debug then tim = os.clock() end
      self.cycles = self.cycles or 0
      if self.cycles == 0 then full = true end        -- if first cycle, force full sync
      self.current_project = r.GetProjectStateChangeCount(0)  -- if project changed, force full sync
      if self.current_project ~= self.previous_project then
        self.previous_project = self.current_project
        full = true
      end
     
      if full then
        if app.debug then r.ShowConsoleMsg('FULL SYNC\n') end
        self.stems           = unpickle(loadLongProjExtKey('STEMS')) or {}
        self.prefSoloIP      = select(2, r.get_config_var_string('soloip')) == '1'
      end
      
      self.trackChangeTracking      = self.trackChangeTracking or ''
      self.tracks = self.tracks or {}
      self.stemToSync      = nil
      self.error           = nil
      self.stemCount       = 0;
      
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
        self.lastTrackCount =  trackCount
        self.tracks          = {}
        for trackIdx = 0, trackCount - 1 do
          local rTrack           = r.GetTrack(0, trackIdx)
          local _, name = r.GetSetMediaTrackInfo_String(rTrack, "P_NAME", "", false)
          local folderDepth      = r.GetMediaTrackInfo_Value(rTrack, "I_FOLDERDEPTH", "", false)
          local color            = r.GetTrackColor(rTrack)
          local _, rawStemMatrix = r.GetSetMediaTrackInfo_String(rTrack, "P_EXT:" .. scr.context_name .. '_STEM_MATRIX', "", false)
          local stemMatrix       = unpickle(rawStemMatrix)
          local trackInfo        = {
            object      = rTrack,
            name        = name,
            folderDepth = folderDepth,
            color       = color,
            stemMatrix  = stemMatrix or {}}
          -- iterate tracks to create stems
          if trackInfo then table.insert(self.tracks, trackInfo) end
          for k,v in pairs(trackInfo.stemMatrix or {}) do self:addStem(k, false) end
        end
      end
      
      for i, track in ipairs(self.tracks) do
      -- if stem is syncing, sync it
        if (self.stemToSync) and (self.syncMode == SYNCMODE_MIRROR) then self:reflectTrackOnStem(self.stemToSync, track) end
      end
      self.cycles = self.cycles + 1
      if app.debug then
        self.cumlativeTime = self.cumlativeTime and (self.cumlativeTime + (os.clock() - tim)) or (os.clock() - tim)
        if self.cycles/10 == math.ceil(self.cycles/10) then
          r.ShowConsoleMsg(string.format("average over %d sync operations: %.10f\n", self.cycles,self.cumlativeTime / self.cycles))
        end
      end
    end}
  
  local validators = {
    stem   = {
      name = (
              function(origVal, val)
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
  
  function deleteLongerProjExtState(key)
    local n = '*'
    while reaper.GetProjExtState(0,scr.context_name, key..n) == 1 do 
      reaper.SetProjExtState(0,scr.context_name, key..n, '')
      n = n..'*' 
    end
  end
  
  function saveLongProjExtState(key, val)
    local maxLength = 2^12-#key-2
    deleteLongerProjExtState(key)
    r.SetProjExtState(0, scr.context_name, key, val:sub(1,maxLength))
    if #val > maxLength then saveLongProjExtState(key..'*', val:sub(maxLength+1, #val)) end
  end
  
  function loadLongProjExtKey(key)
    local i = 0
    local maxLength = 2^12-#key-2
    while true do
      retval, k, val = r.EnumProjExtState(0, scr.context_name, i)
      if not retval then break end
      if (k == key) then
        if #val==maxLength then val = val..(loadLongProjExtKey(key..'*') or '') end
        return val
      end
      i = i + 1
    end
  end
  
  local settings        = {}
  
  local function getDefaultSettings(factory)
    if factory == nil then factory = false end
    local settings = {
      default  = {
        renderaction = RENDERACTION_RENDER,
        wait_time = 5,
        reflect_on_add = REFLECT_ON_ADD_TRUE,
        syncmode = SYNCMODE_MIRROR,
        render_setting_groups = {}
      }
    }
    
    local default_render_settings = {
      description = '',
      render_preset = nil, 
      skip_empty_stems = true,
      put_in_folder = false,
      folder='',
      override_filename = false,
      filename='',
      make_timeSel = false, 
      timeSelStart = 0, 
      timeSelEnd = 0,
      select_regions = false,
      selected_regions = {},
      select_markers = false,
      selected_markers = {},
      run_actions = false,
      actions_to_run = {},
      ignore_warnings = false
    }
    for i=1, RENDER_SETTING_GROUPS_SLOTS do
     table.insert(settings.default.render_setting_groups, deepcopy(default_render_settings))
    end
    
    if not factory then
      local loaded_ext_settings = unpickle(r.GetExtState(scr.context_name, 'DEFAULT SETTINGS') or '')
      -- merge default settings from extstates with script defaults
      for k, v in pairs(loaded_ext_settings or {}) do
        if not (k == 'render_setting_groups') then
          settings.default[k] = v
        else
          for rgIdx,val in ipairs(v) do
            for rgSetting, rgV in pairs(val or {}) do
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
    local loaded_project_settings = unpickle(loadLongProjExtKey('PROJECT SETTINGS'))
    settings.project = deepcopy(settings.default)
    for k, v in pairs(loaded_project_settings or {}) do 
      if not (k == 'render_setting_groups') then
        settings.project[k] = v
      else
        for rgIdx,val in ipairs(v) do
          for rgSetting, rgV in pairs(val or {}) do
            settings.project.render_setting_groups[rgIdx][rgSetting] = rgV
          end
        end
      end
    end
  end
  
  local function saveSettings()
    r.SetExtState(scr.context_name, 'DEFAULT SETTINGS', pickle(settings.default), true)
    saveLongProjExtState('PROJECT SETTINGS',pickle(settings.project))
    r.MarkProjectDirty(0)
  end
  
  
  local function sanitizeFilename(name)
    -- replace special characters that are reserved on Windows
    return name:gsub('[*\\:<>?/|"%c]+', '-')
  end
  
  local function createAction(actionName, cmd)
    local snActionName = sanitizeFilename(actionName)
    local filename = ('%s - %s'):format(scr.no_ext,snActionName)
    
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
        cmd = cmd})
    code = ('-- This file was created by %s on %s\n\n'):format(scr.name, os.date('%c'))..code
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
        pos  = pos + 1 -- eat the opening quote
        tail = line:find('"%s', pos)
        eat  = 2
  
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
  
  -- Save copied tables in `copies`, indexed by original table.
  function deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
      if copies[orig] then
        copy = copies[orig]
      else
        copy = {}
        copies[orig] = copy
        for orig_key, orig_value in next, orig, nil do
          copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
        end
        setmetatable(copy, deepcopy(getmetatable(orig), copies))
      end
    else -- number, string, boolean, etc
      copy = orig
    end
    return copy
  end
  
  function pairsByOrder (t, f)
    local a = {}
    for n in pairs(t) do
      table.insert(a, n)
    end
    table.sort(a, function(a, b)
      return t[a].order < t[b].order
    end)
    local i    = 0      -- iterator variable
    local iter = function()
      -- iterator function
      i = i + 1
      if a[i] == nil then
        return nil
      else
        return a[i], t[a[i]]
      end
    end
    return iter
  end
  
  --------------------------------------------------------------------------------
  -- table serialization ---------------------------------------------------------
  --------------------------------------------------------------------------------
  
  ------------------------------------------- --
  -- Pickle.lua
  -- A table serialization utility for lua
  -- Steve Dekorte, http://www.dekorte.com, Apr 2000
  -- (updated for Lua 5.3 by lb0)
  -- Freeware
  ----------------------------------------------
  
  function pickle(t)
    return Pickle:clone():pickle_(t)
  end
  
  Pickle = {
    clone = function(t)
      local nt = {};
      for i, v in pairs(t) do
        nt[i] = v
      end
      return nt
    end
  }
  
  function Pickle:pickle_(root)
    if type(root) ~= "table" then
      error("can only pickle tables, not " .. type(root) .. "s")
    end
    self._tableToRef = {}
    self._refToTable = {}
    local savecount  = 0
    self:ref_(root)
    local s = ""
  
    while #self._refToTable > savecount do
      savecount = savecount + 1
      local t   = self._refToTable[savecount]
      s         = s .. "{\n"
  
      for i, v in pairs(t) do
        s = string.format("%s[%s]=%s,\n", s, self:value_(i), self:value_(v))
      end
      s = s .. "},\n"
  
    end
    return string.format("{%s}", s)
  end
  
  function Pickle:value_(v)
    local vtype = type(v)
    if vtype == "string" then
      return string.format("%q", v)
    elseif vtype == "number" then
      return v
    elseif vtype == "boolean" then
      return tostring(v)
    elseif vtype == "table" then
      return "{" .. self:ref_(v) .. "}"
    else
      error("pickle a " .. type(v) .. " is not supported")
    end
  end
  
  function Pickle:ref_(t)
    local ref = self._tableToRef[t]
    if not ref then
      if t == self then
        error("can't pickle the pickle class")
      end
      table.insert(self._refToTable, t)
      ref                 = #self._refToTable
      self._tableToRef[t] = ref
    end
    return ref
  end
  
  ----------------------------------------------
  -- unpickle
  ----------------------------------------------
  
  function unpickle(s)
    if s == nil or s == '' then
      return
    end
    if type(s) ~= "string" then
      error("can't unpickle a " .. type(s) .. ", only strings")
    end
    local gentables = load("return " .. s)
    if gentables then
      local tables = gentables()
  
      if tables then
        for tnum = 1, #tables do
          local t     = tables[tnum]
          local tcopy = {};
          for i, v in pairs(t) do
            tcopy[i] = v
          end
          for i, v in pairs(tcopy) do
            local ni, nv
            if type(i) == "table" then
              ni = tables[i[1]]
            else
              ni = i
            end
            if type(v) == "table" then
              nv = tables[v[1]]
            else
              nv = v
            end
            t[i]  = nil
            t[ni] = nv
          end
        end
        return tables[1]
      end
    else
      --error
    end
  end
  
  --------------------------------------------------------------------------------
  -- MAIN APP --------------------------------------------------------------------
  --------------------------------------------------------------------------------
  
  local function GetRegionManagerWindow()
    local title = r.JS_Localize('Region/Marker Manager', 'common')
    return r.JS_Window_Find(title, true)
  end
  
  local function OpenAndGetRegionManagerWindow()
    local manager = GetRegionManagerWindow()
    if not manager then
      r.Main_OnCommand(40326, 0) -- View: Show region/marker manager window
      manager = r.JS_Window_Find(title, true)
    end
    return manager
  end
  
  local function GetAllRegionsOrMarkers(m_type, close)
    if close == nil then close = true end
    local manager = OpenAndGetRegionManagerWindow()
    local lv = r.JS_Window_FindChildByID(manager, 1071)
    local cnt = r.JS_ListView_GetItemCount(lv)
    local t = {}
    if m_type == '' then m_type = nil end
    for i = 0, cnt-1 do
      local matchstring = ("%s%%d+"):format(m_type and (m_type:upper()) or ".")
      for rId in r.JS_ListView_GetItemText(lv, i, 1):gmatch(matchstring) do
        t[#t+1]= {
          is_rgn = rId:sub(1,1) == 'R',
          id = rId, 
          name = r.JS_ListView_GetItemText(lv, i, 2),
          selected = (r.JS_ListView_GetItemState(lv, i)~=0)} 
      end
    end
    if close then r.Main_OnCommand(40326, 0) end -- View: Show region/marker manager window
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
    if close == nil then close = true end
    local markeregions, lv = GetAllRegionsOrMarkers(false)
    r.JS_ListView_SetItemState(lv, -1, 0x0, 0x2)         -- unselect all items
    for _, markeregion_to_select in ipairs(selection) do
      for i, markeregion in ipairs(markeregions) do
        if markeregion.id == tostring(markeregion_to_select.id) then
          r.JS_ListView_SetItemState(lv, i-1, 0xF, 0x2) -- select item @ index
        end
      end
    end
    if close then r.Main_OnCommand(40326, 0) end -- View: Show region/marker manager window
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
    SelectRegionsOrMarkers(selection,close)
  end
  
  local function SelectMarkers(selection, close)
    SelectRegionsOrMarkers(selection,close)
  end
  
  local function checkRenderGroupSettings(rsg) 
    local checks = {}
    local ok = true
    presetName = rsg.render_preset
    
    if presetName and not db.renderPresets[presetName] then
      table.insert(checks, {passed = false, 
                            status="Preset does not exist",
                            severity='critical',
                            hint=("There's no render preset with the name '%s'."):format(presetName)})
      ok = ok and test
    elseif not presetName then
      table.insert(checks,{passed = false, 
                           status="No render preset selected",
                           severity='critical',
                           hint="A render preset must be selected."})
      ok = false
    else
      local preset = db.renderPresets[presetName]
      local test = preset.settings == 1
      table.insert(checks,{passed =test, 
                           status=("Render preset source %s 'Master mix'"):format(test and 'is' or 'is not'),
                           severity= (not test and 'warning' or nil),
                           hint=test and "The render preset's source is set to 'Master mix'." or "For the stems to be rendered correctly, the source must be set to 'Master mix'."})
      ok = ok and test
      
      test = ((rsg.override_filename == true) and string.find(rsg.filename, "$stem")) or string.find(preset.filepattern, "$stem")
      table.insert(checks,{passed = test, 
                           status=("$stem %s filename"):format(test and 'in' or "not in"),
                           severity=(not test and 'warning' or nil),
                           hint=test and "Stem name will be inserted wherever the $stem wildcard is used." or "$stem wildcard not used in render preset. Fix by overriding the filename."})
      ok = ok and test
      
      if preset.boundsflag == RB_TIME_SELECTION and rsg.make_timeSel and not (rsg.timeSelEnd > rsg.timeSelStart) then
        table.insert(checks,{passed = false, 
                     status="Illegal time selection",
                     severity='critical',
                     hint="Please capture time selection, or uncheck 'make time selection before rendering'."})
        ok = false
      end
      if preset.boundsflag == RB_SELECTED_MARKERS then
        if not r.APIExists('JS_Localize') then
          table.insert(checks,{passed = false, 
                               status="js_ReaScriptAPI missing",
                               severity=('critical'),
                               hint="js_ReaScriptAPI extension is required for selecting markers."})
          ok = false
        end
        if rsg.select_markers and #rsg.selected_markers == 0 then
          table.insert(checks,{passed = false, 
                       status="No markers selected",
                       severity='critical',
                       hint="Please select markers or uncheck 'Select markers before rendering'."})
          ok = false
        end
      end
      if preset.boundsflag == RB_SELECTED_REGIONS then
        if not r.APIExists('JS_Localize') then
          table.insert(checks,{passed = false, 
                               status="js_ReaScriptAPI missing",
                               severity='critical',
                               hint="js_ReaScriptAPI extension is required for selecting regions."})
          ok = false
        end
        if rsg.select_regions and #rsg.selected_regions == 0 then
          table.insert(checks,{passed = false, 
                       status="No regions selected",
                       severity='critical',
                       hint="Please select regions or uncheck 'Select regions before rendering'."})
          ok = false
        end
      end
      
    end
    return ok, checks
  end
  
  local function doPerform()
    db:sync()
    app.perform.fullRender = (app.stemToRender == nil) --and app.renderGroupToRender == nil)
    local stemsToRender
    if app.stemToRender then
      stemsToRender =  {[app.stemToRender] = db.stems[app.stemToRender]}
    elseif app.renderGroupToRender then
      stemsToRender = {}
      for k,v in pairs(db.stems) do
        if v.render_setting_group == app.renderGroupToRender then
          stemsToRender[k] = v
        end
      end
    else
      stemsToRender = db.stems      
    end
    coroutine.yield('Rendering stems', 0, 1)
    local idx          = 0
    local laststemName = nil
    local markeregion_selection = {}
    app.render_cancelled = false
    app.current_renderaction = app.forceRenderAction or settings.project.renderaction
    -- check if any stem requires markers or regions, and only save the region/marker
    -- selection if needed (because it requires opening the marker window)
    local save_marker_selection = false
    for stemName, stem in pairs(stemsToRender) do
      local stem = db.stems[stemName]
      local rsg = settings.project.render_setting_groups[stem.render_setting_group]
      if rsg.select_markers or rsg.select_regions then
        save_marker_selection = true
        break
      end
    end
    -- save marker selection, so that it can be restored later
    if save_marker_selection and r.APIExists('JS_Localize') then
      OpenAndGetRegionManagerWindow()
      coroutine.yield('Saving marker/region selection', 0, 1)
      markeregion_selection = GetSelectedRegionsOrMarkers()
      r.Main_OnCommand(40326, 0)
    end
    if r.GetAllProjectPlayStates(0)&1 then r.OnStopButton() end
    for stemName, stem in pairsByOrder(stemsToRender) do
      if not app.render_cancelled then
        idx = idx + 1
        
        --TODO: CONSOLIDATE UNDO HISTORY?:
        local stem = db.stems[stemName]
        local rsg = settings.project.render_setting_groups[stem.render_setting_group]
        
        -- check if any track has a state in this stem
        local foundAssignedTrack = false
        for idx, track in ipairs(db.tracks) do
          foundAssignedTrack = foundAssignedTrack or (track.stemMatrix[stemName] ~= ' ' and track.stemMatrix[stemName] ~= nil)
        end
        if not (rsg.skip_empty_stems and not foundAssignedTrack) or not app.perform.fullRender then
          ---- if no track has a state in this stem, then untoggle the last stem so the project's default solo state will be restored
          ---- Thie was removed in v0.2 since reflect_on_add is on by default, so empty stems are actually the mix by default, unless
          ---- specifically decided not to be by the user. I'm leaving it here in case the request comes up.
          ---- To resume this behavior, uncomment the following two lines and comment the next one.
          -- if foundAssignedTrack then db:toggleStemSync(db.stems[stemName], SYNCMODE_SOLO)
          -- elseif laststemName then db:toggleStemSync(db.stems[laststemName], SYNCMODE_OFF) end
          db:toggleStemSync(db.stems[stemName], SYNCMODE_SOLO)
          coroutine.yield('Creating Stem ' .. stemName, idx, app.perform.fullRender and db.stemCount or 1)
          db:getRenderPresets()
          local ok, checks = checkRenderGroupSettings(rsg)
          local criticalErrorFound = false
          if not ok then
            local errors = {}
            local criticalErrors = {}
            for i, check in ipairs(checks) do
              if not check.passed then
                if check.severity =='critical' then
                  criticalErrorFound = true 
                  table.insert(criticalErrors,' - '..check.status)
                elseif not rsg.ignore_warnings then
                  table.insert(errors,' - '..check.status)
               end
              end
            end
            if #errors > 0 or #criticalErrors > 0 then
              app.errors = app.errors or {}
              table.insert(app.errors, ("Stem '%s' was %s:\n%s"):format(
                  stemName,
                  criticalErrorFound and 'not added to the render queue\nbecause of the following error(s)' 
                                      or 'added to the render queue\nbut the following warning(s) were found',  
                  criticalErrorFound and table.concat(criticalErrors,'\n')
                                      or table.concat(errors,'\n')))
            end
          end
          if not criticalErrorFound then
            local render_preset = db.renderPresets[rsg.render_preset]
            ApplyPresetByName = render_preset.name
            applyPresetScript()
            
            if render_preset.boundsflag == RB_SELECTED_MARKERS and rsg.select_markers then
              -- window must be given an opportunity to open (therefore yielded) for the selection to work
              OpenAndGetRegionManagerWindow()
              coroutine.yield('Creating Stem ' .. stemName.. ' (selecting markers)', idx, app.perform.fullRender and db.stemCount or 1)
              SelectMarkers(rsg.selected_markers)
            elseif render_preset.boundsflag == RB_SELECTED_REGIONS and rsg.select_regions then
              -- window must be given an opportunity to open (therefore yielded) for the selection to work
              OpenAndGetRegionManagerWindow()
              coroutine.yield('Creating Stem ' .. stemName.. ' (selecting regions)', idx, app.perform.fullRender and db.stemCount or 1)
              
              SelectRegions(rsg.selected_regions)
            elseif render_preset.boundsflag == RB_TIME_SELECTION and rsg.make_timeSel then
             r.GetSet_LoopTimeRange2(0,true, false, rsg.timeSelStart,rsg.timeSelEnd,0)--, boolean isLoop, number start, number end, boolean allowautoseek)
            end
            
            local folder = ''
            if rsg.put_in_folder then
              folder            = rsg.folder and (rsg.folder:gsub('/%s*$','') .. "/") or ""
            end
            local filename = render_preset.filepattern
            if rsg.override_filename then
              filename = (rsg.filename == nil or rsg.filename == '') and render_preset.filepattern or rsg.filename
            end
            local filenameInFolder  = (folder .. filename):gsub('$stem',stemName)
            r.GetSetProjectInfo_String(0, "RENDER_PATTERN", filenameInFolder, true)
           
            if rsg.run_actions then
             for aIdx, action in ipairs(rsg.actions_to_run or {}) do
               r.Main_OnCommand(action, 0)
             end
            end
            --local _v, msg = r.GetSetProjectInfo_String(0, "RENDER_PATTERN", '', false)
            if app.current_renderaction == RENDERACTION_RENDER then
              coroutine.yield('rendering', idx, app.perform.fullRender and db.stemCount or 1)
              r.Main_OnCommand(42230, 0) --render now
              r.Main_OnCommand(40043,0) -- go to end of project
              r.OnPlayButtonEx(0)
              local t = os.clock()
              r.ImGui_OpenPopup(gui.ctx,scr.name..'##wait')
              while not app.render_cancelled and (os.clock() - t < settings.project.wait_time) and idx < (app.perform.fullRender and db.stemCount or 1) do
                local wait_left = math.ceil(settings.project.wait_time - (os.clock() - t))
                if app.drawPopup(gui.ctx, 'msg',scr.name..'##wait',{closeKey = r.ImGui_Key_Escape(),okButtonLabel = "Stop rendering", msg = ('Waiting for %d more second%s...'):format(wait_left, wait_left > 1 and 's' or '')}) then
                  app.render_cancelled = true
                end
                coroutine.yield('Waiting...', idx, app.perform.fullRender and db.stemCount or 1)
              end
              r.OnStopButtonEx(0)
            else
              r.Main_OnCommand(41823, 0) --add to render queue
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
      SelectRegionsOrMarkers(markeregion_selection)
    end
    coroutine.yield('Done', 1, 1)
    return
  end
  
  local function checkExternalCommand()
    local raw_cmd = r.GetExtState(scr.context_name, 'EXTERNAL COMMAND')
    local cmd, arg = raw_cmd:match('^([%w_]+)%s*(.*)$')
    if cmd ~= '' and cmd ~= nil then 
      r.SetExtState(scr.context_name, 'EXTERNAL COMMAND','', false) 
      if cmd == 'sync' then
        if arg then stemName = db:findSimilarStem(arg, true) end
        if stemName then
          if db.stems[stemName] then 
            db:toggleStemSync(db.stems[stemName], (db.stems[stemName].sync == SYNCMODE_SOLO) and SYNCMODE_OFF or SYNCMODE_SOLO) 
          end
        end
      elseif (cmd == 'add') or (cmd == 'render') then
        if arg then stemName = db:findSimilarStem(arg, true) end
        if stemName then
          if db.stems[stemName] then 
          app.forceRenderAction = (cmd == 'add') and RENDERACTION_RENDERQUEUE_OPEN or RENDERACTION_RENDER
          app.stemToRender = stemName
          app.coPerform = coroutine.create(doPerform) 
        end
        end
      elseif (cmd == 'add_rg') or (cmd == 'render_rg') then
        local renderGroup = tonumber(arg)
        if renderGroup and renderGroup>=1 and renderGroup <= RENDER_SETTING_GROUPS_SLOTS then
          app.forceRenderAction = (cmd == 'add_rg') and RENDERACTION_RENDERQUEUE_OPEN or RENDERACTION_RENDER
          app.renderGroupToRender = renderGroup
          app.coPerform = coroutine.create(doPerform) 
        end
      elseif cmd == 'add_all' then 
        app.coPerform = coroutine.create(doPerform) 
      end
    end
  end
  
  function app.drawPopup(ctx, popupType, title, data)
    local data   = data or {}
    local center = {gui.mainWindow.pos[1] + gui.mainWindow.size[1] / 2,
                    gui.mainWindow.pos[2] + gui.mainWindow.size[2] / 2, }  --{r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
    if popupType == 'singleInput' then
      local okPressed     = nil
      local initVal       = data.initVal or ''
      local okButtonLabel = data.okButtonLabel or 'OK'
      local validation    = data.validation or function(origVal, val)
        return true
      end
      local bottom_lines  = 2
  
      r.ImGui_SetNextWindowSize(ctx, 350, 110)
      r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
      if r.ImGui_BeginPopupModal(ctx, title, false, r.ImGui_WindowFlags_AlwaysAutoResize()) then
        gui.popups.title = title
  
        if r.ImGui_IsWindowAppearing(ctx) then
          r.ImGui_SetKeyboardFocusHere(ctx)
          gui.popups.singleInput.value  = initVal --gui.popups.singleInput.stem.name
          gui.popups.singleInput.status = ""
        end
        local width = select(1, r.ImGui_GetContentRegionAvail(ctx))
        r.ImGui_PushItemWidth(ctx, width)
        retval, gui.popups.singleInput.value = r.ImGui_InputText(ctx, '##singleInput', gui.popups.singleInput.value)
  
        r.ImGui_SetItemDefaultFocus(ctx)
        r.ImGui_SetCursorPosY(ctx,
                              r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeight(ctx) * bottom_lines) - r.ImGui_GetStyleVar(ctx,
                                                                                                                                r.ImGui_StyleVar_WindowPadding()))
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
      local okPressed             = nil
      local msg                   = data.msg or ''
      local textWidth, textHeight = r.ImGui_CalcTextSize(ctx, msg)
      local okButtonLabel         = data.okButtonLabel or 'OK'
      local bottom_lines          = 1
      local closeKey = data.closeKey or r.ImGui_Key_Enter()
  
      r.ImGui_SetNextWindowSize(ctx, math.max(220,textWidth) + r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()) * 4, textHeight + 90)
      r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
   
      if r.ImGui_BeginPopupModal(ctx, title, false, r.ImGui_WindowFlags_NoResize() + r.ImGui_WindowFlags_NoDocking()) then
        gui.popups.title = title
  
        local width      = select(1, r.ImGui_GetContentRegionAvail(ctx))
        r.ImGui_PushItemWidth(ctx, width)
  
        local windowWidth, windowHeight = r.ImGui_GetWindowSize(ctx);
        r.ImGui_SetCursorPos(ctx, (windowWidth - textWidth) * .5, (windowHeight - textHeight) * .5);

        r.ImGui_TextWrapped(ctx, msg)
        r.ImGui_SetCursorPosY(ctx,
                              r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeight(ctx) * bottom_lines) - r.ImGui_GetStyleVar(ctx,
                                                                                                                                r.ImGui_StyleVar_WindowPadding()))
        local buttonTextWidth = r.ImGui_CalcTextSize(ctx, okButtonLabel) + r.ImGui_GetStyleVar(ctx,
                                                                                               r.ImGui_StyleVar_FramePadding()) * 2;
        r.ImGui_SetCursorPosX(ctx, (windowWidth - buttonTextWidth) * .5);
  
        if r.ImGui_Button(ctx, okButtonLabel) or r.ImGui_IsKeyPressed(ctx, closeKey) then
          okPressed = true
          r.ImGui_CloseCurrentPopup(ctx)
        end
        r.ImGui_EndPopup(ctx)
      end
      return okPressed
    elseif popupType == 'stemActionsMenu' then
      if r.ImGui_BeginPopup(ctx, title) then
        if r.ImGui_Selectable(ctx, 'Rename', false, r.ImGui_SelectableFlags_DontClosePopups()) then gui.popups.object = data.stemName; r.ImGui_OpenPopup(ctx, 'Rename Stem')end
        local retval, newval = app.drawPopup(ctx, 'singleInput', 'Rename Stem', {initVal = data.stemName , okButtonLabel = 'Rename', validation = validators.stem.name})
        if retval == true then db:renameStem(data.stemName, newval) end
        if retval ~= nil then gui.popups.object = nil; r.ImGui_CloseCurrentPopup(ctx) end --could be true (ok) or false (cancel)
        app.setHoveredHint('main', 'Rename stem')
        if r.ImGui_Selectable(ctx, 'Add to render queue', false) then app.stemToRender = data.stemName; app.forceRenderAction = RENDERACTION_RENDERQUEUE_OPEN; app.coPerform = coroutine.create(doPerform) end
        app.setHoveredHint('main', "Add this stem only to the render queue") 
        if r.ImGui_Selectable(ctx, 'Render now', false) then app.stemToRender = data.stemName; app.forceRenderAction = RENDERACTION_RENDER; app.coPerform = coroutine.create(doPerform) end
        app.setHoveredHint('main', "Render this stem only") 
        if r.ImGui_Selectable(ctx, 'Get states from tracks', false) then db:reflectAllTracksOnStem(data.stemName)end
        app.setHoveredHint('main', "Get current solo/mute states from the project's tracks.")
        if r.ImGui_Selectable(ctx, 'Set states on tracks', false) then db:reflectStemOnAllTracks(data.stemName )end
        app.setHoveredHint('main', "Set this stem's solo/mute states on the project's tracks.")
        if r.ImGui_Selectable(ctx, 'Clear states', false) then db:resetStem(data.stemName )end
        app.setHoveredHint('main', "Clear current stem solo/mute states.")
        r.ImGui_Separator(ctx)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), gui.st.col.critical)
        if r.ImGui_Selectable(ctx, 'Delete', false) then db:removeStem(data.stemName) end
        r.ImGui_PopStyleColor(ctx)
        app.setHoveredHint('main', 'Delete stem')
        if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then r.ImGui_CloseCurrentPopup(ctx) end
        r.ImGui_EndPopup(ctx)
      end
    elseif popupType == 'renderPresetSelector' then
      local selectedPreset = nil
      --r.ImGui_SetNextWindowSize(ctx,0,100)
      r.ImGui_SetNextWindowSizeConstraints(ctx, 0, 100, 1000, 250)
      if r.ImGui_BeginPopup(ctx, title) then
        gui.popups.title = title
        local presetCount = 0
        for i, preset in pairs(db.renderPresets) do
          presetCount = presetCount+1
          if r.ImGui_Selectable(ctx, preset.name, false) then
            selectedPreset = preset.name
          end
        end
        if presetCount == 0 then
          r.ImGui_Text(ctx, "No render presets found.\nPlease create and add presets using\nREAPER's render window preset button.")
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
    local letterspacing = (gui.VERTICAL_TEXT_BASE_HEIGHT+gui.VERTICAL_TEXT_BASE_HEIGHT_OFFSET)
    local posX, posY = r.ImGui_GetCursorPosX(ctx), r.ImGui_GetCursorPosY(ctx)-letterspacing*#text
    text = text:reverse()
    for ci = 1, #text do
      r.ImGui_SetCursorPos(ctx, posX, posY+letterspacing*(ci-1))
      r.ImGui_Text(ctx, text:sub(ci, ci))
    end
    r.ImGui_PopFont(ctx)
  end
  
  function app.drawBtn(btnType,data)
    local ctx = gui.ctx
    local cellSize = gui.st.vars.mtrx.cellSize
    local headerRowHeight = gui.st.vars.mtrx.headerRowHeight
    local modKeys = gui.modKeys
    local clicked = false
    if btnType == 'stemSync' then
      local stemSyncMode = data.stemSyncMode
      local generalSyncMode = data.generalSyncMode
      local isSyncing = ((stemSyncMode ~= SYNCMODE_OFF) and (stemSyncMode ~= nil))
      local displayedSyncMode = isSyncing and stemSyncMode or generalSyncMode --if stem is syncing, show its mode, otherwise, show mode based on preferences+alt key
      local altSyncMode = (displayedSyncMode == SYNCMODE_SOLO) and SYNCMODE_SOLO or SYNCMODE_MIRROR
      local btnColor = isSyncing and gui.st.col.stemSyncBtn[displayedSyncMode].active or gui.st.col.stemSyncBtn[displayedSyncMode].inactive
      local circleColor = isSyncing and gui.st.col.stemSyncBtn[displayedSyncMode].active[r.ImGui_Col_Text()] or gui.st.col.stemSyncBtn[displayedSyncMode].active[r.ImGui_Col_Button()]
      local centerPosX, centerPosY = select(1, r.ImGui_GetCursorScreenPos(ctx)) + cellSize / 2, select(2, r.ImGui_GetCursorScreenPos(ctx)) + cellSize / 2
      r.ImGui_SetCursorPosY(ctx,r.ImGui_GetCursorPosY(ctx)+1)
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
        app.setHoveredHint('main', ("Stem is mirrored (soloing/muting in REAPER %s). Click to stop mirroring."):format(SYNCMODE_DESCRIPTIONS[displayedSyncMode]))
      else
        if modKeys=='a' then
          app.setHoveredHint('main', ("%s+click to mirror stem (soloing/muting in REAPER %s)."):format(gui.descModAlt:gsub("^%l", string.upper),SYNCMODE_DESCRIPTIONS[altSyncMode]))
        else
          app.setHoveredHint('main', ("Click to mirror stem (soloing/muting in REAPER %s)."):format(SYNCMODE_DESCRIPTIONS[displayedSyncMode]))
        end
      end
    elseif btnType=='stemActions' then
      local topLeftX, topLeftY = data.topLeftX, data.topLeftY
      local centerPosX, centerPosY = topLeftX + cellSize / 2, topLeftY + cellSize / 2
      local sz, radius = 4.5, 1.5
      local color      = gui.st.col.button[r.ImGui_Col_Text()]
      gui:pushColors(gui.st.col.button)
      if r.ImGui_Button(ctx, '##stemActions', cellSize, cellSize ) then
        r.ImGui_OpenPopup(ctx,'##stemActions')
      end
      gui:popColors(gui.st.col.button)
      r.ImGui_DrawList_AddCircleFilled(gui.draw_list, centerPosX - sz, centerPosY, radius,color,8)
      r.ImGui_DrawList_AddCircleFilled(gui.draw_list, centerPosX, centerPosY, radius,color,8)
      r.ImGui_DrawList_AddCircleFilled(gui.draw_list, centerPosX + sz, centerPosY, radius,color,8)
      app.setHoveredHint('main', 'Stem actions') 
    elseif btnType=='addStem' then
      gui:pushColors(gui.st.col.button)
      r.ImGui_SetCursorPosY(ctx,r.ImGui_GetCursorPosY(ctx)+1)
      if r.ImGui_Button(ctx, '##addStem', cellSize, headerRowHeight) then clicked = true end
      gui:popColors(gui.st.col.button)
      local centerPosX = select(1, r.ImGui_GetCursorScreenPos(ctx)) + cellSize / 2
      local centerPosY = select(2, r.ImGui_GetCursorScreenPos(ctx)) - headerRowHeight / 2
      local color      = gui.st.col.button[r.ImGui_Col_Text()]  --gui.st.col.stemSyncBtn.active[r.ImGui_Col_Text()] or gui.st.col.stemSyncBtn.active[r.ImGui_Col_Button()]
      r.ImGui_DrawList_AddLine(gui.draw_list, centerPosX - cellSize / 5, centerPosY, centerPosX + cellSize / 5, centerPosY, color, 2)
      r.ImGui_DrawList_AddLine(gui.draw_list, centerPosX, centerPosY - cellSize / 5, centerPosX, centerPosY + cellSize / 5, color, 2)
      if modKeys ~= "c" then app.setHoveredHint('main', ('Click to create a new stem %s.'):format(REFLECT_ON_ADD_DESCRIPTIONS[settings.project.reflect_on_add]))
                        else app.setHoveredHint('main', ('%s+click to create a new stem %s.'):format(gui.descModCtrlCmd:gsub("^%l", string.upper), REFLECT_ON_ADD_DESCRIPTIONS[(settings.project.reflect_on_add == REFLECT_ON_ADD_TRUE) and REFLECT_ON_ADD_FALSE or REFLECT_ON_ADD_TRUE]))
      end
    elseif btnType=='renderGroupSelector' then
      local stemName = data.stemName
      local stGrp = data.stGrp
      gui:pushColors(gui.st.col.render_setting_groups[stGrp])
      gui:pushStyles(gui.st.vars.mtrx.stemState)
      local origPosX, origPosY = r.ImGui_GetCursorPos(ctx)
      origPosY = origPosY + 1
      r.ImGui_SetCursorPosY(ctx, origPosY)
      local color = gui.st.col.render_setting_groups[stGrp][r.ImGui_Col_Button()]
      local topLeftX,topLeftY = r.ImGui_GetCursorScreenPos(ctx)
      r.ImGui_DrawList_AddRectFilled(gui.draw_list, topLeftX,topLeftY,topLeftX+cellSize,topLeftY+cellSize,color)
      r.ImGui_SetCursorPosY(ctx, origPosY)
      r.ImGui_Dummy(ctx, cellSize,cellSize)
      app.setHoveredHint('main', 'Stem to be rendered by settings group '..stGrp..'. Click arrows to change group.')
      if r.ImGui_IsItemHovered(ctx) then
        local description = settings.project.render_setting_groups[stGrp].description
        if description ~= nil and description ~= '' then 
          r.ImGui_PushStyleColor(ctx,r.ImGui_Col_Text(), gui.st.col.render_setting_groups[stGrp][r.ImGui_Col_Button()])
          r.ImGui_SetTooltip(ctx,description) 
          r.ImGui_PopStyleColor(ctx)
        end
        local centerX = r.ImGui_GetCursorScreenPos(ctx)+cellSize / 2
        local color = gui.st.col.render_setting_groups[stGrp][r.ImGui_Col_Text()]
        local sz=5
        r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) - cellSize)
        local startY = select(2,r.ImGui_GetCursorScreenPos(ctx))
        r.ImGui_Button(ctx, '###up'..stemName, cellSize,cellSize/3)
        if r.ImGui_IsItemClicked(ctx) then
          db.stems[stemName].render_setting_group = (stGrp == RENDER_SETTING_GROUPS_SLOTS) and 1 or stGrp + 1
          db:save()
        end
        if r.ImGui_IsItemHovered(ctx) then r.ImGui_SetMouseCursor(ctx, 7) end
        r.ImGui_DrawList_AddTriangleFilled(gui.draw_list,centerX,startY,centerX-sz*.5,startY+sz,centerX+sz*.5,startY+sz,color)
        app.setHoveredHint('main', ('Change to setting group %d.'):format((stGrp == RENDER_SETTING_GROUPS_SLOTS) and 1 or stGrp + 1))
        sz = sz+1
        r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) + cellSize/3)
        local startY = select(2,r.ImGui_GetCursorScreenPos(ctx))+ cellSize/3-sz
        r.ImGui_Button(ctx, '###down'..stemName,cellSize,cellSize/3)
        if r.ImGui_IsItemClicked(ctx) then
          db.stems[stemName].render_setting_group = (stGrp == 1) and RENDER_SETTING_GROUPS_SLOTS or stGrp - 1
          db:save()
        end
        if r.ImGui_IsItemHovered(ctx) then r.ImGui_SetMouseCursor(ctx, 7) end
        r.ImGui_DrawList_AddTriangleFilled(gui.draw_list,centerX-sz*.5,startY,centerX+sz*.5,startY,centerX,startY+sz,color)
        app.setHoveredHint('main', ('Change to setting group %d.'):format((stGrp == 1) and RENDER_SETTING_GROUPS_SLOTS or stGrp - 1))
      end
      local textSizeX, textSizeY = r.ImGui_CalcTextSize(ctx, tostring(stGrp))
      r.ImGui_SetCursorPos(ctx, origPosX+(cellSize-textSizeX)/2,origPosY+(cellSize-textSizeY)/2)
      r.ImGui_Text(ctx,stGrp)
      gui:popColors(gui.st.col.render_setting_groups[stGrp])
      gui:popStyles(gui.st.vars.mtrx.stemState) 
    elseif btnType =='stemState' then
      local state = data.state
      local track = data.track
      local stemName = data.stemName
      local stem = db.stems[stemName]
      local color_state = ((state == ' ') and (stem.sync ~= SYNCMODE_OFF) and (stem.sync ~= nil)) and {'sync_'..stem.sync,'sync_'..stem.sync} or STATE_COLORS[state]
      local curScrPos = {r.ImGui_GetCursorScreenPos(ctx)}
      curScrPos[2]=curScrPos[2]+1
      local text_size = {r.ImGui_CalcTextSize(ctx, STATE_LABELS[state])}
      r.ImGui_SetCursorScreenPos(ctx, curScrPos[1],curScrPos[2])
      r.ImGui_Dummy(ctx,cellSize,cellSize)
      local col_a, col_b
      if r.ImGui_IsItemHovered(ctx,r.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem()) then
        col_a = gui.st.col.stemState[color_state[1]][r.ImGui_Col_ButtonHovered()]
        col_b = gui.st.col.stemState[color_state[2]][r.ImGui_Col_ButtonHovered()]
      else
        col_a = gui.st.col.stemState[color_state[1]][r.ImGui_Col_Button()]
        col_b = gui.st.col.stemState[color_state[2]][r.ImGui_Col_Button()]
      end
      r.ImGui_DrawList_AddRectFilled(gui.draw_list, curScrPos[1], curScrPos[2], curScrPos[1]+cellSize/2, curScrPos[2]+cellSize, col_a)
      r.ImGui_DrawList_AddRectFilled(gui.draw_list, curScrPos[1]+cellSize/2, curScrPos[2], curScrPos[1]+cellSize, curScrPos[2]+cellSize, col_b)
      r.ImGui_SetCursorScreenPos(ctx, curScrPos[1]+(cellSize-text_size[1])/2,curScrPos[2]+(cellSize-text_size[2])/2)
      r.ImGui_TextColored(ctx,gui.st.col.stemState[color_state[1]][r.ImGui_Col_Text()],STATE_LABELS[state])
      r.ImGui_SetCursorScreenPos(ctx, curScrPos[1],curScrPos[2])
      r.ImGui_InvisibleButton(ctx, '##'..track.name..state..stemName, cellSize, cellSize)
      if r.ImGui_IsItemHovered(ctx,r.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem()) then
        r.ImGui_SetMouseCursor(ctx, 7)
        local defaultSolo   = db.prefSoloIP and STATES.SOLO_IN_PLACE            or STATES.SOLO_IGNORE_ROUTING
        local otherSolo     = db.prefSoloIP and STATES.SOLO_IGNORE_ROUTING      or STATES.SOLO_IN_PLACE
        local defaultMSolo  = db.prefSoloIP and STATES.MUTE_SOLO_IN_PLACE       or STATES.MUTE_SOLO_IGNORE_ROUTING
        local otherMSolo    = db.prefSoloIP and STATES.MUTE_SOLO_IGNORE_ROUTING or STATES.MUTE_SOLO_IN_PLACE
        local currentStateDesc = (state ~= ' ') and ('Track is %s. '):format(STATE_DESCRIPTIONS[state][2]) or ''
        local stateSwitches = {
          ['']  = {state = defaultSolo,  hint = ('%sClick to %s.'):format(currentStateDesc, (state == defaultSolo) and 'clear' or STATE_DESCRIPTIONS[defaultSolo][1])},
          ['s'] = {state = STATES.MUTE, hint = ('%sShift+click to %s.'):format(currentStateDesc, (state == STATES.MUTE) and 'clear' or STATE_DESCRIPTIONS[STATES.MUTE][1])},
          ['c'] = {state = otherSolo, hint = ('%s%s+click to %s.'):format(currentStateDesc, gui.descModCtrlCmd:gsub("^%l", string.upper), (state == otherSolo) and 'clear' or STATE_DESCRIPTIONS[otherSolo][1])},
          ['sa']= {state = defaultMSolo,hint = ('%sShift+%s+click to %s.'):format(currentStateDesc, gui.descModAlt, (state == defaultMSolo) and 'clear' or STATE_DESCRIPTIONS[defaultMSolo][1])},
          ['sc']= {state = otherMSolo,hint = ('%sShift+%s+click to %s.'):format(currentStateDesc, gui.descModCtrlCmd, (state == otherMSolo) and 'clear' or STATE_DESCRIPTIONS[otherMSolo][1])},
          ['a'] = {state = ' ', hint = ('%s%s'):format(currentStateDesc, ('%s+click to clear.'):format(gui.descModAlt:gsub("^%l", string.upper)))}}
        if stateSwitches[modKeys] then
          app.setHint('main',stateSwitches[modKeys].hint)
          if gui.mtrxTbl.drgState == nil and r.ImGui_IsMouseClicked(ctx, r.ImGui_MouseButton_Left()) then 
            gui.mtrxTbl.drgState = (state == stateSwitches[modKeys]['state']) and ' ' or stateSwitches[modKeys]['state']
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
    local defPadding = r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_FramePadding())
    local topLeftX, topLeftY = r.ImGui_GetCursorScreenPos(ctx)
    local stem = db.stems[stemName]
    r.ImGui_PushID(ctx, stemName)
    r.ImGui_SetCursorPos(ctx, r.ImGui_GetCursorPosX(ctx)+(r.ImGui_GetContentRegionAvail(ctx)-gui.VERTICAL_TEXT_BASE_WIDTH)/2, r.ImGui_GetCursorPosY(ctx) + headerRowHeight - defPadding)
    verticalText(ctx, stemName)
    if r.ImGui_IsMouseHoveringRect(ctx, topLeftX, topLeftY, topLeftX + cellSize, topLeftY + headerRowHeight) 
    and not r.ImGui_IsPopupOpen(ctx, '##stemActions', r.ImGui_PopupFlags_AnyPopup()) 
    or r.ImGui_IsPopupOpen(ctx, '##stemActions') then
      r.ImGui_SetCursorScreenPos(ctx, topLeftX, topLeftY + 1)
      gui:popStyles(gui.st.vars.mtrx.table)
      app.drawBtn('stemActions', {topLeftX=topLeftX, topLeftY=topLeftY})
      app.drawPopup(ctx, 'stemActionsMenu', '##stemActions',{stemName = stemName})
      gui:pushStyles(gui.st.vars.mtrx.table)
    end
    r.ImGui_SetCursorScreenPos(ctx, topLeftX+4, topLeftY + 4)
    r.ImGui_InvisibleButton(ctx, '##stemDrag', cellSize-8, headerRowHeight-6)
    if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_None()) then
      r.ImGui_SetDragDropPayload(ctx, 'STEM_COL', stemName)
      r.ImGui_Text(ctx, ('Move %s...'):format(stemName))
      r.ImGui_EndDragDropSource(ctx)
    end
    if r.ImGui_BeginDragDropTarget(ctx) then
      local payload
      rv,payload = r.ImGui_AcceptDragDropPayload(ctx, 'STEM_COL')
      if rv then
        db:reorderStem(payload,stem.order)
      end
      r.ImGui_EndDragDropTarget(ctx)
    end
    r.ImGui_PopID(ctx)
  end
  
  function app.drawMatrices(ctx, bottom_lines)
    local cellSize = gui.st.vars.mtrx.cellSize
    local childHeight = select(2, r.ImGui_GetContentRegionAvail(ctx)) - (r.ImGui_GetFrameHeightWithSpacing(ctx) * bottom_lines + r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_ItemSpacing())*2)
    local defPadding = r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_FramePadding())
    local modKeys = gui:updateModKeys()
    --if r.ImGui_CollapsingHeader(ctx,"Stem Selection",false,r.ImGui_TreeNodeFlags_DefaultOpen()) then
    if r.ImGui_BeginChild(ctx, 'stemSelector', 0, childHeight) then
      r.ImGui_PushFont(ctx, gui.st.fonts.default)
      if gui.mtrxTbl.drgState and r.ImGui_IsMouseReleased(ctx, r.ImGui_MouseButton_Left()) then gui.mtrxTbl.drgState = nil end -- needs to stop dragging before drag affects released hovered item to prevent edge case
      gui:pushStyles(gui.st.vars.mtrx.table)
      gui:pushColors(gui.st.col.trackname)
      local trackListX, trackListY, trackListWidth,trackListHeight
      trackListWidth = r.ImGui_GetContentRegionAvail(ctx) - r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_ScrollbarSize())
      if r.ImGui_BeginTable(ctx, 'table_scrollx', 1 + db.stemCount + 1, gui.tables.horizontal.flags1) then
        --- SETUP MATRIX TABLE
        local parent_open, depth, open_depth = true, 0, 0
        r.ImGui_TableSetupScrollFreeze(ctx, 1, 3)
        r.ImGui_TableSetupColumn(ctx, 'Track', r.ImGui_TableColumnFlags_NoHide(),
                                 width) -- Make the first column not hideable to match our use of TableSetupScrollFreeze()
        for stemName, tracks in pairsByOrder(db.stems) do
          r.ImGui_TableSetupColumn(ctx, stemName, nil, cellSize)
        end
        --- STEM NAME ROW
        local maxletters         = 0
        for k in pairs(db.stems) do
          maxletters = math.max(maxletters, #k)
        end
        gui.st.vars.mtrx.headerRowHeight = math.max(cellSize * 3, (gui.VERTICAL_TEXT_BASE_HEIGHT+gui.VERTICAL_TEXT_BASE_HEIGHT_OFFSET) * maxletters + defPadding*4)
        local headerRowHeight = gui.st.vars.mtrx.headerRowHeight
        r.ImGui_TableNextRow(ctx)
        r.ImGui_TableNextColumn(ctx)
-- STEM NAME ROW
  -- COL: TRACK/STEM CORNER HEADER ROW
        local x,y = r.ImGui_GetCursorPos(ctx)
        r.ImGui_Dummy(ctx, 230, 0) -- forces a minimum size to the track name col when no tracks exist
        local stemsTitleSizeX, stemsTitleSizeY = r.ImGui_CalcTextSize(ctx,'Stems')
        r.ImGui_SetCursorPos(ctx, x+r.ImGui_GetContentRegionAvail(ctx)-stemsTitleSizeY,y+headerRowHeight-defPadding)
        verticalText(ctx, 'Stems')
        r.ImGui_SetCursorPos(ctx, x+defPadding, y+(headerRowHeight)-stemsTitleSizeY-defPadding)
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
          if modKeys ~= "c" then app.copyOnAddStem = (settings.project.reflect_on_add == REFLECT_ON_ADD_TRUE)
                            else app.copyOnAddStem = (settings.project.reflect_on_add == REFLECT_ON_ADD_FALSE) end
          r.ImGui_OpenPopup(ctx, 'Add Stem')
        end
        gui:popStyles(gui.st.vars.mtrx.table)
        local retval, newval = app.drawPopup(ctx, 'singleInput', 'Add Stem', {okButtonLabel = 'Add', validation = validators.stem.name})
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
          r.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx)+ defPadding*2)
          r.ImGui_Text(ctx, 'Render Setting Groups')
        end
  -- COL: STEM RENDER GROUP
        for k, stem in pairsByOrder(db.stems) do
          if r.ImGui_TableNextColumn(ctx) then
            app.drawBtn('renderGroupSelector',{stemName = k, stGrp = stem.render_setting_group or 1})
          end
        end
-- TRACK NAME & SYNC BUTTONS
  -- COL: TRACK NAME
        r.ImGui_TableNextRow(ctx, r.ImGui_TableRowFlags_Headers(), cellSize)
        if r.ImGui_TableNextColumn(ctx) then
          trackListX, trackListY = select(1,r.ImGui_GetCursorScreenPos(ctx)),select(2,r.ImGui_GetCursorScreenPos(ctx))+cellSize+1
          trackListHeight = r.ImGui_GetCursorPosY(ctx) + select(2,r.ImGui_GetContentRegionAvail(ctx)) - cellSize - headerRowHeight - 2
          r.ImGui_AlignTextToFramePadding(ctx)
          r.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx)+ defPadding*2)
          r.ImGui_Text(ctx, 'Mirror stem')
        end
  -- COLS: STEM SYNC BUTTONS
        for k, stem in pairsByOrder(db.stems) do
          r.ImGui_PushID(ctx, 'sync' .. k)
          if r.ImGui_TableNextColumn(ctx) then
            local syncMode = (modKeys=='a') and ((settings.project.syncmode == SYNCMODE_MIRROR) and SYNCMODE_SOLO or SYNCMODE_MIRROR) or settings.project.syncmode
            if app.drawBtn('stemSync',{stemSyncMode = stem.sync, generalSyncMode = syncMode}) then
              db:toggleStemSync(stem, ((stem.sync == SYNCMODE_OFF) or (stem.sync == nil)) and syncMode or SYNCMODE_OFF)
            end
          end
          r.ImGui_PopID(ctx)
        end
-- TRACK LIST
        local draw_list_w = r.ImGui_GetBackgroundDrawList(ctx)
        local last_open_track = nil
        local arrow_drawn     = {}
        for i = 1, r.GetNumTracks() do
          local track       = db.tracks[i]
          local depth_delta = math.max(track.folderDepth, -depth) -- prevent depth + delta being < 0
          local is_folder   = depth_delta > 0
          if parent_open or depth <= open_depth then
            last_open_track = track
            arrow_drawn     = {}
  --- ROW
            for level = depth, open_depth - 1 do
              r.ImGui_TreePop(ctx);
              open_depth = depth
            end -- close previously open deeper folders
            r.ImGui_TableNextRow(ctx, nil, cellSize)
            -- these lines two solve an issue where upon scrolling the top row gets above the header row (happens from rows 2 onward)
            r.ImGui_DrawList_PushClipRect(gui.draw_list,trackListX,trackListY+(cellSize+1)*(i-1),trackListX+trackListWidth,trackListY+(cellSize+1)*(i-1)+cellSize,false) 
  -- COL: TRACK COLOR + NAME
            r.ImGui_TableNextColumn(ctx)
            r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx)+1)
            r.ImGui_ColorButton(ctx, 'color', r.ImGui_ColorConvertNative(track.color),
                                              r.ImGui_ColorEditFlags_NoAlpha() |
                                              r.ImGui_ColorEditFlags_NoBorder() |
                                              r.ImGui_ColorEditFlags_NoTooltip(), cellSize, cellSize)
            r.ImGui_SameLine(ctx)
            local node_flags = is_folder and gui.treeflags.base or gui.treeflags.leaf
            r.ImGui_PushID(ctx, i) -- Tracks might have the same name
            parent_open      = r.ImGui_TreeNode(ctx, track.name .. '  ', node_flags)
            r.ImGui_PopID(ctx)
            for k, stem in pairsByOrder(db.stems) do
              if r.ImGui_TableNextColumn(ctx) then
  -- COL: STEM STATE
                app.drawBtn('stemState',{track = track, stemName = k, state = track.stemMatrix[k] or ' '})
              end
            end
            
            r.ImGui_DrawList_PopClipRect(gui.draw_list)
          elseif depth > open_depth then
  --- HIDDEN SOLO STATES
            local idx = 0
            for k, stem in pairsByOrder(db.stems) do
              idx = idx + 1
  
              --local state = track.stemMatrix[k] or ' '
              if not arrow_drawn[k] then
                local offsetX, offsetY = cellSize / 2, -1
                if not (track.stemMatrix[k] == ' ') and not (track.stemMatrix[k] == nil) then
                  if r.ImGui_TableSetColumnIndex(ctx, idx) then
                    r.ImGui_SameLine(ctx)
                    r.ImGui_Dummy(ctx, 0, 0)
                    local sz    = 5--((last_open_track.stemMatrix[k] == nil) or (last_open_track.stemMatrix[k] == ' ' )) and (cellSize-4) or 6
                    local posX  = select(1, r.ImGui_GetCursorScreenPos(ctx))--+offsetX
                    local posY  = select(2, r.ImGui_GetCursorScreenPos(ctx)) - sz--+offsetY
                    local color = gui.st.col.hasChildren[(last_open_track.stemMatrix[k] or ' ')][r.ImGui_Col_Text()]
                    r.ImGui_DrawList_AddRectFilled(gui.draw_list, posX, posY, posX + cellSize, posY + sz, color)
                    if r.ImGui_IsMouseHoveringRect(ctx, posX, posY, posX + cellSize, posY + sz) then
                      app.setHint('main','This folder track has hidden children tracks that are soloed/muted.')
                    end
                    arrow_drawn[k] = true
                  end
                end
              end
            end
          end
          depth = depth + depth_delta
          if is_folder and parent_open then
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
  
  local function getReaperActionCommandId(actionNumber)
    local actionId = r.ReverseNamedCommandLookup(actionNumber)
    if actionId == nil then
      return actionNumber
      else
      return '_'..actionId
    end
  end
  
  local function getReaperActionNameOrCommandId(actionNumber)
    if r.APIExists('CF_GetCommandText') then -- if SWS, return name
      return true, r.CF_GetCommandText(0,actionNumber)
    else                                        --otherwise Fallback to Action ID
      return false, getReaperActionCommandId(actionNumber)
    end
  end
  
  function app.drawSettings()
    local ctx = gui.ctx
    local bottom_lines = 2
    local rv
    local x, y = r.ImGui_GetMousePos(ctx)
    local center = {gui.mainWindow.pos[1] + gui.mainWindow.size[1] / 2,
                    gui.mainWindow.pos[2] + gui.mainWindow.size[2] / 2, }  --{r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
    local currentSettings
    local halfWidth = 230
    local itemWidth = halfWidth*2
    local renderaction_list = ''
    local stFrameCount = 0 -- local frameCount for only querying the state of the region manager window every x frames
    for i=0, #RENDERACTION_DESCRIPTIONS do
      renderaction_list = renderaction_list..RENDERACTION_DESCRIPTIONS[i]..'\0'
    end
    
    local reflect_on_add_list = ''
    for i=0, #REFLECT_ON_ADD_DESCRIPTIONS do
      reflect_on_add_list = reflect_on_add_list..REFLECT_ON_ADD_DESCRIPTIONS[i]..'\0'
    end
    
    local syncmode_list = ''
    for i=0, #SYNCMODE_DESCRIPTIONS do
      syncmode_list = syncmode_list..SYNCMODE_DESCRIPTIONS[i]..'\0'
    end
    r.ImGui_SetNextWindowSize(ctx, halfWidth*3+r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_ItemSpacing())*1.5+r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_WindowPadding()),0)
    r.ImGui_SetNextWindowPos(ctx, center[1], gui.mainWindow.pos[2]+100, r.ImGui_Cond_Appearing(), 0.5)
    if r.ImGui_BeginPopupModal(ctx, 'Settings', true, r.ImGui_WindowFlags_AlwaysAutoResize()) then
      r.ImGui_PushFont(ctx, gui.st.fonts.default)
      if r.ImGui_IsWindowAppearing(ctx) then
        loadSettings()
        db:getRenderPresets()
        gui.stWnd.activeRSG = 1 
        gui.stWnd.tmpStngs = deepcopy(settings.project)
        if r.APIExists('JS_Localize') then
          local manager = GetRegionManagerWindow()
          if manager then r.Main_OnCommand(40326, 0) end
          app.rm_window_open = false
        end
      end
      
      local buttonsX = itemWidth+r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_FramePadding())*2
      r.ImGui_Text(ctx, 'Global Settings')
      r.ImGui_Separator(ctx)
      
      r.ImGui_BeginGroup(ctx)
      r.ImGui_AlignTextToFramePadding(ctx)
      r.ImGui_Text(ctx,'New stems will be added')
      r.ImGui_SameLine(ctx)
      rv, gui.stWnd.tmpStngs.reflect_on_add = r.ImGui_Combo(ctx,'##reflect_on_add',gui.stWnd.tmpStngs.reflect_on_add,reflect_on_add_list)
      r.ImGui_EndGroup(ctx)
      app.setHoveredHint('settings',"What solo states will newly added stems have?")
      
      r.ImGui_BeginGroup(ctx)
      r.ImGui_AlignTextToFramePadding(ctx)
      r.ImGui_Text(ctx,'Render action')
      r.ImGui_SameLine(ctx)
      rv, gui.stWnd.tmpStngs.renderaction = r.ImGui_Combo(ctx,'##renderaction',gui.stWnd.tmpStngs.renderaction,renderaction_list)
      r.ImGui_EndGroup(ctx)
      app.setHoveredHint('settings',("What should the default rendering mode be."):format(scr.name))
      
      if gui.stWnd.tmpStngs.renderaction == RENDERACTION_RENDER then
        r.ImGui_BeginGroup(ctx)
        r.ImGui_AlignTextToFramePadding(ctx)
        r.ImGui_Text(ctx,'Wait time between renders')
        r.ImGui_SameLine(ctx)
        rv, gui.stWnd.tmpStngs.wait_time = r.ImGui_DragInt(ctx, '##waitTime',gui.stWnd.tmpStngs.wait_time,0.1, WAITTIME_MIN,WAITTIME_MAX) 
        r.ImGui_EndGroup(ctx)
        app.setHoveredHint('settings',"Time to wait between renders to allow canceling and to let FX tails die down.")
      end
            
      r.ImGui_BeginGroup(ctx)
      r.ImGui_AlignTextToFramePadding(ctx)
      r.ImGui_Text(ctx,'Soloing or muting in REAPER while in mirror mode')
      r.ImGui_SameLine(ctx)
      rv, gui.stWnd.tmpStngs.syncmode = r.ImGui_Combo(ctx,'##syncmode',gui.stWnd.tmpStngs.syncmode,syncmode_list)
      r.ImGui_EndGroup(ctx)
      app.setHoveredHint('settings',("Mirror mode. %s-click the mirror button to trigger other behavior."):format(gui.descModAlt:gsub("^%l", string.upper)))
      
      r.ImGui_Spacing(ctx)
      r.ImGui_Text(ctx, 'Render Groups')
      app.setHoveredHint('settings',("Each stem is associated to one of %d render groups with its own set of settings."):format(RENDER_SETTING_GROUPS_SLOTS))
      r.ImGui_Separator(ctx)
      r.ImGui_PushItemWidth(ctx, itemWidth)
      local availwidth = r.ImGui_GetContentRegionAvail(ctx)
      if r.ImGui_BeginTabBar(ctx,'Render Group Settings') then
        for stGrp=1,RENDER_SETTING_GROUPS_SLOTS do
          if gui.stWnd.activeRSG == stGrp then 
            r.ImGui_SetNextItemWidth(ctx,halfWidth*3/RENDER_SETTING_GROUPS_SLOTS) 
          end
          if r.ImGui_BeginTabItem(ctx,stGrp..'##settingGroup'..stGrp) then
            gui.stWnd.activeRSG = stGrp
            app.setHoveredHint('settings',("Settings for render group %d."):format(stGrp))
            local rsg = gui.stWnd.tmpStngs.render_setting_groups[stGrp]
            
          --description
            rv, rsg.description = r.ImGui_InputText(ctx,"Description",rsg.description)
            app.setHoveredHint('settings',"Used as a reference for yourself. E.g., stems, submixes, mix etc...")
            
          --render presets
            r.ImGui_BeginGroup(ctx)
            if rsg.render_preset == '' then rsg.render_preset = nil end        
            if r.ImGui_Button(ctx, (rsg.render_preset or 'Select...')..'##stemsRenderPresetBtn',itemWidth) then
              if gui.modKeys=='a' then
                rsg.render_preset = nil
              else
                db:getRenderPresets()
                r.ImGui_OpenPopup(ctx, 'Stem Render Presets##stemRenderPresets')
              end
            end
            r.ImGui_AlignTextToFramePadding(ctx)
            r.ImGui_SameLine(ctx)
            r.ImGui_SetCursorPosX(ctx,r.ImGui_GetCursorPosX(ctx)-r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_FramePadding()))
            r.ImGui_Text(ctx, 'Render Preset')
            local rv, presetName = app.drawPopup(ctx, 'renderPresetSelector', 'Stem Render Presets##stemRenderPresets')
            if rv then rsg.render_preset = presetName end
            local _, checks = checkRenderGroupSettings(rsg)
            local preset = db.renderPresets[rsg.render_preset]
            local col_ok    = gui.st.col.ok
            local col_error =  gui.st.col.error
            local col_warning =  gui.st.col.warning 
            r.ImGui_EndGroup(ctx)
            app.setHoveredHint('settings',("A render preset to use for this render group. %s+click to clear."):format(gui.descModAlt:gsub("^%l", string.upper)))
            
            if preset and preset.boundsflag == RB_TIME_SELECTION then
              rv, rsg.make_timeSel = r.ImGui_Checkbox(ctx,'Make time selection before rendering',rsg.make_timeSel)
              app.setHoveredHint('settings',"You may specify a range for a time selection to make before rendering.")
              if rsg.make_timeSel then
                
                local halfWidth = halfWidth - r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_ItemInnerSpacing())
                if r.ImGui_Button(ctx,'Capture time selection', itemWidth) then
                  rsg.timeSelStart, rsg.timeSelEnd = r.GetSet_LoopTimeRange(0,0,0,0,0)--, boolean isLoop, number start, number end, boolean allowautoseek)
                end
                app.setHoveredHint('settings',"Make a time selection and click to capture its start and end positions.")
                r.ImGui_SameLine(ctx)
                r.ImGui_SetCursorPosX(ctx, r.ImGui_GetCursorPosX(ctx)-r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_ItemInnerSpacing()))
                                
                if r.ImGui_BeginChildFrame(ctx,'##timeselstart',halfWidth/2,r.ImGui_GetFrameHeight(ctx)) then
                  r.ImGui_Text(ctx, r.format_timestr_pos(rsg.timeSelStart,'',5)) --
                  r.ImGui_EndChildFrame(ctx)
                end
                app.setHoveredHint('settings',"Time seleciton start.")
                r.ImGui_SameLine(ctx)
                r.ImGui_SetCursorPosX(ctx, r.ImGui_GetCursorPosX(ctx)-r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_ItemInnerSpacing()))
                if r.ImGui_BeginChildFrame(ctx,'##timeselend',r.ImGui_GetContentRegionAvail(ctx),r.ImGui_GetFrameHeight(ctx)) then
                  r.ImGui_Text(ctx,  r.format_timestr_pos(rsg.timeSelEnd,'',5))
                  r.ImGui_EndChildFrame(ctx)
                end
                app.setHoveredHint('settings',"Time seleciton end.")
              end
            elseif preset and preset.boundsflag == RB_SELECTED_REGIONS then
              rv, rsg.select_regions = r.ImGui_Checkbox(ctx,'Select regions before rendering',rsg.select_regions)
              app.setHoveredHint('settings',"You may specify regions to select before rendering.")
              if rsg.select_regions then
                if not r.APIExists('JS_Localize') then
                  r.ImGui_TextColored(ctx,gui.st.col.error,'js_ReaScriptAPI extension is required for selecting regions.')
                else
                  -- GetRegionManagerWindow is not very performant, so only do it once every 6 frames 
                  app.stFrameCount=(app.stFrameCount or 0)+1
                  if app.stFrameCount / 30 == 1 then
                    app.stFrameCount = 0
                    app.rm_window_open = GetRegionManagerWindow() ~= nil
                  end
                  if not app.rm_window_open then
                    local title = ('%s selected'):format((#rsg.selected_regions > 0) and ((#rsg.selected_regions > 1) and #rsg.selected_regions..' regions' or '1 region') or "No region")
                    if r.ImGui_Button(ctx,title, itemWidth) then
                      if  #rsg.selected_regions > 0 and gui.modKeys=="a" then
                        rsg.selected_regions = {}
                      else
                        r.Main_OnCommand(40326, 0)
                      end
                    end
                    if r.ImGui_IsItemHovered(ctx) and #rsg.selected_regions > 0 then
                      app.setHoveredHint('settings',("Click to update selection. %s+click to clear."):format(gui.descModAlt:gsub("^%l", string.upper)))
                      local region_names = ''
                      for i, region in ipairs(rsg.selected_regions) do
                        region_names = region_names..region.id:gsub('R','')..': '..region.name..'\n'
                      end
                      r.ImGui_BeginTooltip(ctx)
                        r.ImGui_Text(ctx,'Selected regions:')
                        r.ImGui_Separator(ctx)
                        r.ImGui_Text(ctx,region_names)
                      r.ImGui_EndTooltip(ctx)
                    else
                      app.setHoveredHint('settings',"Click to select regions.")
                    end
                  else
                    if r.ImGui_Button(ctx,'Capture selected regions', itemWidth) then
                      rsg.selected_regions = GetSelectedRegions()
                    end
                    app.setHint('settings',"Select regions in the region/marker manager and click button to capture the selection.")
                    
                  end
                end
              end
            elseif preset and preset.boundsflag == RB_SELECTED_MARKERS then
              rv, rsg.select_markers = r.ImGui_Checkbox(ctx,'Select markers before rendering',rsg.select_markers)
              app.setHoveredHint('settings',"You may specify markers to select before rendering.")
              if rsg.select_markers then
                if not r.APIExists('JS_Localize') then
                  r.ImGui_TextColored(ctx,gui.st.col.error,'js_ReaScriptAPI extension is required for selecting markers.')
                else
                  -- GetRegionManagerWindow is not very performant, so only do it once every 6 frames 
                  app.stFrameCount=(app.stFrameCount or 0)+1
                  if app.stFrameCount / 10 == 1 then
                    app.stFrameCount = 0
                    app.rm_window_open = GetRegionManagerWindow() ~= nil
                  end
                  if not app.rm_window_open then
                    local title = ('%s selected'):format((#rsg.selected_markers > 0) and ((#rsg.selected_markers > 1) and #rsg.selected_markers..' markers' or '1 marker') or "No marker")
                    if r.ImGui_Button(ctx,title, itemWidth) then
                      if  #rsg.selected_markers > 0 and gui.modKeys=="a" then
                        rsg.selected_markers = {}
                      else
                        r.Main_OnCommand(40326, 0)
                      end
                    end
                    if r.ImGui_IsItemHovered(ctx) and #rsg.selected_markers > 0 then
                      app.setHoveredHint('settings',("Click to update selection. %s+click to clear."):format(gui.descModAlt:gsub("^%l", string.upper)))
                      local marker_names = ''
                      for i, marker in ipairs(rsg.selected_markers) do
                        marker_names = marker_names..marker.id:gsub('M','')..': '..marker.name..'\n'
                      end
                      r.ImGui_BeginTooltip(ctx)
                        r.ImGui_Text(ctx,'Selected markers:')
                        r.ImGui_Separator(ctx)
                        r.ImGui_Text(ctx,marker_names)
                      r.ImGui_EndTooltip(ctx)
                      else
                      app.setHoveredHint('settings',"Click to select markers.")
                    end
                  else
                    if r.ImGui_Button(ctx,'Capture selected markers', itemWidth) then
                      rsg.selected_markers = GetSelectedMarkers()
                    end
                    app.setHint('settings',"Select markers in the region/marker manager and click button to save.")
                  end
                end
              end
            end
            
            
            r.ImGui_BeginGroup(ctx)
            rv, rsg.override_filename = r.ImGui_Checkbox(ctx,'Override filename',rsg.override_filename)
            if rsg.override_filename then
              rv, rsg.filename = r.ImGui_InputTextWithHint(ctx,"##Filename override",preset and preset.filepattern or '',rsg.filename)
            end       
            r.ImGui_EndGroup(ctx)
            app.setHoveredHint('settings',"Use a filename other than the preset. Use $stem for stem name. Wildcards are ok.")
                          
            r.ImGui_BeginGroup(ctx)
            rv, rsg.put_in_folder = r.ImGui_Checkbox(ctx,'Save stems in subfolder',rsg.put_in_folder)
            app.setHoveredHint('settings',"Subfolder will be inside the folder specified in the render preset.")
            if rsg.put_in_folder then             
              rv, rsg.folder = r.ImGui_InputText(ctx,'##Subfolder',rsg.folder)
            end
            r.ImGui_EndGroup(ctx)
            app.setHoveredHint('settings',"Subfolder will be inside the folder specified in the render preset.")
            
            rv, rsg.skip_empty_stems = r.ImGui_Checkbox(ctx,'Render stems without solo/mute states',not rsg.skip_empty_stems)    
            rsg.skip_empty_stems = not rsg.skip_empty_stems
            app.setHoveredHint('settings',"Stems without solos/mutes will render with the project's track states (the mix).")
            
            rv, rsg.run_actions = r.ImGui_Checkbox(ctx,'Run action(s) before rendering', rsg.run_actions)
            app.setHoveredHint('settings',"You may specify one or more actions to run before rendering.")
            if rsg.run_actions then
              rsg.actions_to_run = rsg.actions_to_run or {}
              if r.ImGui_BeginListBox(ctx,'##actions',0,r.ImGui_GetTextLineHeightWithSpacing(ctx)*4) then
                for i,action in ipairs(rsg.actions_to_run) do
                  local rv, name = getReaperActionNameOrCommandId(action)
                  if r.ImGui_Selectable(ctx,name..'##'..i, gui.stWnd.curAction==i) then 
                    if gui.stWnd.curAction == i then gui.stWnd.curAction = nil else gui.stWnd.curAction = i end
                  end
                  if not rv then 
                    app.setHoveredHint('settings','SWS not installed: showing Command ID instead of action names.')
                  end
                end
                r.ImGui_EndListBox(ctx)
              end
              r.ImGui_SameLine(ctx)
              r.ImGui_BeginGroup(ctx)
                if r.ImGui_Button(ctx,'+##addAction', gui.TEXT_BASE_WIDTH*2) then
                  r.PromptForAction(1, 0,0)
                end
                app.setHoveredHint('settings',"Add an action by highlighting it in REAPER's action window and clicking 'Select'.")
                selAction = r.PromptForAction(0, 0,0)
                if selAction ~= 0 then
                  if selAction ~= -1 then table.insert(rsg.actions_to_run, selAction)
                  else r.PromptForAction(-1, 0,0) end
                end
                if r.ImGui_Button(ctx,'-##removeAction', gui.TEXT_BASE_WIDTH*2) then
                  if gui.stWnd.curAction then
                    table.remove(rsg.actions_to_run,gui.stWnd.curAction)
                  end
                end
                app.setHoveredHint('settings',"Remove selected action.")
              r.ImGui_EndGroup(ctx)
            end
            r.ImGui_Spacing(ctx)

--ignore_warnings
            local warnings = false
            for i,check in ipairs(checks) do
              if not check.passed and check.severity == 'warning' then warnings = true end
            end
            r.ImGui_AlignTextToFramePadding(ctx)
            r.ImGui_Text(ctx,'Checklist:')
            if warnings then
              r.ImGui_SameLine(ctx)
              rv, rsg.ignore_warnings = r.ImGui_Checkbox(ctx,"Don't show non critical (orange) errors before rendering", rsg.ignore_warnings)    
              app.setHoveredHint('settings',"This means you're aware of the warnings and are OK with them :)")
            end
            
            r.ImGui_Separator(ctx)
            r.ImGui_Indent(ctx)
            r.ImGui_PushStyleVar(ctx,r.ImGui_StyleVar_DisabledAlpha(),1)
            r.ImGui_BeginDisabled(ctx)
            
            for i,check in ipairs(checks) do
              if check.passed then r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), col_ok)
              elseif check.severity == 'critical' then 
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), col_error) 
              elseif check.severity == 'warning' then 
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), col_warning)
              end
              --r.ImGui_SetCursorPosX(ctx, r.ImGui_GetCursorPosX(ctx)+itemWidth+r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_ItemInnerSpacing()))
              r.ImGui_Checkbox(ctx, check.status, check.passed)
              r.ImGui_PopStyleColor(ctx)
              app.setHoveredHint('settings',check.hint)
            end
            r.ImGui_EndDisabled(ctx)
            r.ImGui_PopStyleVar(ctx)
            r.ImGui_Unindent(ctx)
            
            r.ImGui_EndTabItem(ctx)
          end
          if stGrp ~= gui.stWnd.activeRSG then
            app.setHoveredHint('settings',("Settings for render group %d."):format(stGrp))
          end
        end
        r.ImGui_EndTabBar(ctx)
      end
      r.ImGui_Separator(ctx)
      r.ImGui_PopItemWidth(ctx)
    
      --bottom
      
      --r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeightWithSpacing(ctx) * bottom_lines))
      local status, col = app.getStatus('settings')
      if col then r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), gui.st.col[col]) end
      r.ImGui_Spacing(ctx)
      r.ImGui_Text(ctx, status)
      app.setHint('settings','')
      r.ImGui_Spacing(ctx)
      if col then r.ImGui_PopStyleColor(ctx) end
      if r.ImGui_Button(ctx, "Save") then 
        settings.project = deepcopy(gui.stWnd.tmpStngs)
        saveSettings()
        r.ImGui_CloseCurrentPopup(ctx)
      end
      app.setHoveredHint('settings', ('Save settings for the current project.'):format(gui.descModAlt:gsub("^%l", string.upper)))
      
      r.ImGui_SameLine(ctx)
      
      if r.ImGui_Button(ctx, "Cancel") or r.ImGui_IsKeyPressed(ctx,r.ImGui_Key_Escape()) then 
        r.ImGui_CloseCurrentPopup(ctx)
      end
      app.setHoveredHint('settings', ('Close without saving.'):format(gui.descModAlt:gsub("^%l", string.upper)))
            
      r.ImGui_SameLine(ctx)
      r.ImGui_SetCursorPosX(ctx,
      r.ImGui_GetCursorPosX(ctx)+
      r.ImGui_GetContentRegionAvail(ctx)-
      r.ImGui_CalcTextSize(ctx,"Load default settings")-
      r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_ItemSpacing())-
      r.ImGui_CalcTextSize(ctx,"Save as default settings")-
      r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_FramePadding())*4)
      
      if r.ImGui_Button(ctx, "Load default settings") then
        gui.stWnd.tmpStngs = deepcopy(getDefaultSettings(gui.modKeys=='a').default)
      end
      app.setHoveredHint('settings', ('Revert to saved default settings. %s+click to load factory settings.'):format(gui.descModAlt:gsub("^%l", string.upper)))

      r.ImGui_SameLine(ctx)
      if r.ImGui_Button(ctx, "Save as default settings") then 
        settings.project = deepcopy(gui.stWnd.tmpStngs)
        settings.default = deepcopy(gui.stWnd.tmpStngs)
        saveSettings()
        r.ImGui_CloseCurrentPopup(ctx)
      end
      app.setHoveredHint('settings', ('Default settings for new projects where %s is used.'):format(scr.name))
      r.ImGui_PopFont(ctx)
      r.ImGui_EndPopup(ctx)
    end
  end
  
  function escape_pattern(text)
      return text:gsub("([^%w])", "%%%1")
  end
  
  function updateActionStatuses(actionList)
    local content = getContent(r.GetResourcePath().."/".."reaper-kb.ini")
    local statuses = {}
    for k, v in pairs(actionList) do
      for i in ipairs(v.actions) do
        local action_name = 'Custom: '.. scr.no_ext..' - '..actionList[k].actions[i].title..'.lua'
        actionList[k].actions[i].exists = (content:find(escape_pattern(action_name)) ~= nil)
      end
    end
  end
  
  function app.drawCreateActionWindow()
      local ctx = gui.ctx
      local bottom_lines = 1
      local x, y = r.ImGui_GetMousePos(ctx)
      local _, paddingY = r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_WindowPadding())
              
      local center = {gui.mainWindow.pos[1] + gui.mainWindow.size[1] / 2,
                      gui.mainWindow.pos[2] + gui.mainWindow.size[2] / 2, }  --{r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
      local halfWidth = 200
      r.ImGui_SetNextWindowSize(ctx, halfWidth*3,700,r.ImGui_Cond_Appearing())
      r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
      local visible, open = r.ImGui_Begin(ctx, 'Create Actions', true)
      if visible then
        if r.ImGui_IsWindowAppearing(ctx) then
          gui.caWnd.actionList = {}
          gui.caWnd.actionList['General Actions']       = {order = 1, actions={}}
          gui.caWnd.actionList['Render Group Actions']  = {order = 2, actions={}}
          gui.caWnd.actionList['Stem Actions']          = {order = 3, actions={}} 
          gui.caWnd.actionList['General Actions'].actions = {{title = 'Add all stems to render queue', command = 'add_all'}}
          for k, v in pairsByOrder(db.stems) do
            table.insert(gui.caWnd.actionList['Stem Actions'].actions,{title = ("Toggle '%s' mirroring"):format(k), command = ("sync %s"):format(k)})
          end
          for k, v in pairsByOrder(db.stems) do
            table.insert(gui.caWnd.actionList['Stem Actions'].actions,{title = ("Add '%s' to render queue"):format(k), command = ("add %s"):format(k)})
          end
          for k, v in pairsByOrder(db.stems) do
            table.insert(gui.caWnd.actionList['Stem Actions'].actions,{title = ("Render '%s' now"):format(k), command = ("render %s"):format(k)})
          end
          for i=1, RENDER_SETTING_GROUPS_SLOTS do
            table.insert(gui.caWnd.actionList['Render Group Actions'].actions,{title = ("Add render group %d to render queue"):format(i), command = ("add_rg %d"):format(i)})
          end
          for i=1, RENDER_SETTING_GROUPS_SLOTS do
            table.insert(gui.caWnd.actionList['Render Group Actions'].actions,{title = ("Render group %d now"):format(i), command = ("render_rg %d"):format(i)})
          end
          updateActionStatuses(gui.caWnd.actionList)
        end
        
        r.ImGui_TextWrapped(ctx,"Custom actions allow triggering the stem manager directly from within REAPER's action list.")
        r.ImGui_TextWrapped(ctx,"After clicking 'Create', a new custom action for triggering the relevant action will be added to the action list.")

        local childHeight = select(2, r.ImGui_GetContentRegionAvail(ctx)) - r.ImGui_GetFrameHeightWithSpacing(ctx)-paddingY
        if r.ImGui_BeginChild(ctx, '##ActionList',0,childHeight) then
          for k, actionList in pairsByOrder(gui.caWnd.actionList) do
            r.ImGui_Separator(ctx)
            r.ImGui_Spacing(ctx)
            if r.ImGui_TreeNode(ctx, k, r.ImGui_TreeNodeFlags_DefaultOpen()) then
              for i,action in ipairs(actionList.actions) do
                r.ImGui_PushID(ctx,i)
                r.ImGui_AlignTextToFramePadding(ctx)
                r.ImGui_Text(ctx,action.title)
                r.ImGui_SameLine(ctx)
                r.ImGui_SetCursorPosX(ctx, halfWidth*2)
                local disabled = false
                if action.exists then r.ImGui_BeginDisabled(ctx); disabled = true end
                if r.ImGui_Button(ctx, action.exists and 'Action exists' or 'Create', r.ImGui_GetContentRegionAvail(ctx),0) then
                  createAction(action.title, action.command)
                  updateActionStatuses(gui.caWnd.actionList)
                end
                if disabled then r.ImGui_EndDisabled(ctx) end
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
        r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeight(ctx))-paddingY)
        if r.ImGui_Button(ctx, "Close") or r.ImGui_IsKeyPressed(ctx,r.ImGui_Key_Escape()) then 
          app.show_action_window = false
        end
        
        r.ImGui_End(ctx)
      end
      if not open then app.show_action_window = false end
    end
    
    
  function app.drawHelp()
    local ctx = gui.ctx
    local bottom_lines = 2
    local x, y = r.ImGui_GetMousePos(ctx)
    local center = {gui.mainWindow.pos[1] + gui.mainWindow.size[1] / 2,
                    gui.mainWindow.pos[2] + gui.mainWindow.size[2] / 2, }  --{r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
    r.ImGui_SetNextWindowSize(ctx, 800,700,r.ImGui_Cond_Appearing())
    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    local visible, open = r.ImGui_Begin(ctx, 'Help', true) 
    if visible then
      local help=([[
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

The global section lets you select

#New stem contents#
Whether new stems take on the project's current solo/mute states, or start off without solo/mute states.

#Render behavior#
$script can either render stems immediately when clicking 'Render' or add stems to the render queue.
When running the render queue, reaper opens a snapshot of the project before each render, which causes the project to reload for each stem.
Rendering directly means the project does not have to be reloaded for each stem.

#Wait time between renders#
In case rendering immediately is selected, you can define an amount of time to wait between renders. This serves two purposes - 
- It allows canceling the render operation between renders.
- Some plugins, especially reverb tails, tend to "loop around" to the beginning of renders if they are not given the opportunity to die down. This helps mitigate the issue.

#Stem mirroring mode#
The default stem mirroring mode (see the Mirroring section for more information).


The render group section lets you define $num_of_setting_groups different sets of rules for rendering stems. 

The settings for each render group are:
#Description#
A short description for your own use. This is handy for remembering what each render group is used for (E.g., stems, submixes, mix etc...). When hovering the render setting group number in the main window, a small tool-tip will show the description for that group.

#Render Preset#
A render preset to be loaded before adding the stem to the render queue. Notice that the render preset's source should usually be set to "Master Mix", as that is usually the way in which soloed and muted tracks form... well... a master mix.

#Make time selection before rendering#
If the selected render preset's "bounds" setting is set to "Time selection", you can define a time selection to be made before adding the stem to the render queue. To do this, check the box, make a time selection in REAPER's timeline and click "Capture time selection".

#Select regions before rendering#
If the selected render preset's "bounds" setting is set to "Selected regions", you can define a set of regions to be selected before adding the stem to the render queue. To do this, check the box, click "No region selected", select one or more regions in the now opened Region/Marker Manager window, and click "Capture selected regions" back in $script's settings window. You can $mod_alt+click the button to clear the selection.

#Select markers before rendering#
If the selected render preset's "bounds" setting is set to "Selected markers", you can define a set of markers to be selected before adding the stem to the render queue. To do this, check the box, click "No marker selected", select one or more markers in the now opened Region/Marker Manager window, and click "Capture selected markers" back in $script's settings window. You can $mod_alt+click the button to clear the selection.

#Override filename#
Normally, files will be rendered according to their filename in the render preset. You may (and probably should) use the $stem wildcard to be replaced by the stem's name. You may also override the filename and $script will use that instead of the filename in the render preset. All of REAPER's usual wildcards can be used.

#Save stems in subfolder#
You can specify a subfolder for the stems. This will actually be added using the render window's filename field, so it is possible to use all available wildcards, as well as the $stem wildcard.

#Render stems without solo/mute states#
Stems without any defined solo or mute states will just play the mix as it is, so you will generally want to avoid adding them to the render queue, unless you intend on rendering the mix itself. If so, please make sure to check this option.

#Run action(s) before rendering#
This allows adding custom reaper actions to run before rendering. After checking the box, click the '+' button. This will open REAPER's Action's window, where you can select an action and click "select". The action will then be added to the action list in the render group's settings. Select an action and click the '-' button to remove it from the list.

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

It is dependent on cfillion's work both on the incredible ReaImgui library, and his script 'cfilion_Apply render preset'.
]]):gsub('$([%w_]+)', { 
      script = scr.name,
      default_solo_state = STATE_DESCRIPTIONS[db.prefSoloIP and STATES.SOLO_IN_PLACE or STATES.SOLO_IGNORE_ROUTING][1],
      other_solo_state = STATE_DESCRIPTIONS[db.prefSoloIP and STATES.SOLO_IGNORE_ROUTING or STATES.SOLO_IN_PLACE][1],
      mute_state = STATE_DESCRIPTIONS[STATES.MUTE][1],
      default_mute_solo_state = STATE_DESCRIPTIONS[db.prefSoloIP and STATES.MUTE_SOLO_IN_PLACE or STATES.MUTE_SOLO_IGNORE_ROUTING][1],
      other_mute_solo_state = STATE_DESCRIPTIONS[db.prefSoloIP and STATES.MUTE_SOLO_IGNORE_ROUTING or STATES.MUTE_SOLO_IN_PLACE][1],
      Mod_ctrlcmd = gui.descModCtrlCmd:gsub("^%l", string.upper),
      mod_ctrlcmd = gui.descModCtrlCmd:gsub("^%l", string.upper),
      mod_alt = gui.descModAlt,
      Mod_alt = gui.descModAlt:gsub("^%l", string.upper),
      num_of_setting_groups = RENDER_SETTING_GROUPS_SLOTS
      })
      
      local _, paddingY = r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_WindowPadding())

      local childHeight = select(2, r.ImGui_GetContentRegionAvail(ctx)) - r.ImGui_GetFrameHeightWithSpacing(ctx)*bottom_lines-paddingY
      if r.ImGui_BeginChild(ctx, '##ActionList',0,childHeight) then
      local i = 0
        for title, section in help:gmatch('|([^\r\n]+)([^|]+)') do
          if  r.ImGui_CollapsingHeader(ctx, title,false, (i==0 and r.ImGui_TreeNodeFlags_DefaultOpen() or r.ImGui_TreeNodeFlags_None()) | r.ImGui_Cond_Appearing()) then
            for text, bold in section:gmatch('([^#]*)#?([^#]+)#?\n?\r?') do
              if text then r.ImGui_TextWrapped(ctx, text) end
              if bold then 
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(),0xff8844ff) 
                r.ImGui_TextWrapped(ctx, bold)
                r.ImGui_PopStyleColor(ctx)
              end
            end
          end
          i = i+1
        end
        r.ImGui_EndChild(ctx)
      end
      r.ImGui_Separator(ctx)
      r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeight(ctx) * bottom_lines)-paddingY)
      r.ImGui_Text(ctx,'While this script is free,')
      r.ImGui_SameLine(ctx)
      gui:pushColors(gui.st.col.render_setting_groups[3])
      if r.ImGui_SmallButton(ctx,'donations') then
        if r.APIExists('CF_ShellExecute') then
          r.CF_ShellExecute(scr.donation)
        else
          local command
          if os_is.mac then     command = 'open "%s"'
          elseif os_is.win then command = 'start "URL" /B "%s"'
          elseif os_is.lin then command = 'xdg-open "%s"'
          end
          if command then 
            r.ShowConsoleMsg(command:format(scr.donation))
            os.execute(command:format(scr.donation))
          end
        end
      end
      gui:popColors(gui.st.col.render_setting_groups[1])
      r.ImGui_SameLine(ctx)
      r.ImGui_Text(ctx,'will be very much appreciated ;-)')
      if r.ImGui_Button(ctx, "Close") or r.ImGui_IsKeyPressed(ctx,r.ImGui_Key_Escape()) then 
        app.show_help = false
      end
      r.ImGui_End(ctx)
    end
    if not open then app.show_help = false end
  end
    
  function msg(msg, title, ctx)
    local ctx   = ctx or gui.ctx
    local title = title or scr.name
    r.ImGui_OpenPopup(gui.ctx, title .. "##msg")
    return app.drawPopup(gui.ctx, 'msg', title .. "##msg", {msg = msg})
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
      app.hint[window] = {window = {}}
      if color then
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), gui.st.col[color])
      end
      r.ImGui_SetTooltip(ctx, text)
      if color then
        r.ImGui_PopStyleColor(ctx)
      end
    else
      app.hint[window] = {text = text, color = color}
    end
  end
  
  function app.drawBottom(ctx, bottom_lines)
    r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeightWithSpacing(ctx) * bottom_lines + r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_ItemSpacing())*2))
    local status, col = app.getStatus('main')
    if col then r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), gui.st.col[col]) end
    r.ImGui_Spacing(ctx)
    r.ImGui_Text(ctx, status)
    app.setHint('main','')
    r.ImGui_Spacing(ctx)
    if col then r.ImGui_PopStyleColor(ctx) end
    if not app.coPerform then
      if r.ImGui_Button(ctx, RENDERACTION_DESCRIPTIONS[settings.project.renderaction]:gsub("^%l", string.upper), r.ImGui_GetContentRegionAvail(ctx)) then
        app.coPerform = coroutine.create(doPerform)
      end
    else 
      r.ImGui_ProgressBar(ctx, (app.perform.pos or 1) / (app.perform.total  or 1),r.ImGui_GetContentRegionAvail(ctx))
    end
  end
  
  function app.drawMainWindow(open)
    local ctx = gui.ctx
    r.ImGui_SetNextWindowSize(ctx, 700,
                              math.min(1000, select(2, r.ImGui_Viewport_GetSize(r.ImGui_GetMainViewport(ctx)))),
                              r.ImGui_Cond_Appearing())
    r.ImGui_SetNextWindowPos(ctx,100,100,r.ImGui_Cond_FirstUseEver())
    local visible, open = r.ImGui_Begin(ctx, scr.name..' v'..scr.version .. "##mainWindow", true, r.ImGui_WindowFlags_MenuBar())
    gui.mainWindow      = {
      pos  = {r.ImGui_GetWindowPos(ctx)},
      size = {r.ImGui_GetWindowSize(ctx)}
    }
    db:sync()
    if visible then
      local bottom_lines = 2
       
      if r.ImGui_BeginMenuBar(ctx) then
        --r.ImGui_SetCursorPosX(ctx, r.ImGui_GetContentRegionAvail(ctx)- r.ImGui_CalcTextSize(ctx,'Settings'))
        if r.ImGui_SmallButton(ctx, 'Settings') then 
          r.ImGui_OpenPopup(ctx,'Settings')
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_SmallButton(ctx, 'Create Actions') then 
          app.show_action_window = not (app.show_action_window or false)
        end
        if r.ImGui_SmallButton(ctx, 'Help') then 
          app.show_help = not (app.show_help or false)
        end
        if r.ImGui_IsPopupOpen(ctx, 'Settings') then app.drawSettings() end
        if app.show_help then app.drawHelp() end
        if app.show_action_window then app.drawCreateActionWindow() end
        r.ImGui_EndMenuBar(ctx)
      end
      if app.coPerform and coroutine.status(app.coPerform) == 'running' then r.ImGui_BeginDisabled(ctx) end
      app.drawMatrices(ctx, bottom_lines)
      if app.coPerform and coroutine.status(app.coPerform) == 'running' then r.ImGui_EndDisabled(ctx) end
      app.drawBottom(ctx, bottom_lines)
      r.ImGui_End(ctx)
    end
    -- this is a workaround to allow for the messagebox to be closed (visually) before running post actions
    if app.message_closed == 1 or app.do_post_perform_action then 
      if app.current_renderaction == RENDERACTION_RENDERQUEUE_OPEN then r.Main_OnCommand(40929, 0)
      elseif  (app.current_renderaction == RENDERACTION_RENDERQUEUE_RUN) and (app.perform.fullRender) then r.Main_OnCommand(41207, 0) 
      end
      app.current_renderaction = nil
      app.do_post_perform_action = false
      app.message_closed = nil 
    end
    if app.message_closed == 0 then app.message_closed = 1 end
    if app.summary_msg and not app.do_post_perform_action then
      local ok =  msg(app.summary_msg, 'Errors')
      if ok then app.summary_msg = nil ; app.message_closed = 0 end
    end
    return open
  end
  
  function checkPerform() 
    if app.coPerform then
      if coroutine.status(app.coPerform) == "suspended" then
        retval, app.perform.status, app.perform.pos, app.perform.total = coroutine.resume(app.coPerform, app.stemToRender)
        
        if not retval then
          r.ShowConsoleMsg(app.perform.status)
        end
      elseif coroutine.status(app.coPerform) == "dead" then
        app.stemToRender = nil
        app.renderGroupToRender = nil
        app.coPerform = nil
        if #(app.errors or {}) > 0 then
          app.summary_msg = table.concat(app.errors,"\n\n")
          app.errors = {}
        else
          app.do_post_perform_action = true
        end
      end
    end
  end
  
  function app.loop()
    r.DeleteExtState(scr.context_name, 'defer', false)
    r.ImGui_PushFont(gui.ctx, gui.st.fonts.default)
    app.open = app.drawMainWindow(open)
    r.ImGui_PopFont(gui.ctx)
    checkPerform()
    checkExternalCommand()
    if app.open then
      r.SetExtState(scr.context_name, 'defer', '1', false) 
      r.defer(app.loop)
    else
      r.ImGui_DestroyContext(gui.ctx)
    end
  end
  loadSettings()
  r.defer(app.loop)
end
