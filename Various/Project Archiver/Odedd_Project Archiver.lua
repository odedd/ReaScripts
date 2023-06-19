-- @description Project Archiver
-- @author Oded Davidov
-- @version 0.1.0
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

OD_Init()

dofile(p .. 'lib/Constants.lua')
dofile(p .. 'lib/Settings.lua')
dofile(p .. 'lib/Operation.lua')
dofile(p .. 'lib/App.lua')
dofile(p .. 'lib/Texts.lua')
dofile(p .. 'lib/Gui.lua')

App.debugLevel = DEBUG_LEVEL.INFO

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
    if CheckSettings() then
        Prepare()
        if Settings.keepActiveTakesOnly then
            KeepActiveTakesOnly()
        end
        -- get information on all takes, separated by media source file
        if Settings.backup or Settings.keepActiveTakesOnly or Settings.minimize or Settings.collect ~= 0 or Settings.cleanMediaFolder then
            GetMediaFiles()
        end
        if SubProjectsExist() then
            Cancel(T.ERROR_SUBPROJECTS_UNSPPORTED)
        else
            -- if sources are networked, trashing may not be an option.
            if (Settings.minimize and not Settings.backup) and (Settings.deleteMethod == DELETE_METHOD.MOVE_TO_TRASH) and
                (NetworkedFilesExist()) then
                Cancel(
                    T.ERROR_NETWORKED_FILES_TRASH_UNSPPORTED)
            else
                -- minimize files and apply to original sources
                if Settings.minimize then
                    MinimizeAndApplyMedia()
                end
                if Settings.backup or Settings.collect ~= 0 then
                    CollectMedia()
                end
                if Settings.backup then
                    -- copy to a new project path (move glued files, copy others)
                    CreateBackupProject()
                    -- should happen here so that revert happens afterward
                    CalculateSavings()
                    -- revert back to temporary copy of project
                    Revert()
                else
                    if Settings.minimize then
                        DeleteOriginals()
                    end
                    if Settings.cleanMediaFolder then
                        CleanMediaFolder()
                    end
                    -- finish building peaks for new files
                    FinalizePeaksBuild()
                    -- if not creating a backup, save project
                    r.Main_SaveProject(-1)
                    CalculateSavings()
                end
                -- restore settings and other stuff saved at the beginning of the process
                Restore()

                if Settings.backup then
                    -- open backup project
                    r.Main_openProject("noprompt:" .. App.backupTargetProject)
                end
                coroutine.yield('Done', 0, 1)
            end
        end
    end

    return
end

local function checkPerform()
    if App.coPerform then
        if coroutine.status(App.coPerform) == "suspended" then
            local retval
            retval, App.perform.status = coroutine.resume(App.coPerform)
            if not retval then
                if App.perform.status:sub(-17) == 'cancelled by glue' then
                    Cancel(T.CANCELLED)
                else
                    -- r.ShowConsoleMsg(App.perform.status)
                    Cancel(('Error occured:\n%s'):format(App.perform.status))
                end
            end
        elseif coroutine.status(App.coPerform) == "dead" then
            App.coPerform = nil
        end
    end
end
local function waitForMessageBox()
    if App.revertCancelOnNextFrame == true then
        App.revertCancelOnNextFrame = 2 --wait one more frame for message box drawing
    elseif
        App.revertCancelOnNextFrame == 2 then
        Revert(true)
        App.revertCancelOnNextFrame = nil
    end
end

---------------------------------------
-- UI ---------------------------------
---------------------------------------

function App.drawPerform(open)
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
                for filename, fileInfo in OD_PairsByOrder(App.mediaFiles) do
                    r.ImGui_TableNextRow(ctx)
                    r.ImGui_TableNextColumn(ctx) -- file
                    r.ImGui_Text(ctx, fileInfo.basename .. (fileInfo.ext and ('.' .. fileInfo.ext) or ''))
                    if App.scroll == filename then
                        reaper.ImGui_SetScrollHereY(ctx, 1)
                        App.scroll = false
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
                                string.format("%.f %%", fileInfo.newFileSize / fileInfo.sourceFileSize * 100))
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

