-- @noindex

function LoadPlugin(plugin_name)
  r.InsertTrackAtIndex(0,false)
    local track = r.GetTrack(0,0) 
    local fx = r.TrackFX_AddByName(track, plugin_name, false, 1)
    r.TrackFX_Show(track, fx, 3)
    local success = r.TrackFX_GetCount( track ) > 0
    local hwnd
    if success then
      hwnd = r.JS_Window_FindTop(plugin_name:gsub('(.-):','%1: '), false)
      if not hwnd then --sometimes VST versions are loaded as VSTis, so look for that instead
        hwnd = r.JS_Window_FindTop(plugin_name:gsub('(.-):','%1i: '), false)
      end
      if not hwnd then --fallback to not finding the top window (useful as some plugins show a modal window on startup, which interrupts all following captures)
        hwnd = r.JS_Window_Find(plugin_name:gsub('(.-):','%1: '), false)
      end
      if not hwnd then --fallback to non-top-VSTi same as above
        hwnd = r.JS_Window_Find(plugin_name:gsub('(.-):','%1i: '), false)
      end

      if not hwnd then success = false end
    end
    return success, track, hwnd
  end
  
  function getPluginWindowBounds(hwnd)
    local _, left, top, right, bottom = r.JS_Window_GetClientRect(hwnd)
    if OS_is.mac then
      local parent = r.JS_Window_GetParent(hwnd)
      local _, _, scrh, scrw, _ = r.JS_Window_GetRect(parent)   -- macos
      top, bottom = scrh - top,
          scrh -
          bottom                                                -- macos (On macOS, screen coordinates are relative to the *bottom* left corner of the primary display, and the positive Y-axis points upward.)
      top = top + 20                                            -- compensate for macos main menu bar
      top = top + 29                                            -- plugin reaper bar
      bottom = bottom + 27
    end
    return left, top, right - left, bottom - top
  end
  
  function CapturePluginWindow(window, filename)
    local x, y, w, h = getPluginWindowBounds(window)
    local cmd = 'screencapture -R' .. x .. ',' .. y .. ',' ..
    w .. ',' .. h .. ' -x -a -tjpg ' .. OD_Sanitize(filename) .. ''
    os.execute(cmd)
    -- img = r.ImGui_CreateImage(filename)
  end
  