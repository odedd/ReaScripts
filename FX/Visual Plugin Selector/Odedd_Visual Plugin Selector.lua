-- @description Visual Plugin Loader
-- @author Oded Davidov
-- @version 0.0.1
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
--   Fixed - rendering by clicking the main button after rendering an individual stem in a different way now works as expected

pluginname = 'Pro-Q 3'
frame = 0
local r                  = reaper
local scr                = {}
local cur_os             = r.GetOS()
local os_is              = {win     = cur_os:lower():match("win") and true or false,
                            mac     = cur_os:lower():match("osx") or
                                    cur_os:lower():match("macos") and true or false,
                            mac_arm = cur_os:lower():match("macos") and true or false,
                            lin     = cur_os:lower():match("other") and true or false}

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
scr.dfsetfile = scr.dir..scr.no_ext..'.ini'
findContentKey(getContent(scr.path), "", true)
scr.namespace   = "Odedd"
scr.name        = scr.description
scr.context_name       = scr.namespace:gsub(' ', '_') .. '_' .. scr.name:gsub(' ', '_')
r.ver = tonumber(r.GetAppVersion():match("[%d%.]+"))



-------------------
-- basic helpers --
-------------------

string.split = function(s, delimiter)
  result = {};
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
    table.insert(result, match);
  end
  return result;
end
 
function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

local function prereqCheck ()
  local errors = {}
  
  local apply_render_preset_script_path = r.GetResourcePath() .. '/Scripts/ReaTeam Scripts/Rendering/cfillion_Apply render preset.lua'
  local reaimgui_script_path = r.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua'
  local reaimgui_version = '0.8'
  local min_reaper_version = 6.44

  if r.ver < min_reaper_version then
    table.insert(errors, 'This script is designed to work with REAPER v'..min_reaper_version..'+')
  end
  if file_exists(apply_render_preset_script_path) then
    applyPresetScript = loadfile(apply_render_preset_script_path)
  else
    table.insert(errors, 'This script requires "cfillion_Apply render preset.lua".\nPlease install it via ReaPack.')
  end
  if not r.APIExists('SNM_SetIntConfigVar') then
    table.insert(errors, 'This script requires the\nSWS/S&M extension.\n\nPlease install it at\nhttps://www.sws-extension.org/')
  end
  
  if file_exists(reaimgui_script_path) then 
    local verCheck = loadfile(reaimgui_script_path)
    local status, err = pcall(verCheck(),reaimgui_version)
    if not status then 
      table.insert(errors, ('ReaImgui version must be %s or above.\nPlease update via ReaPack.'):format(reaimgui_version)) 
    elseif not r.ImGui_ColorConvertU32ToDouble4 then
      table.insert(errors, "ReaImGui error.\nPlease reinstall it via ReaPack.\n\nIf you already installed it, remember to restart r.")
    end
  else
    table.insert(errors, 'This script requires ReaImgui.\nPlease install it via ReaPack.')
  end
  
  return errors
end

local prereqErrors = prereqCheck()
if #prereqErrors > 0 then
  r.MB(table.concat(prereqErrors,'\n------------\n'), scr.name,0)
end


