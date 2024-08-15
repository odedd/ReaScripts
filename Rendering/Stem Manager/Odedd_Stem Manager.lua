-- @description Stem Manager
-- @author Oded Davidov
-- @version 1.8.3
-- @donation https://paypal.me/odedda
-- @link https://forum.cockos.com/showthread.php?t=268512
-- @license GNU GPL v3
-- @provides
--   [nomain] ../../Resources/Common/* > Resources/Common/
--   [nomain] ../../Resources/Common/Helpers/* > Resources/Common/Helpers/
--   [nomain] ../../Resources/Common/Helpers/App/* > Resources/Common/Helpers/App/
--   [nomain] ../../Resources/Common/Helpers/Reaper/* > Resources/Common/Helpers/Reaper/
--   [nomain] ../../Resources/Fonts/* > Resources/Fonts/
--   [nomain] ../../Resources/Icons/* > Resources/Icons/
--   [nomain] lib/**
-- @about
--   # Stem Manager
--   Advanced stem rendering automator.
--   Stem Manager was designed with the goal of simplifying the process of stem creation with reaper.
--   While REAPER's flexibility is unmatched, it is still quite cumbersome to create and render sets of tracks independently of signal flow, with emphasis on easy cross-project portability (do it once, then use it everywhere!).
--
--   This is where Stem Manager comes in.
-- @changelog
--   Fix: Regions and markers selection not working on macOS

local r = reaper
local p = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]
if r.file_exists(p .. 'Resources/Common/Common.lua') then
    dofile(p .. 'Resources/Common/Common.lua')
else
    dofile(p .. '../../Resources/Common/Common.lua')
end

r.ClearConsole()

OD_Init()

if OD_PrereqsOK({
        reaimgui_version = '0.8',
        reaper_version = 6.44,
        js_version = 1.310, -- required for JS_Dialog_BrowseForSaveFile
        scripts = {
            ["cfillion_Apply render preset.lua"] = r.GetResourcePath() .. "/Scripts/ReaTeam Scripts/Rendering/cfillion_Apply render preset.lua" }
    }) then
    dofile(p .. 'lib/Constants.lua')
    dofile(p .. 'lib/Db.lua')
    dofile(p .. 'lib/Settings.lua')
    dofile(p .. 'lib/Gui.lua')

    Scr.presetFolder = Scr.dir .. 'Presets'
    r.RecursiveCreateDirectory(Scr.presetFolder, 0)

    local frameCount = 0
    local applyPresetScript = loadfile(r.GetResourcePath() ..
        "/Scripts/ReaTeam Scripts/Rendering/cfillion_Apply render preset.lua")

    App = OD_Perform_App:new()

    App.gui = Gui
    App:init()


    local validators = {
        stem = {
            name = (function(origVal, val)
                if val == "" then
                    return "Can't be blank"
                end
                if not (origVal:upper() == val:upper()) then
                    for k, v in pairs(DB.stems) do
                        if k:upper() == val:upper() then
                            return ('Stem %s already exists'):format(val)
                        end
                    end
                end
                return true
            end)
        }
    }

    local function createAction(actionName, cmd)
        local snActionName = OD_SanitizeFilename(actionName)
        local filename = ('%s - %s'):format(Scr.no_ext, snActionName)

        local outputFn = string.format('%s/%s.lua', Scr.dir, filename)
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
            context = Scr.ext_name,
            scriptname = Scr.basename,
            cmd = cmd
        })
        code = ('-- This file was created by %s on %s\n\n'):format(Scr.name, os.date('%c')) .. code
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

    local function checkRenderGroupSettings(rsg)
        local checks = {}
        local ok = true
        local presetName = rsg.render_preset
        if presetName and not DB.renderPresets[presetName] then
            table.insert(checks, {
                passed = false,
                status = "Preset does not exist",
                severity = 'critical',
                hint = ("There's no render preset with the name '%s'."):format(presetName)
            })
            ok = false
        elseif not presetName then
            table.insert(checks, {
                passed = false,
                status = "No render preset selected",
                severity = 'critical',
                hint = "A render preset must be selected."
            })
            ok = false
        else
            local preset = DB.renderPresets[presetName]
            local test = preset.settings == 1
            table.insert(checks, {
                passed = test,
                status = ("Render preset source %s 'Master mix'"):format(test and 'is' or 'is not'),
                severity = (not test and 'warning' or nil),
                hint = test and "The render preset's source is set to 'Master mix'." or
                    "For the stems to be rendered correctly, the source must be set to 'Master mix'."
            })
            ok = ok and test
            if rsg.override_filename and rsg.filename ~= '' then
                test = string.match(rsg.filename, "$stem") ~= nil
            else
                test = string.match(preset.filepattern, "$stem") ~= nil
            end

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
        DB:sync()
        DB:getRenderPresets()
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

        App.render_cancelled = false
        App.current_renderaction = App.forceRenderAction or Settings.project.renderaction
        App.perform.fullRender = (App.stem_to_render == nil) -- and app.renderGroupToRender == nil)
        -- determine stems to be rendered
        if App.stem_to_render then
            stems_to_render = {
                [App.stem_to_render] = DB.stems[App.stem_to_render]
            }
        elseif App.renderGroupToRender then
            stems_to_render = {}
            for k, v in pairs(DB.stems) do
                if v.render_setting_group == App.renderGroupToRender then
                    stems_to_render[k] = v
                end
            end
        else
            stems_to_render = OD_DeepCopy(DB.stems)
        end
        coroutine.yield('Rendering stems', 0, 1)
        -- go over all stems to be rendered, in order to:
        --  - determine whether bounds should be be pre-saved
        --  - determine what stems should be skipped
        --  - get error messages for the entire render operation
        local included_render_groups = {}
        local stem_names_to_skip = {} -- for message
        for stemName, stem in pairs(stems_to_render) do
            local stem = DB.stems[stemName]
            local rsg = Settings.project.render_setting_groups[stem.render_setting_group]
            if rsg.select_markers or rsg.select_regions then
                save_marker_selection = true
            end
            if rsg.make_timeSel then
                save_time_selection = true
            end
            -- check if any track has a state in this stem
            foundAssignedTrack[stemName] = false
            for idx, track in ipairs(DB.tracks) do
                foundAssignedTrack[stemName] = foundAssignedTrack[stemName] or
                    (track.stemMatrix[stemName] ~= ' ' and track.stemMatrix[stemName] ~=
                        nil)
            end
            if App.perform.fullRender and rsg.skip_empty_stems and not foundAssignedTrack[stemName] then
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
            local rsg = Settings.project.render_setting_groups[rsgIdx]
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

        App.render_count = 0
        for stemName, stem in pairs(stems_to_render) do
            if not criticalErrorFound[stem.render_setting_group] then
                App.render_count = App.render_count + 1
            end
        end
        -- assemble combined error message

        local skpMsg
        if #stem_names_to_skip > 0 then
            skpMsg =
                ('The following stems do not have any tracks with solo/mute states\nin them, so they will be skipped:\n - %s\n(This can be changed in the settings window - render "empty" stems):')
                :format(
                    table.concat(stem_names_to_skip, ', '))
        end

        local ceMsg
        for rsgIdx, statuses in pairs(criticalErrors) do
            if #statuses > 0 then
                local stems_in_rsg = {}
                for stemName, stem in OD_PairsByOrder(stems_to_render) do
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
                for stemName, stem in OD_PairsByOrder(stems_to_render) do
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
            r.ImGui_OpenPopup(Gui.ctx, Scr.name .. '##error')
            while not error_message_closed do
                local ok = App:drawPopup(Gui.ctx, 'msg', Scr.name .. '##error', {
                    msg = msg,
                    showCancelButton = true
                })
                if ok then
                    error_message_closed = true
                elseif ok == false then
                    error_message_closed = true
                    App.render_count = 0
                end
                coroutine.yield('Errors found...', idx, App.perform.fullRender and DB.stemCount or 1)
            end
        end

        if App.render_count > 0 then
            -- save marker selection, so that it can be restored later
            if save_marker_selection and r.APIExists('JS_Localize') then
                OD_OpenAndGetRegionManagerWindow()
                coroutine.yield('Saving marker/region selection', 0, 1)
                saved_markeregion_selection = OD_GetSelectedRegionsOrMarkers()
                r.Main_OnCommand(40326, 0) -- close region/marker manager
            end
            if save_time_selection then
                saved_time_selection = { r.GetSet_LoopTimeRange(0, 0, 0, 0, 0) }
            end
            if r.GetAllProjectPlayStates(0) & 1 then
                r.OnStopButton()
            end
            for stemName, stem in OD_PairsByOrder(stems_to_render) do
                if not App.render_cancelled then
                    idx = idx + 1
                    -- TODO: CONSOLIDATE UNDO HISTORY?:
                    local stem = DB.stems[stemName]
                    local rsg = Settings.project.render_setting_groups[stem.render_setting_group]
                    if not criticalErrorFound[stem.render_setting_group] then
                        DB:toggleStemSync(DB.stems[stemName], SYNCMODE_SOLO)
                        coroutine.yield('Creating stem ' .. stemName, idx, App.render_count)
                        local render_preset = DB.renderPresets[rsg.render_preset]
                        ApplyPresetByName = render_preset.name
                        if applyPresetScript ~= nil then applyPresetScript() end
                        -- when "apply_render_preset" is run, it sets the project's render settings to the preset's settings, 
                        -- but doesn't apply the preset's directory, so I do it manually as a workaround until the script gets updated.
                        -- I already contacted cfillion about it. Will probably be fixed on the next release (>2.1.1).
                        if render_preset.folder then
                            r.GetSetProjectInfo_String(0, "RENDER_FILE", render_preset.folder, true)
                        end
                        if render_preset.boundsflag == RB_SELECTED_MARKERS and rsg.select_markers then
                            -- window must be given an opportunity to open (therefore yielded) for the selection to work
                            OD_OpenAndGetRegionManagerWindow()
                            coroutine.yield('Creating stem ' .. stemName .. ' (selecting markers)', idx,
                                App.render_count)
                            -- for some reason selecting in windows requires region manager window to remain open for some time
                            -- (this is a workaround until proper api support for selecting regions exists)
                            -- if OS_is.win then
                                OD_SelectMarkers(rsg.selected_markers, false)
                                local t = os.clock()
                                while (os.clock() - t < 0.5) do
                                    coroutine.yield('Creating stem ' .. stemName .. ' (selecting markers)', idx,
                                        App.render_count)
                                end
                                r.Main_OnCommand(40326, 0) -- close region/marker manager
                            -- else
                            --     OD_SelectMarkers(rsg.selected_markers)
                            -- end
                        elseif render_preset.boundsflag == RB_SELECTED_REGIONS and rsg.select_regions then
                            -- window must be given an opportunity to open (therefore yielded) for the selection to work

                            OD_OpenAndGetRegionManagerWindow()
                            coroutine.yield('Creating stem ' .. stemName .. ' (selecting regions)', idx,
                                App.render_count)
                            -- for some reason selecting in windows requires region manager window to remain open for some time
                            -- (this is a workaround until proper api support for selecting regions exists)
                            -- if OS_is.win then
                                OD_SelectRegions(rsg.selected_regions, false)
                                local t = os.clock()
                                while (os.clock() - t < 0.5) do
                                    coroutine.yield('Creating stem ' .. stemName .. ' (selecting regions)', idx,
                                        App.render_count)
                                end
                                r.Main_OnCommand(40326, 0) -- close region/marker manager
                            -- else
                            --     OD_SelectRegions(rsg.selected_regions)
                            -- end
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
                                local cmd = r.NamedCommandLookup(action)
                                if cmd then
                                    r.Main_OnCommand(cmd, 0)
                                end
                            end
                        end
                        if App.current_renderaction == RENDERACTION_RENDER then
                            if Settings.project.overwrite_without_asking and RENDERACTION_RENDER then
                                local rv, target_list = r.GetSetProjectInfo_String(0, 'RENDER_TARGETS', '', false)
                                if rv then
                                    local targets = OD_Split(target_list, ';')
                                    for i, target in ipairs(targets) do
                                        if OD_FileExists(target) then
                                            os.remove(target)
                                        end
                                    end
                                end
                            end
                            coroutine.yield('Rendering stem ' .. stemName, idx, App.render_count)

                            r.Main_OnCommand(42230, 0)                           -- render now
                            r.Main_OnCommand(40043, 0)                           -- go to end of project
                            coroutine.yield('Waiting...', idx, App.render_count) -- let a frame pass to start count at a correct place

                            local stopprojlen = select(2, r.get_config_var_string('stopprojlen'))
                            if stopprojlen == '1' then
                                r.SNM_SetIntConfigVar('stopprojlen', 0)
                            end
                            r.OnPlayButtonEx(0)
                            if stopprojlen == '1' then
                                r.SNM_SetIntConfigVar('stopprojlen', 1)
                            end
                            local moreStemsInLine = idx < App.render_count
                            if moreStemsInLine then
                                r.ImGui_OpenPopup(Gui.ctx, Scr.name .. '##wait')
                            end
                            local t = os.clock()
                            while not App.render_cancelled and (os.clock() - t < Settings.project.wait_time + 1) and
                                moreStemsInLine do
                                local wait_left = math.ceil(Settings.project.wait_time - (os.clock() - t))
                                if App:drawPopup(Gui.ctx, 'msg', Scr.name .. '##wait', {
                                        closeKey = r.ImGui_Key_Escape(),
                                        okButtonLabel = "Stop rendering",
                                        msg = ('Waiting for %d more second%s...'):format(wait_left,
                                            wait_left > 1 and 's' or '')
                                    }) then
                                    App.render_cancelled = true
                                end
                                coroutine.yield('Waiting...', idx, App.render_count)
                            end
                            r.OnStopButtonEx(0)
                        else
                            r.Main_OnCommand(41823, 0) -- add to render queue
                        end
                        if rsg.run_actions_after then
                            for aIdx, action in ipairs(rsg.actions_to_run_after or {}) do
                                action = (type(action) == 'string') and '_' .. action or action
                                local cmd = r.NamedCommandLookup(action)
                                if cmd then
                                    r.Main_OnCommand(cmd, 0)
                                end
                            end
                        end
                    end
                    laststemName = stemName
                end
            end
            App.render_cancelled = false
            DB:toggleStemSync(DB.stems[laststemName], SYNCMODE_OFF)
            -- restore marker/region selection if it was saved
            if save_marker_selection and r.APIExists('JS_Localize') then
                OD_OpenAndGetRegionManagerWindow()
                coroutine.yield('Restoring marker/region selection', 1, 1)
                -- if OS_is.win then
                    -- for some reason selecting in windows requires region manager window to remain open for some time
                    -- (this is a workaround until proper api support for selecting regions exists)
                    OD_SelectRegionsOrMarkers(saved_markeregion_selection, false)
                    local t = os.clock()
                    while (os.clock() - t < 0.5) do
                        coroutine.yield('Restoring marker/region selection', idx, App.render_count)
                    end
                    r.Main_OnCommand(40326, 0) -- close region/marker manager
                -- else
                --     OD_SelectRegionsOrMarkers(saved_markeregion_selection)
                -- end
            end
            if save_time_selection then
                r.GetSet_LoopTimeRange2(0, true, false, saved_time_selection[1], saved_time_selection[2], 0) -- , boolean isLoop, number start, number end, boolean allowautoseek)
            end
            r.GetSetProjectInfo_String(0, "RENDER_PATTERN", saved_filename, true)
            if Settings.project.play_sound_when_done and r.APIExists('CF_CreatePreview') then
                local source = reaper.PCM_Source_CreateFromFile(p .. 'lib/render-complete.wav')
                local preview = reaper.CF_CreatePreview(source)
                reaper.PCM_Source_Destroy(source)
                reaper.CF_Preview_Play(preview)
            end
            coroutine.yield('Done', 1, 1)
        else
            coroutine.yield('Done', 0, 1)
        end
        return
    end

    local function checkExternalCommand()
        local raw_cmd = r.GetExtState(Scr.ext_name, 'EXTERNAL COMMAND')
        local cmd, arg = raw_cmd:match('^([%w_]+)%s*(.*)$')
        if cmd ~= '' and cmd ~= nil then
            r.SetExtState(Scr.ext_name, 'EXTERNAL COMMAND', '', false)
            if cmd == 'sync' then
                if arg then
                    stemName = DB:findSimilarStem(arg, true)
                end
                if stemName then
                    if DB.stems[stemName] then
                        DB:toggleStemSync(DB.stems[stemName],
                            (DB.stems[stemName].sync == SYNCMODE_SOLO) and SYNCMODE_OFF or SYNCMODE_SOLO)
                    end
                end
            elseif (cmd == 'add') or (cmd == 'render') then
                if arg then
                    stemName = DB:findSimilarStem(arg, true)
                end
                if stemName then
                    if DB.stems[stemName] then
                        App.forceRenderAction = (cmd == 'add') and RENDERACTION_RENDERQUEUE_OPEN or RENDERACTION_RENDER
                        App.stem_to_render = stemName
                        App.coPerform = coroutine.create(doPerform)
                    end
                end
            elseif (cmd == 'add_rg') or (cmd == 'render_rg') then
                local renderGroup = tonumber(arg)
                if renderGroup and renderGroup >= 1 and renderGroup <= RENDER_SETTING_GROUPS_SLOTS then
                    App.forceRenderAction = (cmd == 'add_rg') and RENDERACTION_RENDERQUEUE_OPEN or RENDERACTION_RENDER
                    App.renderGroupToRender = renderGroup
                    App.coPerform = coroutine.create(doPerform)
                end
            elseif cmd == 'add_all' then
                App.forceRenderAction = RENDERACTION_RENDERQUEUE_OPEN
                App.coPerform = coroutine.create(doPerform)
            elseif cmd == 'render_all' then
                App.forceRenderAction = RENDERACTION_RENDER
                App.coPerform = coroutine.create(doPerform)
            end
        end
    end

    -- only works with monospace (90 degree) fonts
    function verticalText(ctx, text)
        r.ImGui_PushFont(ctx, Gui.st.fonts.vertical)
        local letterspacing = (Gui.VERTICAL_TEXT_BASE_HEIGHT + Gui.VERTICAL_TEXT_BASE_HEIGHT_OFFSET)
        local posX, posY = r.ImGui_GetCursorPosX(ctx), r.ImGui_GetCursorPosY(ctx) - letterspacing * #text
        text = text:reverse()
        for ci = 1, #text do
            r.ImGui_SetCursorPos(ctx, posX, posY + letterspacing * (ci - 1))
            r.ImGui_Text(ctx, text:sub(ci, ci))
        end
        r.ImGui_PopFont(ctx)
    end

    App.drawCols = {}
    function App.drawCols.stemName(stemName)
        local ctx = Gui.ctx
        local cellSize = Gui.st.vars.mtrx.cellSize
        local headerRowHeight = Gui.st.vars.mtrx.headerRowHeight
        local defPadding = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
        local topLeftX, topLeftY = r.ImGui_GetCursorScreenPos(ctx)
        local stem = DB.stems[stemName]
        r.ImGui_PushID(ctx, stemName)
        r.ImGui_SetCursorPos(ctx, r.ImGui_GetCursorPosX(ctx) +
            (r.ImGui_GetContentRegionAvail(ctx) - Gui.VERTICAL_TEXT_BASE_WIDTH) / 2,
            r.ImGui_GetCursorPosY(ctx) + headerRowHeight - defPadding)
        verticalText(ctx, stemName)
        if r.ImGui_IsMouseHoveringRect(ctx, topLeftX, topLeftY, topLeftX + cellSize, topLeftY + headerRowHeight) and
            not r.ImGui_IsPopupOpen(ctx, '', r.ImGui_PopupFlags_AnyPopup()) or r.ImGui_IsPopupOpen(ctx, '##stemActions') then
            r.ImGui_SetCursorScreenPos(ctx, topLeftX, topLeftY + 1)
            Gui:popStyles(Gui.st.vars.mtrx.table)
            App:drawBtn('stemActions', {
                topLeftX = topLeftX,
                topLeftY = topLeftY
            })
            App:drawPopup(ctx, 'stemActionsMenu', '##stemActions', {
                stemName = stemName,
                renderSettingGroup = stem.render_setting_group
            })
            Gui:pushStyles(Gui.st.vars.mtrx.table)
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
                DB:reorderStem(payload, stem.order)
            end
            r.ImGui_EndDragDropTarget(ctx)
        end
        r.ImGui_PopID(ctx)
    end

    function App.drawMatrices(ctx, bottom_lines)
        local cellSize = Gui.st.vars.mtrx.cellSize
        local childHeight = select(2, r.ImGui_GetContentRegionAvail(ctx)) -
            (r.ImGui_GetFrameHeightWithSpacing(ctx) * bottom_lines +
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) * 2)
        local defPadding = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
        local modKeys = Gui:updateModKeys()
        -- if r.ImGui_CollapsingHeader(ctx,"Stem Selection",false,r.ImGui_TreeNodeFlags_DefaultOpen()) then
        if r.ImGui_BeginChild(ctx, 'stemSelector', 0, childHeight) then
            r.ImGui_PushFont(ctx, Gui.st.fonts.default)
            if Gui.mtrxTbl.drgState and r.ImGui_IsMouseReleased(ctx, r.ImGui_MouseButton_Left()) then
                Gui.mtrxTbl.drgState = nil
            end -- needs to stop dragging before drag affects released hovered item to prevent edge case
            Gui:pushStyles(Gui.st.vars.mtrx.table)
            Gui:pushColors(Gui.st.col.trackname)
            local trackListX, trackListY, trackListWidth, trackListHeight
            trackListWidth = r.ImGui_GetContentRegionAvail(ctx) -
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ScrollbarSize())
            if r.ImGui_BeginTable(ctx, 'table_scrollx', 1 + DB.stemCount + 1, Gui.tables.horizontal.flags1) then
                --- SETUP MATRIX TABLE
                local parent_open, depth, open_depth = true, 0, 0
                r.ImGui_TableSetupScrollFreeze(ctx, 1, 3)
                r.ImGui_TableSetupColumn(ctx, 'Track', r.ImGui_TableColumnFlags_NoHide()) -- Make the first column not hideable to match our use of TableSetupScrollFreeze()
                for stemName, tracks in OD_PairsByOrder(DB.stems) do
                    r.ImGui_TableSetupColumn(ctx, stemName, nil, cellSize)
                end
                --- STEM NAME ROW
                local maxletters = 0
                for k in pairs(DB.stems) do
                    maxletters = math.max(maxletters, #k)
                end
                Gui.st.vars.mtrx.headerRowHeight = math.max(cellSize * 3, (Gui.VERTICAL_TEXT_BASE_HEIGHT +
                    Gui.VERTICAL_TEXT_BASE_HEIGHT_OFFSET) * maxletters + defPadding * 4)
                local headerRowHeight = Gui.st.vars.mtrx.headerRowHeight
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
                for k, stem in OD_PairsByOrder(DB.stems) do
                    if r.ImGui_TableNextColumn(ctx) then
                        App.drawCols.stemName(k)
                    end
                end
                r.ImGui_TableNextColumn(ctx)
                -- COL: ADD STEM BUTTON
                if App:drawBtn('addStem') then
                    if modKeys ~= "c" then
                        App.copyOnAddStem = (Settings.project.reflect_on_add == REFLECT_ON_ADD_TRUE)
                    else
                        App.copyOnAddStem = (Settings.project.reflect_on_add == REFLECT_ON_ADD_FALSE)
                    end
                    r.ImGui_OpenPopup(ctx, 'Add Stem')
                end
                Gui:popStyles(Gui.st.vars.mtrx.table)
                local retval, newval = App:drawPopup(ctx, 'singleInput', 'Add Stem', {
                    okButtonLabel = 'Add',
                    validation = validators.stem.name
                })
                if retval then
                    DB:addStem(newval, App.copyOnAddStem)
                    App.copyOnAddStem = nil
                end
                Gui:pushStyles(Gui.st.vars.mtrx.table)
                -- RENDER GROUPS
                -- COL: TRACK NAME
                r.ImGui_TableNextRow(ctx, r.ImGui_TableRowFlags_Headers(), cellSize)
                if r.ImGui_TableNextColumn(ctx) then
                    r.ImGui_AlignTextToFramePadding(ctx)
                    r.ImGui_SetCursorPosX(ctx, r.ImGui_GetCursorPosX(ctx) + defPadding * 2)
                    r.ImGui_Text(ctx, 'Render Setting Groups')
                end
                -- COL: STEM RENDER GROUP
                for k, stem in OD_PairsByOrder(DB.stems) do
                    if r.ImGui_TableNextColumn(ctx) then
                        App:drawBtn('renderGroupSelector', {
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
                for k, stem in OD_PairsByOrder(DB.stems) do
                    r.ImGui_PushID(ctx, 'sync' .. k)
                    if r.ImGui_TableNextColumn(ctx) then
                        local syncMode = (modKeys == 'a') and
                            ((Settings.project.syncmode == SYNCMODE_MIRROR) and SYNCMODE_SOLO or
                                SYNCMODE_MIRROR) or Settings.project.syncmode
                        if App:drawBtn('stemSync', {
                                stemSyncMode = stem.sync,
                                generalSyncMode = syncMode
                            }) then
                            DB:toggleStemSync(stem, ((stem.sync == SYNCMODE_OFF) or (stem.sync == nil)) and syncMode or
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
                    local track = DB.tracks[i]
                    local depth_delta = math.max(track.folderDepth, -depth) -- prevent depth + delta being < 0
                    local is_folder = depth_delta > 0
                    local hide = (not Settings.project.show_hidden_tracks) and track.hidden

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
                            r.ImGui_DrawList_PushClipRect(Gui.draw_list, trackListX,
                                trackListY + (cellSize + 1) * (i - 1), trackListX + trackListWidth,
                                trackListY + (cellSize + 1) * (i - 1) + cellSize, false)
                            -- COL: TRACK COLOR + NAME
                            r.ImGui_TableNextColumn(ctx)
                            r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) + 1)
                            r.ImGui_ColorButton(ctx, 'color', r.ImGui_ColorConvertNative(track.color),
                                r.ImGui_ColorEditFlags_NoAlpha() | r.ImGui_ColorEditFlags_NoBorder() |
                                r.ImGui_ColorEditFlags_NoTooltip(), cellSize, cellSize)
                            r.ImGui_SameLine(ctx)
                            local node_flags = is_folder and Gui.treeflags.base or Gui.treeflags.leaf
                            r.ImGui_PushID(ctx, i) -- Tracks might have the same name
                            parent_open = r.ImGui_TreeNode(ctx, track.name .. '  ', node_flags)
                            r.ImGui_PopID(ctx)
                            for k, stem in OD_PairsByOrder(DB.stems) do
                                if r.ImGui_TableNextColumn(ctx) then
                                    -- COL: STEM STATE
                                    App:drawBtn('stemState', {
                                        track = track,
                                        stemName = k,
                                        state = track.stemMatrix[k] or ' '
                                    })
                                end
                            end
                            r.ImGui_DrawList_PopClipRect(Gui.draw_list)
                        end
                    elseif depth > open_depth then
                        --- HIDDEN SOLO STATES
                        local idx = 0
                        for k, stem in OD_PairsByOrder(DB.stems) do
                            idx = idx + 1
                            -- local state = track.stemMatrix[k] or ' '
                            if not arrow_drawn[k] then
                                local offsetX, offsetY = cellSize / 2, -1
                                if not (track.stemMatrix[k] == ' ') and not (track.stemMatrix[k] == nil) then
                                    if r.ImGui_TableSetColumnIndex(ctx, idx) then
                                        r.ImGui_SameLine(ctx)
                                        r.ImGui_Dummy(ctx, 0, 0)
                                        local sz = 5                                                 -- ((last_open_track.stemMatrix[k] == nil) or (last_open_track.stemMatrix[k] == ' ' )) and (cellSize-4) or 6
                                        local posX = select(1, r.ImGui_GetCursorScreenPos(ctx))      -- +offsetX
                                        local posY = select(2, r.ImGui_GetCursorScreenPos(ctx)) - sz -- +offsetY
                                        local color =
                                            Gui.st.col.hasChildren[(last_open_track.stemMatrix[k] or ' ')]
                                            [r.ImGui_Col_Text()]
                                        r.ImGui_DrawList_AddRectFilled(Gui.draw_list, posX, posY, posX + cellSize,
                                            posY + sz, color)
                                        if r.ImGui_IsMouseHoveringRect(ctx, posX, posY, posX + cellSize, posY + sz) then
                                            App:setHint('main',
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
                Gui:popColors(Gui.st.col.trackname)
                Gui:popStyles(Gui.st.vars.mtrx.table)
            end
            r.ImGui_PopFont(ctx)
            r.ImGui_EndChild(ctx)
        end
    end

    function App.drawSettings()
        local ctx = App.gui.ctx
        local bottom_lines = 2
        local rv
        local x, y = r.ImGui_GetMousePos(ctx)
        local center = { Gui.mainWindow.pos[1] + Gui.mainWindow.size[1] / 2,
            Gui.mainWindow.pos[2] + Gui.mainWindow.size[2] / 2 } -- {r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
        local currentSettings
        local halfWidth = 230
        local itemWidth = halfWidth * 2
        local renderaction_list = ''
        local cP = OD_GetProjGUID()
        local projectChanged = OD_DidProjectGUIDChange()
        Gui.stWnd[cP] = Gui.stWnd[cP] or {}
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
                widgetWidth = itemWidth - Gui.TEXT_BASE_WIDTH * 2 -
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
            App:setHoveredHint('settings', hint)
            return retval, nil
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
                    r.ImGui_TextColored(ctx, Gui.st.col.error,
                        ('js_ReaScriptAPI needed for selecting %ss.'):format(stType))
                else
                    local widgetWidth = itemWidth - Gui.TEXT_BASE_WIDTH * 2 -
                        r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2
                    if stType == 'time_sel' then
                        local clicked = r.ImGui_Button(ctx, 'Capture time selection', widgetWidth)
                        App:setHoveredHint('settings',
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
                        App:setHoveredHint('settings', "Time seleciton start.")
                        r.ImGui_SameLine(ctx)
                        r.ImGui_SetCursorPosX(ctx, r.ImGui_GetCursorPosX(ctx) -
                            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemInnerSpacing()))
                        if r.ImGui_BeginChildFrame(ctx, '##timeselend', r.ImGui_GetContentRegionAvail(ctx),
                                r.ImGui_GetFrameHeight(ctx)) then
                            r.ImGui_Text(ctx, r.format_timestr_pos(retval_b, '', 5))
                            r.ImGui_EndChildFrame(ctx)
                        end
                        App:setHoveredHint('settings', "Time seleciton end.")
                    elseif stType == 'actions' then
                        retval_a = retval_a or {}
                        r.ImGui_SetNextItemWidth(ctx, widgetWidth)
                        if r.ImGui_BeginListBox(ctx, '##' .. text, 0, r.ImGui_GetTextLineHeightWithSpacing(ctx) * 4) then
                            for i, action in ipairs(retval_a) do
                                local rv, name = OD_GetReaperActionNameOrCommandId(action)
                                if r.ImGui_Selectable(ctx, name .. '##' .. text .. i, Gui.stWnd[cP][text] == i) then
                                    if Gui.stWnd[cP][text] == i then
                                        Gui.stWnd[cP][text] = nil
                                    else
                                        Gui.stWnd[cP][text] = i
                                    end
                                end
                                if not rv then
                                    App:setHoveredHint('settings',
                                        'SWS not installed: showing Command ID instead of action names.')
                                end
                            end
                            r.ImGui_EndListBox(ctx)
                        end
                        r.ImGui_SameLine(ctx)
                        local framePaddingX, framePaddingY = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
                        r.ImGui_SetCursorPos(ctx, halfWidth, r.ImGui_GetCursorPosY(ctx) +
                            r.ImGui_GetTextLineHeightWithSpacing(ctx) + framePaddingY * 2)
                        if r.ImGui_Button(ctx, '+##add' .. text, Gui.TEXT_BASE_WIDTH * 2 + framePaddingX) then
                            Gui.stWnd[cP].action_target = text
                            r.PromptForAction(1, 0, 0)
                        end
                        App:setHoveredHint('settings',
                            "Add an action by highlighting it in REAPER's action window and clicking 'Select'.")
                        if Gui.stWnd[cP].action_target == text then
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
                        if r.ImGui_Button(ctx, '-##remove' .. text, Gui.TEXT_BASE_WIDTH * 2 + framePaddingX) then
                            if Gui.stWnd[cP][text] then
                                table.remove(retval_a, Gui.stWnd[cP][text])
                            end
                        end
                        App:setHoveredHint('settings', "Remove selected action.")
                    elseif stType == 'region' or stType == 'marker' then
                        if not r.APIExists('JS_Localize') then
                            r.ImGui_TextColored(ctx, Gui.st.col.error,
                                ('js_ReaScriptAPI extension is required for selecting %ss.'):format(stType))
                        else
                            -- GetRegionManagerWindow is not very performant, so only do it once every 6 frames
                            if Gui.stWnd[cP].frameCount % 10 == 0 then
                                App.rm_window_open = OD_GetRegionManagerWindow() ~= nil
                            end
                            if not App.rm_window_open then
                                local title = (('%s selected'):format((#retval_a > 0) and
                                    ((#retval_a > 1) and #retval_a .. ' %ss' or
                                        '1 %s') or "No %s"):format(stType))
                                local clicked = r.ImGui_Button(ctx, title, widgetWidth)
                                if clicked then
                                    if #retval_a > 0 and Gui.modKeys == "a" then
                                        retval_a = {}
                                    else
                                        r.Main_OnCommand(40326, 0)
                                    end
                                end
                                if r.ImGui_IsItemHovered(ctx) and #retval_a > 0 then
                                    App:setHoveredHint('settings',
                                        ("Click to update selection. %s+click to clear."):format(
                                            Gui.descModAlt:gsub("^%l", string.upper)))
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
                                    App:setHoveredHint('settings', ("Click to select %ss."):format(stType))
                                end
                            else
                                if r.ImGui_Button(ctx, ('Capture selected %ss'):format(stType), widgetWidth) then
                                    retval_a = OD_GetSelectedRegionsOrMarkers(stType:sub(1, 1):upper())
                                end
                                App:setHint('settings',
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
        r.ImGui_SetNextWindowPos(ctx, center[1], Gui.mainWindow.pos[2] + 100, r.ImGui_Cond_Appearing(), 0.5)
        -- if r.ImGui_BeginPopupModal(ctx, 'Settings', false, r.ImGui_WindowFlags_AlwaysAutoResize()) then
        if r.ImGui_Begin(ctx, 'Settings', false, r.ImGui_WindowFlags_AlwaysAutoResize() | r.ImGui_WindowFlags_TopMost()) then
            r.ImGui_PushFont(ctx, Gui.st.fonts.default)
            local windowAppearing = r.ImGui_IsWindowAppearing(ctx)
            if windowAppearing or projectChanged then
                Gui.stWnd[cP].frameCount = 0
                if Gui.stWnd[cP].tS == nil then
                    LoadSettings()
                    Gui.stWnd[cP].tS = OD_DeepCopy(Settings.project)
                end
                DB:getRenderPresets()
                if r.APIExists('JS_Localize') then
                    local manager = OD_GetRegionManagerWindow()
                    if manager then
                        r.Main_OnCommand(40326, 0)
                    end
                    App.rm_window_open = false
                end

                projectChanged = false
                Gui.stWnd[cP].activeRSG = nil
                Gui.stWnd[cP].action_target = nil
            end

            r.ImGui_PushFont(ctx, Gui.st.fonts.bold)
            r.ImGui_Text(ctx, 'Project global settings')
            r.ImGui_PopFont(ctx)
            r.ImGui_Separator(ctx)

            Gui.stWnd[cP].tS.renderaction = setting('combo', 'Render action',
                ("What should the default rendering mode be."):format(Scr.name), Gui.stWnd[cP].tS.renderaction, {
                    list = renderaction_list
                })
            if Gui.stWnd[cP].tS.renderaction == RENDERACTION_RENDER then
                Gui.stWnd[cP].tS.overwrite_without_asking = setting('checkbox', 'Always overwrite',
                    "Suppress REAPER's dialog asking whether files should be overwritten.",
                    Gui.stWnd[cP].tS.overwrite_without_asking)
                Gui.stWnd[cP].tS.wait_time = setting('dragint', 'Wait time between renders',
                    "Time to wait between renders to allow canceling and to let FX tails die down.",
                    Gui.stWnd[cP].tS.wait_time, {
                        step = 0.1,
                        min = WAITTIME_MIN,
                        max = WAITTIME_MAX
                    })
            end

            Gui.stWnd[cP].tS.reflect_on_add = setting('combo', 'New stems created',
                'What solo states will newly added stems have?', Gui.stWnd[cP].tS.reflect_on_add, {
                    list = reflect_on_add_list
                })
            Gui.stWnd[cP].tS.syncmode = setting('combo', 'Mirror mode',
                ("Mirror mode. %s-click the mirror button to trigger other behavior."):format(
                    Gui.descModAlt:gsub("^%l", string.upper)), Gui.stWnd[cP].tS.syncmode, {
                    list = syncmode_list
                })
            Gui.stWnd[cP].tS.show_hidden_tracks = setting('checkbox', 'Show hidden tracks',
                "Show tracks that are hidden in the TCP?", Gui.stWnd[cP].tS.show_hidden_tracks)
            Gui.stWnd[cP].tS.play_sound_when_done = setting('checkbox', 'Play sound when done',
                "Play sound when rendering is done (not applicable when adding to render queue)", Gui.stWnd[cP].tS.play_sound_when_done)
            if Gui.stWnd[cP].tS.play_sound_when_done and not r.APIExists("CF_CreatePreview") then
                r.ImGui_SameLine(ctx)
                r.ImGui_Text(ctx,"SWS pre-release missing. More info")
                r.ImGui_SameLine(ctx)
                local sws_pre_release_url = "https://forum.cockos.com/showthread.php?t=153702"
                if r.ImGui_SmallButton(ctx, 'here') then
                    if r.APIExists('CF_ShellExecute') then
                        r.CF_ShellExecute(sws_pre_release_url)
                    else
                        local command
                        if OS_is.mac then
                            command = 'open "%s"'
                        elseif OS_is.win then
                            command = 'start "URL" /B "%s"'
                        elseif OS_is.lin then
                            command = 'xdg-open "%s"'
                        end
                        if command then
                            os.execute(command:format(sws_pre_release_url))
                        end
                    end
                end
            end

            r.ImGui_Text(ctx, '')
            r.ImGui_PushFont(ctx, Gui.st.fonts.bold)
            r.ImGui_Text(ctx, 'Project render groups')
            r.ImGui_PopFont(ctx)
            App:setHoveredHint('settings',
                ("Each stem is associated to one of %d render groups with its own set of settings."):format(
                    RENDER_SETTING_GROUPS_SLOTS))
            r.ImGui_Separator(ctx)

            local availwidth = r.ImGui_GetContentRegionAvail(ctx)
            if r.ImGui_BeginTabBar(ctx, 'Render Group Settings') then
                for stGrp = 1, RENDER_SETTING_GROUPS_SLOTS do
                    if Gui.stWnd[cP].activeRSG == stGrp then
                        r.ImGui_SetNextItemWidth(ctx, halfWidth * 3 / RENDER_SETTING_GROUPS_SLOTS)
                    end
                    if r.ImGui_BeginTabItem(ctx, stGrp .. '##settingGroup' .. stGrp, false) then
                        -- if tab has changed or is loaded for the first time
                        if Gui.stWnd[cP].activeRSG ~= stGrp then
                            r.PromptForAction(-1, 0, 0)
                            Gui.stWnd[cP].action_target = nil
                            Gui.stWnd[cP].activeRSG = stGrp
                        end
                        App:setHoveredHint('settings', ("Settings for render group %d."):format(stGrp))
                        local rsg = Gui.stWnd[cP].tS.render_setting_groups[stGrp]

                        rsg.description = setting('text', 'Description',
                            "Used as a reference for yourself. E.g., stems, submixes, mix etc...", rsg.description)
                        if rsg.render_preset == '' then
                            rsg.render_preset = nil
                        end
                        local preset = DB.renderPresets[rsg.render_preset]
                        if setting('button', 'Render Preset',
                                ("A render preset to use for this render group. %s+click to clear."):format(
                                    Gui.descModAlt:gsub("^%l", string.upper)), nil, {
                                    label = rsg.render_preset or 'Select...'
                                }) then
                            if Gui.modKeys == 'a' then
                                rsg.render_preset = nil
                            else
                                DB:getRenderPresets()
                                r.ImGui_OpenPopup(ctx, 'Stem Render Presets##stemRenderPresets')
                            end
                        end
                        local rv, presetName = App:drawPopup(ctx, 'renderPresetSelector',
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
                        if Gui.stWnd[cP].frameCount % 10 == 0 then
                            _, Gui.stWnd[cP].checks = checkRenderGroupSettings(rsg)
                        end
                        local col_ok = Gui.st.col.ok
                        local col_error = Gui.st.col.error
                        local col_warning = Gui.st.col.warning
                        local warnings = false
                        for i, check in ipairs(Gui.stWnd[cP].checks) do
                            if not check.passed and check.severity == 'warning' then
                                warnings = true
                            end
                        end
                        r.ImGui_Text(ctx, '')

                        r.ImGui_AlignTextToFramePadding(ctx)
                        r.ImGui_PushFont(ctx, Gui.st.fonts.bold)
                        r.ImGui_Text(ctx, 'Checklist:')
                        r.ImGui_PopFont(ctx)
                        if warnings then
                            r.ImGui_SameLine(ctx)
                            rv, rsg.ignore_warnings = r.ImGui_Checkbox(ctx,
                                "Don't show non critical (orange) errors before rendering", rsg.ignore_warnings)
                            App:setHoveredHint('settings',
                                "This means you're aware of the warnings and are OK with them :)")
                        end

                        r.ImGui_Separator(ctx)
                        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_DisabledAlpha(), 1)
                        r.ImGui_BeginDisabled(ctx)

                        for i, check in ipairs(Gui.stWnd[cP].checks) do
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
                            App:setHoveredHint('settings', check.hint)
                        end
                        r.ImGui_EndDisabled(ctx)
                        r.ImGui_PopStyleVar(ctx)

                        r.ImGui_EndTabItem(ctx)
                    end
                    if stGrp ~= Gui.stWnd[cP].activeRSG then
                        App:setHoveredHint('settings', ("Settings for render group %d."):format(stGrp))
                    end
                end
                r.ImGui_EndTabBar(ctx)
            end
            r.ImGui_Separator(ctx)
            r.ImGui_PopItemWidth(ctx)

            -- bottom

            -- r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeightWithSpacing(ctx) * bottom_lines))
            local status, col = App:getStatus('settings')
            if col then
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), Gui.st.col[col])
            end
            r.ImGui_Spacing(ctx)
            r.ImGui_Text(ctx, status)
            App:setHint('settings', '')
            r.ImGui_Spacing(ctx)
            if col then
                r.ImGui_PopStyleColor(ctx)
            end

            if r.ImGui_Button(ctx, "Load default settings") then
                Gui.stWnd[cP].tS = OD_DeepCopy(GetDefaultSettings(Gui.modKeys == 'a').default)
            end
            App:setHoveredHint('settings',
                ('Revert to saved default settings. %s+click to load factory settings.'):format(
                    Gui.descModAlt:gsub("^%l", string.upper)))

            r.ImGui_SameLine(ctx)
            if r.ImGui_Button(ctx, "Save as default settings") then
                -- Settings.project = OD_DeepCopy(Gui.stWnd[cP].tS)
                -- Settings.default = OD_DeepCopy(Gui.stWnd[cP].tS)
                Settings.project = {}
                Settings.default = {}
                OD_MergeTables(Settings.project, Gui.stWnd[cP].tS)
                OD_MergeTables(Settings.default, Gui.stWnd[cP].tS)
                SaveSettings()
                r.PromptForAction(-1, 0, 0)
                App.show_settings_window = false

                -- r.ImGui_CloseCurrentPopup(ctx)
            end
            App:setHoveredHint('settings', ('Default settings for new projects where %s is used.'):format(Scr.name))

            r.ImGui_SameLine(ctx)
            r.ImGui_SetCursorPosX(ctx,
                r.ImGui_GetCursorPosX(ctx) + r.ImGui_GetContentRegionAvail(ctx) - r.ImGui_CalcTextSize(ctx, "  OK  ") -
                r.ImGui_CalcTextSize(ctx, "Cancel") - r.ImGui_CalcTextSize(ctx, "Apply") -
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) * 2 -
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 6)

            if r.ImGui_Button(ctx, "  OK  ") then
                -- Settings.project = OD_DeepCopy(Gui.stWnd[cP].tS)
                Settings.project = {}
                OD_MergeTables(Settings.project, Gui.stWnd[cP].tS)
                SaveSettings()
                r.PromptForAction(-1, 0, 0)
                App.show_settings_window = false
                -- r.ImGui_CloseCurrentPopup(ctx)
            end
            App:setHoveredHint('settings', ('Save settings for the current project and close the window.'):format(
                Gui.descModAlt:gsub("^%l", string.upper)))
            r.ImGui_SameLine(ctx)
            if r.ImGui_Button(ctx, "Cancel") or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
                r.PromptForAction(-1, 0, 0)
                App.show_settings_window = false
                -- r.ImGui_CloseCurrentPopup(ctx)
            end
            App:setHoveredHint('settings', ('Close without saving.'):format(Gui.descModAlt:gsub("^%l", string.upper)))
            r.ImGui_SameLine(ctx)

            if r.ImGui_Button(ctx, "Apply") then
                -- Settings.project = OD_DeepCopy(Gui.stWnd[cP].tS)
                Settings.project = {}
                OD_MergeTables(Settings.project, Gui.stWnd[cP].tS)
                SaveSettings()
            end
            App:setHoveredHint('settings', ('Save settings for the current project.'):format(
                Gui.descModAlt:gsub("^%l", string.upper)))
            Gui.stWnd[cP].frameCount = (Gui.stWnd[cP].frameCount == 120) and 0 or (Gui.stWnd[cP].frameCount + 1)

            r.ImGui_PopFont(ctx)
            -- r.ImGui_EndPopup(ctx)
            r.ImGui_End(ctx)
        end
    end

    function App:drawPopup(ctx, popupType, title, data)
        local data = data or {}
        local center = { Gui.mainWindow.pos[1] + Gui.mainWindow.size[1] / 2,
            Gui.mainWindow.pos[2] + Gui.mainWindow.size[2] / 2 } -- {r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
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
                Gui.popups.title = title

                if r.ImGui_IsWindowAppearing(ctx) then
                    r.ImGui_SetKeyboardFocusHere(ctx)
                    Gui.popups.singleInput.value = initVal -- gui.popups.singleInput.stem.name
                    Gui.popups.singleInput.status = ""
                end
                local width = select(1, r.ImGui_GetContentRegionAvail(ctx))
                r.ImGui_PushItemWidth(ctx, width)
                retval, Gui.popups.singleInput.value = r.ImGui_InputText(ctx, '##singleInput',
                    Gui.popups.singleInput.value)

                r.ImGui_SetItemDefaultFocus(ctx)
                r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeight(ctx) * bottom_lines) -
                    r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()))
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), Gui.st.col.error)
                r.ImGui_Text(ctx, Gui.popups.singleInput.status)
                r.ImGui_PopStyleColor(ctx)
                if r.ImGui_Button(ctx, okButtonLabel) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
                    Gui.popups.singleInput.status = validation(initVal, Gui.popups.singleInput.value)
                    if Gui.popups.singleInput.status == true then
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
            return okPressed, Gui.popups.singleInput.value
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
                Gui.popups.title = title

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
                    Gui.popups.object = data.stemName;
                    r.ImGui_OpenPopup(ctx, 'Rename Stem')
                end
                local retval, newval = App:drawPopup(ctx, 'singleInput', 'Rename Stem', {
                    initVal = data.stemName,
                    okButtonLabel = 'Rename',
                    validation = validators.stem.name
                })
                if retval == true then
                    DB:renameStem(data.stemName, newval)
                end
                if retval ~= nil then
                    Gui.popups.object = nil;
                    r.ImGui_CloseCurrentPopup(ctx)
                end -- could be true (ok) or false (cancel)
                App:setHoveredHint('main', 'Rename stem')
                if r.ImGui_Selectable(ctx, 'Add stem to render queue', false) then
                    App.stem_to_render = data.stemName;
                    App.forceRenderAction = RENDERACTION_RENDERQUEUE_OPEN;
                    App.coPerform = coroutine.create(doPerform)
                end
                App:setHoveredHint('main', "Add this stem only to the render queue")
                if r.ImGui_Selectable(ctx, 'Render stem now', false) then
                    App.stem_to_render = data.stemName
                    App.forceRenderAction = RENDERACTION_RENDER
                    App.coPerform = coroutine.create(doPerform)
                end
                App:setHoveredHint('main', "Render this stem only")
                if r.ImGui_Selectable(ctx, ('Add group %s to queue'):format(data.renderSettingGroup), false) then
                    App.renderGroupToRender = data.renderSettingGroup
                    App.forceRenderAction = RENDERACTION_RENDERQUEUE_OPEN;
                    App.coPerform = coroutine.create(doPerform)
                end
                App:setHoveredHint('main',
                    ("Add all stems belonging to render group %s only to the render queue"):format(data
                        .renderSettingGroup))
                if r.ImGui_Selectable(ctx, ("Render group %s now"):format(data.renderSettingGroup), false) then
                    App.renderGroupToRender = data.renderSettingGroup
                    App.forceRenderAction = RENDERACTION_RENDER
                    App.coPerform = coroutine.create(doPerform)
                end
                App:setHoveredHint('main', ("Render all stems belonging render group %s"):format(data.renderSettingGroup))
                if r.ImGui_Selectable(ctx, 'Get states from tracks', false) then
                    DB:reflectAllTracksOnStem(data.stemName)
                end
                App:setHoveredHint('main', "Get current solo/mute states from the project's tracks.")
                if r.ImGui_Selectable(ctx, 'Set states on tracks', false) then
                    DB:reflectStemOnAllTracks(data.stemName)
                end
                App:setHoveredHint('main', "Set this stem's solo/mute states on the project's tracks.")
                if r.ImGui_Selectable(ctx, 'Clear states', false) then
                    DB:resetStem(data.stemName)
                end
                App:setHoveredHint('main', "Clear current stem solo/mute states.")
                r.ImGui_Separator(ctx)
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), Gui.st.col.critical)
                if r.ImGui_Selectable(ctx, 'Delete', false) then
                    DB:removeStem(data.stemName)
                end
                r.ImGui_PopStyleColor(ctx)
                App:setHoveredHint('main', 'Delete stem')
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
                Gui.popups.title = title
                local presetCount = 0
                for i, preset in pairs(DB.renderPresets) do
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

    function App:drawBtn(btnType, data)
        local ctx = self.gui.ctx
        local cellSize = Gui.st.vars.mtrx.cellSize
        local headerRowHeight = Gui.st.vars.mtrx.headerRowHeight
        local modKeys = Gui.modKeys
        local clicked = false
        if btnType == 'stemSync' then
            local stemSyncMode = data.stemSyncMode
            local generalSyncMode = data.generalSyncMode
            local isSyncing = ((stemSyncMode ~= SYNCMODE_OFF) and (stemSyncMode ~= nil))
            local displayedSyncMode = isSyncing and stemSyncMode or
                generalSyncMode -- if stem is syncing, show its mode, otherwise, show mode based on preferences+alt key
            local altSyncMode = (displayedSyncMode == SYNCMODE_SOLO) and SYNCMODE_SOLO or SYNCMODE_MIRROR
            local btnColor = isSyncing and Gui.st.col.stemSyncBtn[displayedSyncMode].active or
                Gui.st.col.stemSyncBtn[displayedSyncMode].inactive
            local circleColor = isSyncing and Gui.st.col.stemSyncBtn[displayedSyncMode].active[r.ImGui_Col_Text()] or
                Gui.st.col.stemSyncBtn[displayedSyncMode].active[r.ImGui_Col_Button()]
            local centerPosX, centerPosY = select(1, r.ImGui_GetCursorScreenPos(ctx)) + cellSize / 2,
                select(2, r.ImGui_GetCursorScreenPos(ctx)) + cellSize / 2
            r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) + 1)
            Gui:pushColors(btnColor)
            if r.ImGui_Button(ctx, " ", cellSize, cellSize) then
                clicked = true
            end
            if r.ImGui_IsItemHovered(ctx) then
                r.ImGui_SetMouseCursor(ctx, 7)
            end
            r.ImGui_DrawList_AddCircle(Gui.draw_list, centerPosX, centerPosY, 5, circleColor, 0, 2)
            Gui:popColors(btnColor)
            if isSyncing then
                App:setHoveredHint('main', ("Stem is mirrored (%s). Click to stop mirroring."):format(
                    SYNCMODE_DESCRIPTIONS[displayedSyncMode]))
            else
                if modKeys == 'a' then
                    App:setHoveredHint('main', ("%s+click to mirror stem (%s)."):format(
                        Gui.descModAlt:gsub("^%l", string.upper), SYNCMODE_DESCRIPTIONS[altSyncMode]))
                else
                    App:setHoveredHint('main',
                        ("Click to mirror stem (%s)."):format(SYNCMODE_DESCRIPTIONS[displayedSyncMode]))
                end
            end
        elseif btnType == 'stemActions' then
            local topLeftX, topLeftY = data.topLeftX, data.topLeftY
            local centerPosX, centerPosY = topLeftX + cellSize / 2, topLeftY + cellSize / 2
            local sz, radius = 4.5, 1.5
            local color = Gui.st.col.button[r.ImGui_Col_Text()]
            Gui:pushColors(Gui.st.col.button)
            if r.ImGui_Button(ctx, '##stemActions', cellSize, cellSize) then
                r.ImGui_OpenPopup(ctx, '##stemActions')
            end
            Gui:popColors(Gui.st.col.button)
            r.ImGui_DrawList_AddCircleFilled(Gui.draw_list, centerPosX - sz, centerPosY, radius, color, 8)
            r.ImGui_DrawList_AddCircleFilled(Gui.draw_list, centerPosX, centerPosY, radius, color, 8)
            r.ImGui_DrawList_AddCircleFilled(Gui.draw_list, centerPosX + sz, centerPosY, radius, color, 8)
            App:setHoveredHint('main', 'Stem actions')
        elseif btnType == 'addStem' then
            Gui:pushColors(Gui.st.col.button)
            r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) + 1)
            if r.ImGui_Button(ctx, '##addStem', cellSize, headerRowHeight) then
                clicked = true
            end
            Gui:popColors(Gui.st.col.button)
            local centerPosX = select(1, r.ImGui_GetCursorScreenPos(ctx)) + cellSize / 2
            local centerPosY = select(2, r.ImGui_GetCursorScreenPos(ctx)) - headerRowHeight / 2
            local color = Gui.st.col.button
                [r.ImGui_Col_Text()] -- gui.st.col.stemSyncBtn.active[r.ImGui_Col_Text()] or gui.st.col.stemSyncBtn.active[r.ImGui_Col_Button()]
            r.ImGui_DrawList_AddLine(Gui.draw_list, centerPosX - cellSize / 5, centerPosY, centerPosX + cellSize / 5,
                centerPosY, color, 2)
            r.ImGui_DrawList_AddLine(Gui.draw_list, centerPosX, centerPosY - cellSize / 5, centerPosX,
                centerPosY + cellSize / 5, color, 2)
            if modKeys ~= "c" then
                App:setHoveredHint('main', ('Click to create a new stem %s.'):format(
                    REFLECT_ON_ADD_DESCRIPTIONS[Settings.project.reflect_on_add]))
            else
                App:setHoveredHint('main',
                    ('%s+click to create a new stem %s.'):format(Gui.descModCtrlCmd:gsub("^%l", string.upper),
                        REFLECT_ON_ADD_DESCRIPTIONS[(Settings.project.reflect_on_add == REFLECT_ON_ADD_TRUE) and
                        REFLECT_ON_ADD_FALSE or REFLECT_ON_ADD_TRUE]))
            end
        elseif btnType == 'renderGroupSelector' then
            local stemName = data.stemName
            local stGrp = data.stGrp
            Gui:pushColors(Gui.st.col.render_setting_groups[stGrp])
            Gui:pushStyles(Gui.st.vars.mtrx.stemState)
            local origPosX, origPosY = r.ImGui_GetCursorPos(ctx)
            origPosY = origPosY + 1
            r.ImGui_SetCursorPosY(ctx, origPosY)
            local color = Gui.st.col.render_setting_groups[stGrp][r.ImGui_Col_Button()]
            local topLeftX, topLeftY = r.ImGui_GetCursorScreenPos(ctx)
            r.ImGui_DrawList_AddRectFilled(Gui.draw_list, topLeftX, topLeftY, topLeftX + cellSize, topLeftY + cellSize,
                color)
            r.ImGui_SetCursorPosY(ctx, origPosY)
            r.ImGui_Dummy(ctx, cellSize, cellSize)
            App:setHoveredHint('main',
                'Stem to be rendered by settings group ' .. stGrp .. '. Click arrows to change group.')
            if r.ImGui_IsItemHovered(ctx) then
                local description = Settings.project.render_setting_groups[stGrp].description
                if description ~= nil and description ~= '' then
                    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(),
                        Gui.st.col.render_setting_groups[stGrp][r.ImGui_Col_Button()])
                    r.ImGui_SetTooltip(ctx, description)
                    r.ImGui_PopStyleColor(ctx)
                end
                local centerX = r.ImGui_GetCursorScreenPos(ctx) + cellSize / 2
                local color = Gui.st.col.render_setting_groups[stGrp][r.ImGui_Col_Text()]
                local sz = 5
                r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) - cellSize)
                local startY = select(2, r.ImGui_GetCursorScreenPos(ctx))
                r.ImGui_Button(ctx, '###up' .. stemName, cellSize, cellSize / 3)
                if r.ImGui_IsItemClicked(ctx) then
                    DB.stems[stemName].render_setting_group = (stGrp == RENDER_SETTING_GROUPS_SLOTS) and 1 or stGrp + 1
                    DB:save()
                end
                if r.ImGui_IsItemHovered(ctx) then
                    r.ImGui_SetMouseCursor(ctx, 7)
                end
                r.ImGui_DrawList_AddTriangleFilled(Gui.draw_list, centerX, startY, centerX - sz * .5, startY + sz,
                    centerX + sz * .5, startY + sz, color)
                App:setHoveredHint('main', ('Change to setting group %d.'):format(
                    (stGrp == RENDER_SETTING_GROUPS_SLOTS) and 1 or stGrp + 1))
                sz = sz + 1
                r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) + cellSize / 3)
                local startY = select(2, r.ImGui_GetCursorScreenPos(ctx)) + cellSize / 3 - sz
                r.ImGui_Button(ctx, '###down' .. stemName, cellSize, cellSize / 3)
                if r.ImGui_IsItemClicked(ctx) then
                    DB.stems[stemName].render_setting_group = (stGrp == 1) and RENDER_SETTING_GROUPS_SLOTS or stGrp - 1
                    DB:save()
                end
                if r.ImGui_IsItemHovered(ctx) then
                    r.ImGui_SetMouseCursor(ctx, 7)
                end
                r.ImGui_DrawList_AddTriangleFilled(Gui.draw_list, centerX - sz * .5, startY, centerX + sz * .5, startY,
                    centerX, startY + sz, color)
                App:setHoveredHint('main', ('Change to setting group %d.'):format(
                    (stGrp == 1) and RENDER_SETTING_GROUPS_SLOTS or stGrp - 1))
            end
            local textSizeX, textSizeY = r.ImGui_CalcTextSize(ctx, tostring(stGrp))
            r.ImGui_SetCursorPos(ctx, origPosX + (cellSize - textSizeX) / 2, origPosY + (cellSize - textSizeY) / 2)
            r.ImGui_Text(ctx, stGrp)
            Gui:popColors(Gui.st.col.render_setting_groups[stGrp])
            Gui:popStyles(Gui.st.vars.mtrx.stemState)
        elseif btnType == 'stemState' then
            local state = data.state
            local track = data.track
            local stemName = data.stemName
            local stem = DB.stems[stemName]
            local color_state = ((state == ' ') and (stem.sync ~= SYNCMODE_OFF) and (stem.sync ~= nil)) and
                { 'sync_' .. stem.sync, 'sync_' .. stem.sync } or STATE_COLORS[state]
            local curScrPos = { r.ImGui_GetCursorScreenPos(ctx) }
            curScrPos[2] = curScrPos[2] + 1
            local text_size = { r.ImGui_CalcTextSize(ctx, STATE_LABELS[state]) }
            r.ImGui_SetCursorScreenPos(ctx, curScrPos[1], curScrPos[2])
            r.ImGui_Dummy(ctx, cellSize, cellSize)
            local col_a, col_b
            if r.ImGui_IsItemHovered(ctx, r.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem()) then
                col_a = Gui.st.col.stemState[color_state[1]][r.ImGui_Col_ButtonHovered()]
                col_b = Gui.st.col.stemState[color_state[2]][r.ImGui_Col_ButtonHovered()]
            else
                col_a = Gui.st.col.stemState[color_state[1]][r.ImGui_Col_Button()]
                col_b = Gui.st.col.stemState[color_state[2]][r.ImGui_Col_Button()]
            end
            r.ImGui_DrawList_AddRectFilled(Gui.draw_list, curScrPos[1], curScrPos[2], curScrPos[1] + cellSize / 2,
                curScrPos[2] + cellSize, col_a)
            r.ImGui_DrawList_AddRectFilled(Gui.draw_list, curScrPos[1] + cellSize / 2, curScrPos[2],
                curScrPos[1] + cellSize, curScrPos[2] + cellSize, col_b)
            r.ImGui_SetCursorScreenPos(ctx, curScrPos[1] + (cellSize - text_size[1]) / 2,
                curScrPos[2] + (cellSize - text_size[2]) / 2)
            r.ImGui_TextColored(ctx, Gui.st.col.stemState[color_state[1]][r.ImGui_Col_Text()], STATE_LABELS[state])
            r.ImGui_SetCursorScreenPos(ctx, curScrPos[1], curScrPos[2])
            r.ImGui_InvisibleButton(ctx, '##' .. track.name .. state .. stemName, cellSize, cellSize)
            if r.ImGui_IsItemHovered(ctx, r.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem()) then
                r.ImGui_SetMouseCursor(ctx, 7)
                local defaultSolo = DB.prefSoloIP and STATES.SOLO_IN_PLACE or STATES.SOLO_IGNORE_ROUTING
                local otherSolo = DB.prefSoloIP and STATES.SOLO_IGNORE_ROUTING or STATES.SOLO_IN_PLACE
                local defaultMSolo = DB.prefSoloIP and STATES.MUTE_SOLO_IN_PLACE or STATES.MUTE_SOLO_IGNORE_ROUTING
                local otherMSolo = DB.prefSoloIP and STATES.MUTE_SOLO_IGNORE_ROUTING or STATES.MUTE_SOLO_IN_PLACE
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
                            Gui.descModCtrlCmd:gsub("^%l", string.upper), (state == otherSolo) and 'clear' or
                            STATE_DESCRIPTIONS[otherSolo][1])
                    },
                    ['sa'] = {
                        state = defaultMSolo,
                        hint = ('%sShift+%s+click to %s.'):format(currentStateDesc, Gui.descModAlt, (state ==
                            defaultMSolo) and 'clear' or STATE_DESCRIPTIONS[defaultMSolo][1])
                    },
                    ['sc'] = {
                        state = otherMSolo,
                        hint = ('%sShift+%s+click to %s.'):format(currentStateDesc, Gui.descModCtrlCmd, (state ==
                            otherMSolo) and 'clear' or STATE_DESCRIPTIONS[otherMSolo][1])
                    },
                    ['a'] = {
                        state = ' ',
                        hint = ('%s%s'):format(currentStateDesc,
                            ('%s+click to clear.'):format(Gui.descModAlt:gsub("^%l", string.upper)))
                    }
                }
                if stateSwitches[modKeys] then
                    App:setHint('main', stateSwitches[modKeys].hint)
                    if Gui.mtrxTbl.drgState == nil and r.ImGui_IsMouseClicked(ctx, r.ImGui_MouseButton_Left()) then
                        Gui.mtrxTbl.drgState = (state == stateSwitches[modKeys]['state']) and ' ' or
                            stateSwitches[modKeys]['state']
                    elseif Gui.mtrxTbl.drgState and Gui.mtrxTbl.drgState ~= state then
                        DB:setTrackStateInStem(track, stemName, Gui.mtrxTbl.drgState)
                    end
                end
            end
        end
        return clicked
    end

    function updateActionStatuses(actionList)
        local content = OD_GetContent(r.GetResourcePath() .. "/" .. "reaper-kb.ini")
        local statuses = {}
        for k, v in pairs(actionList) do
            for i in ipairs(v.actions) do
                local action_name = 'Custom: ' .. Scr.no_ext .. ' - ' .. actionList[k].actions[i].title .. '.lua'
                actionList[k].actions[i].exists = (content:find(OD_EscapePattern(action_name)) ~= nil)
            end
        end
    end

    function App.drawLoadChoice()
        local ctx = Gui.ctx
        r.ImGui_OpenPopup(Gui.ctx, Scr.name .. '##loadStems')
        local msg = "Load settings and stems (removing current stems)\nor load settings only (keeping current stems)?"
        local ok = App:drawPopup(Gui.ctx, 'msg', Scr.name .. '##loadStems', {
            msg = msg,
            showCancelButton = true,
            okButtonLabel = "Settings and Stems",
            cancelButtonLabel = "Settings Only"
        })
        if ok then
            DB:loadPreset(App.load_preset_filename, true)
            App.load_preset_filename = nil
        elseif ok == false then
            DB:loadPreset(App.load_preset_filename, false)
            App.load_preset_filename = nil
        end
    end

    function App.drawCreateActionWindow()
        local ctx = Gui.ctx
        local bottom_lines = 1
        local x, y = r.ImGui_GetMousePos(ctx)
        local _, paddingY = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding())

        local center = { Gui.mainWindow.pos[1] + Gui.mainWindow.size[1] / 2,
            Gui.mainWindow.pos[2] + Gui.mainWindow.size[2] / 2 } -- {r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
        local halfWidth = 200
        r.ImGui_SetNextWindowSize(ctx, halfWidth * 3, 700, r.ImGui_Cond_Appearing())
        r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
        local visible, open = r.ImGui_Begin(ctx, 'Create Actions', true)
        local appearing = false
        if Gui.caWnd.old_visible ~= visible then
            appearing = visible
            Gui.caWnd.old_visible = visible
        end
        if visible then
            if r.ImGui_IsWindowAppearing(ctx) or appearing then
                appearing = false
                Gui.caWnd.actionList = {}
                Gui.caWnd.actionList['General Actions'] = {
                    order = 1,
                    actions = {}
                }
                Gui.caWnd.actionList['Render Group Actions'] = {
                    order = 2,
                    actions = {}
                }
                Gui.caWnd.actionList['Stem Render Actions'] = {
                    order = 3,
                    actions = {}
                }
                Gui.caWnd.actionList['Stem Toggle Actions'] = {
                    order = 4,
                    actions = {}
                }
                Gui.caWnd.actionList['General Actions'].actions = { {
                    title = 'Render all stems now',
                    command = 'render_all'
                }, {
                    title = 'Add all stems to render queue',
                    command = 'add_all'
                } }
                for k, v in OD_PairsByOrder(DB.stems) do
                    table.insert(Gui.caWnd.actionList['Stem Toggle Actions'].actions, {
                        title = ("Toggle '%s' mirroring"):format(k),
                        command = ("sync %s"):format(k)
                    })
                end
                for k, v in OD_PairsByOrder(DB.stems) do
                    table.insert(Gui.caWnd.actionList['Stem Render Actions'].actions, {
                        title = ("Render '%s' now"):format(k),
                        command = ("render %s"):format(k)
                    })
                end
                for k, v in OD_PairsByOrder(DB.stems) do
                    table.insert(Gui.caWnd.actionList['Stem Render Actions'].actions, {
                        title = ("Add '%s' to render queue"):format(k),
                        command = ("add %s"):format(k)
                    })
                end
                for i = 1, RENDER_SETTING_GROUPS_SLOTS do
                    table.insert(Gui.caWnd.actionList['Render Group Actions'].actions, {
                        title = ("Render group %d now"):format(i),
                        command = ("render_rg %d"):format(i)
                    })
                end
                for i = 1, RENDER_SETTING_GROUPS_SLOTS do
                    table.insert(Gui.caWnd.actionList['Render Group Actions'].actions, {
                        title = ("Add render group %d to render queue"):format(i),
                        command = ("add_rg %d"):format(i)
                    })
                end
                updateActionStatuses(Gui.caWnd.actionList)
            end

            r.ImGui_TextWrapped(ctx,
                "Custom actions allow triggering the stem manager directly from within REAPER's action list.")
            r.ImGui_TextWrapped(ctx,
                "After clicking 'Create', a new custom action for triggering the relevant action will be added to the action list.")

            local childHeight = select(2, r.ImGui_GetContentRegionAvail(ctx)) - r.ImGui_GetFrameHeightWithSpacing(ctx) -
                paddingY
            if r.ImGui_BeginChild(ctx, '##ActionList', 0, childHeight) then
                for k, actionList in OD_PairsByOrder(Gui.caWnd.actionList) do
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
                                updateActionStatuses(Gui.caWnd.actionList)
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
                App.show_action_window = false
            end

            r.ImGui_End(ctx)
        end
        if not open then
            App.show_action_window = false
        end
    end

    function App.drawHelp()
        local ctx = Gui.ctx
        local bottom_lines = 2
        local x, y = r.ImGui_GetMousePos(ctx)
        local center = { Gui.mainWindow.pos[1] + Gui.mainWindow.size[1] / 2,
            Gui.mainWindow.pos[2] + Gui.mainWindow.size[2] / 2 } -- {r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
        r.ImGui_SetNextWindowSize(ctx, 800, 700, r.ImGui_Cond_Appearing())
        r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
        local visible, open = r.ImGui_Begin(ctx, 'Help', true)
        if visible then
            local help = ([[
|Introduction
$script was designed with the goal of simplifying the process of stem creation with reaper.

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
                script = Scr.name,
                default_solo_state = STATE_DESCRIPTIONS[DB.prefSoloIP and STATES.SOLO_IN_PLACE or
                STATES.SOLO_IGNORE_ROUTING][1],
                other_solo_state = STATE_DESCRIPTIONS[DB.prefSoloIP and STATES.SOLO_IGNORE_ROUTING or
                STATES.SOLO_IN_PLACE][1],
                mute_state = STATE_DESCRIPTIONS[STATES.MUTE][1],
                default_mute_solo_state = STATE_DESCRIPTIONS[DB.prefSoloIP and STATES.MUTE_SOLO_IN_PLACE or
                STATES.MUTE_SOLO_IGNORE_ROUTING][1],
                other_mute_solo_state = STATE_DESCRIPTIONS[DB.prefSoloIP and STATES.MUTE_SOLO_IGNORE_ROUTING or
                STATES.MUTE_SOLO_IN_PLACE][1],
                Mod_ctrlcmd = Gui.descModCtrlCmd:gsub("^%l", string.upper),
                mod_ctrlcmd = Gui.descModCtrlCmd:gsub("^%l", string.upper),
                mod_alt = Gui.descModAlt,
                Mod_alt = Gui.descModAlt:gsub("^%l", string.upper),
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
            Gui:pushColors(Gui.st.col.render_setting_groups[3])
            if r.ImGui_SmallButton(ctx, 'donations') then
                if r.APIExists('CF_ShellExecute') then
                    r.CF_ShellExecute(Scr.donation)
                else
                    local command
                    if OS_is.mac then
                        command = 'open "%s"'
                    elseif OS_is.win then
                        command = 'start "URL" /B "%s"'
                    elseif OS_is.lin then
                        command = 'xdg-open "%s"'
                    end
                    if command then
                        os.execute(command:format(Scr.donation))
                    end
                end
            end
            Gui:popColors(Gui.st.col.render_setting_groups[1])
            r.ImGui_SameLine(ctx)
            r.ImGui_Text(ctx, 'will be very much appreciated ;-)')
            if r.ImGui_Button(ctx, "Close") or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
                App.show_help = false
            end
            r.ImGui_End(ctx)
        end
        if not open then
            App.show_help = false
        end
    end

    function msg(msg, title, ctx)
        local ctx = ctx or Gui.ctx
        local title = title or Scr.name
        r.ImGui_OpenPopup(Gui.ctx, title .. "##msg")
        return App:drawPopup(Gui.ctx, 'msg', title .. "##msg", {
            msg = msg
        })
    end

    function App.drawBottom(ctx, bottom_lines)
        r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) -
            (r.ImGui_GetFrameHeightWithSpacing(ctx) * bottom_lines +
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) * 2))
        local status, col = App:getStatus('main')
        if col then
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), Gui.st.col[col])
        end
        r.ImGui_Spacing(ctx)
        r.ImGui_Text(ctx, status)
        App:setHint('main', '')
        r.ImGui_Spacing(ctx)
        if col then
            r.ImGui_PopStyleColor(ctx)
        end
        if not App.coPerform then
            if r.ImGui_Button(ctx, RENDERACTION_DESCRIPTIONS[Settings.project.renderaction]:gsub("^%l", string.upper),
                    r.ImGui_GetContentRegionAvail(ctx)) then
                App.forceRenderAction = nil
                App.coPerform = coroutine.create(doPerform)
            end
        else
            r.ImGui_ProgressBar(ctx, (App.perform.pos or 0) / (App.perform.total or 1),
                r.ImGui_GetContentRegionAvail(ctx))
        end
    end

    function App.drawMainWindow()
        local ctx = Gui.ctx
        r.ImGui_SetNextWindowSize(ctx, 700,
            math.min(1000, select(2, r.ImGui_Viewport_GetSize(r.ImGui_GetMainViewport(ctx)))), r.ImGui_Cond_Appearing())
        r.ImGui_SetNextWindowPos(ctx, 100, 100, r.ImGui_Cond_FirstUseEver())
        local visible, open = r.ImGui_Begin(ctx,
            Scr.name .. ' v' .. Scr.version .. " by " .. Scr.developer .. "##mainWindow", true,
            r.ImGui_WindowFlags_MenuBar())
        Gui.mainWindow = {
            pos = { r.ImGui_GetWindowPos(ctx) },
            size = { r.ImGui_GetWindowSize(ctx) }
        }
        DB:sync()
        if visible then
            local bottom_lines = 2
            local rv2
            if r.ImGui_BeginMenuBar(ctx) then
                -- r.ImGui_SetCursorPosX(ctx, r.ImGui_GetContentRegionAvail(ctx)- r.ImGui_CalcTextSize(ctx,'Settings'))

                if r.ImGui_BeginMenu(ctx, 'Presets') then
                    -- rv,show_app.main_menu_bar =
                    --   ImGui.MenuItem(ctx, 'Main menu bar', nil, show_app.main_menu_bar)
                    if r.ImGui_MenuItem(ctx, 'Save...', nil, nil) then
                        local rv, fileName = reaper.JS_Dialog_BrowseForSaveFile('Select Preset File', Scr.presetFolder,
                            '',
                            'Preset files (*.smpreset)\0*.smpreset\0\0')
                        if rv and fileName then
                            DB:savePreset(fileName)
                        end
                    end
                    App:setHoveredHint('main', "Save current stems and settings")

                    if r.ImGui_MenuItem(ctx, 'Load...', nil, nil) then
                        local rv, filename = r.GetUserFileNameForRead('', 'Select a stem preset file', 'smpreset')
                        if rv and filename then
                            App.load_preset_filename = filename
                        end
                    end
                    App:setHoveredHint('main', "Load stems and settings")
                    r.ImGui_EndMenu(ctx)
                end

                if r.ImGui_MenuItem(ctx, 'Settings') then
                    App.show_settings_window = true --r.ImGui_OpenPopup(ctx, 'Settings')
                end
                r.ImGui_SameLine(ctx)
                if r.ImGui_MenuItem(ctx, 'Create Actions') then
                    App.show_action_window = not (App.show_action_window or false)
                end
                if r.ImGui_MenuItem(ctx, 'Help') then
                    App.show_help = not (App.show_help or false)
                end
                if App.show_settings_window then --r.ImGui_IsPopupOpen(ctx, 'Settings') then
                    App.drawSettings()
                end
                if App.show_help then
                    App.drawHelp()
                end
                if App.show_action_window then
                    App.drawCreateActionWindow()
                end
                if App.load_preset_filename ~= nil then
                    App.drawLoadChoice()
                end

                r.ImGui_EndMenuBar(ctx)
            end
            if App.coPerform and coroutine.status(App.coPerform) == 'running' then
                r.ImGui_BeginDisabled(ctx)
            end
            App.drawMatrices(ctx, bottom_lines)
            if App.coPerform and coroutine.status(App.coPerform) == 'running' then
                r.ImGui_EndDisabled(ctx)
            end
            App.drawBottom(ctx, bottom_lines)
            r.ImGui_End(ctx)
        end
        return open
    end

    local function checkPerform()
        if App.coPerform then
            if coroutine.status(App.coPerform) == "suspended" then
                local rv
                rv, App.perform.status, App.perform.pos, App.perform.total =
                    coroutine.resume(App.coPerform, App.stem_to_render)
                if not rv then
                end
            elseif coroutine.status(App.coPerform) == "dead" then
                App.stem_to_render = nil
                App.renderGroupToRender = nil
                App.coPerform = nil
                if App.render_count > 0 then
                    if App.current_renderaction == RENDERACTION_RENDERQUEUE_OPEN then
                        r.Main_OnCommand(40929, 0)
                    elseif (App.current_renderaction == RENDERACTION_RENDERQUEUE_RUN) and (App.perform.fullRender) then
                        r.Main_OnCommand(41207, 0)
                    end
                end
                App.current_renderaction = nil
            end
        end
    end

    local function loop()
        r.DeleteExtState(Scr.ext_name, 'defer', false)
        checkPerform()
        r.ImGui_PushFont(Gui.ctx, Gui.st.fonts.default)
        App.open = App.drawMainWindow()
        r.ImGui_PopFont(Gui.ctx)
        checkExternalCommand()
        if App.open then
            r.SetExtState(Scr.ext_name, 'defer', '1', false)
            r.defer(loop)
        else
            r.ImGui_DestroyContext(Gui.ctx)
        end
    end

    
    LoadSettings()
    UpdateSettings() -- fix format of actions saved pre v1.1.0
    r.defer(loop)
end
