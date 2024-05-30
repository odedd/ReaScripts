-- @description Project Archiver
-- @author Oded Davidov
-- @version 0.8.1
-- @donation https://paypal.me/odedda
-- @link Forum Thread https://forum.cockos.com/showthread.php?t=280150
-- @license GNU GPL v3
-- @provides
--   [nomain] ../../Resources/Common/* > Resources/Common/
--   [nomain] ../../Resources/Common/Helpers/* > Resources/Common/Helpers/
--   [nomain] ../../Resources/Common/Helpers/App/* > Resources/Common/Helpers/App/
--   [nomain] ../../Resources/Common/Helpers/Reaper/* > Resources/Common/Helpers/Reaper/
--   [nomain] ../../Resources/Fonts/* > Resources/Fonts/
--   [nomain] ../../Resources/Icons/* > Resources/Icons/
--   [nomain] lib/**
-- @changelog
--   Internal changes

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

if OD_PrereqsOK({
        reaimgui_version = '0.8.4',
        sws = true,            -- required for SNM_SetIntConfigVar - setting config vars (max file size limitation and autosave options)
        js_version = 1.310,    -- required for JS_Dialog_BrowseForFolder
        reaper_version = 6.76, -- required for APPLYFX_FORMAT and OPENCOPY_CFGIDX
        scripts = {
            ['Reateam_RPP-Parser.lua'] = r.path .. "/Scripts/Reateam Scripts/Development/RPP-Parser/Reateam_RPP-Parser.lua"
        }
    }) then
    dofile(p .. 'lib/Constants.lua')
    dofile(p .. 'lib/Settings.lua')
    dofile(p .. 'lib/Operation.lua')
    dofile(p .. 'lib/Gui.lua')
    dofile(p .. 'lib/Texts.lua')

    -- @noindex

    local app = OD_Perform_App:new({
        mediaFiles = {},
        revert = {},
        restore = {},
        popup = {}
    })

    local logger = OD_Logger:new({
        level = OD_Logger.LOG_LEVEL.NONE,
        output = OD_Logger.LOG_OUTPUT.FILE
    })

    app:connect('gui', Gui)
    app:connect('op', Op)
    app:connect('logger', logger)
    app:init()
    logger:init()

    function app:checkProjectChange(force)
        if force or OD_DidProjectGUIDChange() then
            local projPath, projFileName = OD_GetProjectPaths()
            logger:setLogFile(projPath .. Scr.name .. '_' .. projFileName .. '.log')
            self.reset()
        end
    end

    local settings = PA_Settings.current

    Gui.tables = {
        horizontal = {
            flags1 = r.ImGui_TableFlags_NoSavedSettings() | r.ImGui_TableFlags_ScrollX() | r.ImGui_TableFlags_ScrollY() |
                r.ImGui_TableFlags_BordersOuter() | r.ImGui_TableFlags_Borders() | r.ImGui_TableFlags_Resizable() |
                r.ImGui_TableFlags_NoHostExtendX() | r.ImGui_TableFlags_SizingFixedFit()
        }
    }

    Gui.st.col.item = 0x333333ff;
    Gui.st.col.item_keep = 0x2a783fff;
    Gui.st.col.item_delete = 0x852f29ff;
    Gui.st.col.item_ignore = 0x852f29ff;

    Gui.st.col.status = {
        [STATUS.IGNORE] = 0x333333ff,
        [STATUS.SCANNED] = nil,
        [STATUS.MINIMIZING] = 0x703d19ff,
        [STATUS.MINIMIZED] = 0xb06027ff,
        [STATUS.NOTHING_TO_MINIMIZE] = 0xb06027ff,
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
        if PA_Settings:check() then
            -- force checkProjectChange to reset the app, set log file, etc.
            app:checkProjectChange(true)

            logger:logInfo('** Process Started')
            logger:logInfo('OS: ', reaper.GetOS())
            logger:logInfo('Reaper version: ', tostring(r.ver))
            logger:logInfo('Script file: ', Scr.path)
            logger:logInfo('Script version: ', tostring(Scr.version))
            logger:logInfo('JS_ReaScriptAPI version: ', tostring(r.APIExists('JS_ReaScriptAPI_Version')))
            logger:logTable(logger.LOG_LEVEL.INFO, 'Settings', settings)

            Prepare()
            if settings.keepActiveTakesOnly then
                KeepActiveTakesOnly()
            end
            -- get information on all takes, separated by media source file
            if settings.backup or settings.keepActiveTakesOnly or settings.minimize or settings.collect ~= 0 or settings.cleanMediaFolder then
                GetMediaFiles()
            end
            if SubProjectsExist() then
                Cancel(T.ERROR_SUBPROJECTS_UNSPPORTED)
            else
                -- if sources are networked, trashing may not be an option.
                if (settings.minimize and not settings.backup) and (settings.deleteMethod == DELETE_METHOD.MOVE_TO_TRASH) and
                    (NetworkedFilesExist()) then
                    Cancel(
                        T.ERROR_NETWORKED_FILES_TRASH_UNSPPORTED)
                else
                    -- minimize files and apply to original sources
                    if settings.minimize then
                        MinimizeAndApplyMedia()
                    end
                    if settings.backup or settings.collect ~= 0 then
                        CollectMedia()
                    end
                    if settings.freezeHandling == FREEZE_HANDLING.REMOVE then
                        UnlockFrozenItems()
                    end
                    if settings.backup then
                        -- copy to a new project path (move glued files, copy others)
                        CreateBackupProject()
                        if settings.freezeHandling == FREEZE_HANDLING.KEEP then
                            -- fix paths in frozen tracks
                            FixFrozenTracksFileAssociations()
                        elseif settings.freezeHandling == FREEZE_HANDLING.REMOVE then
                            RemoveFreezeChunks()
                        end
                        -- should happen here so that revert happens afterward
                        CalculateSavings()
                        -- revert back to temporary copy of project
                        Revert()
                    else
                        if settings.minimize then
                            DeleteOriginals()
                        end
                        if settings.cleanMediaFolder then
                            CleanMediaFolder()
                        end
                        -- finish building peaks for new files
                        FinalizePeaksBuild()
                        -- if not creating a backup, save project
                        r.Main_SaveProject(-1)
                        if settings.freezeHandling == FREEZE_HANDLING.KEEP then
                            -- fix paths in frozen tracks
                            FixFrozenTracksFileAssociations()
                        elseif settings.freezeHandling == FREEZE_HANDLING.REMOVE then
                            RemoveFreezeChunks()
                        end
                        CalculateSavings()
                    end
                    -- restore settings and other stuff saved at the beginning of the process
                    Restore()

                    if settings.backup then
                        -- open backup project
                        r.Main_openProject("noprompt:" .. app.backupTargetProject)
                    end
                    logger:logInfo('** Process Completed')
                    coroutine.yield('Done', 0, 1)
                end
            end
        end
        logger:flush()
        return
    end

    local function checkPerform()
        if app.coPerform then
            if coroutine.status(app.coPerform) == "suspended" then
                local retval
                retval, app.perform.status = coroutine.resume(app.coPerform)
                if not retval then
                    if app.perform.status:sub(-17) == 'cancelled by glue' then
                        Cancel(T.CANCELLED)
                    else
                        -- r.ShowConsoleMsg(app.perform.status)
                        Cancel(('Error occured:\n%s'):format(app.perform.status))
                    end
                end
            elseif coroutine.status(app.coPerform) == "dead" then
                app.coPerform = nil
            end
        end
    end
    local function waitForMessageBox()
        if app.revertCancelOnNextFrame == true then
            app.revertCancelOnNextFrame = 2 --wait one more frame for message box drawing
        elseif
            app.revertCancelOnNextFrame == 2 then
            Revert(true)
            app.revertCancelOnNextFrame = nil
        end
    end

    ---------------------------------------
    -- UI ---------------------------------
    ---------------------------------------

    function app.drawPerform(open)
        local ctx = Gui.ctx
        local bottom_lines = 2
        local overview_width = 200
        local line_height = r.ImGui_GetTextLineHeight(ctx)

        if open then
            local childHeight = select(2, r.ImGui_GetContentRegionAvail(ctx)) -
                (r.ImGui_GetFrameHeightWithSpacing(ctx) * bottom_lines +
                    r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) * 2)
            if r.ImGui_BeginChild(ctx, 'mediaFiles', 0, childHeight) then
                if r.ImGui_BeginTable(ctx, 'table_scrollx', 10, Gui.tables.horizontal.flags1) then
                    local parent_open, depth, open_depth = true, 0, 0
                    r.ImGui_TableSetupColumn(ctx, 'File', r.ImGui_TableColumnFlags_NoHide(), 250) -- Make the first column not hideable to match our use of TableSetupScrollFreeze()
                    r.ImGui_TableSetupColumn(ctx, 'Type', r.ImGui_TableColumnFlags_NoHide(), 50)  -- Make the first column not hideable to match our use of TableSetupScrollFreeze()
                    r.ImGui_TableSetupColumn(ctx, '#', nil, 30)
                    r.ImGui_TableSetupColumn(ctx, 'Overview', nil, overview_width)
                    r.ImGui_TableSetupColumn(ctx, 'Orig', nil, 65)
                    r.ImGui_TableSetupColumn(ctx, 'New', nil, 65)
                    r.ImGui_TableSetupColumn(ctx, 'Keep\nLength', nil, 50)
                    r.ImGui_TableSetupColumn(ctx, 'Keep\nSize', nil, 50)
                    r.ImGui_TableSetupColumn(ctx, 'Status', nil, 180)
                    r.ImGui_TableSetupColumn(ctx, 'Full Path', nil, 150)
                    r.ImGui_TableSetupScrollFreeze(ctx, 1, 1)

                    r.ImGui_TableHeadersRow(ctx)
                    for filename, fileInfo in OD_PairsByOrder(app.mediaFiles) do
                        r.ImGui_TableNextRow(ctx)
                        r.ImGui_TableNextColumn(ctx) -- file
                        r.ImGui_Text(ctx, fileInfo.basename .. (fileInfo.ext and ('.' .. fileInfo.ext) or ''))
                        if app.scroll == filename then
                            reaper.ImGui_SetScrollHereY(ctx, 1)
                            app.scroll = false
                        end
                        local skiprow = false
                        if not r.ImGui_IsItemVisible(ctx) then skiprow = true end
                        if not skiprow then
                            r.ImGui_TableNextColumn(ctx) -- type
                            r.ImGui_Text(ctx, FILE_TYPE_DESCRPTIONS[fileInfo.fileType])
                            r.ImGui_TableNextColumn(ctx) -- takes
                            r.ImGui_Text(ctx, #fileInfo.occurrences)
                            r.ImGui_TableNextColumn(ctx) -- status
                            local curScrPos = { r.ImGui_GetCursorScreenPos(ctx) }
                            curScrPos[2] = curScrPos[2] + 1

                            overview_width = r.ImGui_GetContentRegionAvail(ctx)
                            r.ImGui_DrawList_AddRectFilled(Gui.draw_list, curScrPos[1], curScrPos[2],
                                curScrPos[1] + overview_width, curScrPos[2] + line_height - 1, (fileInfo.status >=
                                    STATUS.MINIMIZED or #(fileInfo.sections or {}) > 0) and Gui.st.col.item_keep or
                                Gui.st.col.item)

                            for i, sect in OD_PairsByOrder(fileInfo.sections or {}) do
                                r.ImGui_DrawList_AddRectFilled(Gui.draw_list, curScrPos[1] + overview_width * sect.from,
                                    curScrPos[2], curScrPos[1] + overview_width * sect.to, curScrPos[2] + line_height - 1,
                                    Gui.st.col.item_delete)
                            end
                            -- r.ImGui_ProgressBar(ctx, 0,nil, nil,string.format("%.2f", fileInfo.srclen))
                            r.ImGui_TableNextColumn(ctx) -- orig. size
                            r.ImGui_Text(ctx, OD_GetFormattedFileSize(fileInfo.sourceFileSize))
                            r.ImGui_TableNextColumn(ctx) -- new size
                            r.ImGui_Text(ctx, OD_GetFormattedFileSize(fileInfo.newFileSize))
                            r.ImGui_TableNextColumn(ctx) -- keep length
                            r.ImGui_Text(ctx, string.format("%.f %%", fileInfo.keep_length * 100))
                            r.ImGui_TableNextColumn(ctx) -- keep size
                            if fileInfo.newFileSize and fileInfo.sourceFileSize then
                                r.ImGui_Text(ctx,
                                    string.format("%.f %%",
                                        fileInfo.sourceFileSize == 0 and 100 or
                                        (fileInfo.newFileSize / fileInfo.sourceFileSize * 100)))
                            end
                            r.ImGui_TableNextColumn(ctx) -- status
                            if Gui.st.col.status[fileInfo.status] then
                                r.ImGui_TableSetBgColor(ctx, r.ImGui_TableBgTarget_CellBg(),
                                    Gui.st.col.status[fileInfo.status])
                            end
                            r.ImGui_Text(ctx, STATUS_DESCRIPTIONS[fileInfo.status] ..
                                (fileInfo.status_info ~= '' and (' (%s)'):format(fileInfo.status_info) or ''))
                            r.ImGui_TableNextColumn(ctx) -- folder
                            local path = fileInfo.relOrAbsPath
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
        local ctx = Gui.ctx
        local center = { Gui.mainWindow.pos[1] + Gui.mainWindow.size[1] / 2,
            Gui.mainWindow.pos[2] + Gui.mainWindow.size[2] / 2 } -- {r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
        local okButtonLabel = app.popup.secondWarningShown and 'Come on already let\'s do it!' or 'I do'
        local cancelButtonLabel = 'Nope'
        local okPressed = false
        local cancelPressed = false
        local bottom_lines = 1

        local textWidth, textHeight = r.ImGui_CalcTextSize(ctx, T.WARNINGS_EXIST)

        r.ImGui_SetNextWindowSize(ctx,
            math.max(220, textWidth) + r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()) * 4,
            textHeight + 90 + r.ImGui_GetTextLineHeightWithSpacing(ctx))

        r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowTitleAlign(), 0.5, 0.5)
        if r.ImGui_BeginPopupModal(ctx, 'Are you sure?', nil,
                r.ImGui_WindowFlags_NoResize()) then
            local width = select(1, r.ImGui_GetContentRegionAvail(ctx))
            r.ImGui_PushItemWidth(ctx, width)

            local windowWidth, windowHeight = r.ImGui_GetWindowSize(ctx);
            r.ImGui_SetCursorPos(ctx, (windowWidth - textWidth) * .5, (windowHeight - textHeight) * .5);
            r.ImGui_TextWrapped(ctx, T.WARNINGS_EXIST)

            r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeight(ctx) * bottom_lines) -
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()))

            local buttonTextWidth = r.ImGui_CalcTextSize(ctx, okButtonLabel) +
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2

            buttonTextWidth = buttonTextWidth + r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) +
                r.ImGui_CalcTextSize(ctx, cancelButtonLabel) +
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2
            r.ImGui_SetCursorPosX(ctx, (windowWidth - buttonTextWidth) * .5);

            if r.ImGui_Button(ctx, okButtonLabel) then
                if Scr.major_version < 1 and settings.showBetaWarning and not app.popup.secondWarningShown then
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

            local buttonLabel = 'Got it'
            local textWidth, textHeight = r.ImGui_CalcTextSize(ctx, T.BETA_WARNING)
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
                    r.ImGui_TextWrapped(ctx, T.BETA_WARNING)
                    local _, hideThis =
                        r.ImGui_Checkbox(ctx, "Dont show this again", not settings.showBetaWarning)
                    settings.showBetaWarning = not hideThis
                    r.ImGui_EndChild(ctx)
                end

                r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeight(ctx) * bottom_lines) -
                    r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()))
                local buttonTextWidth = r.ImGui_CalcTextSize(ctx, buttonLabel) +
                    r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2
                r.ImGui_SetCursorPosX(ctx, (windowWidth - buttonTextWidth) * .5);

                if r.ImGui_Button(ctx, 'Got it') then
                    PA_Settings:save()
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
        local status, col = app:getStatus('main')
        if col then r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), Gui.st.col[col]) end
        r.ImGui_Spacing(ctx)
        r.ImGui_Text(ctx, status)
        app:setHint('main', '')
        r.ImGui_Spacing(ctx)
        if col then r.ImGui_PopStyleColor(ctx) end
        if not app.coPerform then
            if r.ImGui_Button(ctx, settings.backup and 'Create Backup' or 'Minimize Current Project',
                    r.ImGui_GetContentRegionAvail(ctx)) then
                -- don't save backupDestination into saved preferences, but save all other settings
                local tmpDest = settings.backupDestination
                settings.backupDestination = nil
                PA_Settings:save()
                settings.backupDestination = tmpDest

                local ok, errors = PA_Settings:check()
                if not ok then
                    app:msg(table.concat(errors, '\n\n'))
                else
                    if app.warningCount > 0 then
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
                Cancel(T.CANCELLED)
            end
            r.ImGui_PopStyleColor(ctx)
        end
    end

    function app.drawMainWindow()
        local ctx = Gui.ctx
        local max_w, max_h = r.ImGui_Viewport_GetSize(r.ImGui_GetMainViewport(ctx))
        app.warningCount = 0

        r.ImGui_SetNextWindowSize(ctx, math.min(1197, max_w), math.min(800, max_h), r.ImGui_Cond_Appearing())
        r.ImGui_SetNextWindowPos(ctx, 100, 100, r.ImGui_Cond_FirstUseEver())
        local visible, open = r.ImGui_Begin(ctx,
            Scr.name .. ' v' .. Scr.version .. " by " .. Scr.developer .. "##mainWindow",
            not app.coPerform,
            r.ImGui_WindowFlags_NoDocking() | r.ImGui_WindowFlags_NoCollapse() | r.ImGui_WindowFlags_MenuBar())
        Gui.mainWindow = {
            pos = { r.ImGui_GetWindowPos(ctx) },
            size = { r.ImGui_GetWindowSize(ctx) }
        }

        if visible then
            local bottom_lines = 2
            if app.coPerform and coroutine.status(app.coPerform) == 'suspended' then
                r.ImGui_BeginDisabled(ctx)
            end

            if r.ImGui_BeginMenuBar(ctx) then
                if r.ImGui_BeginMenu(ctx, 'Help') then
                    if r.ImGui_MenuItem(ctx, 'Forum Thread') then
                        OD_OpenLink(Scr.link['Forum Thread'])
                    end
                    if r.ImGui_MenuItem(ctx, 'Youtube Video') then
                        app:msg('soon...')
                        -- OD_OpenLink(Scr.link['YouTube'])
                    end
                    if r.ImGui_BeginMenu(ctx, 'Log Level') then
                        for i, level in OD_PairsByOrder(logger.LOG_LEVEL_INFO) do
                            if r.ImGui_MenuItem(ctx, level.description, nil, logger.level == i) then
                                logger.level = i
                            end
                        end
                        r.ImGui_Separator(ctx)
                        r.ImGui_TextDisabled(ctx,
                            "If anything other than \"None\"\nis selected, a log file will be\ncreated at the current project's\nfolder.\n\nThis setting defaults to NONE\neverytime the script restarts\nto avoid logging for no reason\nwhich could hinder performance.")
                        r.ImGui_EndMenu(ctx)
                    end
                    r.ImGui_Separator(ctx)
                    if r.ImGui_MenuItem(ctx, 'Donations are welcome :)') then
                        OD_OpenLink(Scr.donation)
                    end
                    r.ImGui_EndMenu(ctx)
                end
                r.ImGui_EndMenuBar(ctx)
            end


            r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_IndentSpacing(), 35)

            r.ImGui_SeparatorText(ctx, 'Settings')

            r.ImGui_Bullet(ctx)
            settings.backup = Gui.setting(
                'checkbox',
                T.SETTINGS.BACKUP.LABEL,
                T.SETTINGS.BACKUP.HINT,
                settings.backup)
            if settings.backup then
                settings.backupDestination = Gui.setting(
                    'folder',
                    T.SETTINGS.BACKUP_DESTINATION.LABEL,
                    T.SETTINGS.BACKUP_DESTINATION.HINT,
                    settings.backupDestination,
                    {},
                    true)
            end

            r.ImGui_Bullet(ctx)
            settings.keepActiveTakesOnly = Gui.setting(
                'checkbox',
                T.SETTINGS.KEEP_ACTIVE_TAKES_ONLY.LABEL,
                T.SETTINGS.KEEP_ACTIVE_TAKES_ONLY.HINT,
                settings.keepActiveTakesOnly)

            if settings.minimize and not settings.backup then
                Gui.settingIcon(Gui.icons.caution, T.CAUTION_MINIMIZE)
                app.warningCount = app.warningCount + 1
            else
                r.ImGui_Bullet(ctx)
            end
            settings.minimize = Gui.setting(
                'checkbox',
                T.SETTINGS.MINIMIZE.LABEL,
                T.SETTINGS.MINIMIZE.HINT,
                settings.minimize)

            r.ImGui_Indent(ctx)
            if not settings.minimize then r.ImGui_BeginDisabled(ctx) end
            settings.padding = Gui.setting(
                'dragdouble',
                T.SETTINGS.PADDING.LABEL,
                T.SETTINGS.PADDING.HINT,
                settings.padding, {
                    speed = 0.1,
                    min = 0.0,
                    max = 10.0,
                    format = "%.1f"
                })
            if settings.padding < 0 then settings.padding = 0 end

            settings.minimizeSourceTypes = Gui.setting(
                'combo',
                T.SETTINGS.MINIMIZE_SOURCE_TYPES.LABEL,
                T.SETTINGS.MINIMIZE_SOURCE_TYPES.HINT,
                settings.minimizeSourceTypes, {
                    list = MINIMIZE_SOURCE_TYPES_LIST
                })

            settings.glueFormat = Gui.setting(
                'combo',
                T.SETTINGS.GLUE_FORMAT.LABEL,
                T.SETTINGS.GLUE_FORMAT.HINT,
                settings.glueFormat, {
                    list = GLUE_FORMATS_LIST
                })
            if not settings.minimize then r.ImGui_EndDisabled(ctx) end
            r.ImGui_Unindent(ctx)
            if settings.backup or settings.collect ~= 0 then
                if settings.collectOperation == COLLECT_OPERATION.MOVE then
                    Gui.settingIcon(Gui.icons.caution, T.CAUTION_COLLECT_MOVE)
                    app.warningCount = app.warningCount + 1
                else
                    r.ImGui_Bullet(ctx)
                end
                settings.collectOperation = Gui.setting(
                    'combo',
                    T.SETTINGS.COLLECT_OPERATION.LABEL,
                    T.SETTINGS.COLLECT_OPERATION.HINT,
                    settings.collectOperation, {
                        list = COLLECT_OPERATIONS_LIST
                    })
            else
                r.ImGui_Bullet(ctx)
                r.ImGui_AlignTextToFramePadding(ctx)
                r.ImGui_Text(ctx, T.SETTINGS.COLLECT_OPERATION.LABEL)
            end


            r.ImGui_Indent(ctx)

            for bwVal, option in OD_PairsByOrder(T.SETTINGS.COLLECT) do
                -- disable external files when backup is selected and temporarily save its value to restore if unchecking backup
                if settings.backup and bwVal == COLLECT.EXTERNAL then
                    if app.temp.originalBackupValue == nil then
                        app.temp.originalBackupValue = OD_BfCheck(settings.collect,
                            COLLECT.EXTERNAL)
                    end
                    r.ImGui_BeginDisabled(ctx)
                elseif not settings.backup and bwVal == COLLECT.EXTERNAL and app.temp.originalBackupValue ~= nil then
                    settings.collect = OD_BfSet(settings.collect, COLLECT.EXTERNAL, app.temp.originalBackupValue)
                    app.temp.originalBackupValue = nil
                end
                local op = Gui.setting('checkbox', option.LABEL, option.HINT,
                    (settings.backup and bwVal == COLLECT.EXTERNAL) and true or OD_BfCheck(settings.collect, bwVal))
                settings.collect = OD_BfSet(settings.collect, bwVal, op)
                if settings.backup and bwVal == COLLECT.EXTERNAL then
                    if r.ImGui_IsItemHovered(ctx, r.ImGui_HoveredFlags_AllowWhenDisabled()) then
                        r.ImGui_SetTooltip(ctx, (T.SETTINGS.COLLECT[COLLECT.EXTERNAL].mustCollectHint))
                    end
                    r.ImGui_EndDisabled(ctx)
                end
                if OD_BfCheck(settings.collect, bwVal) then
                    settings.targetPaths[option.targetPath] = OD_Trim(Gui.setting('text_with_hint',
                        option.LABEL .. ' path',
                        option.TEXT_HELP, settings.targetPaths[option.targetPath], { hint = option.TEXT_HINT }, true))
                    if settings.targetPaths[option.targetPath] == '' then settings.targetPaths[option.targetPath] = nil end
                end
            end

            r.ImGui_Unindent(ctx)


            if settings.freezeHandling == FREEZE_HANDLING.REMOVE then
                Gui.settingIcon(Gui.icons.caution, T.CAUTION_FREEZE_REMOVE)
                app.warningCount = app.warningCount + 1
            else
                r.ImGui_Bullet(ctx)
            end
            settings.freezeHandling = Gui.setting(
                'combo',
                T.SETTINGS.FREEZE_HANDLING.LABEL,
                T.SETTINGS.FREEZE_HANDLING.HINT,
                settings.freezeHandling, {
                    list = FREEZE_HANDLING_LIST
                })

            if not settings.backup then
                if settings.cleanMediaFolder then
                    Gui.settingIcon(Gui.icons.caution, T.CAUTION_CLEAN_MEDIA_FOLDER)
                    app.warningCount = app.warningCount + 1
                else
                    r.ImGui_Bullet(ctx)
                end
                settings.cleanMediaFolder = Gui.setting(
                    'checkbox',
                    T.SETTINGS.CLEAN_MEDIA_FOLDER.LABEL,
                    T.SETTINGS.CLEAN_MEDIA_FOLDER.HINT,
                    settings.cleanMediaFolder)
            else
                Gui.settingSpacing()
            end
            if (settings.minimize or settings.cleanMediaFolder) and not settings.backup then
                if settings.cleanMediaFolder and settings.deleteMethod == DELETE_METHOD.KEEP_IN_FOLDER then
                    Gui.settingIcon(Gui.icons.error, T.ERROR_KEEP_IN_FOLDER)
                    app.warningCount = app.warningCount + 1
                elseif settings.deleteMethod == DELETE_METHOD.DELETE_FROM_DISK then
                    Gui.settingIcon(Gui.icons.caution, T.CAUTION_DELETE)
                    app.warningCount = app.warningCount + 1
                else
                    r.ImGui_Bullet(ctx)
                end
                settings.deleteMethod = Gui.setting(
                    'combo',
                    T.SETTINGS.DELETE_METHODS.LABEL,
                    T.SETTINGS.DELETE_METHODS.HINT,
                    settings.deleteMethod, {
                        list = DELETE_METHODS_LIST
                    })
            else
                Gui.settingSpacing()
            end

            if app.coPerform and coroutine.status(app.coPerform) == 'suspended' then r.ImGui_EndDisabled(ctx) end
            r.ImGui_PopStyleVar(ctx)

            r.ImGui_SeparatorText(ctx, 'Overview')

            app.drawPerform(true)
            app.drawBottom(ctx, bottom_lines)
            app:drawMsg()
            r.ImGui_End(ctx)
        end
        return open
    end

    function app.reset()
        app.mediaFiles = {}
        app.usedFiles = {} --keeps track of ALL files used in the session for cleaning the media folder
    end

    function app.loop()
        if not app.coPerform and not app.popup.msg then app:checkProjectChange() end
        waitForMessageBox()
        checkPerform()

        r.ImGui_PushFont(Gui.ctx, Gui.st.fonts.default)
        app.open = app.drawMainWindow()
        r.ImGui_PopFont(Gui.ctx)
        -- checkExternalCommand()
        if app.coPerform or app.popup.msg or (app.open and not reaper.ImGui_IsKeyPressed(Gui.ctx, reaper.ImGui_Key_Escape())) then
            r.defer(app.loop)
        end
    end

    ---------------------------------------
    -- START ------------------------------
    ---------------------------------------

    dofile(r.path .. "/Scripts/Reateam Scripts/Development/RPP-Parser/Reateam_RPP-Parser.lua")
    PA_Settings:load()
    r.defer(app.loop)
end