function App.drawWarning()
    local ctx = Gui.ctx
    local center = { Gui.mainWindow.pos[1] + Gui.mainWindow.size[1] / 2,
        Gui.mainWindow.pos[2] + Gui.mainWindow.size[2] / 2 } -- {r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
    local okButtonLabel = App.popup.secondWarningShown and 'Come on already let\'s do it!' or 'I do'
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
            if Scr.major_version < 1 and Settings.showBetaWarning and not App.popup.secondWarningShown then
                r.ImGui_OpenPopup(ctx, 'Also...')
            else
                App.popup.secondWarningShown = false
                okPressed = true
                r.ImGui_CloseCurrentPopup(ctx)
            end
        end

        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, cancelButtonLabel) then
            App.popup.secondWarningShown = false
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
            App.popup.secondWarningShown = true

            local width = select(1, r.ImGui_GetContentRegionAvail(ctx))
            r.ImGui_PushItemWidth(ctx, width)

            local windowWidth, windowHeight = r.ImGui_GetWindowSize(ctx);
            r.ImGui_SetCursorPos(ctx, (windowWidth - textWidth) * .5, (windowHeight - textHeight) * .5);

            if r.ImGui_BeginChild(ctx, 'msgBody', 0,
                    select(2, r.ImGui_GetContentRegionAvail(ctx)) - (r.ImGui_GetFrameHeight(ctx) * bottom_lines) -
                    r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding())) then
                r.ImGui_TextWrapped(ctx, T.BETA_WARNING)
                local _, hideThis =
                    r.ImGui_Checkbox(ctx, "Dont show this again", not Settings.showBetaWarning)
                Settings.showBetaWarning = not hideThis
                r.ImGui_EndChild(ctx)
            end

            r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeight(ctx) * bottom_lines) -
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()))
            local buttonTextWidth = r.ImGui_CalcTextSize(ctx, buttonLabel) +
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2
            r.ImGui_SetCursorPosX(ctx, (windowWidth - buttonTextWidth) * .5);

            if r.ImGui_Button(ctx, 'Got it') then
                SaveSettings()
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndPopup(ctx)
        end

        r.ImGui_EndPopup(ctx)
    end
    r.ImGui_PopStyleVar(ctx)
    if okPressed then
        App.coPerform = coroutine.create(doPerform)
    end
end

function App.drawBottom(ctx, bottom_lines)
    r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) -
        (r.ImGui_GetFrameHeightWithSpacing(ctx) * bottom_lines +
            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) * 2))
    local status, col = App.getStatus('main')
    if col then r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), Gui.st.col[col]) end
    r.ImGui_Spacing(ctx)
    r.ImGui_Text(ctx, status)
    App.setHint('main', '')
    r.ImGui_Spacing(ctx)
    if col then r.ImGui_PopStyleColor(ctx) end
    if not App.coPerform then
        if r.ImGui_Button(ctx, Settings.backup and 'Create Backup' or 'Minimize Current Project',
                r.ImGui_GetContentRegionAvail(ctx)) then
            -- don't save backupDestination into saved preferences, but save all other settings
            local tmpDest = Settings.backupDestination
            Settings.backupDestination = nil
            SaveSettings()
            Settings.backupDestination = tmpDest

            local ok, errors = CheckSettings()
            if not ok then
                App.msg(table.concat(errors, '\n\n'))
            else
                if App.warningCount > 0 then
                    r.ImGui_OpenPopup(ctx, 'Are you sure?')
                else
                    App.coPerform = coroutine.create(doPerform)
                end
            end
        end

        App.drawWarning()
    else
        local w, h = r.ImGui_GetContentRegionAvail(ctx)
        local btnWidth = 150
        r.ImGui_ProgressBar(ctx, (App.perform.pos or 0) / (App.perform.total or 1), w - 150, h,
            ("%s/%s"):format(App.perform.pos, App.perform.total))
        r.ImGui_SameLine(ctx)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0x444444ff)
        if r.ImGui_Button(ctx, 'Cancel', r.ImGui_GetContentRegionAvail(ctx)) then
            Cancel(T.CANCELLED)
        end
        r.ImGui_PopStyleColor(ctx)
    end
end

