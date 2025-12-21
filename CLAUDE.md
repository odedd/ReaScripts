# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a collection of Lua scripts for REAPER (digital audio workstation). Main projects:
- **Scout** (`FX/Scout/`) - Asset search and organization tool
- **Send Buddy** (`FX/Send Buddy/`) - Send mixer with advanced UI
- **Project Archiver** (`Various/Project Archiver/`) - Project backup/archival
- **Stereo Buddy** (`Various/Stereo Buddy/`) - Stereo image manipulation

Scripts are distributed via **ReaPack** package manager. The `index.xml` file is the ReaPack manifest.

## Development

**Running scripts:** Use VS Code task "Run Reaper Script" or run directly in REAPER.

**No build/test/lint system** - Scripts are interpreted Lua, tested manually in REAPER.

**Required extensions** (vary by script):
- ReaImGui (v0.10.0 for Send Buddy, v0.8.4+ for Project Archiver)
- JS_ReaScriptAPI (v1.310+)
- SWS/S&M Extension

## Architecture

### Shared Framework (`Resources/Common/`)

All scripts share a common framework loaded via `dofile()`:

```lua
-- Standard entry pattern in main scripts:
local p = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]
dofile(p .. 'Resources/Common/Common.lua')  -- or '../../Resources/Common/Common.lua'
OD_Init()
if OD_PrereqsOK({ reaimgui_version = '0.10.0', ... }) then
    -- Script logic
end
```

**Key modules:**
- `Common.lua` - Initializes `Scr` table (script metadata from header), `OS_is`, `r` (reaper alias)
- `Helpers/App/App.lua` - `OD_App` and `OD_Gui_App` base classes for applications
- `Helpers/App/Gui.lua` - GUI utilities and ImGui wrappers
- `Helpers/App/Settings.lua` - Settings management with INI persistence
- `Helpers/Reaper/` - REAPER API wrappers (Tracks, Envelopes, Actions, etc.)

### Script Header Metadata

Scripts use ReaPack-style headers parsed by `Common.lua`:
```lua
-- @description Script Name
-- @version 1.0.0
-- @author Oded Davidov
-- @provides
--   [nomain] ../../Resources/Common/* > Resources/Common/
--   [nomain] lib/**
-- @changelog
--   Changes here
```

### Class Pattern

OOP via metatables:
```lua
ClassName = {}
function ClassName:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end
```

Inheritance: `ChildClass = ParentClass:new({ ... })`

### App Architecture

GUI apps inherit from `OD_Gui_App`:
```lua
local app = OD_Gui_App:new({ ... })
app:connect('gui', SM_Gui:new({}))    -- Connect modules
app:connect('logger', OD_Logger:new({ ... }))
```

The `connect()` method links modules while giving them access to the parent app.

### Per-Script Libraries

Each major script has a `lib/` folder with:
- `Constants.lua` - Script-specific constants
- `Settings.lua` - Settings class extending base settings
- `Gui.lua` - Custom GUI class extending base GUI
- `Db.lua` - Database/data management (if needed)

## Key Globals

- `r` - Alias for `reaper` API
- `Scr` - Script metadata (version, name, path, etc.)
- `OS_is` - Platform detection (`OS_is.win`, `OS_is.mac`, `OS_is.lin`)
- `ImGui` - ReaImGui bindings (when loaded)

## File Conventions

- Main scripts: `Odedd_<Name>.lua`
- Config files: `<script_name>.ini` (gitignored)
- Script libraries: `lib/*.lua`
- Shared resources: `Resources/Common/`, `Resources/Fonts/`, `Resources/Icons/`
