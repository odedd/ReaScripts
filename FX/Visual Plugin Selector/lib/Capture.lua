-- @noindex

function LoadPlugin(plugin_name)
    local track = r.GetTrack(0, 0)               -- get the currently selected track
    local fx_count = r.TrackFX_GetCount(track)   -- get the number of effects on the track
    local found = false
    local fx = r.TrackFX_AddByName(track, plugin_name, false, 1)
    r.TrackFX_Show(track, fx, 3)
    local retval = r.JS_Window_FindTop(plugin_name, false)
    return retval
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
      top = top + 28                                            -- plugin reaper bar
    end
    return left, top, right - left, bottom - top
  end
  
  function CapturePluginWindow(window, filename)
    local x, y, w, h = getPluginWindowBounds(window)
    local cmd = 'screencapture -R' .. x .. ',' .. y .. ',' ..
    w .. ',' .. h .. ' -x -a -tjpg /Users/odeddavidov/Desktop/test2.jpg'
    os.execute(cmd)
    img = r.ImGui_CreateImage('/Users/odeddavidov/Desktop/test2.jpg')
  end
  