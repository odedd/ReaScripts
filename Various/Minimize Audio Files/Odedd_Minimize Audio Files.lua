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
    [STATUS.DONE] = 0x2a783fff,
    [STATUS.ERROR] = 0x852f29ff
}

---------------------------------------
-- Functions --------------------------
---------------------------------------

local function doPerform()
    if checkSettings() then
        -- first save the project in its current form
        reaper.Main_SaveProject(-1)
        -- set global project path in app variable
        setProjPaths()
        -- save stuff to restore in any case
        prepareRestore()
        -- save stuff to restore in case of error/cancel or if creating a backup
        prepareRevert()
        -- since changes will be made during the process, we don't want the project accidentally saved
        disableAutosave()
        -- set glue quality
        setQuality()
        -- get information on all takes, separated by media source file
        collectMediaFiles()
        -- minimize files and apply to original sources
        minimizeAndApplyMedia()

        if settings.backup then
            -- copy to a new project path (move glued files, copy others)
            createBackupProject()
            -- revert back to temporary copy of project
            revert()
        else
            deleteOriginals()
            -- finish building peaks for new files
            finalizePeaksBuild()
        end
        -- restore settings and other stuff saved at the beginning of the process
        restore()

        coroutine.yield('Done', 0, 1)
    end

    return
end

