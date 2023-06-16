-- @description Project Archiver
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

Scr, OS_is = OD_Init()

dofile(p .. 'lib/Constants.lua')
dofile(p .. 'lib/Settings.lua')
dofile(p .. 'lib/Operation.lua')
dofile(p .. 'lib/App.lua')
dofile(p .. 'lib/Texts.lua')
dofile(p .. 'lib/Gui.lua')

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
        -- if sources are networked, trashing may not be an option.
        if (Settings.minimize and not Settings.backup) and (Settings.deleteMethod == DELETE_METHOD.MOVE_TO_TRASH) and
            (NetworkedFilesExist()) then
            Cancel(
                'Networked files were found.\nMoving networkd files to the\ntrash is not supported.\nPlease select deleting files\nor consider backing up instead of\nminimizing.')
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
            end
            -- restore settings and other stuff saved at the beginning of the process
            Restore()
            coroutine.yield('Done', 0, 1)
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
                    Cancel()
                else
                    -- r.ShowConsoleMsg(app.perform.status)
                    Cancel(('Error occured:\n%s'):format(App.perform.status))
                end
            end
        elseif coroutine.status(App.coPerform) == "dead" then
            App.coPerform = nil
        end
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
            if r.ImGui_BeginTable(ctx, 'table_scrollx', 9, Gui.tables.horizontal.flags1) then
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
                for filename, fileInfo in OD_PairsByOrder(App.mediaFiles) do
                    r.ImGui_TableNextRow(ctx)
                    r.ImGui_TableNextColumn(ctx) -- file
                    r.ImGui_Text(ctx, fileInfo.basename .. (fileInfo.ext and ('.' .. fileInfo.ext) or ''))
                    local skiprow = false
                    if not r.ImGui_IsItemVisible(ctx) then skiprow = true end
                    if not skiprow then
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

    local textWidth, textHeight = r.ImGui_CalcTextSize(ctx, TEXTS.WARNINGS_EXIST)

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
        r.ImGui_TextWrapped(ctx, TEXTS.WARNINGS_EXIST)

        r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeight(ctx) * bottom_lines) -
            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()))

        local buttonTextWidth = r.ImGui_CalcTextSize(ctx, okButtonLabel) +
            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2

        buttonTextWidth = buttonTextWidth + r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) +
            r.ImGui_CalcTextSize(ctx, cancelButtonLabel) +
            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2
        r.ImGui_SetCursorPosX(ctx, (windowWidth - buttonTextWidth) * .5);

        if r.ImGui_Button(ctx, okButtonLabel) then
            if Settings.showMinimizeDoubleWarning and not App.popup.secondWarningShown then
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
        local textWidth, textHeight = r.ImGui_CalcTextSize(ctx, TEXTS.BETA_WARNING)
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
                r.ImGui_TextWrapped(ctx, TEXTS.BETA_WARNING)
                local _, hideThis =
                    r.ImGui_Checkbox(ctx, "Dont show this again", not Settings.showMinimizeDoubleWarning)
                Settings.showMinimizeDoubleWarning = not hideThis
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
                App.msg(table.concat(errors, '\n------------\n'))
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
            Cancel()
        end
        r.ImGui_PopStyleColor(ctx)
    end
end

