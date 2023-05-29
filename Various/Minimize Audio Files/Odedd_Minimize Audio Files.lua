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

if OD_PrereqsOK({
    reaimgui_version = '0.7',
    sws = true
}) then

    app = {
        open = true,
        coPerform = nil,
        perform = {
            status = nil,
            pos = nil,
            total = nil
        },
        hint = {
            main = {},
            settings = {}
        }
    }

    r.Undo_BeginBlock()

    -- local pos = r.GetCursorPosition()
    -- local mediaFiles = collectMediaFiles()
    -- local peakOperations = copyItemsToNewTracks(mediaFiles)
    -- r.SetEditCurPos(pos, true, false)
    -- finalizePeaksBuild(peakOperations)
    r.Undo_EndBlock("Minimize Audio Files", 0)

    function checkPerform()
        if app.coPerform then
            if coroutine.status(app.coPerform) == "suspended" then
                coroutine.resume(app.coPerform)
                -- retval, app.perform.status, app.perform.pos, app.perform.total =
                -- coroutine.resume(app.coPerform, app.stem_to_render)
                -- if not retval then
                --    r.ShowConsoleMsg(app.perform.status)
                -- end
            elseif coroutine.status(app.coPerform) == "dead" then
                app.coPerform = nil
            end
        end
    end

    function app.drawMainWindow(open)
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
--            app.drawMatrices(ctx, bottom_lines)
            if app.coPerform and coroutine.status(app.coPerform) == 'running' then
                r.ImGui_EndDisabled(ctx)
            end
--            app.drawBottom(ctx, bottom_lines)
            r.ImGui_End(ctx)
        end
        return open
    end

    function app.loop()
        checkPerform()
        r.ImGui_PushFont(gui.ctx, gui.st.fonts.default)
        app.open = app.drawMainWindow(open)
        r.ImGui_PopFont(gui.ctx)
        -- checkExternalCommand()
        if app.open then
            r.defer(app.loop)
        else
            r.ImGui_DestroyContext(gui.ctx)
        end
    end

    loadSettings()
    r.defer(app.loop)

end
