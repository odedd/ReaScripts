-- @noindex

function GetExternalWindowCorrdinates(plugin_name)
  local cmd =
      ([[tell application "System Events"
  set listOfProcesses to every process whose name contains "reaper"
  repeat with aProcess in listOfProcesses
    set windowList to every window of aProcess
    repeat with aWindow in windowList
      set windowTitle to the name of aWindow
      if windowTitle contains "%s" then
        tell aProcess
          set frontmost to true
          perform action "AXRaise" of aWindow
        end tell
        set {x, y} to position of aWindow
        set {w, h} to size of aWindow
        return ("" & x & "," & y & "," & w & "," & h)
      end if
    end repeat
  end repeat
  end tell
  return -1]]):format(plugin_name:gsub("\"", "\\\""))

  cmd = ('/usr/bin/osascript -e \'' .. cmd:gsub('\n', '\' -e \'') .. '\'')
  local result = r.ExecProcess(cmd, 0)
  local x, y, w, h
  if result == nil or result:match('%-1\n$') then
    return false
  else
    x, y, w, h = result:match('(%d+),(%d+),(%d+),(%d+)')
    if OS_is.mac then
      y = y + 28 -- compensate for macos main menu bar
      h = h - 28 -- plugin reaper bar
    end
    return true, x, y, w, h
  end
end

local function getPluginWindowBounds(hwnd)
  local _, left, top, right, bottom = r.JS_Window_GetClientRect(hwnd)
  if OS_is.mac then
    local parent = r.JS_Window_GetParent(hwnd)
    local _, _, scrh, scrw, _ = r.JS_Window_GetRect(parent) -- macos
    top, bottom = scrh - top,
        scrh -
        bottom     -- macos (On macOS, screen coordinates are relative to the *bottom* left corner of the primary display, and the positive Y-axis points upward.)
    top = top + 20 -- compensate for macos main menu bar
    top = top + 29 -- plugin reaper bar
    bottom = bottom + 27
  end
  return left, top, right - left, bottom - top
end

function CapturePluginWindow(window, filename, coordinates)
  local x, y, w, h
  if coordinates then
    x, y, w, h = coordinates.x, coordinates.y, coordinates.w, coordinates.h
  else
    x, y, w, h = getPluginWindowBounds(window)
  end
  local cmd = 'screencapture -R' .. x .. ',' .. y .. ',' ..
      w .. ',' .. h .. ' -x -a -tjpg ' .. OD_Sanitize(filename) .. ''
  os.execute(cmd)
  -- img = r.ImGui_CreateImage(filename)
end
