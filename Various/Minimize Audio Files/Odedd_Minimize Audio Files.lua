-- @description Minimize Audio Files
-- @author Oded Davidov
-- @version 0.0.1
-- @donation: https://paypal.me/odedda
-- @license GNU GPL v3
-- @provides
--   [nomain] ../../Resources/Common/*
--   [nomain] lib/*
---------------------------------------
-- SETUP ------------------------------
---------------------------------------
r = reaper

local p = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]
dofile(p .. '../../Resources/Common/Common.lua')

r.ClearConsole()

scr, os_is = OD_Init()

dofile(p .. 'lib/Settings.lua')
dofile(p .. 'lib/Minimize.lua')
dofile(p .. 'lib/Gui.lua')
dofile(p .. 'lib/App.lua')

gui.tables = {
    horizontal = {
        flags1 = r.ImGui_TableFlags_NoSavedSettings() | r.ImGui_TableFlags_ScrollX() | r.ImGui_TableFlags_ScrollY() |
            r.ImGui_TableFlags_BordersOuter() | r.ImGui_TableFlags_Borders() | r.ImGui_TableFlags_Resizable() |
            r.ImGui_TableFlags_NoHostExtendX() | r.ImGui_TableFlags_SizingFixedFit()
    }
}

gui.st.col.item = 0x333333ff;
gui.st.col.item_keep = 0x2a783fff;
gui.st.col.item_delete = 0x852f29ff;
gui.st.col.item_ignore = 0x852f29ff;

gui.st.col.status = {
    [STATUS.IGNORE] = 0x333333ff,
    [STATUS.SCANNED] = nil,
    [STATUS.MINIMIZING] = 0x703d19ff,
    [STATUS.MINIMIZED] = 0xb06027ff,
    [STATUS.MOVING] = 0xa67e23ff,
    [STATUS.COPYING] = 0xa67e23ff,
    [STATUS.DELETING] = 0xa67e23ff,
    [STATUS.MOVING_TO_TRASH] = 0xa67e23ff,
    [STATUS.COLLECTING] = 0xa67e23ff,
    [STATUS.COLLECTED] = 0x6b23a6ff,
    [STATUS.DONE] = 0x2a783fff,
    [STATUS.ERROR] = 0x852f29ff
}

---------------------------------------
-- Functions --------------------------
---------------------------------------

local function doPerform()
    if CheckSettings() then
        -- first save the project in its current form
        r.Main_SaveProject(-1)
        -- set global project path in app variable
        SetProjPaths()
        -- save stuff to restore in any case
        PrepareRestore()
        -- save suff to restore in case of error/cancel or if creating a backup
        PrepareRevert()
        -- since changes will be made during the process, we don't want the project accidentally saved
        DisableAutosave()
        -- set glue quality
        SetQuality()
        -- get information on all takes, separated by media source file
        GetMediaFiles()
        -- if sources are networked, trashing may not be an option.
        if (not settings.backup) and (settings.deleteOperation == DELETE_OPERATION.MOVE_TO_TRASH) and
            (NetworkedFilesExist()) then
            cancel(
                'Networked files were found.\nMoving networkd files to the\ntrash is not supported.\nPlease select deleting files\nor consider backing up instead of\nminimizing.')
        else
            -- minimize files and apply to original sources
            MinimizeAndApplyMedia()
            CollectMedia()
            -- if OD_BwCheck(settings.collect, COLLECT.RS5K) then
            --     collectRS5KSamples()
            -- end

            if settings.backup then
                -- copy to a new project path (move glued files, copy others)
                CreateBackupProject()
                -- revert back to temporary copy of project
                Revert()
            else
                DeleteOriginals()
                -- finish building peaks for new files
                FinalizePeaksBuild()
            end
            -- restore settings and other stuff saved at the beginning of the process
            Restore()
            coroutine.yield('Done', 0, 1)
        end
    end

    return
end

local function checkPerform()
    if app.coPerform then
        if coroutine.status(app.coPerform) == "suspended" then
            retval, app.perform.status = coroutine.resume(app.coPerform)
            if not retval then
                if app.perform.status:sub(-17) == 'cancelled by glue' then
                    cancel()
                else
                    -- r.ShowConsoleMsg(app.perform.status)
                    cancel(('Error occured:\n%s'):format(app.perform.status))
                end
            end
        elseif coroutine.status(app.coPerform) == "dead" then
            app.coPerform = nil
        end
    end
end

---------------------------------------
-- UI ---------------------------------
---------------------------------------

function app.drawPerform(open)
    local ctx = gui.ctx
    local bottom_lines = 2
    local overview_width = 200
    local line_height = r.ImGui_GetTextLineHeight(ctx)

    if open then
        local childHeight = select(2, r.ImGui_GetContentRegionAvail(ctx)) -
            (r.ImGui_GetFrameHeightWithSpacing(ctx) * bottom_lines +
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) * 2)
        if r.ImGui_BeginChild(ctx, 'mediaFiles', 0, childHeight) then
            if r.ImGui_BeginTable(ctx, 'table_scrollx', 9, gui.tables.horizontal.flags1) then
                local parent_open, depth, open_depth = true, 0, 0
                r.ImGui_TableSetupColumn(ctx, 'File', r.ImGui_TableColumnFlags_NoHide(), 250) -- Make the first column not hideable to match our use of TableSetupScrollFreeze()
                r.ImGui_TableSetupColumn(ctx, '#', nil, 30)
                r.ImGui_TableSetupColumn(ctx, 'Overview', nil, overview_width)
                r.ImGui_TableSetupColumn(ctx, 'Keep\nLength', nil, 45)
                r.ImGui_TableSetupColumn(ctx, 'Orig', nil, 65)
                r.ImGui_TableSetupColumn(ctx, 'New', nil, 65)
                r.ImGui_TableSetupColumn(ctx, 'Keep\nSize', nil, 45)
                r.ImGui_TableSetupColumn(ctx, 'Status', nil, 180)
                r.ImGui_TableSetupColumn(ctx, 'Full Path', nil, 150)
                r.ImGui_TableSetupScrollFreeze(ctx, 1, 1)

                r.ImGui_TableHeadersRow(ctx)
                for filename, fileInfo in OD_PairsByOrder(app.mediaFiles) do
                    r.ImGui_TableNextRow(ctx)
                    r.ImGui_TableNextColumn(ctx) -- file
                    r.ImGui_Text(ctx, fileInfo.basename .. (fileInfo.ext and ('.' .. fileInfo.ext) or ''))
                    local skiprow = false
                    if not r.ImGui_IsItemVisible(ctx) then
                        skiprow = true
                    end
                    if not skiprow then
                        r.ImGui_TableNextColumn(ctx) -- takes
                        r.ImGui_Text(ctx, #fileInfo.occurrences)
                        r.ImGui_TableNextColumn(ctx) -- status
                        local curScrPos = { r.ImGui_GetCursorScreenPos(ctx) }
                        curScrPos[2] = curScrPos[2] + 1

                        overview_width = r.ImGui_GetContentRegionAvail(ctx)
                        r.ImGui_DrawList_AddRectFilled(gui.draw_list, curScrPos[1], curScrPos[2],
                            curScrPos[1] + overview_width, curScrPos[2] + line_height - 1, (fileInfo.status >=
                                STATUS.MINIMIZED or #(fileInfo.sections or {}) > 0) and gui.st.col.item_keep or
                            gui.st.col.item)

                        for i, sect in OD_PairsByOrder(fileInfo.sections or {}) do
                            r.ImGui_DrawList_AddRectFilled(gui.draw_list, curScrPos[1] + overview_width * sect.from,
                                curScrPos[2], curScrPos[1] + overview_width * sect.to, curScrPos[2] + line_height - 1,
                                gui.st.col.item_delete)
                        end
                        -- r.ImGui_ProgressBar(ctx, 0,nil, nil,string.format("%.2f", fileInfo.srclen))
                        r.ImGui_TableNextColumn(ctx) -- keep length
                        r.ImGui_Text(ctx, string.format("%.f %%", fileInfo.keep_length * 100))
                        r.ImGui_TableNextColumn(ctx) -- orig. size
                        r.ImGui_Text(ctx, OD_GetFormattedFileSize(fileInfo.sourceFileSize))
                        r.ImGui_TableNextColumn(ctx) -- new size
                        r.ImGui_Text(ctx, OD_GetFormattedFileSize(fileInfo.newFileSize))
                        r.ImGui_TableNextColumn(ctx) -- keep size
                        if fileInfo.newFileSize and fileInfo.sourceFileSize then
                            r.ImGui_Text(ctx,
                                string.format("%.f %%", fileInfo.newFileSize / fileInfo.sourceFileSize * 100))
                        end
                        r.ImGui_TableNextColumn(ctx) -- status
                        if gui.st.col.status[fileInfo.status] then
                            r.ImGui_TableSetBgColor(ctx, r.ImGui_TableBgTarget_CellBg(),
                                gui.st.col.status[fileInfo.status])
                        end
                        r.ImGui_Text(ctx, STATUS_DESCRIPTIONS[fileInfo.status] ..
                            (fileInfo.status_info ~= '' and (' (%s)'):format(fileInfo.status_info) or ''))
                        r.ImGui_TableNextColumn(ctx) -- folder
                        local path = (fileInfo.relOrAbsPath):gsub(
                            OD_EscapePattern((fileInfo.basename) .. (fileInfo.ext and ('.' .. fileInfo.ext) or '') .. '$'),
                            '')
                        r.ImGui_Text(ctx, path)
                    end
                end
                r.ImGui_EndTable(ctx)
            end
            r.ImGui_EndChild(ctx)
        end
    end
end

function app.drawWarning()
    local ctx = gui.ctx
    local center = { gui.mainWindow.pos[1] + gui.mainWindow.size[1] / 2,
        gui.mainWindow.pos[2] + gui.mainWindow.size[2] / 2 }            -- {r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
    local text = [[
You have selected not to backup to a new folder.

This means that all* the audio source files will be
DELETED and new "minimized" versions of them will be
created instead.

This will make any other RPP that uses the original
files UNUSABLE!

The only project that will work with those new files
is this one.

Since files are deleted - this cannot be undone!

Please think about it carefully before continuing.


*Audio files outside of the project's media folder
 will not be deleted.
]]
    local okButtonLabel = 'OK'
    local okButtonLabel = app.popup.secondWarningShown and 'Come on already let\'s do it!' or 'OK'
    local cancelButtonLabel = 'Cancel'
    local okPressed = false
    local cancelPressed = false
    local bottom_lines = 1

    local textWidth, textHeight = r.ImGui_CalcTextSize(ctx, text)

    r.ImGui_SetNextWindowSize(ctx,
        math.max(220, textWidth) + r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()) * 4,
        textHeight + 90 + r.ImGui_GetTextLineHeightWithSpacing(ctx))

    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowTitleAlign(), 0.5, 0.5)
    if r.ImGui_BeginPopupModal(ctx, 'Are you sure?', nil,
            r.ImGui_WindowFlags_NoResize() + r.ImGui_WindowFlags_NoDocking()) then
        local width = select(1, r.ImGui_GetContentRegionAvail(ctx))
        r.ImGui_PushItemWidth(ctx, width)

        local windowWidth, windowHeight = r.ImGui_GetWindowSize(ctx);
        r.ImGui_SetCursorPos(ctx, (windowWidth - textWidth) * .5, (windowHeight - textHeight) * .5);
        r.ImGui_TextWrapped(ctx, text)

        r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeight(ctx) * bottom_lines) -
            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()))

        local buttonTextWidth = r.ImGui_CalcTextSize(ctx, okButtonLabel) +
            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2

        buttonTextWidth = buttonTextWidth + r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) +
            r.ImGui_CalcTextSize(ctx, cancelButtonLabel) +
            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2
        r.ImGui_SetCursorPosX(ctx, (windowWidth - buttonTextWidth) * .5);

        if r.ImGui_Button(ctx, okButtonLabel) then
            if settings.showMinimizeDoubleWarning and not app.popup.secondWarningShown then
                r.ImGui_OpenPopup(ctx, 'Also...')
            else
                app.popup.secondWarningShown = false
                okPressed = true
                r.ImGui_CloseCurrentPopup(ctx)
            end
        end

        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, cancelButtonLabel) then
            app.popup.secondWarningShown = false
            okPressed = false
            cancelPressed = true
            r.ImGui_CloseCurrentPopup(ctx)
        end

        local secondWarningText = [[
This script is not even at version 1.0!
Are you crazy?!

While I'm pretty damn sure everything works
you should still probably make sure to have
a backup of this project and all of its
media files, until you're certain that
this script did its job correctly.

I'm not taking responsibility in case
anything goes wrong.

Which reminds me - please let me know at the
Reaper forums if anything does go wrong so
I can fix it.



But everything wil probably be ok :)

]]
        local buttonLabel = 'Got it'
        local textWidth, textHeight = r.ImGui_CalcTextSize(ctx, secondWarningText)
        r.ImGui_SetNextWindowSize(ctx, math.max(220, textWidth) +
            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()) * 4,
            textHeight + 90 + r.ImGui_GetTextLineHeightWithSpacing(ctx) * 2)

        r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)

        if r.ImGui_BeginPopupModal(ctx, 'Also...', nil, r.ImGui_WindowFlags_NoResize() + r.ImGui_WindowFlags_NoDocking()) then
            app.popup.secondWarningShown = true

            local width = select(1, r.ImGui_GetContentRegionAvail(ctx))
            r.ImGui_PushItemWidth(ctx, width)

            local windowWidth, windowHeight = r.ImGui_GetWindowSize(ctx);
            r.ImGui_SetCursorPos(ctx, (windowWidth - textWidth) * .5, (windowHeight - textHeight) * .5);

            if r.ImGui_BeginChild(ctx, 'msgBody', 0,
                    select(2, r.ImGui_GetContentRegionAvail(ctx)) - (r.ImGui_GetFrameHeight(ctx) * bottom_lines) -
                    r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding())) then
                r.ImGui_TextWrapped(ctx, secondWarningText)
                local _, hideThis =
                    r.ImGui_Checkbox(ctx, "Dont show this again", not settings.showMinimizeDoubleWarning)
                settings.showMinimizeDoubleWarning = not hideThis
                r.ImGui_EndChild(ctx)
            end
            -- r.ImGui_TextWrapped(ctx, secondWarningText)

            r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeight(ctx) * bottom_lines) -
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()))
            local buttonTextWidth = r.ImGui_CalcTextSize(ctx, buttonLabel) +
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2
            r.ImGui_SetCursorPosX(ctx, (windowWidth - buttonTextWidth) * .5);

            if r.ImGui_Button(ctx, 'Got it') then
                saveSettings()
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndPopup(ctx)
        end

        r.ImGui_EndPopup(ctx)
    end
    r.ImGui_PopStyleVar(ctx)
    if okPressed then
        app.coPerform = coroutine.create(doPerform)
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
        if r.ImGui_Button(ctx, settings.backup and 'Create Backup' or 'Minimize Current Project',
                r.ImGui_GetContentRegionAvail(ctx)) then
            -- don't save backupDestination into saved preferences, but save all other settings
            local tmpDest = settings.backupDestination
            settings.backupDestination = nil
            saveSettings()
            settings.backupDestination = tmpDest

            local ok, errors = CheckSettings()
            if not ok then
                app.msg(table.concat(errors, '\n------------\n'))
            else
                if not settings.backup then
                    r.ImGui_OpenPopup(ctx, 'Are you sure?')
                else
                    app.coPerform = coroutine.create(doPerform)
                end
            end
        end

        app.drawWarning()
    else
        local w, h = r.ImGui_GetContentRegionAvail(ctx)
        local btnWidth = 150
        r.ImGui_ProgressBar(ctx, (app.perform.pos or 0) / (app.perform.total or 1), w - 150, h,
            ("%s/%s"):format(app.perform.pos, app.perform.total))
        r.ImGui_SameLine(ctx)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0x444444ff)
        if r.ImGui_Button(ctx, 'Cancel', r.ImGui_GetContentRegionAvail(ctx)) then
            cancel()
        end
        r.ImGui_PopStyleColor(ctx)
    end
end

function app.drawMainWindow()
    local ctx = gui.ctx
    local max_w, max_h = r.ImGui_Viewport_GetSize(r.ImGui_GetMainViewport(ctx))

    -- r.ShowConsoleMsg(viewPortWidth)
    r.ImGui_SetNextWindowSize(ctx, math.min(1125, max_w), math.min(800, max_h), r.ImGui_Cond_Appearing())
    r.ImGui_SetNextWindowPos(ctx, 100, 100, r.ImGui_Cond_FirstUseEver())
    local visible, open = r.ImGui_Begin(ctx, scr.name .. ' v' .. scr.version .. "##mainWindow", not app.coPerform,
        r.ImGui_WindowFlags_NoDocking() | r.ImGui_WindowFlags_NoCollapse())
    gui.mainWindow = {
        pos = { r.ImGui_GetWindowPos(ctx) },
        size = { r.ImGui_GetWindowSize(ctx) }
    }

    if visible then
        local bottom_lines = 2
        local rv2
        -- if r.ImGui_BeginMenuBar(ctx) then
        --     -- r.ImGui_SetCursorPosX(ctx, r.ImGui_GetContentRegionAvail(ctx)- r.ImGui_CalcTextSize(ctx,'Settings'))
        --     r.ImGui_EndMenuBar(ctx)
        -- end
        if app.coPerform and coroutine.status(app.coPerform) == 'suspended' then
            r.ImGui_BeginDisabled(ctx)
        end

        r.ImGui_SeparatorText(ctx, 'Settings')

        settings.backup = gui.setting('checkbox', 'Backup to a new project',
            "Create backup project or minimize current project", settings.backup)
        if settings.backup then
            settings.backupDestination = gui.setting('folder', 'Destination', 'Select an empty folder',
                settings.backupDestination, {}, true)
        end

        settings.padding = gui.setting('dragdouble', 'padding (s)',
            "How much unused audio, in seconds, to leave before and after items start and end positions",
            settings.padding, {
                speed = 0.1,
                min = 0.0,
                max = 10.0,
                format = "%.1f"
            })
        if settings.padding < 0 then
            settings.padding = 0
        end

        settings.minimizeSourceTypes = gui.setting('combo', 'File types to minimize',
            "Minimizing compressed files, such as MP3s, will result in larger (!) \"minimized\" files, since those will be uncompressed WAV files",
            settings.minimizeSourceTypes, {
                list = MINIMIZE_SOURCE_TYPES_LIST
            })

        settings.glueFormat = gui.setting('combo', 'Minimized files format',
            "Lossless compression (FLAC and WAVPACK) will result in the smallest sizes without losing quality, but takes longer to create",
            settings.glueFormat, {
                list = GLUE_FORMATS_LIST
            })

        local tmpSetting
        if settings.backup then
            r.ImGui_BeginDisabled(ctx)
        end
        settings.deleteOperation = gui.setting('combo', 'After minimizing', "What should be done after minimizing",
            settings.deleteOperation, {
                list = DELETE_OPERATIONS_LIST
            })
        if settings.backup then
            app.temp.originalBackupValue = app.temp.originalBackupValue or
                OD_BfCheck(settings.collect, COLLECT.EXTERNAL)
            tmpSetting = {
                [COLLECT.EXTERNAL] = COLLECT_DESCRIPTIONS[COLLECT.EXTERNAL]
            }
            gui.bitwise_setting('checkbox', COLLECT.EXTERNAL, tmpSetting)
            r.ImGui_SameLine(ctx)
            r.ImGui_Text(ctx, ('Must %s when backing up'):format(COLLECT_DESCRIPTIONS[COLLECT.EXTERNAL].label):lower())
            COLLECT_DESCRIPTIONS[COLLECT.EXTERNAL] = nil
            -- settings.collect = OD_BwSet(settings.collect,COLLECT.EXTERNAL,true)
            r.ImGui_EndDisabled(ctx)
        end

        settings.collect = gui.bitwise_setting('checkbox', settings.collect, COLLECT_DESCRIPTIONS)

        if settings.backup then
            COLLECT_DESCRIPTIONS[COLLECT.EXTERNAL] = tmpSetting[COLLECT.EXTERNAL]
        end
        if app.coPerform and coroutine.status(app.coPerform) == 'suspended' then
            r.ImGui_EndDisabled(ctx)
        end

        r.ImGui_SeparatorText(ctx, 'Overview')

        app.drawPerform(true)
        app.drawBottom(ctx, bottom_lines)
        app.drawMsg(ctx, bottom_lines)
        r.ImGui_End(ctx)
    end
    return open
end

function app.loop()
    checkPerform()
    r.ImGui_PushFont(gui.ctx, gui.st.fonts.default)
    app.open = app.drawMainWindow()
    r.ImGui_PopFont(gui.ctx)
    -- checkExternalCommand()
    if app.open then
        r.defer(app.loop)
    else
        r.ImGui_DestroyContext(gui.ctx)
    end
end

---------------------------------------
-- START ------------------------------
---------------------------------------

if OD_PrereqsOK({
        reaimgui_version = '0.8',
        sws = true,       -- required for SNM_SetIntConfigVar - setting config vars (max file size limitation and autosave options)
        js_version = 1.310, -- required for JS_Dialog_BrowseForFolder
        reaper_version = 6.76 -- required for APPLYFX_FORMAT and OPENCOPY_CFGIDX
        -- scripts = {
        --     ['Mavriq Lua Batteris'] =  r.GetResourcePath() .."/Scripts/Mavriq ReaScript Repository/Various/Mavriq-Lua-Batteries/batteries_header.lua"
        -- }
    }) then
    loadSettings()
    -- app.coPerform = coroutine.create(doPerform)
    r.defer(app.loop)
end

---------------------------------------
-- IDEAS and TODOS --------------------
---------------------------------------

-- TODO collect rs5k samples
-- TODO handle subprojects (collect?)
-- TODO enable "Save project file references with relative pathnames" and reapply previous setting after
-- TODO keep selected takes only (unless item marked with "play all takes")
-- TODO show total savings and close script upon completion
-- TODO scan media folder for extra files at the end (make that a setting)
-- TODO verify minimization before deleting files
-- TODO check handling of missing files
-- TODO handle unsaved project
-- TODO handle empty project
-- TODO reset when switching projects
-- TODO (later): figure out section

-- check project has a folder:
--     local proj_name = r.GetProjectName( 0, '' )
--    if proj_name == '' then MB('Project has not any parent folder.', 'Collect RS5k samples into project folder', 0) return end
-- local spls_path = r.GetProjectPathEx( 0, '' )..'/RS5K samples/'

-- -- function by MPL
-- ---------------------------------------------------------------------
-- function IsRS5K(tr, fxnumber)
--     if not tr then
--         return
--     end
--     local rv, buf = r.TrackFX_GetFXName(tr, fxnumber, '')
--     if not rv then
--         return
--     end
--     local rv, buf = r.TrackFX_GetParamName(tr, fxnumber, 3, '')
--     if not rv or buf ~= 'Note range start' then
--         return
--     end
--     return true, tr, fxnumber
-- end
-- -- heavily based on funciton by MPL
-- ---------------------------------------------------------------------
-- function collectRS5KSamples()
--     local proj_name = r.GetProjectName(0, '')
--     local spls_path = r.GetProjectPathEx(0, '') .. '/RS5K samples/'
--     r.RecursiveCreateDirectory(spls_path, 0)
--     for i = 1, r.GetNumTracks(0) do
--         local tr = r.GetTrack(0, i - 1)
--         for fx = 1, r.TrackFX_GetCount(tr) do
--             if IsRS5K(tr, fx - 1) then
--                 local retval, file_src = r.TrackFX_GetNamedConfigParm(tr, fx - 1, 'FILE0')
--                 local _, file, ext = dissectFilename(file_src)
--                 local file_dest = spls_path .. file .. (ext and ('.' .. ext) or '')
--                 local rel_file_dest = 'RS5K samples/' .. file .. (ext and ('.' .. ext) or '')
--                 file_src = file_src:gsub('\\', '/')
--                 file_dest = file_dest:gsub('\\', '/')
--                 rel_file_dest = rel_file_dest:gsub('\\', '/')
--                 r.ShowConsoleMsg(file_src .. '\n')
--                 r.ShowConsoleMsg(rel_file_dest .. '\n')
--                 copyFile(file_src, file_dest)
--                 r.TrackFX_SetNamedConfigParm(tr, fx - 1, 'FILE0', rel_file_dest)
--             end
--         end
--     end
-- end
-- 