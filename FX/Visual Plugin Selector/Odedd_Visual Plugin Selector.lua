-- @noindex
-- @description Visual Plugin Loader
-- @author Oded Davidov
-- @donation: https://paypal.me/odedda
-- @license GNU GPL v3

---------------------------------------
-- SETUP ------------------------------
---------------------------------------
r = reaper

local p = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]

if r.file_exists(p .. 'Resources/Common/Common.lua') then
  dofile(p .. 'Resources/Common/Common.lua')
else
  dofile(p .. '../../Resources/Common/Common.lua')
end

r.ClearConsole()

OD_Init()

dofile(p .. 'lib/Capture.lua')
dofile(p .. 'lib/Db.lua')

-- @noindex

local app = OD_Perform_App:new({
  mediaFiles = {},
  revert = {},
  restore = {},
  popup = {}
})

local gui = OD_Gui:new()
local logger = OD_Logger:new({level = OD_Logger.LOG_LEVEL.ERROR})
local db = OD_VPS_DB:new()

app:connect('gui', gui)
app:connect('db', db)
app:connect('logger', logger)
app:connect('scr', Scr)
-- app:connect('op', Op)
app:init()
gui:init()
logger:init()
db:init()

local ctx = gui.ctx

-------------------
-- basic helpers --
-------------------

function app.drawMainWindow()
  r.ImGui_SetNextWindowSize(ctx, 1700,
    math.min(1000, select(2, r.ImGui_Viewport_GetSize(r.ImGui_GetMainViewport(ctx)))),
    r.ImGui_Cond_Appearing())
  r.ImGui_SetNextWindowPos(ctx, 100, 100, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, Scr.name .. ' v' .. Scr.version .. "##mainWindow", true,
    r.ImGui_WindowFlags_MenuBar())
  gui.mainWindow      = {
    pos  = { r.ImGui_GetWindowPos(ctx) },
    size = { r.ImGui_GetWindowSize(ctx) }
  }
  if visible then
    -- local w, h = r.ImGui_Image_GetSize(img)
    -- local uv0_x, uv0_y, uv1_x, uv1_y
    -- -- crop to middle square of image
    -- if w > h then
    --   uv0_x, uv0_y, uv1_x, uv1_y = (1 - h / w) / 2, 0, 1 - ((1 - h / w) / 2), 1
    -- elseif h > w then
    --   uv0_x, uv0_y, uv1_x, uv1_y = 0, (1 - h / w) / 2, (1 - (1 - h / w) / 2), 1
    -- else
    --   uv0_x, uv0_y, uv1_x, uv1_y = 0, 0, 1, 1
    -- end
    -- r.ImGui_Image(ctx, img, 300, 300, uv0_x, uv0_y, uv1_x, uv1_y)
    r.ImGui_End(ctx)
  end
  return open
end

function app.loop()
  app:checkPerform()
  r.ImGui_PushFont(gui.ctx, gui.st.fonts.default)
  app.open = app.drawMainWindow()
  r.ImGui_PopFont(gui.ctx)
  if app.open then
    r.defer(app.loop)
  else
    r.ImGui_DestroyContext(gui.ctx)
  end
end

if OD_PrereqsOK({
      reaimgui_version = '0.8',
      sws = true,           -- required for SNM_SetIntConfigVar - setting config vars (max file size limitation and autosave options)
      js_version = 1.310,   -- required for JS_Dialog_BrowseForFolder
      reaper_version = 6.76 -- required for APPLYFX_FORMAT and OPENCOPY_CFGIDX
    }) then
  local pluginname = 'Pro-C 2'
  --  local window = LoadPlugin(pluginname)
  --  r.defer(function() CapturePluginWindow(window) end)
  app.onCancel = function()
    reaper.ShowConsoleMsg('I\'ve been cancelled\n')
    reaper.ShowConsoleMsg(app.perform.status..'\n')
  end

  app.onDone = function()
    reaper.ShowConsoleMsg('I\'m done\n')
    table.save(db.items, p .. Scr.no_ext .. '.db')
  end
  -- db.items = table.load(p .. Scr.basename .. '.db')
  -- reaper.ShowConsoleMsg(('loaded %s items\n'):format(#db.items.plugins))
  -- app.coPerform = coroutine.create(function() db:scan() end)
  -- r.defer(app.loop)
  reaper.ShowConsoleMsg(r.get_ini_file()..'\n')
  -- logger.level = OD_Logger.LOG_LEVEL.DEBUG
  -- db:addPlugin('JJP-Bass Mono/Stereo (Waves)')
end
