-- @noindex
-- @description Minimize Audio Files
-- @author Oded Davidov
-- @version 0.0.1
-- @donation: https://paypal.me/odedda
-- @license GNU GPL v3
-- @provides
--   [nomain] ../../Resources/Common/*
--   [nomain] lib/*

r = reaper

local p = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]
dofile(p .. '../../Resources/Common/Common.lua')

r.ClearConsole()

scr, os_is = OD_Init()

--dofile(p .. 'lib/Settings.lua')
--dofile(p .. 'lib/Minimize.lua')
--dofile(p .. 'lib/Gui.lua')

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

    function checkPerform()
        if app.coPerform then
            if coroutine.status(app.coPerform) == "suspended" then
                coroutine.resume(app.coPerform)
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
        -- other loading here...

        if visible then
            -- draw...
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