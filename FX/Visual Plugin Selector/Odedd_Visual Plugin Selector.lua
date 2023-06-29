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
local logger = OD_Logger:new({ level = OD_Logger.LOG_LEVEL.ERROR })
local db = OD_VPS_DB:new()
local settings = OD_Settings:new({
  default = {
    photosPath = p .. 'Photos/',
    vendorWaitTimes = {
      ['Universal Audio (UADx)'] = 2,
      ['Tokyo Dawn Labs'] = 1,
      ['Leapwing Audio'] = 1,
      ['Sound Radix'] = 1,
    }
  },
  dfsetfile = Scr.dfsetfile
})

app:connect('gui', gui)
app:connect('db', db)
app:connect('logger', logger)
app:connect('scr', Scr)
app:connect('settings', settings)

db.filename = p .. Scr.no_ext .. '.db'

app:init()
gui:init()
logger:init()
db:init()
settings:init()

local ctx = gui.ctx

logger.level = logger.LOG_LEVEL.DEBUG
logger.output = logger.LOG_OUTPUT.FILE
logger:setLogFile(p .. Scr.no_ext .. '_' .. os.date("%c") .. '.log')

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
  settings:load()
  db:load()
  app.onCancel = function()
    reaper.ShowConsoleMsg('I\'ve been cancelled\n')
    reaper.ShowConsoleMsg(app.perform.status .. '\n')
  end

  app.onDone = function()
    reaper.ShowConsoleMsg('I\'m done\n')
    db:save()
    logger:flush()
    logger:closeLogFile()
  end

  -- local mainHwnd = reaper.GetMainHwnd()
  -- reaper.JS_Window_SetForeground(mainHwnd)
  -- coroutine.yield()
  -- app.coPerform = coroutine.create(function() db:scanPhotos() end)
   app.coPerform = coroutine.create(function() db:scan(true) end)
   r.defer(app.loop)

  -- local plugin_name = 'AU:iZotope: Stutter Edit'
  -- r.InsertTrackAtIndex(0, false)
  -- local track = r.GetTrack(0, 0)
  -- local fx = r.TrackFX_AddByName(track, plugin_name, false, -1000)
  -- if fx == -1 then return false, track, nil, 'does not exist' end
  -- r.TrackFX_Show(track, fx, 3)
  -- -- reaper.defer()
  -- -- reaper.defer()
  -- -- reaper.defer()
  -- -- reaper.defer()
  -- -- local windowName = plugin_name:gsub('^(.-):', '%1: ')
  -- -- OD_Wait(0.5)
  -- local windowTitleString = 'AU: Stutter Edit'
  -- local hwnd = r.JS_Window_FindTop(windowTitleString, false) or
  --                   r.JS_Window_FindTop(windowTitleString:gsub('^(.-):', '%1i:'), false) or --sometimes VST versions are loaded as VSTis, so look for that instead
  --                   r.JS_Window_Find(windowTitleString, false) or                            --fallback to not finding the top window (useful as some plugins show a modal window on startup, which interrupts all following captures)
  --                   r.JS_Window_Find(windowTitleString:gsub('^(.-):', '%1i:'), false)       --or    --fallback to non-top-VSTi same as above

  -- reaper.ShowConsoleMsg(tostring(hwnd) .. '\n')
end

-- TODO: Run as a dedicated process:
-- in reaper-vstbridge32.ini
-- [vst_dll_options]
-- (for vst - use filename) FabFilter Pro-Q 3.vst3=2 -1
-- (for au - use full_name) FabFilter: Pro-Q 3=2 -1
