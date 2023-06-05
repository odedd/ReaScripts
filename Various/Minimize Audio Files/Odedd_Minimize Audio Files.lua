-- @description Minimize Audio Files
-- @author Oded Davidov
-- @version 0.0.1
-- @donation: https://paypal.me/odedda
-- @license GNU GPL v3
-- @provides
--   [nomain] ../../Resources/Common/*
--   [nomain] lib/*
-- todo (99% ok): figure out playrate (look at Script: X-Raym_Reset take playback rate from snap offset.eel)
-- todo: figure out section
-- todo: GUI
-- todo: cancel
-- todo: check if glue operation failed and stop
-- todo: backup to new project
-- todo: delete replaced files
-- todo: make sure to match glued file format / quality to original
-- todo: figure out MP3s
-- todo: figure out other sourceTypes (videos etc)
-- todo: figure out sampler files
-- todo: disable auto-save before backup operation and reapply previous setting after
-- todo: enable "Save project file references with relative pathnames" and reapply previous setting after
-- todo: keep selected takes only
-- requires sws to remove max file size limitation, as well as for sections
--    if r.GetPlayState()&4==4 then;
--        re aper.MB("Eng:\nYou shouldn't record when using this action.\n\n"..
--                  "Rus:\nВы не должны записывать при использовании этого действия"
--        ,"Oops",0);
--    else;
r = reaper

REAL = true

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

if OD_PrereqsOK({
    reaimgui_version = '0.8',
    sws = true,
    js_version = 1.310,
    -- scripts = {
    --     ['Mavriq Lua Batteris'] =  r.GetResourcePath() .."/Scripts/Mavriq ReaScript Repository/Various/Mavriq-Lua-Batteries/batteries_header.lua"
    -- }
}) then
    -- dofile(reaper.GetResourcePath() ..
            --    "/Scripts/Mavriq ReaScript Repository/Various/Mavriq-Lua-Batteries/batteries_header.lua")
    -- local lfs = require('lfs')
    -- lfs.rename()
    -- assert(false)
    local function doPerform()
        r.Undo_BeginBlock()
        if checkSettings() then
            app.showPerform = true
            local pos = r.GetCursorPosition()
            local projPath, projFileName, fullProjPath, projectRecordingPath, relProjectRecordingPath =
                getProjectPaths()
            local tmpBackupFileName = projPath .. select(2, dissectFilename(projFileName)) .. '_' ..
                                          reaper.time_precise() .. '.RPP'
            local saveopts = select(2, r.get_config_var_string('saveopts'))
            local tmpOpts = saveopts

            if settings.mainOperation == MAIN_OPERATION.BACKUP then

                if saveopts & 2 == 2 then
                    tmpOpts = tmpOpts - 2
                end -- Save to project -> off
                if saveopts & 4 == 4 then
                    tmpOpts = tmpOpts - 4
                end -- Save to timestamped file in project directory -> off
                if saveopts & 8 == 8 then
                    tmpOpts = tmpOpts - 8
                end -- Save to timestamped file in additional directory -> off
                -- restore saved saving options
                r.SNM_SetIntConfigVar('saveopts', tmpOpts)

                copyFile(fullProjPath, tmpBackupFileName)
                reaper.Main_SaveProject(-1)

            end

            -- then minimize without saving

            app.mediaFiles = {}
            collectMediaFiles()
            local peakOperations = copyItemsToNewTracks(mediaFiles)
            r.SetEditCurPos(pos, true, false)
            finalizePeaksBuild(peakOperations)

            r.Undo_EndBlock("Minimize Audio Files", 0)

            if settings.mainOperation == MAIN_OPERATION.BACKUP then

                reaper.Main_SaveProject(-1)

                local targetPath = settings.backupDestination .. '/'
                local targetProject = targetPath .. projFileName
                copyFile(fullProjPath, targetProject)
                app.perform.total = app.mediaFileCount
                app.perform.pos = 0
                for filename, filenameinfo in pairsByOrder(app.mediaFiles) do
                    -- move processed files
                    reaper.RecursiveCreateDirectory(targetPath .. relProjectRecordingPath, 0)
                    app.perform.pos = app.perform.pos + 1
                    coroutine.yield('Creating backup project')
                    if filenameinfo.ignore == false then
                        filenameinfo.status = STATUS.MOVING
                        -- reaper.ShowConsoleMsg(filenameinfo.newfilename..'\n')
                        local _, newFN, newExt = dissectFilename(filenameinfo.newfilename)
                        local target = targetPath .. relProjectRecordingPath .. '/' .. newFN .. '.' .. newExt

                        -- lfs.rename(filenameinfo.newfilename, target)
                        local success = os.rename(filenameinfo.newfilename, target)
                        -- if moving using rename failed, resort to copy + delete
                        if not success then 
                            success = copyFile(filenameinfo.newfilename, target)
                            if success then os.remove(filenameinfo.newfilename) end
                        end
                    else -- copy all other files, if in media folder
                        if filenameinfo.pathIsRelative then
                            filenameinfo.status = STATUS.COPYING
                            local target = targetPath .. filenameinfo.relOrAbsPath
                            -- reaper.ShowConsoleMsg(target)
                            
                            local success = copyFile(filenameinfo.filenameWithPath, target)
                        else
                            filenameinfo.status = STATUS.DONE
                        end
                    end
                    filenameinfo.status = STATUS.DONE
                    coroutine.yield('Creating backup project')
                end

                -- restore temporary file saved before minimizing
                copyFile(tmpBackupFileName, fullProjPath)

                r.Main_openProject(fullProjPath)
--                r.Main_openProject(targetProject)

                local success, error = os.remove(tmpBackupFileName)

                -- restore saved saving options
                r.SNM_SetIntConfigVar('saveopts', saveopts)
            end

            coroutine.yield('Done', 0, 1)
        end

        return
    end

    function checkPerform()
        if app.coPerform then
            if coroutine.status(app.coPerform) == "suspended" then

                -- coroutine.resume(app.coPerform)
                retval, app.perform.status = coroutine.resume(app.coPerform)
                if not retval then
                    r.ShowConsoleMsg(app.perform.status)
                end
            elseif coroutine.status(app.coPerform) == "dead" then
                app.coPerform = nil
            end
        end
    end

    function app.drawPerform(open)
        local ctx = gui.ctx
        local bottom_lines = 2
        local overview_width = 200
        local line_height = r.ImGui_GetTextLineHeight(ctx)

        -- r.ImGui_SetNextWindowSize(ctx, 700, math.min(1000, select(2, r.ImGui_Viewport_GetSize(
        --     r.ImGui_GetMainViewport(ctx)))), r.ImGui_Cond_Appearing())
        -- r.ImGui_SetNextWindowPos(ctx, 100, 100, r.ImGui_Cond_FirstUseEver())
        if open then
            local childHeight = select(2, r.ImGui_GetContentRegionAvail(ctx)) -
                                    (r.ImGui_GetFrameHeightWithSpacing(ctx) * bottom_lines +
                                        r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) * 2)
            -- if r.ImGui_CollapsingHeader(ctx,"Stem Selection",false,r.ImGui_TreeNodeFlags_DefaultOpen()) then
            if r.ImGui_BeginChild(ctx, 'mediaFiles', 0, childHeight) then
                if r.ImGui_BeginTable(ctx, 'table_scrollx', 6, gui.tables.horizontal.flags1) then
                    --- SETUP MATRIX TABLE
                    local parent_open, depth, open_depth = true, 0, 0
                    r.ImGui_TableSetupColumn(ctx, 'File', r.ImGui_TableColumnFlags_NoHide(), 250) -- Make the first column not hideable to match our use of TableSetupScrollFreeze()
                    r.ImGui_TableSetupColumn(ctx, '#', nil, 30)
                    r.ImGui_TableSetupColumn(ctx, 'Overview', nil, overview_width)
                    r.ImGui_TableSetupColumn(ctx, 'Keep', nil, 45)
                    r.ImGui_TableSetupColumn(ctx, 'Status', nil, 180)
                    r.ImGui_TableSetupColumn(ctx, 'Folder', nil, nil)
                    r.ImGui_TableSetupScrollFreeze(ctx, 1, 1)

                    r.ImGui_TableHeadersRow(ctx)
                    for filename, info in pairsByOrder(app.mediaFiles) do
                        r.ImGui_TableNextRow(ctx)
                        if info.ignore then
                            reaper.ImGui_TableSetBgColor(ctx, reaper.ImGui_TableBgTarget_RowBg0(),
                                gui.st.col.item_ignore)
                        end
                        r.ImGui_TableNextColumn(ctx) -- file
                        r.ImGui_Text(ctx, info.basename)
                        local skiprow = false
                        if not r.ImGui_IsItemVisible(ctx) then
                            skiprow = true
                        end
                        if not skiprow then
                            r.ImGui_TableNextColumn(ctx) -- takes
                            r.ImGui_Text(ctx, #info.occurrences)
                            r.ImGui_TableNextColumn(ctx) -- status
                            local curScrPos = {r.ImGui_GetCursorScreenPos(ctx)}
                            curScrPos[2] = curScrPos[2] + 1

                            overview_width = r.ImGui_GetContentRegionAvail(ctx)
                            r.ImGui_DrawList_AddRectFilled(gui.draw_list, curScrPos[1], curScrPos[2],
                                curScrPos[1] + overview_width, curScrPos[2] + line_height - 1, (info.status >=
                                    STATUS.MINIMIZED) and gui.st.col.item_keep or gui.st.col.item)

                            for i, sect in pairsByOrder(info.sections or {}) do
                                r.ImGui_DrawList_AddRectFilled(gui.draw_list, curScrPos[1] + overview_width * sect.from,
                                    curScrPos[2], curScrPos[1] + overview_width * sect.to,
                                    curScrPos[2] + line_height - 1, gui.st.col.item_delete)
                            end
                            -- r.ImGui_ProgressBar(ctx, 0,nil, nil,string.format("%.2f", filenameinfo.srclen))
                            r.ImGui_TableNextColumn(ctx) -- keep
                            r.ImGui_Text(ctx, string.format("%.f %%", info.keep * 100))
                            -- r.ImGui_Text(ctx, info.hasSection and 'Sections not supported. Skipping.' or '')
                            r.ImGui_TableNextColumn(ctx) -- status
                            r.ImGui_Text(ctx, STATUS_DESCRIPTIONS[info.status] ..
                                (info.status_info ~= '' and (' (%s)'):format(info.status_info) or ''))
                            r.ImGui_TableNextColumn(ctx) -- folder
                            r.ImGui_Text(ctx, info.relOrAbsPath)
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
            if r.ImGui_Button(ctx, MAIN_OPERATION_DESCRIPTIONS[settings.mainOperation],
                r.ImGui_GetContentRegionAvail(ctx)) then
                saveSettings()
                local ok, errors = checkSettings()
                if not ok then
                    app.msg(table.concat(errors, '\n------------\n'))
                else
                    app.coPerform = coroutine.create(doPerform)
                end
            end
        else
            r.ImGui_ProgressBar(ctx, (app.perform.pos or 0) / (app.perform.total or 1),
                 r.ImGui_GetContentRegionAvail(ctx))
        end
    end

    function app.drawMainWindow()
        local ctx = gui.ctx
        max_w, max_h = r.ImGui_Viewport_GetSize(r.ImGui_GetMainViewport(ctx))

        -- reaper.ShowConsoleMsg(viewPortWidth)
        r.ImGui_SetNextWindowSize(ctx, math.min(1800, max_w), math.min(800, max_h), r.ImGui_Cond_Appearing())
        r.ImGui_SetNextWindowPos(ctx, 100, 100, r.ImGui_Cond_FirstUseEver())
        local visible, open = r.ImGui_Begin(ctx, scr.name .. ' v' .. scr.version .. "##mainWindow", true)
        gui.mainWindow = {
            pos = {r.ImGui_GetWindowPos(ctx)},
            size = {r.ImGui_GetWindowSize(ctx)}
        }
        if visible then
            local bottom_lines = 2
            local rv2
            if r.ImGui_BeginMenuBar(ctx) then
                -- r.ImGui_SetCursorPosX(ctx, r.ImGui_GetContentRegionAvail(ctx)- r.ImGui_CalcTextSize(ctx,'Settings'))
                r.ImGui_EndMenuBar(ctx)
            end
            if app.coPerform and coroutine.status(app.coPerform) == 'suspended' then
                r.ImGui_BeginDisabled(ctx)
            end

            settings.mainOperation = gui.setting('combo', 'Operation', "Main operation to be performed",
                settings.mainOperation, {
                    list = MAIN_OPERATIONS_LIST
                })
            if settings.mainOperation == MAIN_OPERATION.BACKUP then
                settings.backupDestination = gui.setting('folder', 'Destination', 'Select an empty folder',
                    settings.backupDestination)
                settings.backupOperation = gui.bitwise_setting('checkbox', settings.backupOperation,
                    BACKUP_OPERATION_DESCRIPTIONS)
            end
            if settings.mainOperation == MAIN_OPERATION.MINIMIZE then
                settings.deleteOperation = gui.setting('combo', 'After minimizing',
                    "What should be done after minimizing.", settings.deleteOperation, {
                        list = DELETE_OPERATIONS_LIST
                    })
            end

            settings.suffix = gui.setting('text', 'suffix', "Suffix to be added to minimized files", settings.suffix)
            settings.padding = gui.setting('dragdouble', 'padding (s)', "How much audio to before and after items",
                settings.padding, {
                    speed = 0.1,
                    min = 0.0,
                    max = 10.0,
                    format = "%.1f"
                })
            if settings.padding < 0 then
                settings.padding = 0
            end

            settings.minimizeSourceTypes = gui.setting('combo', 'File types', "What file type should be minimized.",
                settings.minimizeSourceTypes, {
                    list = MINIMIZE_SOURCE_TYPES_LIST
                })

            if app.coPerform and coroutine.status(app.coPerform) == 'suspended' then
                r.ImGui_EndDisabled(ctx)
            end

            app.drawPerform(app.showPerform)
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

    loadSettings()
    -- app.coPerform = coroutine.create(doPerform)
    r.defer(app.loop)
    -- doPerform()
end