function App.drawMainWindow()
    local ctx = Gui.ctx
    local max_w, max_h = r.ImGui_Viewport_GetSize(r.ImGui_GetMainViewport(ctx))
    App.warningCount = 0

    -- r.ShowConsoleMsg(viewPortWidth)
    r.ImGui_SetNextWindowSize(ctx, math.min(1125, max_w), math.min(800, max_h), r.ImGui_Cond_Appearing())
    r.ImGui_SetNextWindowPos(ctx, 100, 100, r.ImGui_Cond_FirstUseEver())
    local visible, open = r.ImGui_Begin(ctx, Scr.name .. ' v' .. Scr.version .. "##mainWindow", not App.coPerform,
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
        Settings.backup = Gui.setting('checkbox', 'Backup project to a new folder',
            "Copy project to a new directory, along with used media only", Settings.backup)
        if Settings.backup then
            Settings.backupDestination = Gui.setting('folder', 'Destination', 'Select an empty folder',
                Settings.backupDestination, {}, true)
        end

        r.ImGui_Bullet(ctx)
        Settings.keepActiveTakesOnly = Gui.setting('checkbox', 'Remove unused takes',
            "Keep only selected takes", Settings.keepActiveTakesOnly)

        if Settings.minimize and not Settings.backup then
            Gui.settingCaution(TEXTS.CAUTION_MINIMIZE)
            App.warningCount = App.warningCount + 1
        else
            r.ImGui_Bullet(ctx)
        end
        Settings.minimize = Gui.setting('checkbox', 'Minimize audio files',
            "Keep only the parts of the audio that are being used in the project", Settings.minimize)

        r.ImGui_Indent(ctx)
        if not Settings.minimize then r.ImGui_BeginDisabled(ctx) end
        Settings.padding = Gui.setting('dragdouble', 'padding (s)',
            "How much unused audio, in seconds, to leave before and after items start and end positions",
            Settings.padding, {
                speed = 0.1,
                min = 0.0,
                max = 10.0,
                format = "%.1f"
            })
        if Settings.padding < 0 then Settings.padding = 0 end

        Settings.minimizeSourceTypes = Gui.setting('combo', 'File types to minimize',
            "Minimizing compressed files, such as MP3s, will result in larger (!) \"minimized\" files, since those will be uncompressed WAV files",
            Settings.minimizeSourceTypes, {
                list = MINIMIZE_SOURCE_TYPES_LIST
            })

        Settings.glueFormat = Gui.setting('combo', 'Minimized files format',
            "Lossless compression (FLAC and WAVPACK) will result in the smallest sizes without losing quality, but takes longer to create",
            Settings.glueFormat, {
                list = GLUE_FORMATS_LIST
            })
        if not Settings.minimize then r.ImGui_EndDisabled(ctx) end
        r.ImGui_Unindent(ctx)
        if Settings.backup or Settings.collect ~= 0 then
            if Settings.collectOperation == COLLECT_OPERATION.MOVE then
                Gui.settingCaution(TEXTS.CAUTION_COLLECT_MOVE)
                App.warningCount = App.warningCount + 1
            else
                r.ImGui_Bullet(ctx)
            end

            Settings.collectOperation = Gui.setting('combo', 'Collect Files into project folder',
                "When collecting external files, should they be copied or moved from their original location",
                Settings.collectOperation, {
                    list = COLLECT_OPERATIONS_LIST
                })
        else
            r.ImGui_Bullet(ctx)
            r.ImGui_AlignTextToFramePadding(ctx)
            r.ImGui_Text(ctx, 'Collect Files into project folder')
        end


        r.ImGui_Indent(ctx)

        for bwVal, option in OD_PairsByOrder(COLLECT_DESCRIPTIONS) do
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
            local op = Gui.setting('checkbox', option.label, option.hint,
                (Settings.backup and bwVal == COLLECT.EXTERNAL) and true or OD_BfCheck(Settings.collect, bwVal))
            Settings.collect = OD_BfSet(Settings.collect, bwVal, op)
            if Settings.backup and bwVal == COLLECT.EXTERNAL then
                if r.ImGui_IsItemHovered(ctx, r.ImGui_HoveredFlags_AllowWhenDisabled()) then
                    r.ImGui_SetTooltip(ctx, ('Must collect when backing up'))
                end
                r.ImGui_EndDisabled(ctx)
            end
            if OD_BfCheck(Settings.collect, bwVal) then
                Settings.targetPaths[option.targetPath] = OD_Trim(Gui.setting('text_with_hint', option.label .. ' path',
                    option.textHelp, Settings.targetPaths[option.targetPath], { hint = option.textHint }, true))
                if Settings.targetPaths[option.targetPath] == '' then Settings.targetPaths[option.targetPath] = nil end
            end
        end

        r.ImGui_Unindent(ctx)
        if not Settings.backup then
            if Settings.cleanMediaFolder then
                Gui.settingCaution(TEXTS.CAUTION_CLEAN_MEDIA_FOLDER)
                App.warningCount = App.warningCount + 1
            else
                r.ImGui_Bullet(ctx)
            end
            Settings.cleanMediaFolder = Gui.setting('checkbox', 'Clean media folder',
                "Keep only the files that are being used in the project in the media folder", Settings.cleanMediaFolder)
        else
            Gui.settingSpacing()
        end
        if (Settings.minimize or Settings.cleanMediaFolder) and not Settings.backup then
            if Settings.deleteMethod == DELETE_METHOD.DELETE_FROM_DISK then
                Gui.settingCaution(TEXTS.CAUTION_DELETE)
                App.warningCount = App.warningCount + 1
            else
                r.ImGui_Bullet(ctx)
            end
            Settings.deleteMethod = Gui.setting('combo', 'Deletion Method',
                "When deleting files, which method should be used?",
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

function App.loop()
    checkPerform()
    r.ImGui_PushFont(Gui.ctx, Gui.st.fonts.default)
    App.open = App.drawMainWindow()
    r.ImGui_PopFont(Gui.ctx)
    -- checkExternalCommand()
    if App.open then
        r.defer(App.loop)
    else
        r.ImGui_DestroyContext(Gui.ctx)
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
    -- app.coPerform = coroutine.create(doPerform)
    r.defer(App.loop)
end

---------------------------------------
-- IDEAS and TODOS --------------------
---------------------------------------

-- TODO export current settings as action
-- TODO handle subprojects (collect? render?)
-- TODO show total savings and close script upon completion
-- TODO handle unsaved project
-- TODO handle empty project
-- TODO handle switching projects
-- TODO (later): figure out section
-- TODO check for "nothing to do" if no relevant setting was checked
-- ? check handling of missing files
-- ? test only active takes
-- ? test (updated) cleaning media folder
-- ? check project media folder at project root
-- ? test project media folder in root project folder (or in external folder?)

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