if next(prereqErrors) == nil then
    
  local app               = {}
  
  local gui               = {}
  do
    -- these needs to be temporarily created to be refered to from some of the gui vars
    local ctx          = r.ImGui_CreateContext(scr.context_name .. '_MAIN')
    local cellSize     = 25
  
    --local font_vertical = r.ImGui_CreateFont(scr.dir..'../../Resources/Fonts/Cousine-90deg.otf', 11)
    local font_default = r.ImGui_CreateFont('sans-serif', 16)
    --local font_bold = r.ImGui_CreateFont(scr.dir..'../../Resources/Fonts/Cousine-Regular.ttf', 16,r.ImGui_FontFlags_Bold())
    
    reaper.ImGui_Attach(ctx, font_default)
  --  r.ImGui_AttachFont(ctx, font_vertical)
  --  r.ImGui_AttachFont(ctx, font_bold)
  --]]
    gui = {
      ctx           = ctx,
      mainWindow    = {},
      draw_list     = r.ImGui_GetWindowDrawList(ctx),
      keyModCtrlCmd = (os_is.mac or os_is.mac_arm) and r.ImGui_Mod_Super() or r.ImGui_Key_ModCtrl(),
      notKeyModCtrlCmd = (os_is.mac or os_is.mac_arm) and r.ImGui_Mod_Ctrl() or r.ImGui_Key_ModSuper(),
      descModCtrlCmd= (os_is.mac or os_is.mac_arm) and 'cmd' or 'control',
      descModAlt    = (os_is.mac or os_is.mac_arm) and 'opt' or 'alt',      
      st            = {
        fonts = {
          default  = font_default,
          vertical = font_vertical,
          bold     = font_bold}
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
  
    --r.ImGui_PushFont(ctx, gui.st.fonts.default)
    gui.TEXT_BASE_WIDTH, gui.TEXT_BASE_HEIGHT = r.ImGui_CalcTextSize(ctx, 'A'), r.ImGui_GetTextLineHeightWithSpacing(ctx)
    --r.ImGui_PopFont(ctx)
  
  end
  --[[
  function waitforplugin(plugin_name, track)
    reaper.ShowConsoleMsg('.')
  
    if reaper.TrackFX_AddByName(track, plugin_name, false, 0) == -1 then 
      r.defer(function() waitforplugin(plugin_name, track) end)
    end
    return
  end
  --]] 
  function loadPlugin(plugin_name)
 track = reaper.GetTrack(0, 0) -- get the currently selected track
    fx_count = reaper.TrackFX_GetCount(track) -- get the number of effects on the track
    found = false
    fx = reaper.TrackFX_AddByName(track, plugin_name, false, 1)
    reaper.TrackFX_Show(track, fx, 3)
    local retval = reaper.JS_Window_FindTop(plugin_name, false)
    return retval
  end
  
  function GetPluginWindowBounds(hwnd)
    local _, left, top, right, bottom = reaper.JS_Window_GetClientRect(hwnd)
    if os_is.mac then
      local parent = reaper.JS_Window_GetParent(hwnd)
      local _, _, scrh,  scrw,_ = reaper.JS_Window_GetRect(parent) -- macos
      top,bottom = scrh-top, scrh-bottom -- macos (On macOS, screen coordinates are relative to the *bottom* left corner of the primary display, and the positive Y-axis points upward.)
      top = top + 20 -- compensate for macos main menu bar
      top = top + 28 -- plugin reaper bar
    end
    return left, top, right-left, bottom-top
  end
  
  function capture_plugin_window(window)
    x, y, w, h = GetPluginWindowBounds(window)
    local cmd = 'screencapture -R'..x..','..y..','..w..','..h..' -x -a -tjpg /Users/odeddavidov/Desktop/test2.jpg'
    os.execute(cmd)
    img = reaper.ImGui_CreateImage('/Users/odeddavidov/Desktop/test2.jpg')
  end
  
  function app.drawMainWindow(open)
    local ctx = gui.ctx
    r.ImGui_SetNextWindowSize(ctx, 1700,
                              math.min(1000, select(2, r.ImGui_Viewport_GetSize(r.ImGui_GetMainViewport(ctx)))),
                              r.ImGui_Cond_Appearing())
    r.ImGui_SetNextWindowPos(ctx,100,100,r.ImGui_Cond_FirstUseEver())
    local visible, open = r.ImGui_Begin(ctx, scr.name..' v'..scr.version .. "##mainWindow", true, r.ImGui_WindowFlags_MenuBar())
    gui.mainWindow      = {
      pos  = {r.ImGui_GetWindowPos(ctx)},
      size = {r.ImGui_GetWindowSize(ctx)}
    }
    if visible then
      local w, h = reaper.ImGui_Image_GetSize(img)
      -- crop to middle square of image
      if w > h then
        uv0_x,uv0_y,uv1_x,uv1_y=(1-h/w)/2,0,1-((1-h/w)/2),1
      elseif h > w then
        uv0_x,uv0_y,uv1_x,uv1_y=0,(1-h/w)/2,(1-(1-h/w)/2),1
      else
        uv0_x,uv0_y,uv1_x,uv1_y=0,0,1,1
      end
      reaper.ImGui_Image(ctx, img, 300, 300,uv0_x,uv0_y,uv1_x,uv1_y)
      r.ImGui_End(ctx)
    end
    return open
  end
  
  function app.loop()
    frame = frame + 1
    
    r.ImGui_PushFont(gui.ctx, gui.st.fonts.default)
    app.open = app.drawMainWindow(open)
    r.ImGui_PopFont(gui.ctx)
    if app.open then
      --reaper.ShowConsoleMsg(frame..'\n')
      r.defer(app.loop)
    else
      r.ImGui_DestroyContext(gui.ctx)
    end
  end
  
  reaper.ClearConsole()
  local window = loadPlugin(pluginname)
  reaper.defer(function() capture_plugin_window(window) end)
  
  r.defer(app.loop)
  
end