local function checkPerform()
    if app.coPerform then
        if coroutine.status(app.coPerform) == "suspended" then
            retval, app.perform.status = coroutine.resume(app.coPerform)
            if not retval then
                if app.perform.status:sub(-9) ~= 'cancelled' then
                    r.ShowConsoleMsg(app.perform.status)
                end
                cancel()
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
                for filename, fileInfo in pairsByOrder(app.mediaFiles) do
                    r.ImGui_TableNextRow(ctx)
                    r.ImGui_TableNextColumn(ctx) -- file
                    r.ImGui_Text(ctx, fileInfo.basename .. '.' .. fileInfo.ext)
                    local skiprow = false
                    if not r.ImGui_IsItemVisible(ctx) then
                        skiprow = true
                    end
                    if not skiprow then
                        r.ImGui_TableNextColumn(ctx) -- takes
                        r.ImGui_Text(ctx, #fileInfo.occurrences)
                        r.ImGui_TableNextColumn(ctx) -- status
                        local curScrPos = {r.ImGui_GetCursorScreenPos(ctx)}
                        curScrPos[2] = curScrPos[2] + 1

                        overview_width = r.ImGui_GetContentRegionAvail(ctx)
                        r.ImGui_DrawList_AddRectFilled(gui.draw_list, curScrPos[1], curScrPos[2],
                            curScrPos[1] + overview_width, curScrPos[2] + line_height - 1, (fileInfo.status >=
                                STATUS.MINIMIZED or #(fileInfo.sections or {}) > 0) and gui.st.col.item_keep or
                                gui.st.col.item)

                        for i, sect in pairsByOrder(fileInfo.sections or {}) do
                            r.ImGui_DrawList_AddRectFilled(gui.draw_list, curScrPos[1] + overview_width * sect.from,
                                curScrPos[2], curScrPos[1] + overview_width * sect.to, curScrPos[2] + line_height - 1,
                                gui.st.col.item_delete)
                        end
                        -- r.ImGui_ProgressBar(ctx, 0,nil, nil,string.format("%.2f", fileInfo.srclen))
                        r.ImGui_TableNextColumn(ctx) -- keep length
                        r.ImGui_Text(ctx, string.format("%.f %%", fileInfo.keep_length * 100))
                        r.ImGui_TableNextColumn(ctx) -- orig. size
                        r.ImGui_Text(ctx, getFormattedFileSize(fileInfo.sourceFileSize))
                        r.ImGui_TableNextColumn(ctx) -- new size
                        if fileInfo.newFileSize then
                            r.ImGui_Text(ctx, getFormattedFileSize(fileInfo.newFileSize))
                        end
                        r.ImGui_TableNextColumn(ctx) -- keep size
                        if fileInfo.newFileSize then
                            r.ImGui_Text(ctx, string.format("%.f %%", fileInfo.newFileSize/fileInfo.sourceFileSize * 100))
                        end
                        r.ImGui_TableNextColumn(ctx) -- status
                        if gui.st.col.status[fileInfo.status] then
                            reaper.ImGui_TableSetBgColor(ctx, reaper.ImGui_TableBgTarget_CellBg(),
                                gui.st.col.status[fileInfo.status])
                        end
                        r.ImGui_Text(ctx, STATUS_DESCRIPTIONS[fileInfo.status] ..
                            (fileInfo.status_info ~= '' and (' (%s)'):format(fileInfo.status_info) or ''))
                        r.ImGui_TableNextColumn(ctx) -- folder
                        local path = (fileInfo.relOrAbsPath):gsub(
                            escape_pattern((fileInfo.basename) .. '.' .. (fileInfo.ext)) .. '$', '')
                        r.ImGui_Text(ctx, path)
                    end
                end
                r.ImGui_EndTable(ctx)
            end
            r.ImGui_EndChild(ctx)
        end
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
            local ok, errors = checkSettings()
            if not ok then
                app.msg(table.concat(errors, '\n------------\n'))
            else
                app.coPerform = coroutine.create(doPerform)
            end
        end
    else
        local w, h = r.ImGui_GetContentRegionAvail(ctx)
        local btnWidth = 150
        r.ImGui_ProgressBar(ctx, (app.perform.pos or 0) / (app.perform.total or 1), w - 150, h,
            ("%s/%s"):format(app.perform.pos, app.perform.total))
        r.ImGui_SameLine(ctx)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x444444ff)
        if r.ImGui_Button(ctx, 'Cancel', r.ImGui_GetContentRegionAvail(ctx)) then
            cancel()
        end
        reaper.ImGui_PopStyleColor(ctx)

    end
end

function app.drawMainWindow()
    local ctx = gui.ctx
    local max_w, max_h = r.ImGui_Viewport_GetSize(r.ImGui_GetMainViewport(ctx))

    -- reaper.ShowConsoleMsg(viewPortWidth)
    r.ImGui_SetNextWindowSize(ctx, math.min(1125, max_w), math.min(800, max_h), r.ImGui_Cond_Appearing())
    r.ImGui_SetNextWindowPos(ctx, 100, 100, r.ImGui_Cond_FirstUseEver())
    local visible, open = r.ImGui_Begin(ctx, scr.name .. ' v' .. scr.version .. "##mainWindow", not app.coPerform,
        reaper.ImGui_WindowFlags_NoDocking() | reaper.ImGui_WindowFlags_NoCollapse())
    gui.mainWindow = {
        pos = {r.ImGui_GetWindowPos(ctx)},
        size = {r.ImGui_GetWindowSize(ctx)}
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

        if settings.backup then
            r.ImGui_BeginDisabled(ctx)
        end
        settings.deleteOperation = gui.setting('combo', 'After minimizing', "What should be done after minimizing",
            settings.deleteOperation, {
                list = DELETE_OPERATIONS_LIST
            })
        if settings.backup then
            r.ImGui_EndDisabled(ctx)
        end

        -- r.ImGui_SeparatorText(ctx, 'Collect Files')

        settings.collect = gui.bitwise_setting('checkbox', settings.collect, COLLECT_DESCRIPTIONS)

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
    sws = true, -- required for SNM_SetIntConfigVar - setting config vars (max file size limitation and autosave options)
    js_version = 1.310 -- required for JS_Dialog_BrowseForFolder
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

-- todo: warning on minimize only (not backup)
-- todo: figure out trash on windows
-- todo: collect external audio + video files + rs5k
-- todo: enable "Save project file references with relative pathnames" and reapply previous setting after
-- todo: keep selected takes only (unless item marked with "play all takes")
-- todo: reset when switching projects
-- todo: show total savings?
-- todo: rename items? probably not
-- todo: scan media folder at the end
-- todo (later): figure out section
