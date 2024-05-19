-- @description Send Buddy
-- @author Oded Davidov
-- @version 0.0.0
-- @donation https://paypal.me/odedda
-- @license GNU GPL v3
-- @provides
--   [nomain] ../../Resources/Common/* > Resources/Common/
--   [nomain] ../../Resources/Common/Helpers/* > Resources/Common/Helpers/
--   [nomain] ../../Resources/Common/Helpers/App/* > Resources/Common/Helpers/App/
--   [nomain] ../../Resources/Common/Helpers/Reaper/* > Resources/Common/Helpers/Reaper/
--   [nomain] ../../Resources/Fonts/* > Resources/Fonts/
--   [nomain] ../../Resources/Icons/* > Resources/Icons/
--   [nomain] lib/**

---------------------------------------
-- SETUP ------------------------------
---------------------------------------
r = reaper
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
ImGui = require 'imgui' '0.9.1'

local p = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]

if r.file_exists(p .. 'Resources/Common/Common.lua') then
    dofile(p .. 'Resources/Common/Common.lua')
else
    dofile(p .. '../../Resources/Common/Common.lua')
end

r.ClearConsole()

OD_Init()

if OD_PrereqsOK({
        reaimgui_version = '0.9.1',
        sws = true,            -- required for SNM_SetIntConfigVar - setting config vars (max file size limitation and autosave options)
        js_version = 1.310,    -- required for JS_Dialog_BrowseForFolder
        reaper_version = 7.01, -- required for APPLYFX_FORMAT and OPENCOPY_CFGIDX
    }) then
    dofile(p .. 'lib/Constants.lua')
    dofile(p .. 'lib/Settings.lua')
    dofile(p .. 'lib/Gui.lua')
    dofile(p .. 'lib/Db.lua')
    dofile(p .. 'lib/Texts.lua')

    -- @noindex

    local app = OD_Gui_App:new({
        mediaFiles = {},
        revert = {},
        restore = {},
        popup = {},
        faderReset = {},
        focusMainReaperWindow = true
    })

    local logger = OD_Logger:new({
        level = OD_Logger.LOG_LEVEL.ERROR,
        output = OD_Logger.LOG_OUTPUT.CONSOLE
    })

    local gui = SM_Gui:new({})

    app:connect('gui', gui)
    app:connect('logger', logger)
    app:connect('scr', Scr)
    app:connect('db', DB)
    app:init()
    logger:init()

    -- logger:logTable(OD_Logger.LOG_LEVEL.DEBUG,'scr',app.scr)

    app.gui:init();

    function app:checkProjectChange(force)
        if force or OD_DidProjectGUIDChange() then
            local projPath, projFileName = OD_GetProjectPaths()
            logger:setLogFile(projPath .. Scr.name .. '_' .. projFileName .. '.log')
            self.reset()
        end
    end

    -- local settings = SM_Settings
    app:connect('settings', SM_Settings)

    ---------------------------------------
    -- Functions --------------------------
    ---------------------------------------


    function app.minimizeText(text, maxWidth)
        if app.maxTextLen == nil then
            local i = 0
            while app.gui.TEXT_BASE_WIDTH * i <= maxWidth do
                i = i + 1
            end
            app.maxTextLen = i
        end
        if text:len() > app.maxTextLen then
            -- text = text:gsub(' ', '')
            text = text:len() <= app.maxTextLen and text or text:gsub('[^%a%d]', '')
            text = text:len() <= app.maxTextLen and text or text:gsub(' ', '')
            text = text:len() <= app.maxTextLen and text or text:gsub('a', '')
            text = text:len() <= app.maxTextLen and text or text:gsub('e', '')
            text = text:len() <= app.maxTextLen and text or text:gsub('i', '')
            text = text:len() <= app.maxTextLen and text or text:gsub('o', '')
            text = text:len() <= app.maxTextLen and text or text:gsub('u', '')
            text = text:len() <= app.maxTextLen and text or text:gsub('%d', '')
            return text:sub(1, app.maxTextLen), true
        end
        return text, false
    end

    -- function app.minimizeText2(text, maxWidth)
    -- local ctx = app.gui.ctx
    --     if select(1, ImGui.CalcTextSize(ctx, text)) > maxWidth then
    --         -- text = text:gsub(' ', '')
    --         text = (select(1, ImGui.CalcTextSize(ctx, text)) <= maxWidth) and text or text:gsub('[^%a%d]', '')
    --         text = (select(1, ImGui.CalcTextSize(ctx, text)) <= maxWidth) and text or text:gsub(' ', '')
    --         text = (select(1, ImGui.CalcTextSize(ctx, text)) <= maxWidth) and text or text:gsub('a', '')
    --         text = (select(1, ImGui.CalcTextSize(ctx, text)) <= maxWidth) and text or text:gsub('e', '')
    --         text = (select(1, ImGui.CalcTextSize(ctx, text)) <= maxWidth) and text or text:gsub('i', '')
    --         text = (select(1, ImGui.CalcTextSize(ctx, text)) <= maxWidth) and text or text:gsub('o', '')
    --         text = (select(1, ImGui.CalcTextSize(ctx, text)) <= maxWidth) and text or text:gsub('u', '')
    --         text = (select(1, ImGui.CalcTextSize(ctx, text)) <= maxWidth) and text or text:gsub('%d', '')
    --         for i = 1, text:len() do
    --             if select(1, ImGui.CalcTextSize(ctx, text:sub(1, i))) > maxWidth then
    --                 text = text:sub(1, i - 1)
    --             end
    --         end
    --         return text:sub(1, app.maxTextLen), true
    --     end
    --     return text, false
    -- end

    ---------------------------------------
    -- UI ---------------------------------
    ---------------------------------------

    function app.resetOnDoubleClick(id, value, default)
        local ctx = app.gui.ctx
        if ImGui.IsItemDeactivated(ctx) and app.faderReset[id] then
            app.faderReset[id] = nil
            return true, default
        elseif ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
            app.faderReset[id] = true
        end
        return false, value
    end

    function app.refreshWindowSize()
        if app.page then
            local max_w, max_h = ImGui.Viewport_GetSize(ImGui.GetMainViewport(app.gui.ctx))
            local width = app.page.width
            local minHeight = app.page.minHeight or 0
            if app.page == APP_PAGE.MIXER then
                width, minHeight = app.calculateMixerSize()
            end
            app.gui.mainWindow.min_w, app.gui.mainWindow.min_h = math.max(width, app.page.width),
                (minHeight or app.page.minHeight or 0) or 0
            app.gui.mainWindow.max_w, app.gui.mainWindow.max_h = ImGui.Viewport_GetSize(ImGui.GetMainViewport(app
                .gui.ctx))
            ImGui.SetNextWindowSize(app.gui.ctx, math.max(width, app.page.width), app.page.height or 0)
            app.refreshWindowSizeOnNextFrame = false
        end
    end

    function app.resetTemp()
        app.temp.confirmation = {}
    end

    function app.handlePageSwitch()
        if app.pageSwitched then
            app.resetTemp()
            app.framesSincePageSwitch = (app.framesSincePageSwitch or 0) + 1
        end
        if app.framesSincePageSwitch == 1 then
            app.refreshWindowSize()
        end
        if app.framesSincePageSwitch and app.framesSincePageSwitch > 1 then
            app.pageSwitched = false
            app.framesSincePageSwitch = nil
        end
    end

    function app.setPage(page)
        if page ~= app.page then
            app.page = page
            app.pageSwitched = true
        end
    end

    function app.calculateMixerSize()
        -- top bar
        local wPadding = ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_WindowPadding)
        local vSpacing = select(2, ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_ItemSpacing))
        local topBarH = app.gui.TEXT_BASE_HEIGHT_LARGE + vSpacing * 2 + 1
        -- inserts
        local insertsH = (app.settings.current.maxNumInserts + 1) *
            (app.gui.TEXT_BASE_HEIGHT_SMALL + app.gui.vars.framePaddingY * 2)
        local separatorH = 5
        -- sends
        local sendsH = 7 * (app.gui.TEXT_BASE_HEIGHT_SMALL + app.gui.vars.framePaddingY * 2) + vSpacing +
            app.settings.current.minFaderHeight
        local h = wPadding + topBarH + insertsH + vSpacing + separatorH + vSpacing + sendsH + vSpacing +
            app.gui.mainWindow.hintHeight + wPadding

        local shouldScroll = app.db.maxNumInserts > app.settings.current.maxNumInserts
        local w = app.settings.current.sendWidth * (app.db.numSends + 1) +
            ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_WindowPadding) +
            (shouldScroll and ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_ScrollbarSize) or 0)
        return w, h
    end

    function app.drawMixer()
        local ctx = app.gui.ctx
        local altPressed = OD_IsKeyPressed('alt')
        local ctrlPressed = OD_IsKeyPressed('control')
        local shiftPressed = OD_IsKeyPressed('shift')

        app.db:sync()
        ImGui.PushFont(ctx, app.gui.st.fonts.small)

        local drawSend = function(s, part)
            local drawDummy = function(col, h)
                app.gui:pushColors(col)
                ImGui.BeginDisabled(ctx)
                ImGui.Button(ctx, '##dummy', app.settings.current.sendWidth, h)
                ImGui.EndDisabled(ctx)
                app:setHoveredHint('main', ' ')
                app.gui:popColors(col)
            end
            local drawEnvVolButton = function(h)
                app.gui:pushColors(app.gui.st.col.buttons.env)
                -- ImGui.PushFont(ctx, app.gui.st.fonts.icons_large)
                if ImGui.Button(ctx, 'VOL\nENV##vEnvelope', app.settings.current.sendWidth, h) then
                    s:toggleVolEnv()
                end
                app:setHoveredHint('main', s.name .. ' - Show/hide send volume envelope')
                -- ImGui.PopFont(ctx)
                app.gui:popColors(app.gui.st.col.buttons.env)
            end
            local drawDeleteSend = function()
                local deleteTimeOut = 3
                local confirmationKey = s.order
                if app.temp.confirmation[confirmationKey] then
                    if reaper.time_precise() - app.temp.confirmation[confirmationKey] > deleteTimeOut then
                        app.temp.confirmation[confirmationKey] = nil
                    else
                        app.gui:pushColors(app.gui.st.col.buttons.deleteSend)
                        if ImGui.Button(ctx, 'Sure?##deleteSend', app.settings.current.sendWidth) then
                            s:delete()
                        end
                        app:setHoveredHint('main', s.name .. ' - Click again to confirm')
                        app.gui:popColors(app.gui.st.col.buttons.deleteSend)
                    end
                end
                if app.temp.confirmation[confirmationKey] == nil then -- not else because then I miss a frame after the timeout just passed
                    app.gui:pushColors(app.gui.st.col.buttons.env)
                    ImGui.PushFont(ctx, app.gui.st.fonts.icons_small)
                    if ImGui.Button(ctx, ICONS.TRASH .. '##deleteSend', app.settings.current.sendWidth) then
                        app.temp.confirmation[confirmationKey] = reaper.time_precise()
                    end
                    app:setHoveredHint('main', s.name .. ' - Delete send')
                    ImGui.PopFont(ctx)
                    app.gui:popColors(app.gui.st.col.buttons.env)
                end
            end
            local drawEnvMuteButton = function()
                app.gui:pushColors(app.gui.st.col.buttons.mute[false])
                -- ImGui.PushFont(ctx, app.gui.st.fonts.icons_small)     -- TODO: Fix Icon
                if ImGui.Button(ctx, 'MUTE\nENV##mEnvelope' .. s.order, app.settings.current.sendWidth, app.gui.TEXT_BASE_HEIGHT_SMALL * 2.5 + select(2, ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)) * 2.5) then
                    s:toggleMuteEnv()
                end
                -- ImGui.PopFont(ctx)
                app:setHoveredHint('main', s.name .. ' - Show/hide send mute envelope')
                app.gui:popColors(app.gui.st.col.buttons.mute[false])
            end
            local drawEnvPanButton = function()
                app.gui:pushColors(app.gui.st.col.buttons.route)
                -- ImGui.PushFont(ctx, app.gui.st.fonts.icons_small)     -- TODO: Fix Icon
                if ImGui.Button(ctx, 'PAN\nENV##pEnvelope' .. s.order, app.settings.current.sendWidth, app.gui.TEXT_BASE_HEIGHT_SMALL * 2.5 + select(2, ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)) * 2.5) then
                    s:togglePanEnv()
                end
                -- ImGui.PopFont(ctx)
                app:setHoveredHint('main', s.name .. ' - Show/hide send pan envelope')
                app.gui:popColors(app.gui.st.col.buttons.route)
            end
            local drawFader = function(h)
                local v = OD_dBFromValue(s.vol)
                local mw = ImGui.GetMouseWheel(ctx)
                local scaledV = (v >= app.settings.current.scaleLevel) and (v / app.settings.current.scaleFactor) or
                    (v * app.settings.current.scaleFactor)
                if v >= app.settings.current.scaleLevel then
                    scaledV = v * app.settings.current.scaleFactor
                else
                    scaledV = app.settings.current.scaleLevel * app.settings.current.scaleFactor +
                        (v - app.settings.current.scaleLevel) /
                        ((app.settings.current.minSendVol - app.settings.current.scaleLevel) / (app.settings.current.minSendVol - (app.settings.current.scaleLevel * app.settings.current.scaleFactor)))
                end
                app.gui:pushStyles(app.gui.st.vars.vol)
                local rv, v2 = ImGui.VSliderDouble(ctx, '##v', app.settings.current.sendWidth,
                    h,
                    scaledV,
                    app.settings.current.minSendVol,
                    app.settings.current.maxSendVol * app.settings.current.scaleFactor,
                    '')
                app:setHoveredHint('main', s.name .. ' - Send volume')
                app.gui:popStyles(app.gui.st.vars.vol)
                if (v2 < app.settings.current.scaleLevel * app.settings.current.scaleFactor) then
                    v2 = app.settings.current.scaleLevel +
                        (v2 - app.settings.current.scaleLevel * app.settings.current.scaleFactor) *
                        (app.settings.current.minSendVol - app.settings.current.scaleLevel) /
                        (app.settings.current.minSendVol - (app.settings.current.scaleLevel * app.settings.current.scaleFactor))
                else
                    v2 = v2 / app.settings.current.scaleFactor
                end

                local shouldReset, v2 = app.resetOnDoubleClick('s' .. s.order, v2, 0.0)

                if rv or shouldReset then
                    s:setVolDB(v2)
                end
                if ImGui.IsItemHovered(ctx) then
                    if mw ~= 0 then
                        local scale = .2
                        if v > app.settings.current.scaleLevel then
                            scale = 0.05
                        end
                        if ctrlPressed then
                            scale = scale * 0.2
                        end
                        if v < app.settings.current.minSendVol then
                            v = app.settings.current.minSendVol
                        end
                        local newV = v + (app.settings.current.mouseScrollReversed and -mw or mw) * scale
                        s:setVolDB(newV)
                    end
                end
            end

            local drawPan = function()
                local mw = ImGui.GetMouseWheel(ctx)
                ImGui.SetNextItemWidth(ctx, app.settings.current.sendWidth)
                app.gui:pushStyles(app.gui.st.vars.pan)
                local rv, v2 = ImGui.SliderDouble(ctx, '##p', s.pan, -1, 1, '')
                app:setHoveredHint('main', s.name .. ' - Send panning')
                app.gui:popStyles(app.gui.st.vars.pan)
                if rv then
                    s:setPan(v2)
                end
                local shouldReset, v2 = app.resetOnDoubleClick('p' .. s.order, v2, 0.0)

                if rv or shouldReset then
                    s:setPan(v2)
                end
                if ImGui.IsItemHovered(ctx) then
                    if mw ~= 0 then
                        local scale = .01
                        local newV = s.pan + (app.settings.current.mouseScrollReversed and -mw or mw) * scale
                        s:setPan(newV)
                    end
                end
            end
            local drawVolLabel = function()
                local v = OD_dBFromValue(s.vol)
                ImGui.SetNextItemWidth(ctx, app.settings.current.sendWidth)
                local rv, v3 = ImGui.DragDouble(ctx, '##db', v, 0, 0, 0, '%.2f')
                app:setHoveredHint('main', s.name .. ' - Send volume. Double-click to enter exact amount.')
                if rv then
                    s:setVolDB(v3)
                end
            end

            local drawSoloMute = function()
                local w = app.settings.current.sendWidth / 2 -
                    ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing) / 2

                app.gui:pushColors(app.gui.st.col.buttons.mute[s.mute])
                if ImGui.Button(ctx, 'M##mute' .. s.order, w) then
                    s:setMute(not s.mute)
                end
                app:setHoveredHint('main', s.name .. ' - Mute send')
                app.gui:popColors(app.gui.st.col.buttons.mute[s.mute])

                ImGui.SameLine(ctx)
                local soloed = app.db.soloedSends[s.order] ~= nil
                app.gui:pushColors(app.gui.st.col.buttons.solo[soloed])
                if ImGui.Button(ctx, 'S##solo' .. s.order, w) then
                    s:setSolo(not soloed, not ImGui.IsKeyDown(ctx, app.gui.keyModCtrlCmd))
                end
                app:setHoveredHint('main', s.name .. ' - Solo send')
                app.gui:popColors(app.gui.st.col.buttons.solo[soloed])
            end
            local drawPhaseSoloDefeat = function()
                local w = app.settings.current.sendWidth / 2 -
                    ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing) / 2
                app.gui:pushColors(app.gui.st.col.buttons.polarity[s.polarity])
                ImGui.PushFont(ctx, app.gui.st.fonts.icons_small)
                if ImGui.Button(ctx, 'O##polarity' .. s.order, w) then
                    s:setPolarity(not s.polarity)
                end
                app:setHoveredHint('main', s.name .. ' - Invert polarity')
                ImGui.PopFont(ctx)
                app.gui:popColors(app.gui.st.col.buttons.mute[s.mute])
                ImGui.SameLine(ctx)
                local soloed = app.db.soloedSends[s.order] ~= nil
                app.gui:pushColors(app.gui.st.col.buttons.solo[soloed])
                if ImGui.Button(ctx, 'D##solodefeat' .. s.order, w) then -- TODO: Implement
                    s:setSolo(not soloed, not ImGui.IsKeyDown(ctx, app.gui.keyModCtrlCmd))
                end
                app:setHoveredHint('main', s.name .. ' - Solo defeat')
                app.gui:popColors(app.gui.st.col.buttons.solo[soloed])
            end
            local drawModeButton = function()
                local w = app.settings.current.sendWidth
                app.gui:pushColors(app.gui.st.col.buttons.mode[s.mode])
                local label = s.mode == 0 and "post" or (s.mode == 1 and "preFX" or "postFX")
                if ImGui.Button(ctx, label .. '##mode' .. s.order, w) then
                    s:setMode(s.mode == 0 and 1 or (s.mode == 1 and 3 or 0))
                end
                app:setHoveredHint('main', s.name .. ' - Send placement')
                app.gui:popColors(app.gui.st.col.buttons.mode[s.mode])
            end
            local drawMIDIRouteButtons = function()
                local w = app.settings.current.sendWidth
                app.gui:pushColors(app.gui.st.col.buttons.route)
                ImGui.BeginGroup(ctx)
                local label
                if s.midiSrcChn == 0 and s.midiSrcBus == 0 then
                    label = 'all'
                elseif s.midiSrcChn == 0 and s.midiSrcBus > 0 then
                    label = 'B' .. s.midiSrcBus
                elseif s.midiSrcBus > 0 then
                    label = s.midiSrcBus .. '/' .. s.midiSrcChn
                else
                    label = s.midiSrcChn
                end
                if s.midiSrcBus == 255 then
                    label = 'None'
                end
                if ImGui.Button(ctx, label .. '##srcMidiChan' .. s.order, w) then
                    ImGui.OpenPopup(ctx, '##srcMidiChanMenu' .. s.order)
                end
                app:setHoveredHint('main', s.name .. ' - Source MIDI channel')
                if s.midiSrcBus == 255 then
                    label = ''
                    ImGui.BeginDisabled(ctx)
                elseif s.midiDestChn == 0 and s.midiDestBus == 0 then
                    label = 'all'
                elseif s.midiDestChn == 0 and s.midiDestBus > 0 then
                    label = 'B' .. s.midiDestBus
                elseif s.midiDestBus > 0 then
                    label = s.midiDestBus .. '/' .. s.midiDestChn
                else
                    label = s.midiDestChn
                end

                if ImGui.Button(ctx, label .. '##destMidiChan' .. s.order, w) then
                    ImGui.OpenPopup(ctx, '##destMidiChanMenu' .. s.order)
                end
                app:setHoveredHint('main', s.name .. ' - Destination MIDI channel')
                if s.midiSrcBus == 255 then
                    ImGui.EndDisabled(ctx)
                end
                app.gui:popColors(app.gui.st.col.buttons.route)
                ImGui.EndGroup(ctx)
                ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 300, 300.0, nil)
                if ImGui.BeginPopup(ctx, '##srcMidiChanMenu' .. s.order) then
                    if ImGui.MenuItem(ctx, 'None', nil, s.midiSrcBus == 255, true) then s:setMidiRouting(0x1f, 0xff) end
                    if ImGui.MenuItem(ctx, 'All', nil, s.midiSrcChn == 0 and s.midiSrcBus == 0, true) then
                        s:setMidiRouting(0, 0)
                    end
                    ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 100, 300.0, nil)
                    for i = 1, 16 do
                        if ImGui.MenuItem(ctx, tostring(i), nil, s.midiSrcChn == i and s.midiSrcBus == 0, true) then
                            s:setMidiRouting(i, 0)
                        end
                    end
                    for bus = 1, 128 do
                        ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 100, 300.0, nil)
                        if ImGui.BeginMenu(ctx, "Bus " .. bus) then
                            if ImGui.MenuItem(ctx, 'All', nil, s.midiSrcChn == 0 and s.midiSrcBus == bus, true) then
                                s:setMidiRouting(0, bus)
                            end
                            for i = 1, 16 do
                                if ImGui.MenuItem(ctx, tostring(i), nil, s.midiSrcChn == i and s.midiSrcBus == bus, true) then
                                    s:setMidiRouting(i, bus)
                                end
                            end
                            ImGui.EndMenu(ctx)
                        end
                    end
                    app.focusMainReaperWindow = false
                    ImGui.EndPopup(ctx)
                end
                ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 300, 300.0, nil)
                if ImGui.BeginPopup(ctx, '##destMidiChanMenu' .. s.order) then
                    if ImGui.MenuItem(ctx, 'All', nil, s.midiDestChn == 0 and s.midiDestBus == 0, true) then
                        s:setMidiRouting(nil, nil, 0, 0)
                    end
                    ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 100, 300.0, nil)
                    for i = 1, 16 do
                        if ImGui.MenuItem(ctx, tostring(i), nil, s.midiDestChn == i and s.midiDestBus == 0, true) then
                            s:setMidiRouting(nil, nil, i, 0)
                        end
                    end
                    for bus = 1, 128 do
                        ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 100, 300.0, nil)
                        if ImGui.BeginMenu(ctx, "Bus " .. bus) then
                            if ImGui.MenuItem(ctx, 'All', nil, s.midiDestChn == 0 and s.midiDestBus == bus, true) then
                                s:setMidiRouting(nil, nil, 0, bus)
                            end
                            for i = 1, 16 do
                                if ImGui.MenuItem(ctx, tostring(i), nil, s.midiDestChn == i and s.midiDestBus == bus, true) then
                                    s:setMidiRouting(nil, nil, i, bus)
                                end
                            end
                            ImGui.EndMenu(ctx)
                        end
                    end
                    app.focusMainReaperWindow = false
                    ImGui.EndPopup(ctx)
                end
            end
            local drawRouteButtons = function()
                local w = app.settings.current.sendWidth
                app.gui:pushColors(app.gui.st.col.buttons.route)
                ImGui.BeginGroup(ctx)
                if ImGui.Button(ctx, SRC_CHANNELS[s.srcChan].label .. '##srcChan' .. s.order, w) then
                    ImGui.OpenPopup(ctx, '##srcChanMenu' .. s.order)
                end
                app:setHoveredHint('main', s.name .. ' - Source audio channel')
                local label = s.srcChan == -1 and '' or
                    (s.destChan < 1024) and (s.destChan + 1 .. '/' .. (s.destChan + SRC_CHANNELS[s.srcChan].numChannels)) or
                    s.destChan + 1 - 1024
                if s.srcChan == -1 then
                    ImGui.BeginDisabled(ctx)
                end
                if ImGui.Button(ctx, label .. '##destChan' .. s.order, w) then
                    ImGui.OpenPopup(ctx, '##destChanMenu' .. s.order)
                end
                app:setHoveredHint('main', s.name .. ' - Destination audio channel')
                if s.srcChan == -1 then
                    ImGui.EndDisabled(ctx)
                end
                app.gui:popColors(app.gui.st.col.buttons.route)
                ImGui.EndGroup(ctx)
                if ImGui.BeginPopup(ctx, '##srcChanMenu' .. s.order) then
                    if ImGui.MenuItem(ctx, 'None', nil, s.srcChan == -1, true) then s:setSrcChan(-1) end
                    ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 100, 300.0, nil)
                    if ImGui.BeginMenu(ctx, 'Mono source') then
                        for i = 0, NUM_CHANNELS - 1 do
                            if ImGui.MenuItem(ctx, SRC_CHANNELS[i + 1024].label, nil, s.srcChan == i + 1024, true) then
                                s:setSrcChan(i + 1024)
                            end
                        end
                        ImGui.EndMenu(ctx)
                    end
                    ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 100, 300.0, nil)
                    if ImGui.BeginMenu(ctx, 'Stereo source') then
                        for i = 0, NUM_CHANNELS - 2 do
                            if ImGui.MenuItem(ctx, SRC_CHANNELS[i].label, nil, s.srcChan == i, true) then
                                s:setSrcChan(
                                    i)
                            end
                        end
                        ImGui.EndMenu(ctx)
                    end
                    ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 300, 300.0, nil)
                    if ImGui.BeginMenu(ctx, 'Multichannel source') then
                        for numChannels = 4, NUM_CHANNELS, 2 do
                            ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 100, 300.0, nil)
                            if ImGui.BeginMenu(ctx, numChannels .. " channels") then
                                for i = 0, NUM_CHANNELS - numChannels do
                                    if ImGui.MenuItem(ctx, SRC_CHANNELS[numChannels * 512 + i].label, nil, s.srcChan == numChannels * 512 + i, true) then
                                        s:setSrcChan(numChannels * 512 + i)
                                    end
                                end
                                ImGui.EndMenu(ctx)
                            end
                        end
                        ImGui.EndMenu(ctx)
                    end
                    app.focusMainReaperWindow = false
                    ImGui.EndPopup(ctx)
                end
                ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 300, 300.0, nil)
                if ImGui.BeginPopup(ctx, '##destChanMenu' .. s.order) then
                    ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 100, 300.0, nil)
                    if ImGui.BeginMenu(ctx, 'Downmix to mono') then
                        for i = 0, NUM_CHANNELS - 1 do
                            if ImGui.MenuItem(ctx, tostring(i + 1), nil, s.destChan == i + 1024, true) then
                                s:setDestChan(i + 1024)
                            end
                        end
                        ImGui.EndMenu(ctx)
                    end

                    for i = 0, NUM_CHANNELS - SRC_CHANNELS[s.srcChan].numChannels do
                        if ImGui.MenuItem(ctx, (i + 1 .. '/' .. (i + SRC_CHANNELS[s.srcChan].numChannels)), nil, s.destChan == i, true) then
                            s:setDestChan(i)
                        end
                    end
                    app.focusMainReaperWindow = false
                    ImGui.EndPopup(ctx)
                end
            end

            local drawSendName = function()
                local shortName, shortened = app.minimizeText(s.name, app.settings.current.sendWidth)
                if ImGui.BeginChild(ctx, '##' .. part.name .. 'Label', app.settings.current.sendWidth, app.gui.TEXT_BASE_HEIGHT, nil) then
                    ImGui.AlignTextToFramePadding(ctx)
                    ImGui.Text(ctx, shortName)
                    ImGui.EndChild(ctx)
                end
                app:setHoveredHint('main', s.name)
            end

            local drawInserts = function()
                for i, insert in OD_PairsByOrder(s.destInserts) do
                    local colors = insert.offline and app.gui.st.col.insert.offline or
                        (not insert.enabled and app.gui.st.col.insert.disabled or app.gui.st.col.insert.enabled)
                    app.gui:pushColors(colors)
                    local rv = ImGui.Button(ctx, insert.shortName .. "##" .. i, app.settings.current.sendWidth)
                    app.gui:popColors(colors)
                    if rv then
                        -- r.Undo_BeginBlock()
                        if ImGui.IsKeyDown(ctx, app.gui.keyModCtrlCmd) and ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
                            insert:setOffline(not insert.offline)
                        elseif ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
                            insert:setEnabled(not insert.enabled)
                        elseif ImGui.IsKeyDown(ctx, ImGui.Mod_Alt) then
                            insert:delete()
                        else
                            if insert:toggleShow() then app.focusMainReaperWindow = false end
                        end
                        -- r.Undo_EndBlock("Change",0)
                    end
                    local statusHint = insert.offline and ' (Offline)' or (not insert.enabled and ' (Bypassed)' or '')
                    local showHint = 'Click to show/hide, '
                    local offlineHint = (app.gui.descModCtrlCmd .. '-shift-click to' .. (insert.offline and ' make FX online, ' or ' make FX offline, '))
                    local bypassHint = ('shift-click to' .. (insert.enabled and ' bypass, ' or ' unbypass, '))
                    local deleteHint = (app.gui.descModAlt .. '-click to delete.')
                    app:setHoveredHint('main', string.format('%s%s. %s',
                        insert.name,
                        statusHint,
                        string.format("%s%s%s%s",
                            insert.offline and '' or showHint,
                            insert.offline and '' or bypassHint,
                            offlineHint,
                            deleteHint):gsub('^%l', string.upper)))
                end
                app.gui:pushColors(app.gui.st.col.insert.add)
                ImGui.PushFont(ctx, app.gui.st.fonts.icons_small)
                if ImGui.Button(ctx, "P##", app.settings.current.sendWidth) then
                    app.temp.addFxToSend = s
                    app.setPage(APP_PAGE.SEARCH_FX)
                end
                app:setHoveredHint('main', 'Add FX')
                ImGui.PopFont(ctx)
                app.gui:popColors(app.gui.st.col.insert.add)
            end

            ImGui.PushID(ctx, 's' .. (s and s.order or -1))
            -- ImGui.BeginGroup(ctx)

            local faderHeight = math.max(app.settings.current.minFaderHeight,
                select(2, ImGui.GetContentRegionAvail(ctx)) - app.gui.TEXT_BASE_HEIGHT_SMALL * 2 -
                app.gui.mainWindow.hintHeight - ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing) * 2)

            if part.name == 'inserts' then
                drawInserts()
            elseif part.name == 'dummy' then
                drawDummy(part.color)
            elseif part.name == 'dummyFader' then
                drawDummy(app.gui.st.col.buttons.env, faderHeight)
            elseif part.name == 'pan' then
                drawPan()
            elseif part.name == 'envmute' then
                drawEnvMuteButton()
            elseif part.name == 'solomute' then
                drawSoloMute()
            elseif part.name == 'phasesolod' then
                drawPhaseSoloDefeat()
            elseif part.name == 'modebutton' then
                drawModeButton()
            elseif part.name == 'routebutton' then
                drawRouteButtons()
            elseif part.name == 'midiroutebutton' then
                drawMIDIRouteButtons()
            elseif part.name == 'envpan' then
                drawEnvPanButton()
            elseif part.name == 'fader' then
                drawFader(faderHeight)
            elseif part.name == 'deletesend' then
                drawDeleteSend()
            elseif part.name == 'envvol' then
                drawEnvVolButton(faderHeight)
            elseif part.name == 'volLabel' then
                drawVolLabel()
            elseif part.name == 'sendName' then
                drawSendName()
            end

            ImGui.PopID(ctx)
            -- ImGui.EndGroup(ctx)
        end

        ImGui.BeginGroup(ctx)
        if next(app.db.sends) then
            local h = -app.gui.vars.framePaddingY +
                (app.settings.current.maxNumInserts + 1) *
                (app.gui.TEXT_BASE_HEIGHT_SMALL + app.gui.vars.framePaddingY * 2)
            -- local rv =
            if ImGui.BeginChild(ctx, "##inserts", nil, h, ImGui.ChildFlags_None) then
                for i, s in OD_PairsByOrder(app.db.sends) do
                    ImGui.BeginGroup(ctx)
                    drawSend(s, { name = 'inserts' })
                    ImGui.EndGroup(ctx)
                    ImGui.SameLine(ctx)
                end
                ImGui.EndChild(ctx)
            end
            -- ImGui.Dummy(ctx, select(1,ImGui.GetContentRegionAvail(ctx)), 3)
            ImGui.InvisibleButton(ctx, '##separator', select(1, ImGui.GetContentRegionAvail(ctx)), 5)

            if ImGui.IsItemHovered(ctx) then
                app:setHoveredHint('main', 'Scroll to change number of inserts')
                ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeNS)
            end
            if ImGui.IsItemActive(ctx) then
                ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeNS)
                local value_with_lock_threshold_x, value_with_lock_threshold_y = ImGui.GetMouseDragDelta(ctx, nil, nil,
                    ImGui.MouseButton_Left)
                if value_with_lock_threshold_y ~= 0 then
                    if value_with_lock_threshold_y > 0 + app.gui.TEXT_BASE_HEIGHT_SMALL then
                        app.settings.current.maxNumInserts = app.settings.current.maxNumInserts + 1
                        ImGui.ResetMouseDragDelta(ctx, ImGui.MouseButton_Left)
                        app.gui.mainWindow.min_w, app.gui.mainWindow.min_h = app.calculateMixerSize()
                    elseif app.settings.current.maxNumInserts > 0 and value_with_lock_threshold_y < 0 - app.gui.TEXT_BASE_HEIGHT_SMALL then
                        app.settings.current.maxNumInserts = app.settings.current.maxNumInserts - 1
                        ImGui.ResetMouseDragDelta(ctx, ImGui.MouseButton_Left)
                        app.gui.mainWindow.min_w, app.gui.mainWindow.min_h = app.calculateMixerSize()
                    end
                end
            end
            ImGui.SetCursorPosY(ctx,
                ImGui.GetCursorPosY(ctx) - 2 - select(2, ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)))
            ImGui.Separator(ctx)
            ImGui.SetCursorPosY(ctx,
                ImGui.GetCursorPosY(ctx) + 2 + select(2, ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)))
            local parts = {
                { name = 'solomute' },
                { name = 'modebutton' },
                { name = 'routebutton' }, -- TODO: Maybe make alternate and implement envelopes instead
                { name = 'pan' },
                { name = 'fader' },
                { name = 'volLabel' },
                { name = 'sendName' }
            }
            if altPressed then -- TODO: Implement
                parts = {
                    { name = 'phasesolod' },
                    { name = 'dummy',          color = app.gui.st.col.buttons.mode[0] },
                    { name = 'midiroutebutton' },
                    { name = 'dummy',          color = app.gui.st.col.buttons.env },
                    { name = 'dummyFader' },
                    { name = 'deletesend' },
                    { name = 'sendName' }
                }
            end
            if shiftPressed then -- TODO: Implement
                parts = {
                    { name = 'envmute' },
                    { name = 'envpan' },
                    { name = 'envvol' },
                    { name = 'dummy',   color = app.gui.st.col.buttons.env },
                    { name = 'sendName' }
                }
            end
            ImGui.BeginGroup(ctx)
            for j, part in ipairs(parts) do
                ImGui.BeginGroup(ctx)
                for i, s in OD_PairsByOrder(app.db.sends) do
                    drawSend(s, part)
                    ImGui.SameLine(ctx)
                end
                ImGui.EndGroup(ctx)
            end
            ImGui.EndGroup(ctx)
            ImGui.SameLine(ctx)
        end
        ImGui.PopFont(ctx)
        ImGui.EndGroup(ctx)
        if app.hint.main.text == '' then
            app:setHoveredHint('main',
                'Hold ' .. app.gui.descModAlt .. ' for more controls. Hold shift for envelopes.')
        end
    end

    function app.drawSearch()
        local function nocase(s)
            s = string.gsub(s, "%a", function(c)
                return string.format("[%s%s]", string.lower(c),
                    string.upper(c))
            end)
            return s
        end

        local function filterResults(query)
            app.temp.searchInput = query
            app.temp.searchResults = {}
            query = query:gsub('%s+', ' ')
            r.ClearConsole()
            if app.page == APP_PAGE.SEARCH_SEND or (app.page == APP_PAGE.SEARCH_FX and asset.type ~= ASSETS.TRACK) then
                for i, asset in ipairs(app.db.assets) do
                    local foundIndexes = {}
                    local allWordsFound = true
                    for word in query:lower():gmatch("%S+") do
                        local wordFound = false
                        for j, assetWord in ipairs(asset.searchText) do
                            local pos = string.find((assetWord.text):lower(), OD_EscapePattern(word))
                            if pos then
                                foundIndexes[j] = foundIndexes[j] or {}
                                foundIndexes[j][pos] = #word
                                wordFound = true
                            end
                        end
                        if not wordFound then
                            allWordsFound = false
                            break
                        end
                    end
                    if allWordsFound then
                        local result = OD_DeepCopy(asset)
                        result.foundIndexes = foundIndexes
                        table.insert(app.temp.searchResults, result)
                    end
                end
            end
            app.temp.highlightedResult = #app.temp.searchResults > 0 and 1 or nil
            app.temp.lastInvisibleGroup = nil
        end

        local ctx = app.gui.ctx
        local selectedResult = nil
        local w = select(1, ImGui.GetContentRegionAvail(ctx))

        ImGui.PushFont(ctx, app.gui.st.fonts.medium)
        app.gui:pushStyles(app.gui.st.vars.searchWindow)
        app.gui:pushColors(app.gui.st.col.searchWindow)
        app.temp.searchResults = app.temp.searchResults or {}

        if app.pageSwitched then
            -- app.db:init()
            filterResults('')
            ImGui.SetKeyboardFocusHere(ctx, 0)
        end
        ImGui.SetNextItemWidth(ctx, w)
        local rv, searchInput = ImGui.InputText(ctx, "##searchInput", app.temp.searchInput)

        local h = select(2, ImGui.GetContentRegionAvail(ctx)) - app.gui.mainWindow.hintHeight
        local maxSearchResults = math.floor(h / (app.gui.TEXT_BASE_HEIGHT_LARGE))

        if rv then filterResults(searchInput) end

        if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
            app.setPage(APP_PAGE.MIXER)
        elseif app.temp.highlightedResult then
            if ImGui.IsKeyPressed(ctx, ImGui.Key_DownArrow) then
                if app.temp.highlightedResult < #app.temp.searchResults then
                    app.temp.highlightedResult = app.temp.highlightedResult + 1
                    app.temp.checkScrollDown = true
                end
            elseif ImGui.IsKeyPressed(ctx, ImGui.Key_UpArrow) then
                if app.temp.highlightedResult > 1 then
                    app.temp.highlightedResult = app.temp.highlightedResult - 1
                    app.temp.checkScrollUp = true
                end
            elseif ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
                if app.temp.highlightedResult then
                    selectedResult = app.temp.searchResults[app.temp.highlightedResult]
                else
                    ImGui.SetKeyboardFocusHere(ctx, -1)
                end
            end
        end

        local selectableFlags = ImGui.SelectableFlags_SpanAllColumns
        local outer_size = { 0.0, app.gui.TEXT_BASE_HEIGHT_LARGE * h / (app.gui.TEXT_BASE_HEIGHT_LARGE) }
        local tableFlags = ImGui.TableFlags_ScrollY
        local lastGroup = nil

        local upperRowY = select(2, ImGui.GetCursorScreenPos(ctx))
        if ImGui.BeginTable(ctx, "##searchResults", 1, tableFlags, table.unpack(outer_size)) then
            ImGui.TableSetupScrollFreeze(ctx, 0, 1)
            local firstVisibleAbsIndex = nil
            local highlightedY = 0
            local foundInvisibleGroup = false
            local absIndex = 0
            for i, result in ipairs(app.temp.searchResults) do
                -- local currentScreenY =

                if result.group ~= lastGroup then
                    ImGui.TableNextRow(ctx, ImGui.TableRowFlags_None, app.gui.TEXT_BASE_HEIGHT_LARGE)
                    absIndex = absIndex + 1
                    ImGui.TableSetColumnIndex(ctx, 0)
                    ImGui.SeparatorText(ctx, i == 1 and app.temp.lastInvisibleGroup or result.group)
                    lastGroup = result.group
                    if select(2, ImGui.GetCursorScreenPos(ctx)) <= upperRowY + app.gui.TEXT_BASE_HEIGHT_LARGE then
                        app.temp.lastInvisibleGroup = result.group
                        foundInvisibleGroup = true
                    end
                end
                if not foundInvisibleGroup then app.temp.lastInvisibleGroup = nil end
                ImGui.PushID(ctx, 'result' .. i)
                ImGui.TableNextRow(ctx, ImGui.TableRowFlags_None, app.gui.TEXT_BASE_HEIGHT_LARGE)
                absIndex = absIndex + 1
                ImGui.TableSetColumnIndex(ctx, 0)
                if (app.temp.checkScrollDown or app.temp.checkScrollUp) and i == app.temp.highlightedResult then
                    highlightedY = select(2, ImGui.GetCursorScreenPos(ctx))
                end
                if ImGui.Selectable(ctx, '', i == app.temp.highlightedResult, selectableFlags, 0, 0) then
                    selectedResult = result
                end
                ImGui.SameLine(ctx)

                if result.type == ASSETS.TRACK then
                    ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx))
                    local size = app.gui.TEXT_BASE_HEIGHT_LARGE - app.gui.vars.framePaddingY * 2
                    ImGui.ColorButton(ctx, 'color', ImGui.ColorConvertNative(result.color),
                        ImGui.ColorEditFlags_NoAlpha | ImGui.ColorEditFlags_NoBorder |
                        ImGui.ColorEditFlags_NoTooltip, size, size)
                    ImGui.SameLine(ctx)
                end

                if result.group == FAVORITE_GROUP then
                    -- app.gui:pushColors(app.gui.st.col.searchWindow.favorite)
                    ImGui.PushFont(ctx, app.gui.st.fonts.icons_medium)
                    app.gui:pushColors(app.gui.st.col.search.favorite)
                    ImGui.Text(ctx, ICONS.STAR)
                    app.gui:popColors(app.gui.st.col.search.favorite)
                    ImGui.PopFont(ctx)
                    ImGui.SameLine(ctx)
                end

                -- draw result name, highlighting the search query

                ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0.0, 0.0)
                for i, st in ipairs(result.searchText) do
                    if not st.hide then
                        if i > 1 then 
                            ImGui.Text(ctx, ' ')
                            ImGui.SameLine(ctx)
                            app.gui:pushColors(app.gui.st.col.search.secondaryResult)
                        else

                            app.gui:pushColors(app.gui.st.col.search.mainResult)
                        end
                        local curIndex = 1
                        for k, v in pairs(result.foundIndexes[i] or {}) do
                            if curIndex < k then
                                ImGui.Text(ctx, (st.text):sub(curIndex, k - 1))
                                ImGui.SameLine(ctx)
                            end
                            app.gui:pushColors(app.gui.st.col.search.highlight)
                            curIndex = k + v
                            ImGui.Text(ctx, (st.text):sub(k, curIndex - 1))
                            app.gui:popColors(app.gui.st.col.search.highlight)
                            ImGui.SameLine(ctx)
                            -- body
                        end
                        if curIndex < #(st.text) then
                            local txt = (st.text):sub(curIndex, #(st.text))
                            ImGui.Text(ctx, txt)
                            ImGui.SameLine(ctx)
                        end
                        if i > 1 then
                            app.gui:popColors(app.gui.st.col.search.secondaryResult)
                        else
                            app.gui:popColors(app.gui.st.col.search.mainResult)
                        end
                    end
                end
                ImGui.PopStyleVar(ctx)

                ImGui.PopID(ctx)
            end
            if app.temp.checkScrollDown and highlightedY > upperRowY + maxSearchResults * app.gui.TEXT_BASE_HEIGHT_LARGE then
                ImGui.SetScrollY(ctx,
                    ImGui.GetScrollY(ctx) +
                    (highlightedY - (upperRowY + (maxSearchResults - 1) * app.gui.TEXT_BASE_HEIGHT_LARGE) - 1))
                app.temp.checkScrollDown = false
            end
            if app.temp.checkScrollUp and highlightedY <= upperRowY + app.gui.TEXT_BASE_HEIGHT_LARGE then
                ImGui.SetScrollY(ctx,
                    ImGui.GetScrollY(ctx) - (upperRowY - highlightedY + 1) - app.gui.TEXT_BASE_HEIGHT_LARGE - 1)
                app.temp.checkScrollUp = false
            end
            ImGui.EndTable(ctx)
        end
        app.gui:popColors(app.gui.st.col.searchWindow)
        app.gui:popStyles(app.gui.st.vars.searchWindow)
        ImGui.PopFont(ctx)
        if selectedResult then
            if app.page == APP_PAGE.SEARCH_FX then
                app.temp.addFxToSend:addInsert(selectedResult.load)
                app.temp.addFxToSend = nil
            elseif app.page == APP_PAGE.SEARCH_SEND then
                app.db:createNewSend(selectedResult, selectedResult.searchText[1].text)
            end
            -- TODO: handle going back to a "no track" or "no sends" page
            app.setPage(APP_PAGE.MIXER)
        end
    end

    function app.drawErrorNoSends()
        local ctx = app.gui.ctx
        app.db:sync()
        local w, h =
            select(1, ImGui.GetContentRegionAvail(ctx)) -
            ImGui.GetStyleVar(ctx, ImGui.StyleVar_WindowPadding) * 2,
            select(2, ImGui.GetContentRegionAvail(ctx)) - app.gui.mainWindow.hintHeight
        if ImGui.BeginChild(ctx, '##noSends', w, h, nil, nil) then
            ImGui.Dummy(ctx, w, h)
            ImGui.SetCursorPos(ctx, w / 2,
                h / 2 - app.gui.TEXT_BASE_HEIGHT * 2)
            app.gui:drawSadFace(4, app.gui.st.basecolors.main)
            local text = 'No sends here yet...'
            ImGui.SetCursorPos(ctx, (w - ImGui.CalcTextSize(ctx, text)) / 2,
                h / 2 + app.gui.TEXT_BASE_HEIGHT)
            ImGui.Text(ctx, text)
            text = 'Why not add one?'
            ImGui.SetCursorPos(ctx, w / 2 - ImGui.CalcTextSize(ctx, text) / 2, h / 2 + app.gui.TEXT_BASE_HEIGHT * 3)
            ImGui.Text(ctx, text)
            ImGui.SameLine(ctx)
            ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + app.gui.TEXT_BASE_HEIGHT / 2)
            ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + app.gui.TEXT_BASE_WIDTH)
            local x, y = ImGui.GetCursorScreenPos(ctx)
            local sz = app.gui.TEXT_BASE_WIDTH * 1.5
            local th = 3
            ImGui.DrawList_AddBezierQuadratic(app.gui.draw_list,
                x, y, app.temp.addSendBtnX, y, app.temp.addSendBtnX, app.temp.addSendBtnY,
                app.gui.st.basecolors.main, th, 20)
            ImGui.DrawList_AddBezierQuadratic(app.gui.draw_list,
                app.temp.addSendBtnX, app.temp.addSendBtnY,
                app.temp.addSendBtnX + sz / 1.5, app.temp.addSendBtnY + sz * 1.5,
                app.temp.addSendBtnX + sz, app.temp.addSendBtnY + sz * 1.5,
                app.gui.st.basecolors.main, th, 20)
            ImGui.DrawList_AddBezierQuadratic(app.gui.draw_list,
                app.temp.addSendBtnX, app.temp.addSendBtnY,
                app.temp.addSendBtnX - sz / 1.5, app.temp.addSendBtnY + sz * 1.5,
                app.temp.addSendBtnX - sz, app.temp.addSendBtnY + sz * 1.5,
                app.gui.st.basecolors.main, th, 20)

            ImGui.EndChild(ctx)
        end
    end

    function app.drawErrorNoTrack()
        local ctx = app.gui.ctx
        app.db:sync()
        local w, h =
            select(1, ImGui.GetContentRegionAvail(ctx)) -
            ImGui.GetStyleVar(ctx, ImGui.StyleVar_WindowPadding) * 2,
            select(2, ImGui.GetContentRegionAvail(ctx)) - app.gui.mainWindow.hintHeight
        if ImGui.BeginChild(ctx, '##noTrack', w, h, nil, nil) then
            ImGui.Dummy(ctx, w, h)
            ImGui.SetCursorPos(ctx, w / 2,
                h / 2 - app.gui.TEXT_BASE_HEIGHT * 1)
            app.gui:drawSadFace(4, app.gui.st.basecolors.main)
            local text = 'No track selected'
            ImGui.SetCursorPos(ctx, (w - ImGui.CalcTextSize(ctx, text)) / 2,
                h / 2 + app.gui.TEXT_BASE_HEIGHT * 2)
            ImGui.Text(ctx, text)
            -- app.gui:popStyles(app.gui.st.vars.bigButton)
            ImGui.EndChild(ctx)
        end
    end

    function app.iconButton(ctx, icon)
        local x, y = ImGui.GetCursorPos(ctx)
        local w = select(1, ImGui.CalcTextSize(ctx, ICONS[(icon):upper()])) + app.gui.vars.framePaddingX * 2
        local clicked
        if ImGui.InvisibleButton(ctx, '##menuBtn' .. icon, w, ImGui.GetTextLineHeightWithSpacing(ctx)) then
            clicked = true
        end
        if ImGui.IsItemHovered(ctx) and not ImGui.IsItemActive(ctx) then
            app.gui:pushColors(app.gui.st.col.buttons.topBarIcon.hovered)
        elseif ImGui.IsItemActive(ctx) then
            app.gui:pushColors(app.gui.st.col.buttons.topBarIcon.active)
        else
            app.gui:pushColors(app.gui.st.col.buttons.topBarIcon.default)
        end
        ImGui.SetCursorPos(ctx, x + app.gui.vars.framePaddingX, y + app.gui.vars.framePaddingY)
        ImGui.Text(ctx, tostring(ICONS[icon:upper()]))
        app.gui:popColors(app.gui.st.col.buttons.topBarIcon.default)
        ImGui.SetCursorPos(ctx, x + w, y)
        return clicked
    end

    function app.drawTopBar()
        local function beginRightIconMenu(ctx, buttons)
            local windowEnd = app.gui.mainWindow.size[1] - ImGui.GetStyleVar(ctx, ImGui.StyleVar_WindowPadding) -
                ((ImGui.GetScrollMaxY(app.gui.ctx) > 0) and ImGui.GetStyleVar(ctx, ImGui.StyleVar_ScrollbarSize) or 0)
            ImGui.SameLine(ctx, windowEnd)
            ImGui.PushFont(ctx, app.gui.st.fonts.icons_large)
            local clicked = nil
            local prevX = ImGui.GetCursorPosX(ctx) - ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
            for i, btn in ipairs(buttons) do
                local w = select(1, ImGui.CalcTextSize(ctx, ICONS[(btn.icon):upper()])) +
                    app.gui.vars.framePaddingX * 2
                local x = prevX - w - ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
                prevX = x
                ImGui.SetCursorPosX(ctx, x)
                if app.iconButton(ctx, btn.icon) then clicked = btn.icon end
                if app.page == APP_PAGE.NO_SENDS and btn.icon == 'plus' then
                    app.temp.addSendBtnX, app.temp.addSendBtnY = ImGui.GetCursorScreenPos(ctx)
                    app.temp.addSendBtnX = app.temp.addSendBtnX - w / 2
                    app.temp.addSendBtnY = app.temp.addSendBtnY + w * 1.5
                end
                app:setHoveredHint('main', btn.hint)
            end
            ImGui.PopFont(ctx)
            return clicked ~= nil, clicked
        end


        local ctx = app.gui.ctx
        ImGui.BeginGroup(ctx)
        ImGui.PushFont(ctx, app.gui.st.fonts.large_bold)
        app.gui:pushColors(app.gui.st.col.title)
        ImGui.AlignTextToFramePadding(ctx)
        ImGui.Text(ctx, app.scr.name)
        app.gui:popColors(app.gui.st.col.title)
        ImGui.PopFont(ctx)
        ImGui.PushFont(ctx, app.gui.st.fonts.large)
        ImGui.SameLine(ctx)
        ImGui.BeginDisabled(ctx)
        local caption = app.db.track and app.db.track.name or ''
        if app.page == APP_PAGE.SEARCH_SEND then
            caption = 'Add Send to track \'' .. app.db.track.name .. '\''
        end
        ImGui.Text(ctx, ' ' .. caption)
        ImGui.EndDisabled(ctx)
        local menu = {}
        if app.page == APP_PAGE.MIXER or app.page == APP_PAGE.NO_SENDS then
            table.insert(menu, { icon = 'close', hint = 'Close' })
            table.insert(menu, { icon = 'plus', hint = 'Add Send' })
            table.insert(menu, { icon = 'gear', hint = 'Settings' })
        elseif app.page == APP_PAGE.NO_TRACK then
            table.insert(menu, { icon = 'close', hint = 'Close' })
            table.insert(menu, { icon = 'gear', hint = 'Settings' })
        elseif app.page == APP_PAGE.SEARCH_SEND or app.page == APP_PAGE.SEARCH_FX then
            table.insert(menu, { icon = 'right', hint = 'Back' })
            table.insert(menu, { icon = 'gear', hint = 'Settings' })
        end
        if ImGui.IsWindowDocked(ctx) then
            table.insert(menu, { icon = 'undock', hint = 'Undock' })
        else
            if app.settings.current.lastDockId then
                table.insert(menu, { icon = 'dock_down', hint = 'Dock' })
            end
        end
        local rv, btn = beginRightIconMenu(ctx, menu)
        ImGui.PopFont(ctx)
        ImGui.EndGroup(ctx)
        ImGui.Separator(ctx)
        if rv then
            if btn == 'close' then
                app.exit = true
            elseif btn == 'undock' then
                app.gui.mainWindow.dockTo = 0
            elseif btn == 'dock_down' then
                app.gui.mainWindow.dockTo = app.settings.current.lastDockId
            elseif btn == 'plus' then
                app.setPage(APP_PAGE.SEARCH_SEND)
            elseif btn == 'gear' then
                -- app.setPage(APP_PAGE.SETTINGS)
            elseif btn == 'right' then
                app.setPage(APP_PAGE.MIXER)
            end
        end
    end

    function app.drawHint(window)
        local ctx = app.gui.ctx
        local status, col = app:getHint(window)
        ImGui.Spacing(ctx)
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)
        if col then app.gui:pushColors(app.gui.st.col[col]) end
        ImGui.PushFont(ctx, app.gui.st.fonts.default)
        ImGui.Text(ctx, status)
        ImGui.PopFont(ctx)
        if col then app.gui:popColors(app.gui.st.col[col]) end
        app:setHint(window, '')
    end

    function app.drawMainWindow()
        local ctx = app.gui.ctx

        if app.refreshWindowSizeOnNextFrame then
            app.refreshWindowSize()
        end
        if app.gui.mainWindow.dockTo ~= nil then
            ImGui.SetNextWindowDockID(ctx, app.gui.mainWindow.dockTo, ImGui.Cond_Always)
            app.gui.mainWindow.dockTo = nil
        end

        ImGui.SetNextWindowPos(ctx, 100, 100, ImGui.Cond_FirstUseEver)
        ImGui.SetNextWindowSizeConstraints(app.gui.ctx, app.gui.mainWindow.min_w, app.gui.mainWindow.min_h,
            app.gui.mainWindow.max_w, app.gui.mainWindow.max_h)

        local visible, open = ImGui.Begin(ctx, "###mainWindow",
            true,
            ImGui.WindowFlags_NoCollapse |
            ImGui.WindowFlags_NoTitleBar | app.page.windowFlags)
        -- ImGui.WindowFlags_NoResize
        app.gui.mainWindow.pos = { ImGui.GetWindowPos(ctx) }
        app.gui.mainWindow.size = { ImGui.GetWindowSize(ctx) }

        if ImGui.GetWindowDockID(ctx) ~= app.gui.mainWindow.dockId then
            app.refreshWindowSizeOnNextFrame = true
            app.gui.mainWindow.dockId = ImGui.GetWindowDockID(ctx)
            if app.gui.mainWindow.dockId ~= 0 then
                app.settings.current.lastDockId = app.gui.mainWindow.dockId
                app.settings:save()
            end
        end
        if visible then
            app.drawTopBar()

            if app.page == APP_PAGE.MIXER then
                app.drawMixer()
                if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then open = false end
            elseif app.page == APP_PAGE.SEARCH_SEND or app.page == APP_PAGE.SEARCH_FX then
                app.drawSearch()
            elseif app.page == APP_PAGE.NO_SENDS then
                app.drawErrorNoSends()
            elseif app.page == APP_PAGE.NO_TRACK then
                app.drawErrorNoTrack()
            end
            app.drawHint('main')
            ImGui.End(ctx)
        end
        return open
    end

    function app.loop()
        local ctx = app.gui.ctx
        app.handlePageSwitch()

        app.gui:pushColors(app.gui.st.col.main)
        app.gui:pushStyles(app.gui.st.vars.main)
        ImGui.PushFont(ctx, app.gui.st.fonts.large)
        app.open = app.drawMainWindow()
        ImGui.PopFont(ctx)
        app.gui:popColors(app.gui.st.col.main)
        app.gui:popStyles(app.gui.st.vars.main)
        if app.page.giveFocus and ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_AnyWindow) and app.focusMainReaperWindow and not (ImGui.IsPopupOpen(ctx, '', ImGui.PopupFlags_AnyPopup) or ImGui.IsAnyMouseDown(ctx) or ImGui.IsAnyItemActive(ctx) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape)) then
            r.JS_Window_SetFocus(app.gui.reaperHWND)
        else
            app.focusMainReaperWindow = true
        end

        if app.open and not app.exit then
            r.defer(app.loop)
        end
    end

    ---------------------------------------
    -- START ------------------------------
    ---------------------------------------
    -- make it so that script gets terminated on a relaunch
    reaper.set_action_options(1)
    app.settings:load()
    -- app.settings:save()
    app.db:init()
    app.db:sync()
    r.defer(app.loop)
end