function App.drawMainWindow()
    local ctx = Gui.ctx
    local max_w, max_h = r.ImGui_Viewport_GetSize(r.ImGui_GetMainViewport(ctx))
    App.warningCount = 0

    -- r.ShowConsoleMsg(viewPortWidth)
    r.ImGui_SetNextWindowSize(ctx, math.min(1197, max_w), math.min(800, max_h), r.ImGui_Cond_Appearing())
    r.ImGui_SetNextWindowPos(ctx, 100, 100, r.ImGui_Cond_FirstUseEver())
    local visible, open = r.ImGui_Begin(ctx, Scr.name .. ' v' .. Scr.version .. " by " .. Scr.developer .. "##mainWindow",
        not App.coPerform,
        r.ImGui_WindowFlags_NoDocking() | r.ImGui_WindowFlags_NoCollapse())
    Gui.mainWindow = {
        pos = { r.ImGui_GetWindowPos(ctx) },
        size = { r.ImGui_GetWindowSize(ctx) }
    }

    if visible then
        local bottom_lines = 2
        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_IndentSpacing(), 35)
        if App.coPerform and coroutine.status(App.coPerform) == 'suspended' then
            r.ImGui_BeginDisabled(ctx)
        end

        r.ImGui_SeparatorText(ctx, 'Settings')

        r.ImGui_Bullet(ctx)
        Settings.backup = Gui.setting(
            'checkbox',
            T.SETTINGS.BACKUP.LABEL,
            T.SETTINGS.BACKUP.HINT,
            Settings.backup)
        if Settings.backup then
            Settings.backupDestination = Gui.setting(
                'folder',
                T.SETTINGS.BACKUP_DESTINATION.LABEL,
                T.SETTINGS.BACKUP_DESTINATION.HINT,
                Settings.backupDestination,
                {},
                true)
        end

        r.ImGui_Bullet(ctx)
        Settings.keepActiveTakesOnly = Gui.setting(
            'checkbox',
            T.SETTINGS.KEEP_ACTIVE_TAKES_ONLY.LABEL,
            T.SETTINGS.KEEP_ACTIVE_TAKES_ONLY.HINT,
            Settings.keepActiveTakesOnly)

        if Settings.minimize and not Settings.backup then
            Gui.settingIcon(Gui.icons.caution, T.CAUTION_MINIMIZE)
            App.warningCount = App.warningCount + 1
        else
            r.ImGui_Bullet(ctx)
        end
        Settings.minimize = Gui.setting(
            'checkbox',
            T.SETTINGS.MINIMIZE.LABEL,
            T.SETTINGS.MINIMIZE.HINT,
            Settings.minimize)

        r.ImGui_Indent(ctx)
        if not Settings.minimize then r.ImGui_BeginDisabled(ctx) end
        Settings.padding = Gui.setting(
            'dragdouble',
            T.SETTINGS.PADDING.LABEL,
            T.SETTINGS.PADDING.HINT,
            Settings.padding, {
                speed = 0.1,
                min = 0.0,
                max = 10.0,
                format = "%.1f"
            })
        if Settings.padding < 0 then Settings.padding = 0 end

        Settings.minimizeSourceTypes = Gui.setting(
            'combo',
            T.SETTINGS.MINIMIZE_SOURCE_TYPES.LABEL,
            T.SETTINGS.MINIMIZE_SOURCE_TYPES.HINT,
            Settings.minimizeSourceTypes, {
                list = MINIMIZE_SOURCE_TYPES_LIST
            })

        Settings.glueFormat = Gui.setting(
            'combo',
            T.SETTINGS.GLUE_FORMAT.LABEL,
            T.SETTINGS.GLUE_FORMAT.HINT,
            Settings.glueFormat, {
                list = GLUE_FORMATS_LIST
            })
        if not Settings.minimize then r.ImGui_EndDisabled(ctx) end
        r.ImGui_Unindent(ctx)
        if Settings.backup or Settings.collect ~= 0 then
            if Settings.collectOperation == COLLECT_OPERATION.MOVE then
                Gui.settingIcon(Gui.icons.caution, T.CAUTION_COLLECT_MOVE)
                App.warningCount = App.warningCount + 1
            else
                r.ImGui_Bullet(ctx)
            end
            Settings.collectOperation = Gui.setting(
                'combo',
                T.SETTINGS.COLLECT_OPERATION.LABEL,
                T.SETTINGS.COLLECT_OPERATION.HINT,
                Settings.collectOperation, {
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
            if Settings.backup and bwVal == COLLECT.EXTERNAL then
                if App.temp.originalBackupValue == nil then
                    App.temp.originalBackupValue = OD_BfCheck(Settings.collect,
                        COLLECT.EXTERNAL)
                end
                r.ImGui_BeginDisabled(ctx)
            elseif not Settings.backup and bwVal == COLLECT.EXTERNAL and App.temp.originalBackupValue ~= nil then
                Settings.collect = OD_BfSet(Settings.collect, COLLECT.EXTERNAL, App.temp.originalBackupValue)
                App.temp.originalBackupValue = nil
            end
            local op = Gui.setting('checkbox', option.LABEL, option.HINT,
                (Settings.backup and bwVal == COLLECT.EXTERNAL) and true or OD_BfCheck(Settings.collect, bwVal))
            Settings.collect = OD_BfSet(Settings.collect, bwVal, op)
            if Settings.backup and bwVal == COLLECT.EXTERNAL then
                if r.ImGui_IsItemHovered(ctx, r.ImGui_HoveredFlags_AllowWhenDisabled()) then
                    r.ImGui_SetTooltip(ctx, (T.SETTINGS.COLLECT[COLLECT.EXTERNAL].mustCollectHint))
                end
                r.ImGui_EndDisabled(ctx)
            end
            if OD_BfCheck(Settings.collect, bwVal) then
                Settings.targetPaths[option.targetPath] = OD_Trim(Gui.setting('text_with_hint', option.LABEL .. ' path',
                    option.TEXT_HELP, Settings.targetPaths[option.targetPath], { hint = option.TEXT_HINT }, true))
                if Settings.targetPaths[option.targetPath] == '' then Settings.targetPaths[option.targetPath] = nil end
            end
        end

        r.ImGui_Unindent(ctx)
        if not Settings.backup then
            if Settings.cleanMediaFolder then
                Gui.settingIcon(Gui.icons.caution, T.CAUTION_CLEAN_MEDIA_FOLDER)
                App.warningCount = App.warningCount + 1
            else
                r.ImGui_Bullet(ctx)
            end
            Settings.cleanMediaFolder = Gui.setting(
                'checkbox',
                T.SETTINGS.CLEAN_MEDIA_FOLDER.LABEL,
                T.SETTINGS.CLEAN_MEDIA_FOLDER.HINT,
                Settings.cleanMediaFolder)
        else
            Gui.settingSpacing()
        end
        if (Settings.minimize or Settings.cleanMediaFolder) and not Settings.backup then
            if Settings.cleanMediaFolder and Settings.deleteMethod == DELETE_METHOD.KEEP_IN_FOLDER then
                Gui.settingIcon(Gui.icons.error, T.ERROR_KEEP_IN_FOLDER)
                App.warningCount = App.warningCount + 1
            elseif Settings.deleteMethod == DELETE_METHOD.DELETE_FROM_DISK then
                Gui.settingIcon(Gui.icons.caution, T.CAUTION_DELETE)
                App.warningCount = App.warningCount + 1
            else
                r.ImGui_Bullet(ctx)
            end
            Settings.deleteMethod = Gui.setting(
                'combo', 
                T.SETTINGS.DELETE_METHODS.LABEL,
                T.SETTINGS.DELETE_METHODS.HINT,
                Settings.deleteMethod, {
                    list = DELETE_METHODS_LIST
                })
        else
            Gui.settingSpacing()
        end

        if App.coPerform and coroutine.status(App.coPerform) == 'suspended' then r.ImGui_EndDisabled(ctx) end
        r.ImGui_PopStyleVar(ctx)

        r.ImGui_SeparatorText(ctx, 'Overview')

        App.drawPerform(true)
        App.drawBottom(ctx, bottom_lines)
        App.drawMsg()
        r.ImGui_End(ctx)
    end
    return open
end

function App.reset()
    App.mediaFiles = {}
    App.usedFiles = {} --keeps track of ALL files used in the session for cleaning the media folder
end

function App.loop()
    if not App.coPerform and not App.popup.msg then App.checkProjectChange() end
    waitForMessageBox()
    checkPerform()
    r.ImGui_PushFont(Gui.ctx, Gui.st.fonts.default)
    App.open = App.drawMainWindow()
    r.ImGui_PopFont(Gui.ctx)
    -- checkExternalCommand()
    if App.coPerform or App.popup.msg or (App.open and not reaper.ImGui_IsKeyPressed(Gui.ctx, reaper.ImGui_Key_Escape())) then
        r.defer(App.loop)
    end
end

---------------------------------------
-- START ------------------------------
---------------------------------------

if OD_PrereqsOK({
        reaimgui_version = '0.8',
        sws = true,           -- required for SNM_SetIntConfigVar - setting config vars (max file size limitation and autosave options)
        js_version = 1.310,   -- required for JS_Dialog_BrowseForFolder
        reaper_version = 6.76 -- required for APPLYFX_FORMAT and OPENCOPY_CFGIDX
    }) then
    LoadSettings()
    r.defer(App.loop)
end