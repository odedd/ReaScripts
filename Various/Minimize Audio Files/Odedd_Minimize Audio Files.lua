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
-- requires sws to remove max file size limitation, as well as for sections
--    if r.GetPlayState()&4==4 then;
--        re aper.MB("Eng:\nYou shouldn't record when using this action.\n\n"..
--                  "Rus:\nВы не должны записывать при использовании этого действия"
--        ,"Oops",0);
--    else;
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
        flags1 = r.ImGui_TableFlags_ScrollX() | r.ImGui_TableFlags_ScrollY() | r.ImGui_TableFlags_BordersOuter() |
            r.ImGui_TableFlags_Borders() | r.ImGui_TableFlags_NoHostExtendX() | r.ImGui_TableFlags_SizingFixedFit()
    }
}

if OD_PrereqsOK({
    reaimgui_version = '0.7',
    sws = true
}) then

    local function doPerform()
        r.Undo_BeginBlock()
        app.showPerformWindow = true
        local pos = r.GetCursorPosition()
        app.mediaFiles = {}
        collectMediaFiles()
        -- local peakOperations = copyItemsToNewTracks(mediaFiles)
        -- r.SetEditCurPos(pos, true, false)
        -- finalizePeaksBuild(peakOperations)
        r.Undo_EndBlock("Minimize Audio Files", 0)
        coroutine.yield('Done', 0, 1)
        return
    end

    function checkPerform()
        if app.coPerform then
            if coroutine.status(app.coPerform) == "suspended" then

                coroutine.resume(app.coPerform)
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
        local bottom_lines = 2
        if open then
            local ctx = gui.ctx
            r.ImGui_SetNextWindowSize(ctx, 700, math.min(1000, select(2, r.ImGui_Viewport_GetSize(
                r.ImGui_GetMainViewport(ctx)))), r.ImGui_Cond_Appearing())
            r.ImGui_SetNextWindowPos(ctx, 100, 100, r.ImGui_Cond_FirstUseEver())
            local visible, open = r.ImGui_Begin(ctx, scr.name .. ' v' .. scr.version .. "##performWindow", true)
            gui.mainWindow = {
                pos = {r.ImGui_GetWindowPos(ctx)},
                size = {r.ImGui_GetWindowSize(ctx)}
            }
            if visible then
                local childHeight = select(2, r.ImGui_GetContentRegionAvail(ctx)) -
                                        (r.ImGui_GetFrameHeightWithSpacing(ctx) * bottom_lines +
                                            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) * 2)
                -- if r.ImGui_CollapsingHeader(ctx,"Stem Selection",false,r.ImGui_TreeNodeFlags_DefaultOpen()) then
                if r.ImGui_BeginChild(ctx, 'mediaFiles', 0, childHeight) then
                    if r.ImGui_BeginTable(ctx, 'table_scrollx', 2, gui.tables.horizontal.flags1) then
                        --- SETUP MATRIX TABLE
                        local parent_open, depth, open_depth = true, 0, 0
                        r.ImGui_TableSetupScrollFreeze(ctx, 1, 2)
                        r.ImGui_TableSetupColumn(ctx, 'File', r.ImGui_TableColumnFlags_NoHide(), nil) -- Make the first column not hideable to match our use of TableSetupScrollFreeze()

                        r.ImGui_TableSetupColumn(ctx, 'Occurances', nil, nil)
                        for filename, filenameinfo in pairsByOrder(app.mediaFiles) do
                            r.ImGui_TableNextRow(ctx)
                            r.ImGui_TableNextColumn(ctx)
                            r.ImGui_Text(ctx, filenameinfo.basename)
                            r.ImGui_TableNextColumn(ctx)
                            r.ImGui_Text(ctx, #filenameinfo.occurrences)
                        end
                        r.ImGui_EndTable(ctx)
                    end
                    r.ImGui_EndChild(ctx)
                end

                r.ImGui_End(ctx)
            end
            return open
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
            if r.ImGui_Button(ctx, 'Minimize Files', r.ImGui_GetContentRegionAvail(ctx)) then
                saveSettings()
                app.coPerform = coroutine.create(doPerform)
            end
        else
            -- r.ImGui_ProgressBar(ctx, (app.perform.pos or 0) / (app.perform.total or 1),
            --     r.ImGui_GetContentRegionAvail(ctx))
        end
    end

    function app.drawMainWindow()
        local ctx = gui.ctx
        r.ImGui_SetNextWindowSize(ctx, 700,
            math.min(1000, select(2, r.ImGui_Viewport_GetSize(r.ImGui_GetMainViewport(ctx)))), r.ImGui_Cond_Appearing())
        r.ImGui_SetNextWindowPos(ctx, 100, 100, r.ImGui_Cond_FirstUseEver())
        local visible, open = r.ImGui_Begin(ctx, scr.name .. ' v' .. scr.version .. "##mainWindow", true,
            r.ImGui_WindowFlags_MenuBar())
        gui.mainWindow = {
            pos = {r.ImGui_GetWindowPos(ctx)},
            size = {r.ImGui_GetWindowSize(ctx)}
        }
        -- db:sync()
        if visible then
            local bottom_lines = 2
            local rv2
            if r.ImGui_BeginMenuBar(ctx) then
                -- r.ImGui_SetCursorPosX(ctx, r.ImGui_GetContentRegionAvail(ctx)- r.ImGui_CalcTextSize(ctx,'Settings'))
                r.ImGui_EndMenuBar(ctx)
            end
            if app.coPerform and coroutine.status(app.coPerform) == 'running' then
                r.ImGui_BeginDisabled(ctx)
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

            --            app.drawMatrices(ctx, bottom_lines)
            if app.coPerform and coroutine.status(app.coPerform) == 'running' then
                r.ImGui_EndDisabled(ctx)
            end
            app.drawBottom(ctx, bottom_lines)
            r.ImGui_End(ctx)
        end
        return open
    end

    function app.loop()
        checkPerform()
        r.ImGui_PushFont(gui.ctx, gui.st.fonts.default)
        app.open = app.drawMainWindow()
        app.showPerformWindow = app.drawPerform(app.showPerformWindow)
        r.ImGui_PopFont(gui.ctx)
        -- checkExternalCommand()
        if app.open then
            r.defer(app.loop)
        else
            r.ImGui_DestroyContext(gui.ctx)
        end
    end

    loadSettings()
    app.coPerform = coroutine.create(doPerform)
    r.defer(app.loop)

end
