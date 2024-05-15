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
    --     if select(1, r.ImGui_CalcTextSize(ctx, text)) > maxWidth then
    --         -- text = text:gsub(' ', '')
    --         text = (select(1, r.ImGui_CalcTextSize(ctx, text)) <= maxWidth) and text or text:gsub('[^%a%d]', '')
    --         text = (select(1, r.ImGui_CalcTextSize(ctx, text)) <= maxWidth) and text or text:gsub(' ', '')
    --         text = (select(1, r.ImGui_CalcTextSize(ctx, text)) <= maxWidth) and text or text:gsub('a', '')
    --         text = (select(1, r.ImGui_CalcTextSize(ctx, text)) <= maxWidth) and text or text:gsub('e', '')
    --         text = (select(1, r.ImGui_CalcTextSize(ctx, text)) <= maxWidth) and text or text:gsub('i', '')
    --         text = (select(1, r.ImGui_CalcTextSize(ctx, text)) <= maxWidth) and text or text:gsub('o', '')
    --         text = (select(1, r.ImGui_CalcTextSize(ctx, text)) <= maxWidth) and text or text:gsub('u', '')
    --         text = (select(1, r.ImGui_CalcTextSize(ctx, text)) <= maxWidth) and text or text:gsub('%d', '')
    --         for i = 1, text:len() do
    --             if select(1, r.ImGui_CalcTextSize(ctx, text:sub(1, i))) > maxWidth then
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
        if r.ImGui_IsItemDeactivated(ctx) and app.faderReset[id] then
            app.faderReset[id] = nil
            return true, default
        elseif reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            app.faderReset[id] = true
        end
        return false, value
    end

    function app.refreshWindowSize()
        if app.page then
            local max_w, max_h = r.ImGui_Viewport_GetSize(r.ImGui_GetMainViewport(app.gui.ctx))
            local width = app.page.width
            local minHeight = app.page.minHeight or 0
            if app.page == APP_PAGE.MIXER then
                width, minHeight = app.calculateMixerSize()
            end
            app.gui.mainWindow.min_w, app.gui.mainWindow.min_h = math.max(width, app.page.width),
                (minHeight or app.page.minHeight or 0) or 0
            app.gui.mainWindow.max_w, app.gui.mainWindow.max_h = r.ImGui_Viewport_GetSize(r.ImGui_GetMainViewport(app
                .gui.ctx))
            r.ImGui_SetNextWindowSize(app.gui.ctx, math.max(width, app.page.width), app.page.height or 0)
            app.refreshWindowSizeOnNextFrame = false
        end
    end

    function app.handlePageSwitch()
        if app.pageSwitched then
            app.framesSincePageSwitch = (app.framesSincePageSwitch or 0) + 1
        end
        if app.framesSincePageSwitch == 1 then
            -- r.ShowConsoleMsg('framesSincePageSwitch == 1 \n')
            --  different pages have different window sizes. since the window gets automatically resized, we need to set the size to a small value first
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
        local wPadding = r.ImGui_GetStyleVar(app.gui.ctx, r.ImGui_StyleVar_WindowPadding())
        local vSpacing = select(2, r.ImGui_GetStyleVar(app.gui.ctx, r.ImGui_StyleVar_ItemSpacing()))
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
            r.ImGui_GetStyleVar(app.gui.ctx, r.ImGui_StyleVar_WindowPadding()) +
            (shouldScroll and r.ImGui_GetStyleVar(app.gui.ctx, r.ImGui_StyleVar_ScrollbarSize()) or 0)
        return w, h
    end

    function app.drawMixer()
        local ctx = app.gui.ctx
        local altPressed = OD_IsKeyPressed('alt')
        local ctrlPressed = OD_IsKeyPressed('control')
        local showEnvelopeButtons = OD_IsKeyPressed('shift')
        -- if OD_IsKeyPressed('control') then
        --     r.ShowConsoleMsg('command pressed\n')
        -- end

        app.db:sync()
        r.ImGui_PushFont(ctx, app.gui.st.fonts.small)
        local drawSend = function(s, part, label)
            local drawFader = function(h)
                if showEnvelopeButtons then
                    app.gui:pushColors(app.gui.st.col.buttons.env)
                    r.ImGui_PushFont(ctx, app.gui.st.fonts.icons_large)
                    if r.ImGui_Button(ctx, ICONS.ENVELOPE .. '##vEnvelope', app.settings.current.sendWidth, h) then
                        s:toggleVolEnv()
                    end
                    app:setHoveredHint('main', s.name .. ' - Show/hide send volume envelope')
                    r.ImGui_PopFont(ctx)
                    app.gui:popColors(app.gui.st.col.buttons.env)
                else
                    local v = OD_dBFromValue(s.vol)
                    local mw = r.ImGui_GetMouseWheel(ctx)
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
                    local rv, v2 = r.ImGui_VSliderDouble(ctx, '##v', app.settings.current.sendWidth,
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
                    if r.ImGui_IsItemHovered(ctx) then
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
            end

            local drawPan = function()
                local mw = r.ImGui_GetMouseWheel(ctx)
                r.ImGui_SetNextItemWidth(ctx, app.settings.current.sendWidth)
                app.gui:pushStyles(app.gui.st.vars.pan)
                local rv, v2 = r.ImGui_SliderDouble(ctx, '##p', s.pan, -1, 1, '')
                app:setHoveredHint('main', s.name .. ' - Send panning')
                app.gui:popStyles(app.gui.st.vars.pan)
                if rv then
                    s:setPan(v2)
                end
                local shouldReset, v2 = app.resetOnDoubleClick('p' .. s.order, v2, 0.0)

                if rv or shouldReset then
                    s:setPan(v2)
                end
                if r.ImGui_IsItemHovered(ctx) then
                    if mw ~= 0 then
                        local scale = .01
                        local newV = s.pan + (app.settings.current.mouseScrollReversed and -mw or mw) * scale
                        s:setPan(newV)
                    end
                end
            end
            local drawVolLabel = function()
                local v = OD_dBFromValue(s.vol)
                r.ImGui_SetNextItemWidth(ctx, app.settings.current.sendWidth)
                if v == app.minSendVol then
                    v = '-inf'
                end
                local rv, v3 = r.ImGui_DragDouble(ctx, '##db', v, 0, 0, 0, '%.2f')
                app:setHoveredHint('main', s.name .. ' - Send volume. Double-click to enter exact amount.')
                if rv then
                    s:setVolDB(v3)
                end
            end

            local drawSoloMute = function()
                local w = app.settings.current.sendWidth / 2 -
                    r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) / 2

                if showEnvelopeButtons then
                    app.gui:pushColors(app.gui.st.col.buttons.mute[false])
                    r.ImGui_PushFont(ctx, app.gui.st.fonts.icons_small) -- TODO: Fix Icon
                    if r.ImGui_Button(ctx, ICONS.ENVELOPE .. '##mEnvelope' .. s.order, w) then
                        s:toggleMuteEnv()
                    end
                    r.ImGui_PopFont(ctx)
                    app:setHoveredHint('main', s.name .. ' - Show/hide send mute envelope')
                    app.gui:popColors(app.gui.st.col.buttons.mute[false])
                else
                    app.gui:pushColors(app.gui.st.col.buttons.mute[s.mute])
                    if r.ImGui_Button(ctx, 'M##mute' .. s.order, w) then
                        s:setMute(not s.mute)
                    end
                    app:setHoveredHint('main', s.name .. ' - Mute send')
                    app.gui:popColors(app.gui.st.col.buttons.mute[s.mute])
                end
                r.ImGui_SameLine(ctx)
                local soloed = app.db.soloedSends[s.order] ~= nil
                app.gui:pushColors(app.gui.st.col.buttons.solo[soloed])
                if r.ImGui_Button(ctx, 'S##solo' .. s.order, w) then
                    s:setSolo(not soloed, not r.ImGui_IsKeyDown(ctx, app.gui.keyModCtrlCmd))
                end
                app:setHoveredHint('main', s.name .. ' - Solo send')
                app.gui:popColors(app.gui.st.col.buttons.solo[soloed])
            end
            local drawPhaseSoloDefeat = function()
                local w = app.settings.current.sendWidth / 2 -
                    r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) / 2
                app.gui:pushColors(app.gui.st.col.buttons.polarity[s.polarity])
                r.ImGui_PushFont(ctx, app.gui.st.fonts.icons_small)
                if r.ImGui_Button(ctx, 'O##polarity' .. s.order, w) then
                    s:setPolarity(not s.polarity)
                end
                app:setHoveredHint('main', s.name .. ' - Invert polarity')
                r.ImGui_PopFont(ctx)
                app.gui:popColors(app.gui.st.col.buttons.mute[s.mute])
                r.ImGui_SameLine(ctx)
                local soloed = app.db.soloedSends[s.order] ~= nil
                app.gui:pushColors(app.gui.st.col.buttons.solo[soloed])
                if r.ImGui_Button(ctx, 'D##solodefeat' .. s.order, w) then -- TODO: Implement
                    s:setSolo(not soloed, not r.ImGui_IsKeyDown(ctx, app.gui.keyModCtrlCmd))
                end
                app:setHoveredHint('main', s.name .. ' - Solo defeat')
                app.gui:popColors(app.gui.st.col.buttons.solo[soloed])
            end
            local drawModeButton = function()
                local w = app.settings.current.sendWidth
                app.gui:pushColors(app.gui.st.col.buttons.mode[s.mode])
                local label = s.mode == 0 and "post" or (s.mode == 1 and "preFX" or "postFX")
                if r.ImGui_Button(ctx, label .. '##mode' .. s.order, w) then
                    s:setMode(s.mode == 0 and 1 or (s.mode == 1 and 3 or 0))
                end
                app:setHoveredHint('main', s.name .. ' - Send placement')
                app.gui:popColors(app.gui.st.col.buttons.mode[s.mode])
            end
            local drawMIDIRouteButtons = function()
                local w = app.settings.current.sendWidth
                app.gui:pushColors(app.gui.st.col.buttons.route)
                r.ImGui_BeginGroup(ctx)
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
                if r.ImGui_Button(ctx, label .. '##srcMidiChan' .. s.order, w) then
                    r.ImGui_OpenPopup(ctx, '##srcMidiChanMenu' .. s.order)
                end
                app:setHoveredHint('main', s.name .. ' - Source MIDI channel')
                if s.midiSrcBus == 255 then
                    label = ''
                    r.ImGui_BeginDisabled(ctx)
                elseif s.midiDestChn == 0 and s.midiDestBus == 0 then
                    label = 'all'
                elseif s.midiDestChn == 0 and s.midiDestBus > 0 then
                    label = 'B' .. s.midiDestBus
                elseif s.midiDestBus > 0 then
                    label = s.midiDestBus .. '/' .. s.midiDestChn
                else
                    label = s.midiDestChn
                end

                if r.ImGui_Button(ctx, label .. '##destMidiChan' .. s.order, w) then
                    r.ImGui_OpenPopup(ctx, '##destMidiChanMenu' .. s.order)
                end
                app:setHoveredHint('main', s.name .. ' - Destination MIDI channel')
                if s.midiSrcBus == 255 then
                    r.ImGui_EndDisabled(ctx)
                end
                app.gui:popColors(app.gui.st.col.buttons.route)
                r.ImGui_EndGroup(ctx)
                if r.ImGui_BeginPopup(ctx, '##srcMidiChanMenu' .. s.order) then
                    if r.ImGui_MenuItem(ctx, 'None', nil, s.midiSrcBus == 255, true) then s:setMidiRouting(0x1f, 0xff) end
                    if r.ImGui_MenuItem(ctx, 'All', nil, s.midiSrcChn == 0 and s.midiSrcBus == 0, true) then
                        s:setMidiRouting(0, 0)
                    end
                    r.ImGui_SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 100, 300.0, nil)
                    for i = 1, 16 do
                        if r.ImGui_MenuItem(ctx, i, nil, s.midiSrcChn == i, true) then
                            s:setMidiRouting(1, 0)
                        end
                    end
                    for bus = 1, 128 do
                        r.ImGui_SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 100, 300.0, nil)
                        if r.ImGui_BeginMenu(ctx, "Bus " .. bus) then
                            if r.ImGui_MenuItem(ctx, 'All', nil, s.midiSrcChn == 0 and s.midiSrcBus == bus, true) then
                                s:setMidiRouting(0, bus)
                            end
                            for i = 1, 16 do
                                if r.ImGui_MenuItem(ctx, i, nil, s.midiSrcChn == i and s.midiSrcBus == bus, true) then
                                    s:setMidiRouting(i, bus)
                                end
                            end
                            r.ImGui_EndMenu(ctx)
                        end
                    end
                    app.focusMainReaperWindow = false
                    r.ImGui_EndPopup(ctx)
                end
                r.ImGui_SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 300, 300.0, nil)
                if r.ImGui_BeginPopup(ctx, '##destMidiChanMenu' .. s.order) then
                    if r.ImGui_MenuItem(ctx, 'All', nil, s.midiDestChn == 0 and s.midiDestBus == 0, true) then
                        s:setMidiRouting(nil, nil, 0, 0)
                    end
                    r.ImGui_SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 100, 300.0, nil)
                    for i = 1, 16 do
                        if r.ImGui_MenuItem(ctx, i, nil, s.midiDestChn == i, true) then
                            s:setMidiRouting(nil, nil, 1, 0)
                        end
                    end
                    for bus = 1, 128 do
                        r.ImGui_SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 100, 300.0, nil)
                        if r.ImGui_BeginMenu(ctx, "Bus " .. bus) then
                            if r.ImGui_MenuItem(ctx, 'All', nil, s.midiDestChn == 0 and s.midiDestBus == bus, true) then
                                s:setMidiRouting(nil, nil, 0, bus)
                            end
                            for i = 1, 16 do
                                if r.ImGui_MenuItem(ctx, i, nil, s.midiDestChn == i and s.midiDestBus == bus, true) then
                                    s:setMidiRouting(nil, nil, i, bus)
                                end
                            end
                            r.ImGui_EndMenu(ctx)
                        end
                    end
                    app.focusMainReaperWindow = false
                    r.ImGui_EndPopup(ctx)
                end
            end
            local drawRouteButtons = function()
                local w = app.settings.current.sendWidth
                app.gui:pushColors(app.gui.st.col.buttons.route)
                r.ImGui_BeginGroup(ctx)
                if r.ImGui_Button(ctx, SRC_CHANNELS[s.srcChan].label .. '##srcChan' .. s.order, w) then
                    r.ImGui_OpenPopup(ctx, '##srcChanMenu' .. s.order)
                end
                app:setHoveredHint('main', s.name .. ' - Source audio channel')
                local label = s.srcChan == -1 and '' or
                    (s.destChan < 1024) and (s.destChan + 1 .. '/' .. (s.destChan + SRC_CHANNELS[s.srcChan].numChannels)) or
                    s.destChan + 1 - 1024
                if s.srcChan == -1 then
                    r.ImGui_BeginDisabled(ctx)
                end
                if r.ImGui_Button(ctx, label .. '##destChan' .. s.order, w) then
                    r.ImGui_OpenPopup(ctx, '##destChanMenu' .. s.order)
                end
                app:setHoveredHint('main', s.name .. ' - Destination audio channel')
                if s.srcChan == -1 then
                    r.ImGui_EndDisabled(ctx)
                end
                app.gui:popColors(app.gui.st.col.buttons.route)
                r.ImGui_EndGroup(ctx)
                if r.ImGui_BeginPopup(ctx, '##srcChanMenu' .. s.order) then
                    if r.ImGui_MenuItem(ctx, 'None', nil, s.srcChan == -1, true) then s:setSrcChan(-1) end
                    r.ImGui_SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 100, 300.0, nil)
                    if r.ImGui_BeginMenu(ctx, 'Mono source') then
                        for i = 0, NUM_CHANNELS - 1 do
                            if r.ImGui_MenuItem(ctx, SRC_CHANNELS[i + 1024].label, nil, s.srcChan == i + 1024, true) then
                                s:setSrcChan(i + 1024)
                            end
                        end
                        r.ImGui_EndMenu(ctx)
                    end
                    r.ImGui_SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 100, 300.0, nil)
                    if r.ImGui_BeginMenu(ctx, 'Stereo source') then
                        for i = 0, NUM_CHANNELS - 2 do
                            if r.ImGui_MenuItem(ctx, SRC_CHANNELS[i].label, nil, s.srcChan == i, true) then
                                s:setSrcChan(
                                    i)
                            end
                        end
                        r.ImGui_EndMenu(ctx)
                    end
                    r.ImGui_SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 300, 300.0, nil)
                    if r.ImGui_BeginMenu(ctx, 'Multichannel source') then
                        for numChannels = 4, NUM_CHANNELS, 2 do
                            r.ImGui_SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 100, 300.0, nil)
                            if r.ImGui_BeginMenu(ctx, numChannels .. " channels") then
                                for i = 0, NUM_CHANNELS - numChannels do
                                    if r.ImGui_MenuItem(ctx, SRC_CHANNELS[numChannels * 512 + i].label, nil, s.srcChan == numChannels * 512 + i, true) then
                                        s:setSrcChan(numChannels * 512 + i)
                                    end
                                end
                                r.ImGui_EndMenu(ctx)
                            end
                        end
                        r.ImGui_EndMenu(ctx)
                    end
                    app.focusMainReaperWindow = false
                    r.ImGui_EndPopup(ctx)
                end
                r.ImGui_SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 300, 300.0, nil)
                if r.ImGui_BeginPopup(ctx, '##destChanMenu' .. s.order) then
                    r.ImGui_SetNextWindowSizeConstraints(ctx, 0.0, 0.0, 100, 300.0, nil)
                    if r.ImGui_BeginMenu(ctx, 'Downmix to mono') then
                        for i = 0, NUM_CHANNELS - 1 do
                            if r.ImGui_MenuItem(ctx, tostring(i + 1), nil, s.destChan == i + 1024, true) then
                                s:setDestChan(i + 1024)
                            end
                        end
                        r.ImGui_EndMenu(ctx)
                    end

                    for i = 0, NUM_CHANNELS - SRC_CHANNELS[s.srcChan].numChannels do
                        if r.ImGui_MenuItem(ctx, (i + 1 .. '/' .. (i + SRC_CHANNELS[s.srcChan].numChannels)), nil, s.destChan == i, true) then
                            s:setDestChan(i)
                        end
                    end
                    app.focusMainReaperWindow = false
                    r.ImGui_EndPopup(ctx)
                end
            end

            local drawSendName = function()
                local shortName, shortened = app.minimizeText(s.name, app.settings.current.sendWidth)
                if r.ImGui_BeginChild(ctx, '##' .. part .. 'Label', app.settings.current.sendWidth, app.gui.TEXT_BASE_HEIGHT, nil) then
                    r.ImGui_AlignTextToFramePadding(ctx)
                    r.ImGui_Text(ctx, shortName)
                    r.ImGui_EndChild(ctx)
                end
                app:setHoveredHint('main', s.name)
            end

            local drawInserts = function()
                for i, insert in OD_PairsByOrder(s.destInserts) do
                    local colors = insert.offline and app.gui.st.col.insert.offline or
                        (not insert.enabled and app.gui.st.col.insert.disabled or app.gui.st.col.insert.enabled)
                    app.gui:pushColors(colors)
                    local rv = r.ImGui_Button(ctx, insert.shortName .. "##" .. i, app.settings.current.sendWidth)
                    app.gui:popColors(colors)
                    if rv then
                        -- r.Undo_BeginBlock()
                        if r.ImGui_IsKeyDown(ctx, app.gui.keyModCtrlCmd) and r.ImGui_IsKeyDown(ctx, r.ImGui_Mod_Shift()) then
                            insert:setOffline(not insert.offline)
                        elseif r.ImGui_IsKeyDown(ctx, r.ImGui_Mod_Shift()) then
                            insert:setEnabled(not insert.enabled)
                        elseif r.ImGui_IsKeyDown(ctx, r.ImGui_Mod_Alt()) then
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
                r.ImGui_PushFont(ctx, app.gui.st.fonts.icons_small)
                if r.ImGui_Button(ctx, "P##", app.settings.current.sendWidth) then
                    app.temp.addFxToSend = s
                    app.setPage(APP_PAGE.SEARCH_FX)
                end
                app:setHoveredHint('main', 'Add FX')
                r.ImGui_PopFont(ctx)
                app.gui:popColors(app.gui.st.col.insert.add)
            end

            r.ImGui_PushID(ctx, 's' .. (s and s.order or -1))
            -- r.ImGui_BeginGroup(ctx)

            local faderHeight = math.max(app.settings.current.minFaderHeight,
                select(2, r.ImGui_GetContentRegionAvail(ctx)) - app.gui.TEXT_BASE_HEIGHT_SMALL * 2 -
                app.gui.mainWindow.hintHeight - r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) * 2)
            if s == nil then
                if r.ImGui_BeginChild(ctx, '##' .. part .. 'Label', app.settings.current.sendWidth, select(2, r.ImGui_CalcTextSize(ctx, label or '')), nil, r.ImGui_WindowFlags_NoScrollbar() | r.ImGui_WindowFlags_NoScrollWithMouse()) then
                    if label then
                        r.ImGui_AlignTextToFramePadding(ctx)
                        r.ImGui_Text(ctx, label or '')
                    end
                    r.ImGui_EndChild(ctx)
                end
            else
                if part == 'inserts' then
                    drawInserts()
                elseif part == 'pan' then
                    drawPan()
                elseif part == 'solomute' then
                    drawSoloMute()
                elseif part == 'phasesolod' then
                    drawPhaseSoloDefeat()
                elseif part == 'modebutton' then
                    drawModeButton()
                elseif part == 'routebutton' then
                    drawRouteButtons()
                elseif part == 'midiroutebutton' then
                    drawMIDIRouteButtons()
                elseif part == 'fader' then
                    drawFader(faderHeight)
                elseif part == 'volLabel' then
                    drawVolLabel()
                elseif part == 'sendName' then
                    drawSendName()
                end
            end

            r.ImGui_PopID(ctx)
            -- r.ImGui_EndGroup(ctx)
        end

        if next(app.db.sends) then
            local h = -app.gui.vars.framePaddingY +
                (app.settings.current.maxNumInserts + 1) *
                (app.gui.TEXT_BASE_HEIGHT_SMALL + app.gui.vars.framePaddingY * 2)
            -- local rv =
            if r.ImGui_BeginChild(ctx, "##inserts", nil, h, false) then
                for i, s in OD_PairsByOrder(app.db.sends) do
                    r.ImGui_BeginGroup(ctx)
                    drawSend(s, 'inserts')
                    r.ImGui_EndGroup(ctx)
                    r.ImGui_SameLine(ctx)
                end
                r.ImGui_EndChild(ctx)
            end
            -- r.ImGui_Dummy(ctx, select(1,r.ImGui_GetContentRegionAvail(ctx)), 3)
            r.ImGui_InvisibleButton(ctx, '##separator', select(1, r.ImGui_GetContentRegionAvail(ctx)), 5)

            if r.ImGui_IsItemHovered(ctx) then
                app:setHoveredHint('main', 'Scroll to change number of inserts')
                r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeNS())
            end
            if r.ImGui_IsItemActive(ctx) then
                r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeNS())
                local value_with_lock_threshold_x, value_with_lock_threshold_y = r.ImGui_GetMouseDragDelta(ctx, 0, 0,
                    r.ImGui_MouseButton_Left())
                if value_with_lock_threshold_y ~= 0 then
                    if value_with_lock_threshold_y > 0 + app.gui.TEXT_BASE_HEIGHT_SMALL then
                        app.settings.current.maxNumInserts = app.settings.current.maxNumInserts + 1
                        r.ImGui_ResetMouseDragDelta(ctx, r.ImGui_MouseButton_Left())
                        app.gui.mainWindow.min_w, app.gui.mainWindow.min_h = app.calculateMixerSize()
                    elseif app.settings.current.maxNumInserts > 0 and value_with_lock_threshold_y < 0 - app.gui.TEXT_BASE_HEIGHT_SMALL then
                        app.settings.current.maxNumInserts = app.settings.current.maxNumInserts - 1
                        r.ImGui_ResetMouseDragDelta(ctx, r.ImGui_MouseButton_Left())
                        app.gui.mainWindow.min_w, app.gui.mainWindow.min_h = app.calculateMixerSize()
                    end
                end
            end
            r.ImGui_SetCursorPosY(ctx,
                r.ImGui_GetCursorPosY(ctx) - 2 - select(2, r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())))
            r.ImGui_Separator(ctx)
            r.ImGui_SetCursorPosY(ctx,
                r.ImGui_GetCursorPosY(ctx) + 2 + select(2, r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())))
            local parts = {
                { name = 'solomute',    label = 'S/M' },
                { name = 'modebutton',  label = 'Mode' },
                { name = 'routebutton', label = 'Route' }, -- TODO: Maybe make alternate and implement envelopes instead
                { name = 'pan',         label = 'Pan' },
                { name = 'fader',       label = 'Send\nVolume' },
                { name = 'volLabel' },
                { name = 'sendName' }
            }
            if altPressed then -- TODO: Implement
                parts = {
                    { name = 'phasesolod',      label = 'Phase/Solo Defeat' },
                    { name = 'modebutton',      label = 'Mode' },
                    { name = 'midiroutebutton', label = 'Route' },
                    { name = 'pan',             label = 'Pan' },
                    { name = 'fader',           label = 'Send\nVolume' },
                    { name = 'volLabel' },
                    { name = 'sendName' }
                }
            end
            r.ImGui_BeginGroup(ctx)
            for j, part in ipairs(parts) do
                r.ImGui_BeginGroup(ctx)
                for i, s in OD_PairsByOrder(app.db.sends) do
                    drawSend(s, part.name)
                    r.ImGui_SameLine(ctx)
                end
                r.ImGui_EndGroup(ctx)
            end
            r.ImGui_EndGroup(ctx)
            r.ImGui_SameLine(ctx)
        end

        r.ImGui_PopFont(ctx)
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
            for i, asset in ipairs(app.db.assets) do
                if app.page == APP_PAGE.SEARCH_SEND or (app.page == APP_PAGE.SEARCH_FX and asset.type ~= ASSETS.TRACK) then
                    -- local numResults = #app.temp.searchResults
                    local pat = OD_EscapePattern(query):lower():gsub('%% ', '.-[ -_]')
                    if string.find(asset.name:lower(), pat) then
                        local result = OD_DeepCopy(asset)
                        table.insert(app.temp.searchResults, result)
                    end
                end
            end
            app.temp.highlightedResult = #app.temp.searchResults > 0 and 1 or nil
            app.temp.lastInvisibleGroup = nil
        end

        local ctx = app.gui.ctx
        local selectedResult = nil
        local w = select(1, r.ImGui_GetContentRegionAvail(ctx))

        r.ImGui_PushFont(ctx, app.gui.st.fonts.medium)
        app.gui:pushStyles(app.gui.st.vars.searchWindow)
        app.gui:pushColors(app.gui.st.col.searchWindow)
        app.temp.searchResults = app.temp.searchResults or {}

        if app.pageSwitched then
            app.db:init()
            filterResults('')
            r.ImGui_SetKeyboardFocusHere(ctx, 0)
        end
        r.ImGui_SetNextItemWidth(ctx, w)
        local rv, searchInput = r.ImGui_InputText(ctx, "##searchInput", app.temp.searchInput)

        local h = select(2, r.ImGui_GetContentRegionAvail(ctx)) - app.gui.mainWindow.hintHeight
        local maxSearchResults = math.floor(h / (app.gui.TEXT_BASE_HEIGHT_LARGE))

        if rv then filterResults(searchInput) end

        if r.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
            app.setPage(APP_PAGE.MIXER)
        elseif app.temp.highlightedResult then
            if r.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_DownArrow()) then
                if app.temp.highlightedResult < #app.temp.searchResults then
                    app.temp.highlightedResult = app.temp.highlightedResult + 1
                    app.temp.checkScrollDown = true
                end
            elseif r.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_UpArrow()) then
                if app.temp.highlightedResult > 1 then
                    app.temp.highlightedResult = app.temp.highlightedResult - 1
                    app.temp.checkScrollUp = true
                end
            elseif r.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) then
                if app.temp.highlightedResult then
                    selectedResult = app.temp.searchResults[app.temp.highlightedResult]
                else
                    r.ImGui_SetKeyboardFocusHere(ctx, -1)
                end
            end
        end

        local selectableFlags = r.ImGui_SelectableFlags_SpanAllColumns() | r.ImGui_SelectableFlags_AllowItemOverlap()
        local outer_size = { 0.0, app.gui.TEXT_BASE_HEIGHT_LARGE * h / (app.gui.TEXT_BASE_HEIGHT_LARGE) }
        local tableFlags = r.ImGui_TableFlags_ScrollY()
        local lastGroup = nil

        local upperRowY = select(2, r.ImGui_GetCursorScreenPos(ctx))
        if r.ImGui_BeginTable(ctx, "##searchResults", 1, tableFlags, table.unpack(outer_size)) then
            r.ImGui_TableSetupScrollFreeze(ctx, 0, 1)
            local firstVisibleAbsIndex = nil
            local highlightedY = 0
            local foundInvisibleGroup = false
            local absIndex = 0
            for i, result in ipairs(app.temp.searchResults) do
                -- local currentScreenY =

                if result.group ~= lastGroup then
                    r.ImGui_TableNextRow(ctx, r.ImGui_TableRowFlags_None(), app.gui.TEXT_BASE_HEIGHT_LARGE)
                    absIndex = absIndex + 1
                    r.ImGui_TableSetColumnIndex(ctx, 0)
                    r.ImGui_SeparatorText(ctx, i == 1 and app.temp.lastInvisibleGroup or result.group)
                    lastGroup = result.group
                    if select(2, r.ImGui_GetCursorScreenPos(ctx)) <= upperRowY + app.gui.TEXT_BASE_HEIGHT_LARGE then
                        app.temp.lastInvisibleGroup = result.group
                        foundInvisibleGroup = true
                    end
                end
                if not foundInvisibleGroup then app.temp.lastInvisibleGroup = nil end
                r.ImGui_PushID(ctx, 'result' .. i)
                r.ImGui_TableNextRow(ctx, r.ImGui_TableRowFlags_None(), app.gui.TEXT_BASE_HEIGHT_LARGE)
                absIndex = absIndex + 1
                r.ImGui_TableSetColumnIndex(ctx, 0)
                if (app.temp.checkScrollDown or app.temp.checkScrollUp) and i == app.temp.highlightedResult then
                    highlightedY = select(2, r.ImGui_GetCursorScreenPos(ctx))
                end
                if r.ImGui_Selectable(ctx, '', i == app.temp.highlightedResult, selectableFlags, 0, 0) then
                    selectedResult = result
                end
                r.ImGui_SameLine(ctx)

                if result.type == ASSETS.TRACK then
                    r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx))
                    local size = app.gui.TEXT_BASE_HEIGHT_LARGE - app.gui.vars.framePaddingY * 2
                    r.ImGui_ColorButton(ctx, 'color', r.ImGui_ColorConvertNative(result.color),
                        r.ImGui_ColorEditFlags_NoAlpha() | r.ImGui_ColorEditFlags_NoBorder() |
                        r.ImGui_ColorEditFlags_NoTooltip(), size, size)
                    r.ImGui_SameLine(ctx)
                end

                if result.group == FAVORITE_GROUP then
                    -- app.gui:pushColors(app.gui.st.col.searchWindow.favorite)
                    r.ImGui_PushFont(ctx, app.gui.st.fonts.icons_medium)
                    app.gui:pushColors(app.gui.st.col.search.favorite)
                    r.ImGui_Text(ctx, ICONS.STAR)
                    app.gui:popColors(app.gui.st.col.search.favorite)
                    r.ImGui_PopFont(ctx)
                    r.ImGui_SameLine(ctx)
                end

                -- draw result name, highlighting the search query

                local text = result.name
                r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(), 0.0, 0.0)
                for foundText in searchInput:gmatch('([^%s]+)') do
                    local pat = nocase('(.-[ -_]-)(' .. OD_EscapePattern(foundText) .. ')(.*)')
                    for notFound, found, rest in text:gmatch(pat) do
                        if notFound then
                            r.ImGui_Text(ctx, notFound)
                            r.ImGui_SameLine(ctx)
                        end
                        if found then
                            app.gui:pushColors(app.gui.st.col.search.highlight)
                            r.ImGui_Text(ctx, found)
                            app.gui:popColors(app.gui.st.col.search.highlight)
                            r.ImGui_SameLine(ctx)
                        end
                        text = rest
                    end
                end
                r.ImGui_Text(ctx, text)
                r.ImGui_PopStyleVar(ctx)

                r.ImGui_PopID(ctx)
            end
            if app.temp.checkScrollDown and highlightedY > upperRowY + maxSearchResults * app.gui.TEXT_BASE_HEIGHT_LARGE then
                r.ImGui_SetScrollY(ctx,
                    r.ImGui_GetScrollY(ctx) +
                    (highlightedY - (upperRowY + (maxSearchResults - 1) * app.gui.TEXT_BASE_HEIGHT_LARGE) - 1))
                app.temp.checkScrollDown = false
            end
            if app.temp.checkScrollUp and highlightedY <= upperRowY + app.gui.TEXT_BASE_HEIGHT_LARGE then
                r.ImGui_SetScrollY(ctx,
                    r.ImGui_GetScrollY(ctx) - (upperRowY - highlightedY + 1) - app.gui.TEXT_BASE_HEIGHT_LARGE - 1)
                app.temp.checkScrollUp = false
            end
            r.ImGui_EndTable(ctx)
        end
        app.gui:popColors(app.gui.st.col.searchWindow)
        app.gui:popStyles(app.gui.st.vars.searchWindow)
        r.ImGui_PopFont(ctx)
        if selectedResult then
            if app.page == APP_PAGE.SEARCH_FX then
                app.temp.addFxToSend:addInsert(selectedResult.load)
                app.temp.addFxToSend = nil
            elseif app.page == APP_PAGE.SEARCH_SEND then
                app.db:createNewSend(selectedResult)
            end
            -- TODO: handle going back to a "no track" or "no sends" page
            app.setPage(APP_PAGE.MIXER)
        end
    end

    function app.drawErrorNoSends()
        local ctx = app.gui.ctx
        app.db:sync()
        local w, h =
            select(1, r.ImGui_GetContentRegionAvail(ctx)) -
            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()) * 2,
            select(2, r.ImGui_GetContentRegionAvail(ctx)) - app.gui.mainWindow.hintHeight
        if r.ImGui_BeginChild(ctx, '##noSends', w, h, nil, nil) then
            r.ImGui_Dummy(ctx, w, h)
            r.ImGui_SetCursorPos(ctx, w / 2,
                h / 2 - app.gui.TEXT_BASE_HEIGHT * 2)
            app.gui:drawSadFace(4, app.gui.st.basecolors.main)
            local text = 'No sends here yet...'
            r.ImGui_SetCursorPos(ctx, (w - r.ImGui_CalcTextSize(ctx, text)) / 2,
                h / 2 + app.gui.TEXT_BASE_HEIGHT)
            r.ImGui_Text(ctx, text)
            text = 'Why not add one?'
            r.ImGui_SetCursorPos(ctx, w / 2 - r.ImGui_CalcTextSize(ctx, text) / 2, h / 2 + app.gui.TEXT_BASE_HEIGHT * 3)
            r.ImGui_Text(ctx, text)
            r.ImGui_SameLine(ctx)
            r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) + app.gui.TEXT_BASE_HEIGHT / 2)
            r.ImGui_SetCursorPosX(ctx, r.ImGui_GetCursorPosX(ctx) + app.gui.TEXT_BASE_WIDTH)
            local x, y = r.ImGui_GetCursorScreenPos(ctx)
            local sz = app.gui.TEXT_BASE_WIDTH * 1.5
            local th = 3
            r.ImGui_DrawList_AddBezierQuadratic(app.gui.draw_list,
                x, y, app.temp.addSendBtnX, y, app.temp.addSendBtnX, app.temp.addSendBtnY,
                app.gui.st.basecolors.main, th, 20)
            r.ImGui_DrawList_AddBezierQuadratic(app.gui.draw_list,
                app.temp.addSendBtnX, app.temp.addSendBtnY,
                app.temp.addSendBtnX + sz / 1.5, app.temp.addSendBtnY + sz * 1.5,
                app.temp.addSendBtnX + sz, app.temp.addSendBtnY + sz * 1.5,
                app.gui.st.basecolors.main, th, 20)
            r.ImGui_DrawList_AddBezierQuadratic(app.gui.draw_list,
                app.temp.addSendBtnX, app.temp.addSendBtnY,
                app.temp.addSendBtnX - sz / 1.5, app.temp.addSendBtnY + sz * 1.5,
                app.temp.addSendBtnX - sz, app.temp.addSendBtnY + sz * 1.5,
                app.gui.st.basecolors.main, th, 20)

            r.ImGui_EndChild(ctx)
        end
    end

    function app.drawErrorNoTrack()
        local ctx = app.gui.ctx
        app.db:sync()
        local w, h =
            select(1, r.ImGui_GetContentRegionAvail(ctx)) -
            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()) * 2,
            select(2, r.ImGui_GetContentRegionAvail(ctx)) - app.gui.mainWindow.hintHeight
        if r.ImGui_BeginChild(ctx, '##noTrack', w, h, nil, nil) then
            r.ImGui_Dummy(ctx, w, h)
            r.ImGui_SetCursorPos(ctx, w / 2,
                h / 2 - app.gui.TEXT_BASE_HEIGHT * 1)
            app.gui:drawSadFace(4, app.gui.st.basecolors.main)
            local text = 'No track selected'
            r.ImGui_SetCursorPos(ctx, (w - r.ImGui_CalcTextSize(ctx, text)) / 2,
                h / 2 + app.gui.TEXT_BASE_HEIGHT * 2)
            r.ImGui_Text(ctx, text)
            -- app.gui:popStyles(app.gui.st.vars.bigButton)
            r.ImGui_EndChild(ctx)
        end
    end

    function app.iconButton(ctx, icon)
        local x, y = r.ImGui_GetCursorPos(ctx)
        local w = select(1, r.ImGui_CalcTextSize(ctx, ICONS[(icon):upper()])) + app.gui.vars.framePaddingX * 2
        local clicked
        if r.ImGui_InvisibleButton(ctx, '##menuBtn' .. icon, w, r.ImGui_GetTextLineHeightWithSpacing(ctx)) then
            clicked = true
        end
        if r.ImGui_IsItemHovered(ctx) and not r.ImGui_IsItemActive(ctx) then
            app.gui:pushColors(app.gui.st.col.buttons.topBarIcon.hovered)
        elseif r.ImGui_IsItemActive(ctx) then
            app.gui:pushColors(app.gui.st.col.buttons.topBarIcon.active)
        else
            app.gui:pushColors(app.gui.st.col.buttons.topBarIcon.default)
        end
        r.ImGui_SetCursorPos(ctx, x + app.gui.vars.framePaddingX, y + app.gui.vars.framePaddingY)
        r.ImGui_Text(ctx, tostring(ICONS[icon:upper()]))
        app.gui:popColors(app.gui.st.col.buttons.topBarIcon.default)
        r.ImGui_SetCursorPos(ctx, x + w, y)
        return clicked
    end

    function app.drawTopBar()
        local function beginRightIconMenu(ctx, buttons)
            local windowEnd = app.gui.mainWindow.size[1] - r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()) -
                ((r.ImGui_GetScrollMaxY(app.gui.ctx) > 0) and r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ScrollbarSize()) or 0)
            r.ImGui_SameLine(ctx, windowEnd)
            r.ImGui_PushFont(ctx, app.gui.st.fonts.icons_large)
            local clicked = nil
            local prevX = r.ImGui_GetCursorPosX(ctx) - r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())
            for i, btn in ipairs(buttons) do
                local w = select(1, r.ImGui_CalcTextSize(ctx, ICONS[(btn.icon):upper()])) +
                    app.gui.vars.framePaddingX * 2
                local x = prevX - w - r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())
                prevX = x
                r.ImGui_SetCursorPosX(ctx, x)
                if app.iconButton(ctx, btn.icon) then clicked = btn.icon end
                if app.page == APP_PAGE.NO_SENDS and btn.icon == 'plus' then
                    app.temp.addSendBtnX, app.temp.addSendBtnY = r.ImGui_GetCursorScreenPos(ctx)
                    app.temp.addSendBtnX = app.temp.addSendBtnX - w / 2
                    app.temp.addSendBtnY = app.temp.addSendBtnY + w * 1.5
                end
                app:setHoveredHint('main', btn.hint)
            end
            r.ImGui_PopFont(ctx)
            return clicked ~= nil, clicked
        end


        local ctx = app.gui.ctx
        r.ImGui_BeginGroup(ctx)
        r.ImGui_PushFont(ctx, app.gui.st.fonts.large_bold)
        app.gui:pushColors(app.gui.st.col.title)
        r.ImGui_AlignTextToFramePadding(ctx)
        r.ImGui_Text(ctx, app.scr.name)
        app.gui:popColors(app.gui.st.col.title)
        r.ImGui_PopFont(ctx)
        r.ImGui_PushFont(ctx, app.gui.st.fonts.large)
        r.ImGui_SameLine(ctx)
        r.ImGui_BeginDisabled(ctx)
        local caption = app.db.track and app.db.trackName or ''
        if app.page == APP_PAGE.SEARCH_SEND then
            caption = 'Add Send to track \'' .. app.db.trackName .. '\''
        end
        r.ImGui_Text(ctx, ' ' .. caption)
        r.ImGui_EndDisabled(ctx)
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
        if r.ImGui_IsWindowDocked(ctx) then
            table.insert(menu, { icon = 'undock', hint = 'Undock' })
        else
            if app.settings.current.lastDockId then
                table.insert(menu, { icon = 'dock_down', hint = 'Dock' })
            end
        end
        local rv, btn = beginRightIconMenu(ctx, menu)
        r.ImGui_PopFont(ctx)
        r.ImGui_EndGroup(ctx)
        r.ImGui_Separator(ctx)
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
        r.ImGui_Spacing(ctx)
        r.ImGui_Separator(ctx)
        r.ImGui_Spacing(ctx)
        if col then app.gui:pushColors(app.gui.st.col[col]) end
        r.ImGui_Text(ctx, status)
        if col then app.gui:popColors(app.gui.st.col[col]) end
        app:setHint(window, '')
    end

    function app.drawMainWindow()
        local ctx = app.gui.ctx

        if app.refreshWindowSizeOnNextFrame then
            app.refreshWindowSize()
        end
        if app.gui.mainWindow.dockTo ~= nil then
            r.ImGui_SetNextWindowDockID(ctx, app.gui.mainWindow.dockTo, r.ImGui_Cond_Always())
            app.gui.mainWindow.dockTo = nil
        end

        r.ImGui_SetNextWindowPos(ctx, 100, 100, r.ImGui_Cond_FirstUseEver())
        r.ImGui_SetNextWindowSizeConstraints(app.gui.ctx, app.gui.mainWindow.min_w, app.gui.mainWindow.min_h,
            app.gui.mainWindow.max_w, app.gui.mainWindow.max_h)

        local visible, open = r.ImGui_Begin(ctx, "###mainWindow",
            true,
            r.ImGui_WindowFlags_NoCollapse() |
            r.ImGui_WindowFlags_NoTitleBar() | app.page.windowFlags)
        -- r.ImGui_WindowFlags_NoResize()
        app.gui.mainWindow.pos = { r.ImGui_GetWindowPos(ctx) }
        app.gui.mainWindow.size = { r.ImGui_GetWindowSize(ctx) }

        if r.ImGui_GetWindowDockID(ctx) ~= app.gui.mainWindow.dockId then
            app.refreshWindowSizeOnNextFrame = true
            app.gui.mainWindow.dockId = r.ImGui_GetWindowDockID(ctx)
            if app.gui.mainWindow.dockId ~= 0 then
                app.settings.current.lastDockId = app.gui.mainWindow.dockId
                app.settings:save()
            end
        end
        if visible then
            app.drawTopBar()

            if app.page == APP_PAGE.MIXER then
                app.drawMixer()
                if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then open = false end
            elseif app.page == APP_PAGE.SEARCH_SEND or app.page == APP_PAGE.SEARCH_FX then
                app.drawSearch()
            elseif app.page == APP_PAGE.NO_SENDS then
                app.drawErrorNoSends()
            elseif app.page == APP_PAGE.NO_TRACK then
                app.drawErrorNoTrack()
            end
            app.drawHint('main')
            r.ImGui_End(ctx)
        end
        return open
    end

    function app.loop()
        local ctx = app.gui.ctx
        app.handlePageSwitch()

        app.gui:pushColors(app.gui.st.col.main)
        app.gui:pushStyles(app.gui.st.vars.main)
        r.ImGui_PushFont(ctx, app.gui.st.fonts.large)
        app.open = app.drawMainWindow()
        r.ImGui_PopFont(ctx)
        app.gui:popColors(app.gui.st.col.main)
        app.gui:popStyles(app.gui.st.vars.main)
        if app.page.giveFocus and r.ImGui_IsWindowFocused(ctx, r.ImGui_FocusedFlags_AnyWindow()) and app.focusMainReaperWindow and not (reaper.ImGui_IsPopupOpen(ctx, r.ImGui_PopupFlags_AnyPopup()) or reaper.ImGui_IsAnyMouseDown(ctx) or reaper.ImGui_IsAnyItemActive(ctx) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape())) then
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
