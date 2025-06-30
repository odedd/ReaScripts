-- @description Send Buddy
-- @author Oded Davidov
-- @version 1.1.9
-- @donation https://paypal.me/odedda
-- @license GNU GPL v3
-- @about
--   # Send Buddy
--   Send mixer with some tricks up its sleeve.
--   Send buddy allows you to control your sends in a more intuitive way,
--   setting FX on receiving tracks, creating and deleting sends, and more.
--
--   The UI in the search and settings window was inspired by the great work of nvk. Check out his work at https://nvk.tools/
--   Thanks cfillion, sexan, x-raym and all other awesome people in the reaper scripting and development community for their help.
--
--   This script is free, but as always, donations are most welcome at https://paypal.me/odedda :)
-- @provides
--   [nomain] ../../Resources/Common/* > Resources/Common/
--   [nomain] ../../Resources/Common/Helpers/* > Resources/Common/Helpers/
--   [nomain] ../../Resources/Common/Helpers/App/* > Resources/Common/Helpers/App/
--   [nomain] ../../Resources/Common/Helpers/Reaper/* > Resources/Common/Helpers/Reaper/
--   [nomain] ../../Resources/Fonts/* > Resources/Fonts/
--   [nomain] ../../Resources/Icons/* > Resources/Icons/
--   [nomain] lib/**
-- @changelog
--   Internal change for supporting future scripts

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
        reaimgui_version = '0.9.1',
        js_version = 1.310,    -- required for JS_Window_Find and JS_VKeys_GetState
        reaper_version = 7.03, -- required for set_action_options
    }) then
    package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
    ImGui = require 'imgui' '0.9.1'

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

    local projPath, projFileName = OD_GetProjectPaths()

    local logger = OD_Logger:new({
        level = OD_Logger.LOG_LEVEL.NONE,
        output = OD_Logger.LOG_OUTPUT.CONSOLE,
        filename = projPath .. Scr.name .. '_' .. projFileName .. '.log'
    })

    local gui = SM_Gui:new({})

    app:connect('gui', gui)
    app:connect('logger', logger)
    app:connect('scr', Scr)
    app:connect('db', DB)
    app:init()
    logger:init()
    function app:checkProjectChange(force)
        if force or OD_DidProjectGUIDChange() then
            local projPath, projFileName = OD_GetProjectPaths()
            logger:setLogFile(projPath .. Scr.name .. '_' .. projFileName .. '.log')
        end
    end

    local settings = SM_Settings:new({})
    app:connect('settings', settings)
    app.settings:load()
    app.gui:init();


    ---------------------------------------
    -- Functions --------------------------
    ---------------------------------------


    function app.minimizeText(text, maxWidth)
        local key = app.settings.current.uiScale .. maxWidth
        app.maxTextLen = app.maxTextLen or {}
        if app.maxTextLen[key] == nil then
            local i = 0
            while ImGui.CalcTextSize(app.gui.ctx, string.rep('A', i)) < maxWidth do
                i = i + 1
            end
            app.maxTextLen[key] = i
        end
        if text:len() > app.maxTextLen[key] then
            if app.settings.current.textMinimizationStyle == MINIMIZATION_STYLE.PT then
                -- text = text:gsub(' ', '')
                text = text:len() <= app.maxTextLen[key] and text or text:gsub(' ', '')
                text = text:len() <= app.maxTextLen[key] and text or text:gsub('[^%a%d%/%.]', '')
                text = text:len() <= app.maxTextLen[key] and text or text:gsub('a', '')
                text = text:len() <= app.maxTextLen[key] and text or text:gsub('e', '')
                text = text:len() <= app.maxTextLen[key] and text or text:gsub('i', '')
                text = text:len() <= app.maxTextLen[key] and text or text:gsub('o', '')
                text = text:len() <= app.maxTextLen[key] and text or text:gsub('u', '')
                local lastLen = text:len()
                while text:len() > app.maxTextLen[key] do -- remove lowercase one by one
                    text = text:gsub('([a-z]+)[a-z]', '%1')
                    if lastLen == text:len() then
                        lastLen = text:len()
                        break
                    else
                        lastLen = text:len()
                    end
                end
                while text:len() > app.maxTextLen[key] do -- remove uppercase one by one
                    text = text:gsub('([A-Z]+)[A-Z]', '%1')
                    if lastLen == text:len() then
                        break
                    else
                        lastLen = text:len()
                    end
                end
            end
            return text:sub(1, app.maxTextLen[key]):gsub("%s+$", ''), true -- trim to max length
        end
        return text, false
    end

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
            local width = app.page.width
            local minHeight = app.page.minHeight or 0
            if app.page == APP_PAGE.MIXER then
                width, minHeight, app.gui.mainWindow.mixerInsertsH, app.gui.mainWindow.debugOverLay = app
                    .calculateMixerWindowSize()
                app.gui.mainWindow.mixerW = width
            end
            app.gui.mainWindow.min_w, app.gui.mainWindow.min_h = app.page.width * app.settings.current.uiScale,
                ((minHeight or app.page.minHeight or 0) or 0)
            ImGui.SetNextWindowSize(app.gui.ctx,
                math.max(app.settings.current.lastWindowWidth or 0, app.page.width * app.settings.current.uiScale),
                math.max(app.settings.current.lastWindowHeight or 0,
                    (app.page.height or 0) * app.settings.current.uiScale))
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
        if page == APP_PAGE.MIXER then
            if app.db.track.object == nil then
                page = APP_PAGE.NO_TRACK
            end
        end
        if page ~= app.page then
            app.page = page
            app.pageSwitched = true
        end
    end

    function app.calculateMixerWindowSize()
        -- top bar
        local wPadding = ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_WindowPadding)
        local vSpacing = select(2, ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_ItemSpacing))
        local topBarH = app.gui.TEXT_BASE_HEIGHT_LARGE +
            select(2, ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_FramePadding)) * 2 +
            ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_SeparatorTextBorderSize)

        -- inserts
        local insertsH = (app.settings.current.maxNumInserts + 1) *
            (app.gui.TEXT_BASE_HEIGHT_SMALL + select(2, ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_FramePadding)) * 2) -
            vSpacing

        local separatorH = app.gui.st.sizes.mixerSeparatorWidth
        -- sends
        local sendsH = 8 *
            (app.gui.TEXT_BASE_HEIGHT_SMALL + select(2, ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_FramePadding)) * 2) +
            app.gui.st.sizes.minFaderHeight

        local h = wPadding + topBarH + vSpacing + insertsH + vSpacing + separatorH + sendsH +
            app.gui.st.sizes.hintHeight + vSpacing + wPadding
        local shouldScroll = app.db.maxNumInserts > app.settings.current.maxNumInserts
        local visibleSendNum = 0
        local visibleSendTypes = 0
        for i, type in pairs(SEND_TYPE) do
            visibleSendNum = visibleSendNum +
                (app.settings.current.sendTypeVisibility[type] and app.db.numSends[type] or 0)
            visibleSendTypes = visibleSendTypes + (app.settings.current.sendTypeVisibility[type] and 1 or 0)
        end
        local w = (math.floor(app.settings.current.sendWidth * app.settings.current.uiScale) + ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_ItemSpacing)) *
            visibleSendNum +
            (app.gui.st.sizes.sendTypeSeparatorWidth + ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_ItemSpacing)) *
            visibleSendTypes +
            ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_WindowPadding) +
            ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_ItemSpacing) +
            (shouldScroll and ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_ScrollbarSize) or 0)
        return w, h, insertsH
        --, {0,topBarH+vSpacing+insertsH+vSpacing+separatorH+sendsH+vSpacing,w, app.gui.st.sizes.hintHeight+vSpacing}--app.gui.st.sizes.hintHeight}
    end

    function app.drawMixer()
        local ctx = app.gui.ctx
        local altPressed = OD_IsGlobalKeyDown(OD_KEYCODES.ALT, false, -60)
        local ctrlPressed = OD_IsGlobalKeyDown(OD_KEYCODES.CONTROL, false, -60)
        local macCtrlPressed = _OD_ISMAC and OD_IsGlobalKeyDown(OD_KEYCODES.STARTKEY, false, -60)
        local shiftPressed = OD_IsGlobalKeyDown(OD_KEYCODES.SHIFT, false, -60)

        app.db:sync()
        ImGui.PushFont(ctx, app.gui.st.fonts.small)

        local drawSend = function(s, parts)
            local drawDummy = function(w, col, h)
                app.gui:pushColors(col)
                ImGui.BeginDisabled(ctx)
                ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, 1.0)
                ImGui.Button(ctx, '##dummy' .. s.order, w, h)
                ImGui.PopStyleVar(ctx)
                ImGui.EndDisabled(ctx)
                app:setHoveredHint('main', ' ')
                app.gui:popColors(col)
            end
            local drawEnvVolButton = function(w, h)
                app.gui:pushColors(app.gui.st.col.buttons.env)
                if ImGui.Button(ctx, 'VOL\nENV##vEnvelope', w, h) then
                    s:toggleVolEnv()
                end
                app:setHoveredHint('main',
                    (s.name .. ' - Show/hide %s volume envelope'):format((s.type == SEND_TYPE.RECV) and 'receive' or
                        'send'))
                app.gui:popColors(app.gui.st.col.buttons.env)
            end
            local drawDeleteSend = function(w)
                local deleteTimeOut = 3
                local confirmationKey = s.order
                if app.temp.confirmation[confirmationKey] then
                    if reaper.time_precise() - app.temp.confirmation[confirmationKey] > deleteTimeOut then
                        app.temp.confirmation[confirmationKey] = nil
                    else
                        app.gui:pushColors(app.gui.st.col.buttons.deleteSend.confirm)
                        if ImGui.Button(ctx, 'Sure?##deleteSend', w) then
                            s:delete()
                            app.temp.confirmation[confirmationKey] = nil
                        end
                        app:setHoveredHint('main', s.name .. ' - Click again to confirm')
                        app.gui:popColors(app.gui.st.col.buttons.deleteSend.confirm)
                    end
                end
                if app.temp.confirmation[confirmationKey] == nil then -- not else because then I miss a frame after the timeout just passed
                    app.gui:pushColors(app.gui.st.col.buttons.deleteSend.initial)
                    ImGui.PushFont(ctx, app.gui.st.fonts.icons_small)
                    if ImGui.Button(ctx, ICONS.TRASH .. '##deleteSend', w) then
                        app.temp.confirmation[confirmationKey] = reaper.time_precise()
                    end
                    app:setHoveredHint('main',
                        (s.name .. ' - Delete %s'):format((s.type == SEND_TYPE.RECV) and 'receive' or 'send'))
                    ImGui.PopFont(ctx)
                    app.gui:popColors(app.gui.st.col.buttons.deleteSend.initial)
                end
            end
            local drawEnvMuteButton = function(w)
                app.gui:pushColors(app.gui.st.col.buttons.mute[false])
                local h = 5 *
                    (app.gui.TEXT_BASE_HEIGHT_SMALL + select(2, ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)) * 2) /
                    2 -
                    select(2, ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing))
                if ImGui.Button(ctx, 'MUTE\nENV##mEnvelope' .. s.order, w, h) then
                    s:toggleMuteEnv()
                end
                app:setHoveredHint('main',
                    (s.name .. ' - Show/hide %s mute envelope'):format((s.type == SEND_TYPE.RECV) and 'receive' or 'send'))
                app.gui:popColors(app.gui.st.col.buttons.mute[false])
            end
            local drawEnvPanButton = function(w)
                app.gui:pushColors(app.gui.st.col.buttons.route)
                local h = 5 *
                    (app.gui.TEXT_BASE_HEIGHT_SMALL + select(2, ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)) * 2) /
                    2 -
                    select(2, ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing))
                if ImGui.Button(ctx, 'PAN\nENV##pEnvelope' .. s.order, w, h) then
                    s:togglePanEnv()
                end
                app:setHoveredHint('main',
                    (s.name .. ' - Show/hide %s pan envelope'):format((s.type == SEND_TYPE.RECV) and 'receive' or 'send'))
                app.gui:popColors(app.gui.st.col.buttons.route)
            end
            local drawFader = function(w, h, targetTrack)
                if targetTrack and s.type == SEND_TYPE.HW then
                    drawDummy(w, app.gui.st.colpresets.darkButton, h)
                    return
                end
                local target = targetTrack and ((s.type == SEND_TYPE.SEND) and s.destTrack or s.srcTrack) or s
                local v = OD_dBFromValue(target.vol)
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
                if targetTrack then app.gui:pushColors(app.gui.st.col.targetFader) end
                local rv, v2 = ImGui.VSliderDouble(ctx, '##v', w,
                    h,
                    scaledV,
                    app.settings.current.minSendVol,
                    app.settings.current.maxSendVol * app.settings.current.scaleFactor,
                    '')
                app.gui:popStyles(app.gui.st.vars.vol)
                if targetTrack then app.gui:popColors(app.gui.st.col.targetFader) end

                app:setHoveredHint('main',
                    (s.name .. ' - %s volume. Drag or scroll to change, %s-scroll to fine-tune.'):format(
                        (s.type == SEND_TYPE.RECV) and (targetTrack and 'Source track' or 'Receive') or
                        (targetTrack and 'Destination track' or 'Send'), OD_KEYCODE_NAMES[OD_KEYCODES.CONTROL]))
                if (v2 < app.settings.current.scaleLevel * app.settings.current.scaleFactor) then
                    v2 = app.settings.current.scaleLevel +
                        (v2 - app.settings.current.scaleLevel * app.settings.current.scaleFactor) *
                        (app.settings.current.minSendVol - app.settings.current.scaleLevel) /
                        (app.settings.current.minSendVol - (app.settings.current.scaleLevel * app.settings.current.scaleFactor))
                else
                    v2 = v2 / app.settings.current.scaleFactor
                end

                local shouldReset, v2 = app.resetOnDoubleClick('s' .. s.order, v2, 0.0)
                if rv or shouldReset then      -- or (app.temp.sendConstantVol and app.temp.sendConstantVol[s.order]) then
                    target:setVolDB(v2, false) -- set without creating undo point
                end
                if ImGui.IsItemDeactivatedAfterEdit(ctx) or shouldReset then
                    target:setVolDB(v2, true) -- finish edit operation for touch automation to work, and create undo point
                end
                if ImGui.IsItemHovered(ctx) then
                    if mw ~= 0 then
                        if not app.temp.volDragging then
                            app.temp.volDragging = true
                        end
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
                        target:setVolDB(newV, false) -- set without creating undo point
                    elseif mw == 0.0 and app.temp.volDragging then
                        app.temp.volDraggingStopTimer = reaper.time_precise()
                        app.temp.volDragging = nil
                    end
                    if app.temp.volDraggingStopTimer and (reaper.time_precise() - app.temp.volDraggingStopTimer) > 0.15 then
                        app.temp.volDraggingStopTimer = nil
                        target:setVolDB(target.vol, true) -- create undo point
                    end
                end
            end
            local drawPan = function(w, targetTrack)
                if targetTrack and s.type == SEND_TYPE.HW then
                    drawDummy(w, app.gui.st.colpresets.darkButton, nil)
                    return
                end
                local target = targetTrack and ((s.type == SEND_TYPE.SEND) and s.destTrack or s.srcTrack) or s
                local mw = ImGui.GetMouseWheel(ctx)
                ImGui.SetNextItemWidth(ctx, w)

                app.gui:pushStyles(app.gui.st.vars.pan)
                if targetTrack then app.gui:pushColors(app.gui.st.col.targetFader) end

                local rv, v2 = ImGui.SliderDouble(ctx, '##p', target.pan, -1, 1, '')
                app:setHoveredHint('main',
                    (s.name .. ' - %s panning. Drag or scroll to change.'):format((s.type == SEND_TYPE.RECV) and
                        (targetTrack and 'Source track' or 'Receive') or (targetTrack and 'Destination track' or 'Send')))
                app.gui:popStyles(app.gui.st.vars.pan)
                if targetTrack then app.gui:popColors(app.gui.st.col.targetFader) end

                local shouldReset, v2 = app.resetOnDoubleClick('p' .. s.order, v2, 0.0)
                if rv or shouldReset then    --or (app.temp.sendConstantPan and app.temp.sendConstantPan[s.order]) then
                    target:setPan(v2, false) -- set without creating undo point
                end
                if ImGui.IsItemDeactivatedAfterEdit(ctx) or shouldReset then
                    target:setPan(v2, true) -- finish edit operation for touch automation to work, and create undo point
                end
                if ImGui.IsItemHovered(ctx) then
                    if mw ~= 0 then
                        if not app.temp.panDragging then
                            app.temp.panDragging = true
                        end
                        local scale = .01
                        local newV = s.pan + (app.settings.current.mouseScrollReversed and -mw or mw) * scale
                        target:setPan(newV, false) -- set without creating undo point
                    elseif mw == 0.0 and app.temp.panDragging then
                        app.temp.panDraggingStopTimer = reaper.time_precise()
                        app.temp.panDragging = nil
                    end
                    if app.temp.panDraggingStopTimer and (reaper.time_precise() - app.temp.panDraggingStopTimer) > 0.15 then
                        app.temp.panDraggingStopTimer = nil
                        target:setPan(target.pan, true) -- create undo point
                    end
                end
            end
            local drawVolLabel = function(w, targetTrack)
                if targetTrack and s.type == SEND_TYPE.HW then
                    drawDummy(w, app.gui.st.colpresets.darkButton, nil)
                    return
                end
                local target = targetTrack and ((s.type == SEND_TYPE.SEND) and s.destTrack or s.srcTrack) or s
                local v = OD_dBFromValue(target.vol)
                ImGui.SetNextItemWidth(ctx, w)
                if targetTrack then app.gui:pushColors(app.gui.st.col.targetFader) end
                local rv, v3 = ImGui.DragDouble(ctx, '##db', v, 0, 0, 0, '%.2f')
                if ImGui.IsItemFocused(ctx) and targetTrack then
                    app.temp.inputTargetVolLabel = true
                end

                if targetTrack then app.gui:popColors(app.gui.st.col.targetFader) end
                app:setHoveredHint('main',
                    (s.name .. ' - %s volume. Double-click to enter exact amount.'):format((s.type == SEND_TYPE.RECV) and
                        'Receive' or 'Send'))
                if rv then
                    target:setVolDB(v3, ImGui.IsItemDeactivatedAfterEdit(ctx))
                    r.Undo_OnStateChangeEx2(0, 'Set send volume', 1, -1)
                end
            end
            local drawMute = function(w)
                app.gui:pushColors(app.gui.st.col.buttons.mute[s.mute])
                if ImGui.Button(ctx, 'M##mute' .. s.order, w) then
                    s:setMute(not s.mute)
                end
                app:setHoveredHint('main',
                    (s.name .. ' - Mute %s'):format((s.type == SEND_TYPE.RECV) and 'receive' or 'send'))
                app.gui:popColors(app.gui.st.col.buttons.mute[s.mute])
            end
            local drawMono = function(w)
                if s.type == SEND_TYPE.HW then
                    ImGui.BeginDisabled(ctx)
                end
                app.gui:pushColors(app.gui.st.col.buttons.mono[s.mono])
                ImGui.PushFont(ctx, app.gui.st.fonts.icons_small)
                if ImGui.Button(ctx, (s.mono and ICONS.MONO or ICONS.STEREO) .. '##mono' .. s.order, w) then
                    s:setMono(not s.mono)
                end
                app:setHoveredHint('main',
                    (s.name .. ' - Set %s to %s'):format((s.type == SEND_TYPE.RECV) and 'receive' or 'send',
                        s.mono and 'stereo' or 'mono'))
                ImGui.PopFont(ctx)
                app.gui:popColors(app.gui.st.col.buttons.mono[s.mono])
                if s.type == SEND_TYPE.HW then
                    ImGui.EndDisabled(ctx)
                end
            end
            local drawSolo = function(w)
                local soloed = s:getSolo() -- OD_BfCheck(s.track.soloMatrix, 2^(s.order))
                app.gui:pushColors(app.gui.st.col.buttons.solo[soloed])
                if ImGui.Button(ctx, (soloed == SOLO_STATES.SOLO_DEFEAT and 'D' or 'S') .. '##solo' .. s.order, w) then
                    s:setSolo((soloed == SOLO_STATES.NONE) and SOLO_STATES.SOLO or SOLO_STATES.NONE,
                        not ImGui.IsKeyDown(ctx, app.gui.keyModCtrlCmd))
                end
                app:setHoveredHint('main',
                    (s.name .. ' - Solo %s'):format((s.type == SEND_TYPE.RECV) and 'receive' or 'send'))
                app.gui:popColors(app.gui.st.col.buttons.solo[soloed])
            end
            local drawSoloDefeat = function(w)
                local soloed = s:getSolo() == SOLO_STATES.SOLO_DEFEAT
                app.gui:pushColors(app.gui.st.col.buttons.solo[soloed and SOLO_STATES.SOLO_DEFEAT or SOLO_STATES.NONE])
                if ImGui.Button(ctx, 'D##solodefeat' .. s.order, w) then
                    s:setSolo(soloed and SOLO_STATES.NONE or SOLO_STATES.SOLO_DEFEAT)
                end
                app:setHoveredHint('main', s.name .. ' - Toggle solo defeat')
                app.gui:popColors(app.gui.st.col.buttons.solo[soloed and SOLO_STATES.SOLO_DEFEAT or SOLO_STATES.NONE])
            end
            local drawPhase = function(w)
                app.gui:pushColors(app.gui.st.col.buttons.polarity[s.polarity])
                ImGui.PushFont(ctx, app.gui.st.fonts.icons_small)
                if ImGui.Button(ctx, ICONS.POLARITY .. '##polarity' .. s.order, w) then
                    s:setPolarity(not s.polarity)
                end
                app:setHoveredHint('main', s.name .. ' - Invert polarity')
                ImGui.PopFont(ctx)
                app.gui:popColors(app.gui.st.col.buttons.mute[s.mute])
            end
            local drawGoToDestTrack = function(w)
                if s.type == SEND_TYPE.SEND or s.type == SEND_TYPE.RECV then
                    app.gui:pushColors(app.gui.st.col.buttons.scrollToTrack)
                    ImGui.PushFont(ctx, app.gui.st.fonts.icons_small)
                    local icon = s.type == SEND_TYPE.SEND and ICONS.ARROW_RIGHT or ICONS.ARROW_LEFT
                    if ImGui.Button(ctx, icon .. '##goToDest' .. s.order, w) then
                        s:goToDestTrack()
                    end
                    app:setHoveredHint('main',
                        (s.name .. ' - Scroll to %s track'):format(s.type == SEND_TYPE.SEND and 'destination' or 'source'))
                    ImGui.PopFont(ctx)
                    app.gui:popColors(app.gui.st.col.buttons.scrollToTrack)
                else
                    drawDummy(w, app.gui.st.colpresets.darkButton, nil)
                end
            end
            local drawListen = function(w, listenMode)
                local state = s:isListening()
                app.gui:pushColors(app.gui.st.col.buttons.listen[state and s.track.sendListenMode or listenMode][state])
                ImGui.PushFont(ctx, app.gui.st.fonts.icons_small)
                if ImGui.Button(ctx, ICONS.HEADPHONES .. '##listen' .. s.order, w) then
                    s:toggleListen(listenMode)
                end
                app:setHoveredHint('main',
                    s.name ..
                    ' - Listen to return ' ..
                    (listenMode == SEND_LISTEN_MODES.NORMAL and 'and original tracks ' or 'track ') .. 'only')
                ImGui.PopFont(ctx)
                app.gui:popColors(app.gui.st.col.buttons.listen
                    [state and s.track.sendListenMode or listenMode][state])
            end
            local drawModeButton = function(w)
                app.gui:pushColors(app.gui.st.col.buttons.mode[s.mode])
                local label = SEND_MODE[s.mode]
                if ImGui.Button(ctx, label .. '##mode' .. s.order, w) then
                    s:setMode(s.mode == 0 and 1 or (s.mode == 1 and 3 or 0))
                end
                app:setHoveredHint('main', s.name .. ' - Send placement')
                app.gui:popColors(app.gui.st.col.buttons.mode[s.mode])
            end
            local drawAutoMode = function(w)
                local label = app.minimizeText(T.AUTO_MODE_DESCRIPTIONS[s.autoMode].label,
                    w - ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding) * 4)
                app.gui:pushColors(app.gui.st.col.buttons.autoMode[s.autoMode])
                if ImGui.Button(ctx, label .. '##autoMode' .. s.order, w) then
                    ImGui.OpenPopup(ctx, '##autoModeMenu' .. s.order)
                end
                app:setHoveredHint('main',
                    (s.name .. ' - automation mode for this %s only'):format(s.type == SEND_TYPE.RECV and 'receive' or
                        'send'))
                app.gui:popColors(app.gui.st.col.buttons.autoMode[s.autoMode])
                ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, FLT_MAX, 300.0, nil)
                if ImGui.BeginPopup(ctx, '##autoModeMenu' .. s.order) then
                    app.temp.autoModeMenuOpen = true
                    if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
                        app.temp.ignoreEscapeKey = true
                        ImGui.CloseCurrentPopup(ctx)
                    end
                    for k, am in OD_PairsByOrder(T.AUTO_MODE_DESCRIPTIONS) do
                        if ImGui.MenuItem(ctx, am.label .. ' (' .. am.description .. ')', nil, s.autoMode == k, true) then
                            s:setAutoMode(k)
                        end
                    end
                    ImGui.EndPopup(ctx)
                end
            end
            local drawMIDIRouteButtons = function(w)
                if s.type == SEND_TYPE.HW then
                    ImGui.BeginGroup(ctx)
                    drawDummy(w, app.gui.st.col.buttons.route, nil)
                    drawDummy(w, app.gui.st.col.buttons.route, nil)
                    ImGui.EndGroup(ctx)
                else
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
                    ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, FLT_MAX, 300.0, nil)
                    if ImGui.BeginPopup(ctx, '##srcMidiChanMenu' .. s.order) then
                        app.temp.midiRouteMenuOpen = true
                        if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
                            app.temp.ignoreEscapeKey = true
                            ImGui.CloseCurrentPopup(ctx)
                        end
                        if ImGui.MenuItem(ctx, 'None', nil, s.midiSrcBus == 255, true) then s:setMidiRouting(0x1f, 0xff) end
                        if ImGui.MenuItem(ctx, 'All', nil, s.midiSrcChn == 0 and s.midiSrcBus == 0, true) then
                            s:setMidiRouting(0, 0)
                        end
                        ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, FLT_MAX, 300.0, nil)
                        for i = 1, 16 do
                            if ImGui.MenuItem(ctx, tostring(i), nil, s.midiSrcChn == i and s.midiSrcBus == 0, true) then
                                s:setMidiRouting(i, 0)
                            end
                        end
                        for bus = 1, 128 do
                            ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, FLT_MAX, 300.0, nil)
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
                    ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, FLT_MAX, 300.0, nil)
                    if ImGui.BeginPopup(ctx, '##destMidiChanMenu' .. s.order) then
                        app.temp.midiRouteMenuOpen = true
                        if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
                            app.temp.ignoreEscapeKey = true
                            ImGui.CloseCurrentPopup(ctx)
                        end
                        if ImGui.MenuItem(ctx, 'All', nil, s.midiDestChn == 0 and s.midiDestBus == 0, true) then
                            s:setMidiRouting(nil, nil, 0, 0)
                        end
                        ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, FLT_MAX, 300.0, nil)
                        for i = 1, 16 do
                            if ImGui.MenuItem(ctx, tostring(i), nil, s.midiDestChn == i and s.midiDestBus == 0, true) then
                                s:setMidiRouting(nil, nil, i, 0)
                            end
                        end
                        for bus = 1, 128 do
                            ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, FLT_MAX, 300.0, nil)
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
            end
            local drawRouteButtons = function(w)
                app.gui:pushColors(app.gui.st.col.buttons.route)
                ImGui.BeginGroup(ctx)
                if ImGui.Button(ctx, SRC_CHANNELS[s.srcChan].label .. '##srcChan' .. s.order, w) then
                    ImGui.OpenPopup(ctx, '##srcChanMenu' .. s.order)
                end
                app:setHoveredHint('main', s.name .. ' - Source audio channel')
                local label
                if s.type == SEND_TYPE.HW then
                    label = s.shortName
                else
                    label = s.srcChan == -1 and '' or
                        (s.destChan < 1024) and
                        (s.destChan + 1 .. '/' .. (s.destChan + SRC_CHANNELS[s.srcChan].numChannels)) or
                        s.destChan + 1 - 1024
                end
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
                    if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
                        app.temp.ignoreEscapeKey = true
                        ImGui.CloseCurrentPopup(ctx)
                    end
                    if ImGui.MenuItem(ctx, 'None', nil, s.srcChan == -1, true) then s:setSrcChan(-1) end
                    ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, FLT_MAX, 300.0, nil)
                    if ImGui.BeginMenu(ctx, 'Mono source') then
                        for i = 0, NUM_CHANNELS - 1 do
                            if ImGui.MenuItem(ctx, SRC_CHANNELS[i + 1024].label, nil, s.srcChan == i + 1024, true) then
                                s:setSrcChan(i + 1024)
                            end
                        end
                        ImGui.EndMenu(ctx)
                    end
                    ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, FLT_MAX, 300.0, nil)
                    if ImGui.BeginMenu(ctx, 'Stereo source') then
                        for i = 0, NUM_CHANNELS - 2 do
                            if ImGui.MenuItem(ctx, SRC_CHANNELS[i].label, nil, s.srcChan == i, true) then
                                s:setSrcChan(
                                    i)
                            end
                        end
                        ImGui.EndMenu(ctx)
                    end
                    ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, FLT_MAX, 300.0, nil)
                    if ImGui.BeginMenu(ctx, 'Multichannel source') then
                        for numChannels = 4, NUM_CHANNELS, 2 do
                            ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, FLT_MAX, 300.0, nil)
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
                ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, FLT_MAX, 300.0, nil)
                if ImGui.BeginPopup(ctx, '##destChanMenu' .. s.order) then
                    if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
                        app.temp.ignoreEscapeKey = true
                        ImGui.CloseCurrentPopup(ctx)
                    end
                    ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, FLT_MAX, 300.0, nil)
                    if ImGui.BeginMenu(ctx, 'Downmix to mono') then
                        for i = 0, NUM_CHANNELS - 1 do
                            local label = s.type == SEND_TYPE.HW and OUTPUT_CHANNEL_NAMES[i + 1] or (i + 1)
                            if ImGui.MenuItem(ctx, label, nil, s.destChan == i + 1024, true) then
                                s:setDestChan(i + 1024)
                            end
                        end
                        ImGui.EndMenu(ctx)
                    end

                    for i = 0, NUM_CHANNELS - SRC_CHANNELS[s.srcChan].numChannels do
                        local label = s.type == SEND_TYPE.HW and
                            (SRC_CHANNELS[s.srcChan].numChannels == 1 and OUTPUT_CHANNEL_NAMES[i + 1] or
                                ((OUTPUT_CHANNEL_NAMES[i + 1] .. (SRC_CHANNELS[s.srcChan].numChannels > 2 and '..' or '/') .. OUTPUT_CHANNEL_NAMES[i + SRC_CHANNELS[s.srcChan].numChannels])))
                            or (SRC_CHANNELS[s.srcChan].numChannels == 1 and i + 1 or
                                (i + 1 .. '/' .. (i + SRC_CHANNELS[s.srcChan].numChannels)))
                        if ImGui.MenuItem(ctx, label, nil, s.destChan == i, true) then
                            s:setDestChan(i)
                        end
                    end
                    app.focusMainReaperWindow = false
                    ImGui.EndPopup(ctx)
                end
            end

            local drawSendName = function(w)
                local track = s.type == SEND_TYPE.RECV and s.srcTrack or s.destTrack
                if s.type ~= SEND_TYPE.HW then
                    ImGui.PushStyleColor(ctx, ImGui.Col_Button, track.color or 0x000000ff)
                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, OD_ColorIsBright(track.color) and 0x000000ff or 0xffffffff)
                else
                    app.gui:pushColors(app.gui.st.col.insert.blank)
                end
                ImGui.BeginDisabled(ctx)
                ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, 1.0)
                ImGui.Button(ctx, s.shortName .. "##sendName", w)
                ImGui.PopStyleVar(ctx)
                ImGui.EndDisabled(ctx)
                if s.destTrack then
                    ImGui.PopStyleColor(ctx)
                    ImGui.PopStyleColor(ctx)
                else
                    app.gui:popColors(app.gui.st.col.insert.blank)
                end
                app:setHoveredHint('main', app.debug and (altPressed and s.guid or s.name) or s.name)
            end

            local drawInserts = function(w)
                local totalDrawn = 0
                for i, insert in OD_PairsByOrder(s.destTrack.inserts) do
                    totalDrawn = totalDrawn + 1
                    local colors = insert.offline and app.gui.st.col.insert.offline or
                        (not insert.enabled and app.gui.st.col.insert.disabled or app.gui.st.col.insert.enabled)
                    app.gui:pushColors(colors)
                    local rv = ImGui.Button(ctx, insert.shortName .. "##" .. i, w)
                    app.gui:popColors(colors)
                    if rv then
                        if ImGui.IsKeyDown(ctx, app.gui.keyModCtrlCmd) and ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
                            insert:setOffline(not insert.offline)
                        elseif ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
                            insert:setEnabled(not insert.enabled)
                        elseif ImGui.IsKeyDown(ctx, ImGui.Mod_Alt) then
                            insert:delete()
                        else
                            if insert:toggleShow() then app.focusMainReaperWindow = false end
                        end
                    end
                    if ImGui.BeginDragDropSource(ctx) then
                        ImGui.SetDragDropPayload(ctx, 'insert' .. s.order, i)
                        ImGui.EndDragDropSource(ctx)
                    end
                    if ImGui.BeginDragDropTarget(ctx) then
                        local payload, data = ImGui.AcceptDragDropPayload(ctx, 'insert' .. s.order)
                        if payload then
                            local oldIdx = tonumber(data)
                            s.destTrack:getInsertAtIndex(oldIdx - 1):moveToIndex(i - 1)
                        end
                        ImGui.EndDragDropTarget(ctx)
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
                if ImGui.Button(ctx, "P##", w) then
                    app.temp.addFxToSend = s
                    app.temp.addSendType = nil
                    app.setPage(APP_PAGE.SEARCH_FX)
                end
                app:setHoveredHint('main', 'Add FX')
                ImGui.PopFont(ctx)
                app.gui:popColors(app.gui.st.col.insert.add)
                app.gui:pushColors(app.gui.st.col.insert.blank)
                app.gui:pushColors(app.gui.st.col.insert.add)
                ImGui.BeginDisabled(ctx)
                ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, 1.0)
                if totalDrawn < app.settings.current.maxNumInserts then
                    for i = totalDrawn + 1, app.settings.current.maxNumInserts do
                        ImGui.Button(ctx, "##dummy", w)
                    end
                end
                ImGui.PopStyleVar(ctx)
                ImGui.EndDisabled(ctx)
                app.gui:popColors(app.gui.st.col.insert.add)
                app.gui:popColors(app.gui.st.col.insert.blank)
            end

            ImGui.PushID(ctx, 's' .. (s and s.order or -1))

            local faderHeight = math.max(app.gui.st.sizes.minFaderHeight,
                select(2, ImGui.GetContentRegionAvail(ctx)) - app.gui.TEXT_BASE_HEIGHT_SMALL * 2 -
                ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding) * 4)

            local w = math.floor(app.settings.current.sendWidth * app.settings.current.uiScale)
            if parts.name then
                parts = { parts }
            else
                w = math.floor(app.settings.current.sendWidth * app.settings.current.uiScale) / #parts -
                    ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing) / #
                    parts
            end

            for i, part in ipairs(parts) do
                if part.sameLine == true then ImGui.SameLine(ctx) end
                if part.name == 'inserts' then
                    drawInserts(w)
                elseif part.name == 'dummy' then
                    drawDummy(w, part.color)
                elseif part.name == 'dummyFader' then
                    drawDummy(w, app.gui.st.colpresets.darkButton, faderHeight)
                elseif part.name == 'pan' then
                    drawPan(w, part.targetTrack)
                elseif part.name == 'envmute' then
                    drawEnvMuteButton(w)
                elseif part.name == 'solo' then
                    drawSolo(w)
                elseif part.name == 'mute' then
                    drawMute(w)
                elseif part.name == 'mono' then
                    drawMono(w)
                elseif part.name == 'solod' then
                    drawSoloDefeat(w)
                elseif part.name == 'phase' then
                    drawPhase(w)
                elseif part.name == 'scrollToTrack' then
                    drawGoToDestTrack(w)
                elseif part.name == 'listen' then
                    drawListen(w, part.listenMode)
                elseif part.name == 'modebutton' then
                    drawModeButton(w)
                elseif part.name == 'automode' then
                    drawAutoMode(w)
                elseif part.name == 'routebutton' then
                    drawRouteButtons(w)
                elseif part.name == 'midiroutebutton' then
                    drawMIDIRouteButtons(w)
                elseif part.name == 'envpan' then
                    drawEnvPanButton(w)
                elseif part.name == 'fader' then
                    drawFader(w, faderHeight, part.targetTrack)
                elseif part.name == 'deletesend' then
                    drawDeleteSend(w)
                elseif part.name == 'envvol' then
                    drawEnvVolButton(w, faderHeight)
                elseif part.name == 'volLabel' then
                    drawVolLabel(w, part.targetTrack)
                elseif part.name == 'sendName' then
                    drawSendName(w)
                end
                if i < #parts then
                    ImGui.SameLine(ctx)
                end
            end

            ImGui.PopID(ctx)
            -- ImGui.EndGroup(ctx)
        end

        local h = app.gui.mainWindow.mixerInsertsH
        local w = app.gui.mainWindow.mixerW - ImGui.GetStyleVar(ctx, ImGui.StyleVar_WindowPadding) * 2
        local visibleSendTypes = {}
        for _, type in ipairs(app.settings.current.sendTypeOrder) do
            if app.settings.current.sendTypeVisibility[type] then
                table.insert(visibleSendTypes, type)
            end
        end

        if ImGui.BeginChild(ctx, "##inserts", w, h, ImGui.ChildFlags_None) then
            for _, type in ipairs(visibleSendTypes) do
                local count = 0
                for i, s in pairs(app.db.sends) do
                    if s.type == type then
                        count = count + 1
                    end
                end

                ImGui.BeginGroup(ctx)
                ImGui.PushFont(ctx, app.gui.st.fonts.icons_small)
                app.gui:pushStyles(app.gui.st.vars.addSendButton)
                app.gui:pushColors(app.gui.st.col.buttons.addSend)
                local clicked = false
                if not ImGui.IsPopupOpen(ctx, '', ImGui.PopupFlags_AnyPopup) then
                    local key = (type == SEND_TYPE.SEND) and 'addSend' or
                        ((type == SEND_TYPE.RECV) and 'addRecv' or 'addHW')
                    if app.isShortcutPressed(key) then
                        clicked = true
                        local scriptHwnd = app.gui.mainWindow.dockId < 0 and
                            reaper.JS_Window_Find(Scr.context_name, true) or reaper.JS_Window_FindTop(Scr.name, true)
                        r.JS_Window_SetFocus(scriptHwnd)
                    end
                end
                if ImGui.Button(ctx, ICONS.PLUS .. '##addSends' .. type, app.gui.st.sizes.sendTypeSeparatorWidth, app.gui.st.sizes.sendTypeSeparatorWidth) or clicked then
                    if type == SEND_TYPE.HW then
                        ImGui.OpenPopup(ctx, '##newHWSendMenu')
                    else
                        app.temp.addSendType = type
                        app.setPage(APP_PAGE.SEARCH_SEND)
                    end
                end
                app:setHoveredHint('main', 'Add new ' .. (T.SEND_TYPE_NAMES[type].SINGULAR):lower())
                app.gui:popColors(app.gui.st.col.buttons.addSend)
                app.gui:popStyles(app.gui.st.vars.addSendButton)
                ImGui.PopFont(ctx)
                if type == SEND_TYPE.HW then
                    local x, y = OD_GetMousePos()
                    ImGui.SetNextWindowPos(ctx, x, y, ImGui.Cond_Appearing)
                    ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, FLT_MAX, 300.0, nil)
                    if ImGui.BeginPopup(ctx, '##newHWSendMenu') then
                        if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
                            app.temp.ignoreEscapeKey = true
                            ImGui.CloseCurrentPopup(ctx)
                        end
                        ImGui.SetNextWindowSizeConstraints(ctx, 0.0, 0.0, FLT_MAX, 300.0, nil)
                        if ImGui.BeginMenu(ctx, 'Downmix to mono') then
                            for j = 0, app.db.numAudioOutputs - 1 do
                                if ImGui.MenuItem(ctx, OUTPUT_CHANNEL_NAMES[j + 1], nil, false, true) then
                                    app.db:createNewSend(type, j + 1024)
                                end
                            end
                            ImGui.EndMenu(ctx)
                        end

                        for j = 0, app.db.numAudioOutputs - 2 do
                            local label = ((OUTPUT_CHANNEL_NAMES[j + 1] .. '/' .. OUTPUT_CHANNEL_NAMES[j + 2]))
                            if ImGui.MenuItem(ctx, label, nil, false, true) then
                                app.db:createNewSend(type, j)
                            end
                        end
                        app.focusMainReaperWindow = false
                        ImGui.EndPopup(ctx)
                    end
                end

                ImGui.EndGroup(ctx)
                ImGui.SameLine(ctx)
                if count > 0 then
                    if type ~= SEND_TYPE.SEND then
                        local left, top = ImGui.GetCursorScreenPos(ctx)
                        local insertsPadding = app.settings.current.uiScale
                        local fillerW, fillerH = insertsPadding +
                            (math.floor(app.settings.current.sendWidth * app.settings.current.uiScale) + select(1, ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing))) *
                            count - select(1, ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)), h

                        ImGui.SameLine(ctx)
                        ImGui.DrawList_AddRectFilled(app.gui.draw_list, left - insertsPadding, top,
                            left + fillerW,
                            top + fillerH,
                            app.gui.st.basecolors.darkestBG, ImGui.GetStyleVar(ctx, ImGui.StyleVar_FrameRounding))
                    end
                    for i, s in OD_PairsByOrder(app.db.sends) do
                        if s.type == type then
                            ImGui.BeginGroup(ctx)
                            if type == SEND_TYPE.SEND then
                                drawSend(s, { name = 'inserts' })
                            else
                                ImGui.Dummy(ctx,
                                    math.floor(app.settings.current.sendWidth * app.settings.current.uiScale), 0)
                            end
                            ImGui.EndGroup(ctx)
                            ImGui.SameLine(ctx)
                        end
                    end
                end
            end
            ImGui.EndChild(ctx)
        end

        if next(visibleSendTypes) then
            local sepH = app.gui.st.sizes.mixerSeparatorWidth
            local w = math.max(w, ImGui.GetContentRegionAvail(ctx))
            ImGui.InvisibleButton(ctx, '##separator', w, sepH)
            if ImGui.IsItemHovered(ctx) then
                app:setHoveredHint('main', 'Scroll to change number of inserts')
                ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeNS)
            end
            if ImGui.IsItemActive(ctx) then
                ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeNS)
                local value_with_lock_threshold_x, value_with_lock_threshold_y = ImGui.GetMouseDragDelta(ctx, nil,
                    nil,
                    ImGui.MouseButton_Left)
                if value_with_lock_threshold_y ~= 0 then
                    if value_with_lock_threshold_y > 0 + app.gui.TEXT_BASE_HEIGHT_SMALL then
                        app.settings.current.maxNumInserts = app.settings.current.maxNumInserts + 1
                        app.settings:save()
                        ImGui.ResetMouseDragDelta(ctx, ImGui.MouseButton_Left)
                        -- app.gui.mainWindow.min_w, app.gui.mainWindow.min_h = app.calculateMixerSize()
                        app.refreshWindowSizeOnNextFrame = true
                    elseif app.settings.current.maxNumInserts > 0 and value_with_lock_threshold_y < 0 - app.gui.TEXT_BASE_HEIGHT_SMALL then
                        app.settings.current.maxNumInserts = app.settings.current.maxNumInserts - 1
                        app.settings:save()
                        ImGui.ResetMouseDragDelta(ctx, ImGui.MouseButton_Left)
                        -- app.gui.mainWindow.min_w, app.gui.mainWindow.min_h = app.calculateMixerSize()
                        app.refreshWindowSizeOnNextFrame = true
                    end
                end
            end
            local postButtonY = ImGui.GetCursorPosY(ctx)

            ImGui.SetCursorPosY(ctx,
                ImGui.GetCursorPosY(ctx) - (sepH / 2) - ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing))
            ImGui.SetNextItemWidth(ctx, w)
            local x, y = ImGui.GetCursorScreenPos(ctx)
            ImGui.DrawList_AddLine(app.gui.draw_list, x, y - (sepH / 2),
                x + w, y - (sepH / 2), app.gui.st.basecolors.midBG, 1 * app.settings.current.uiScale)
            ImGui.DrawList_AddLine(app.gui.draw_list, x, y + (sepH / 2),
                x + w, y + (sepH / 2), app.gui.st.basecolors.midBG, 1 * app.settings.current.uiScale)
            ImGui.SetCursorPosY(ctx, postButtonY)
        end

        local parts = {
            { { name = 'mute' },   { name = 'solo' } },
            { { name = 'phase' },  { name = 'listen', listenMode = SEND_LISTEN_MODES.NORMAL } },
            { name = 'modebutton' },
            { name = 'routebutton' },
            { name = 'pan' },
            { name = 'fader' },
            { name = 'volLabel' },
            { name = 'sendName' }
        }
        if altPressed or app.temp.midiRouteMenuOpen or app.temp.inputTargetVolLabel then
            parts = {
                { { name = 'mono' },       { name = 'solod' } },
                { { name = 'phase' },      { name = 'listen', listenMode = SEND_LISTEN_MODES.RETURN_ONLY } },
                { name = 'deletesend' },
                { name = 'midiroutebutton' },
                { name = 'pan',            targetTrack = true },
                { name = 'fader',          targetTrack = true },
                { name = 'volLabel',       targetTrack = true },
                { name = 'sendName' },
            }
        end
        if shiftPressed or app.temp.autoModeMenuOpen then
            parts = {
                { name = 'automode' },
                { name = 'envmute' },
                { name = 'envpan' },
                { name = 'envvol' },
                { name = 'scrollToTrack' },
                { name = 'sendName' }
            }
        end
        app.temp.autoModeMenuOpen = false
        app.temp.midiRouteMenuOpen = false
        app.temp.inputTargetVolLabel = false
        local totalH = select(2, ImGui.GetContentRegionAvail(ctx))
        for _, type in ipairs(visibleSendTypes) do
            local count = 0
            for i, s in pairs(app.db.sends) do
                if s.type == type then
                    count = count + 1
                end
            end

            ImGui.BeginGroup(ctx)
            local left, top = ImGui.GetCursorScreenPos(ctx)
            local w, h      = app.gui.st.sizes.sendTypeSeparatorWidth,
                app.gui.st.sizes.sendTypeSeparatorHeight

            ImGui.DrawList_AddLine(app.gui.draw_list, left + w, top, left + w, top + totalH,
                app.settings.current.sendTypeColor[type], app.settings.current.uiScale)

            local points = reaper.new_array({
                left, top + h + 40,
                left + w, top + h,
                left + w, top + totalH,
                left, top + totalH
            })
            local text = (T.SEND_TYPE_NAMES[type].TITLE):upper()
            ImGui.DrawList_AddConvexPolyFilled(app.gui.draw_list, points,
                app.settings.current.sendTypeColor[type])
            local textTop = top + select(2, ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding))
            local textRight = left + w - ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)
            app.gui:drawVerticalText(app.gui.draw_list, text, textRight,
                textTop, app.gui.st.basecolors.text, true, true)
            ImGui.Dummy(ctx, app.gui.st.sizes.sendTypeSeparatorWidth, 1)
            ImGui.EndGroup(ctx)
            ImGui.SameLine(ctx)
            if count > 0 then
                ImGui.BeginGroup(ctx)
                for j, part in ipairs(parts) do
                    ImGui.BeginGroup(ctx)
                    for i, s in OD_PairsByOrder(app.db.sends) do
                        if s.type == type then
                            drawSend(s, part)
                            ImGui.SameLine(ctx)
                        end
                    end
                    ImGui.EndGroup(ctx)
                end
                ImGui.EndGroup(ctx)
                ImGui.SameLine(ctx)
            end
        end
        ImGui.PopFont(ctx)
        if app.hint.main.text == '' then
            app:setHoveredHint('main',
                'Hold ' .. app.gui.descModAlt .. ' for more controls. Hold shift for envelopes.')
        end
    end

    function app.isShortcutPressed(key)
        if app.settings.current.shortcuts[key] and app.settings.current.shortcuts[key].key == -1 then return false end
        return app.settings.current.shortcuts[key] and OD_IsGlobalKeyPressed(app.settings.current.shortcuts[key].key) and
            OD_IsGlobalKeyDown(OD_KEYCODES.CONTROL) == app.settings.current.shortcuts[key].ctrl
            and OD_IsGlobalKeyDown(OD_KEYCODES.SHIFT) == app.settings.current.shortcuts[key].shift
            and OD_IsGlobalKeyDown(OD_KEYCODES.ALT) == app.settings.current.shortcuts[key].alt
            and OD_IsGlobalKeyDown(OD_KEYCODES.STARTKEY) == app.settings.current.shortcuts[key].macCtrl
    end

    function app.getShortcutDescription(key)
        local shortcut = app.settings.current.shortcuts[key]
        local desc = ''
        if shortcut and shortcut.key ~= -1 then
            if shortcut.ctrl then desc = desc .. OD_KEYCODE_NAMES[OD_KEYCODES.CONTROL] end
            if shortcut.shift then desc = desc .. '+' .. OD_KEYCODE_NAMES[OD_KEYCODES.SHIFT] end
            if shortcut.alt then desc = desc .. '+' .. OD_KEYCODE_NAMES[OD_KEYCODES.ALT] end
            if shortcut.macCtrl then desc = desc .. '+' .. OD_KEYCODE_NAMES[OD_KEYCODES.STARTKEY] end
            desc = desc .. ' + ' .. OD_KEYCODE_NAMES[shortcut.key]
        end
        return desc
    end

    function app.drawSearch()
        local function filterResults(query)
            app.temp.searchInput = query
            app.temp.searchResults = {}
            query = query:gsub('%s+', ' ')
            for i, asset in ipairs(app.db.assets) do
                local skip = false
                if app.page == APP_PAGE.SEARCH_FX and asset.type == ASSETS.TRACK then skip = true end
                if app.page == APP_PAGE.SEARCH_FX and asset.type == ASSETS.TRACK_TEMPLATE then skip = true end
                if app.temp.addSendType == SEND_TYPE.RECV and asset.type ~= ASSETS.TRACK then skip = true end
                if asset.type == ASSETS.TRACK and asset.load == app.db.track.guid then skip = true end
                if not skip then
                    local foundIndexes = {}
                    local allWordsFound = true
                    for word in query:lower():gmatch("%S+") do
                        local wordFound = false
                        for j, assetWord in ipairs(asset.searchText) do
                            local pos = string.find((assetWord.text):lower(), OD_EscapePattern(word))
                            if pos then
                                foundIndexes[j] = foundIndexes[j] or {}
                                table.insert(foundIndexes[j], { from = pos, to = pos + #word - 1, order = pos })
                                wordFound = true
                            end
                        end
                        if not wordFound then
                            allWordsFound = false
                            break
                        end
                    end
                    if allWordsFound then
                        asset.foundIndexes = foundIndexes
                        table.insert(app.temp.searchResults, asset)
                    end
                end
            end
            app.temp.highlightedResult = #app.temp.searchResults > 0 and 1 or nil
            app.temp.lastInvisibleGroup = nil
            -- if receiving track, add assign all results to ALL_TRACKS_GROUP and sort them by track order
            if app.temp.addSendType == SEND_TYPE.RECV then
                table.sort(app.temp.searchResults, function(a, b)
                    return a.order < b.order
                end)
                for i, result in ipairs(app.temp.searchResults) do
                    result.group = ALL_TRACKS_GROUP
                end
            end
        end

        local ctx = app.gui.ctx
        local selectedResult = nil
        local hintResult = nil
        local hintContext = nil
        local w = select(1, ImGui.GetContentRegionAvail(ctx))

        local fontLineHeight = ImGui.GetTextLineHeightWithSpacing(ctx)
        app.gui:pushStyles(app.gui.st.vars.searchWindow)
        app.gui:pushColors(app.gui.st.col.searchWindow)
        app.temp.searchResults = app.temp.searchResults or {}

        if app.pageSwitched then
            app.db:init()
            filterResults('')
            ImGui.SetKeyboardFocusHere(ctx, 0)
        end
        ImGui.SetNextItemWidth(ctx, w)
        local rv, searchInput = ImGui.InputText(ctx, "##searchInput", app.temp.searchInput)

        local h = select(2, ImGui.GetContentRegionAvail(ctx))
        local maxSearchResults = math.floor(h / (fontLineHeight))

        if rv then
            filterResults(searchInput)
            app.temp.scrollToTop = true
        end

        if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
            app.temp.ignoreEscapeKey = true
            app.setPage(APP_PAGE.MIXER)
        elseif app.temp.highlightedResult then
            hintResult = app.temp.searchResults[app.temp.highlightedResult]
            hintContext = 'Enter'
            if ImGui.IsKeyPressed(ctx, ImGui.Key_DownArrow) then
                if app.temp.highlightedResult < #app.temp.searchResults then
                    app.temp.highlightedResult = app.temp.highlightedResult + 1
                    app.temp.checkScrollDown = true
                end
            elseif ImGui.IsKeyPressed(ctx, ImGui.Key_PageDown) then
                if app.temp.highlightedResult + maxSearchResults - 3 < #app.temp.searchResults then
                    app.temp.highlightedResult = app.temp.highlightedResult + maxSearchResults - 3
                    app.temp.checkScrollDown = true
                elseif app.temp.highlightedResult ~= #app.temp.searchResults then
                    app.temp.highlightedResult = #app.temp.searchResults
                    app.temp.checkScrollDown = true
                end
            elseif ImGui.IsKeyPressed(ctx, ImGui.Key_PageUp) then
                if app.temp.highlightedResult - maxSearchResults - 3 > 1 then
                    app.temp.highlightedResult = app.temp.highlightedResult - maxSearchResults - 3
                    app.temp.checkScrollUp = true
                elseif app.temp.highlightedResult ~= 1 then
                    app.temp.highlightedResult = 1
                    app.temp.checkScrollUp = true
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
            elseif app.isShortcutPressed('markFavorite') then
                if app.temp.highlightedResult then
                    local result = app.temp.searchResults[app.temp.highlightedResult]
                    local fav = result:toggleFavorite()
                    filterResults(searchInput)
                    if fav then
                        for i, r in ipairs(app.temp.searchResults) do
                            -- if r.type == oldType and r.load == oldLoad then
                            if r == result then
                                app.temp.highlightedResult = i
                                break
                            end
                        end
                    end
                end
            end
        end

        local selectableFlags = ImGui.SelectableFlags_SpanAllColumns
        local outer_size = { 0.0, fontLineHeight * h / (fontLineHeight) }
        local tableFlags = ImGui.TableFlags_ScrollY
        local lastGroup = nil

        local upperRowY = select(2, ImGui.GetCursorScreenPos(ctx))
        if ImGui.BeginTable(ctx, "##searchResults", 1, tableFlags, table.unpack(outer_size)) then
            ImGui.TableSetupScrollFreeze(ctx, 0, 1)
            if app.temp.scrollToTop == true then
                ImGui.SetScrollY(ctx, 0)
                app.temp.scrollToTop = false
            end
            local highlightedY = 0
            local foundInvisibleGroup = false
            local absIndex = 0
            for i, result in ipairs(app.temp.searchResults) do
                -- local currentScreenY =

                if result.group ~= lastGroup then
                    ImGui.TableNextRow(ctx, ImGui.TableRowFlags_None, fontLineHeight)
                    absIndex = absIndex + 1
                    ImGui.TableSetColumnIndex(ctx, 0)
                    ImGui.SeparatorText(ctx, i == 1 and app.temp.lastInvisibleGroup or result.group)
                    lastGroup = result.group
                    if select(2, ImGui.GetCursorScreenPos(ctx)) <= upperRowY + fontLineHeight then
                        app.temp.lastInvisibleGroup = result.group
                        foundInvisibleGroup = true
                    end
                end
                if not foundInvisibleGroup then app.temp.lastInvisibleGroup = nil end
                ImGui.PushID(ctx, 'result' .. i)
                ImGui.TableNextRow(ctx, ImGui.TableRowFlags_None, fontLineHeight)
                absIndex = absIndex + 1
                ImGui.TableSetColumnIndex(ctx, 0)
                if (app.temp.checkScrollDown or app.temp.checkScrollUp) and i == app.temp.highlightedResult then
                    highlightedY = select(2, ImGui.GetCursorScreenPos(ctx))
                end
                if ImGui.Selectable(ctx, '', i == app.temp.highlightedResult, selectableFlags, 0, 0) then
                    selectedResult = result
                end
                if ImGui.IsItemHovered(ctx) then
                    hintResult = app.temp.searchResults[i]
                    hintContext = 'Click'
                end
                ImGui.SameLine(ctx)

                if result.type == ASSETS.TRACK then
                    ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx))
                    local size = fontLineHeight -
                        select(2, ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_FramePadding)) * 2
                    ImGui.ColorButton(ctx, 'color', result.color,
                        ImGui.ColorEditFlags_NoBorder |
                        ImGui.ColorEditFlags_NoTooltip, size, size)
                    ImGui.SameLine(ctx)
                end

                if result.group == FAVORITE_GROUP then
                    ImGui.PushFont(ctx, app.gui.st.fonts.icons_small)
                    app.gui:pushColors(app.gui.st.col.search.favorite)
                    ImGui.Text(ctx, ICONS.STAR)
                    app.gui:popColors(app.gui.st.col.search.favorite)
                    ImGui.PopFont(ctx)
                    ImGui.SameLine(ctx)
                end

                -- draw result name, highlighting the search query

                ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0.0, 0.0)
                for j, st in ipairs(result.searchText) do
                    if not st.hide then
                        if j > 1 then
                            ImGui.Text(ctx, ' ')
                            ImGui.SameLine(ctx)
                            app.gui:pushColors(app.gui.st.col.search.secondaryResult)
                        else
                            app.gui:pushColors(app.gui.st.col.search.mainResult)
                        end
                        local curIndex = 1
                        for k, highlight in OD_PairsByOrder(result.foundIndexes[j] or {}) do
                            if curIndex <= highlight.from then
                                ImGui.Text(ctx, (st.text):sub(curIndex, highlight.from - 1))
                                ImGui.SameLine(ctx)
                            end
                            if curIndex <= highlight.to + 1 then
                                app.gui:pushColors(app.gui.st.col.search.highlight)
                                local txt = (st.text):sub(math.max(curIndex, highlight.from), highlight.to)
                                ImGui.Text(ctx, txt)
                                app.gui:popColors(app.gui.st.col.search.highlight)
                                ImGui.SameLine(ctx)
                                curIndex = highlight.to + 1
                            end
                        end
                        if curIndex <= #(st.text) then
                            local txt = (st.text):sub(curIndex, #(st.text))
                            ImGui.Text(ctx, txt)
                            ImGui.SameLine(ctx)
                        end
                        if j > 1 then
                            app.gui:popColors(app.gui.st.col.search.secondaryResult)
                        else
                            app.gui:popColors(app.gui.st.col.search.mainResult)
                        end
                    end
                end
                ImGui.PopStyleVar(ctx)

                ImGui.PopID(ctx)
            end
            if app.temp.checkScrollDown and highlightedY > upperRowY + maxSearchResults * fontLineHeight then
                ImGui.SetScrollY(ctx,
                    ImGui.GetScrollY(ctx) +
                    (highlightedY - (upperRowY + (maxSearchResults - 1) * fontLineHeight) - 1))
                app.temp.checkScrollDown = false
            end
            if app.temp.checkScrollUp and highlightedY <= upperRowY + fontLineHeight then
                ImGui.SetScrollY(ctx,
                    ImGui.GetScrollY(ctx) - (upperRowY - highlightedY + 1) - fontLineHeight - 1)
                app.temp.checkScrollUp = false
            end
            ImGui.EndTable(ctx)
        end
        app.gui:popColors(app.gui.st.col.searchWindow)
        app.gui:popStyles(app.gui.st.vars.searchWindow)
        if hintResult then
            local action = (hintResult.type == ASSETS.TRACK and 'add a send to track %s' or 'create a new track with FX %s')
                :format(hintResult.searchText[1].text)
            app:setHint('main',
                ('%s to %s.'):format(hintContext, action) ..
                (app.getShortcutDescription('markFavorite') ~= '' and (' Press %s to %s.'):format(app.getShortcutDescription('markFavorite'),
                    hintResult.group == FAVORITE_GROUP and 'unfavorite' or 'favorite') or ''))
        else
            app:setHint('main', '')
        end
        if selectedResult then
            if app.page == APP_PAGE.SEARCH_FX then
                app.temp.addFxToSend:addInsert(selectedResult.load)
                app.temp.addFxToSend = nil
            elseif app.page == APP_PAGE.SEARCH_SEND then
                app.db:createNewSend(app.temp.addSendType, selectedResult.type, selectedResult.load,
                    selectedResult.searchText[1].text)
            end
            app.setPage(APP_PAGE.MIXER)
        end
    end

    function app.drawErrorNoTrack()
        local ctx = app.gui.ctx
        app.db:sync()
        local w, h =
            select(1, ImGui.GetContentRegionAvail(ctx)) -
            ImGui.GetStyleVar(ctx, ImGui.StyleVar_WindowPadding) * 2,
            select(2, ImGui.GetContentRegionAvail(ctx)) -- app.gui.st.sizes.hintHeight
        if ImGui.BeginChild(ctx, '##noTrack', w, h, nil, nil) then
            ImGui.Dummy(ctx, w, h)
            ImGui.SetCursorPos(ctx, w / 2,
                h / 2 - app.gui.TEXT_BASE_HEIGHT * 1)
            app.gui:drawSadFace(4, app.gui.st.basecolors.main)
            local text = 'No track selected'
            ImGui.SetCursorPos(ctx, (w - ImGui.CalcTextSize(ctx, text)) / 2,
                h / 2 + app.gui.TEXT_BASE_HEIGHT * 2)
            ImGui.Text(ctx, text)
            ImGui.EndChild(ctx)
        end
    end

    function app.iconButton(ctx, icon, colClass, font)
        local font = font or app.gui.st.fonts.icons_large
        ImGui.PushFont(ctx, font)
        local x, y = ImGui.GetCursorPos(ctx)
        local w = select(1, ImGui.CalcTextSize(ctx, ICONS[(icon):upper()])) +
            ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_FramePadding) * 2
        local clicked
        if ImGui.InvisibleButton(ctx, '##menuBtn' .. icon, w, ImGui.GetTextLineHeightWithSpacing(ctx)) then
            clicked = true
        end
        if ImGui.IsItemHovered(ctx) and not ImGui.IsItemActive(ctx) then
            app.gui:pushColors(colClass.hovered)
        elseif ImGui.IsItemActive(ctx) then
            app.gui:pushColors(colClass.active)
        else
            app.gui:pushColors(colClass.default)
        end
        ImGui.SetCursorPos(ctx, x + ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_FramePadding),
            y + select(2, ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_FramePadding)))
        ImGui.Text(ctx, tostring(ICONS[icon:upper()]))
        app.gui:popColors(colClass.default)
        ImGui.PopFont(ctx)
        ImGui.SetCursorPos(ctx, x + w, y)
        return clicked
    end

    function app.drawSettings()
        local ctx = app.gui.ctx
        local w = 700 * app.settings.current.uiScale
        -- since sometimes we need to capture Escape, we need to make sure it doesn't trigger
        -- closing this window. So we increment a counter which will be reset if the shortcut is
        -- being captured, so that we can know to ignore the captured key unless some frames have passed.
        app.temp.captureCounter = app.temp.captureCounter and app.temp.captureCounter + 1 or 0
        ImGui.SetNextWindowSize(ctx, w, 0, nil)
        if app.settings.current.settingsWindowPos == nil then
            ImGui.SetNextWindowPos(ctx, app.gui.screen.size[1] / 2, app.gui.screen.size[2] / 2, ImGui.Cond_Appearing, 0.5,
                0.5)
        else
            ImGui.SetNextWindowPos(ctx, app.settings.current.settingsWindowPos[1],
                app.settings.current.settingsWindowPos[2], ImGui.Cond_Appearing)
        end
        local visible, open = ImGui.BeginPopupModal(ctx, Scr.name .. ' Settings##settingsWindow', true,
            ImGui.WindowFlags_NoDocking | ImGui.WindowFlags_AlwaysAutoResize)
        if visible then
            app.temp.settingsWindowOpen = true
            app.settings.current.settingsWindowPos = { ImGui.GetWindowPos(ctx) }
            ImGui.SeparatorText(ctx, 'General')
            app.settings.current.uiScale = app.gui:setting('dragdouble', T.SETTINGS.UI_SCALE.LABEL,
                    T.SETTINGS.UI_SCALE.HINT,
                    app.settings.current.uiScale * 100,
                    { default = app.settings.default.uiScale * 100, min = 50, max = 200, speed = 1, format = '%.f%%', dontUnpdateWhileEnteringManually = true, flags = (ImGui.SliderFlags_AlwaysClamp) }) /
                100
            app.settings.current.followSelectedTrack = app.gui:setting('checkbox', T.SETTINGS.FOLLOW_SELECTED_TRACK
                .LABEL, T.SETTINGS.FOLLOW_SELECTED_TRACK.HINT, app.settings.current.followSelectedTrack)
            app.settings.current.mouseScrollReversed = app.gui:setting('checkbox', T.SETTINGS.MW_REVERSED.LABEL,
                T.SETTINGS.MW_REVERSED.HINT, app.settings.current.mouseScrollReversed)
            app.settings.current.volType = app.gui:setting('combo', T.SETTINGS.VOL_TYPE.LABEL, T.SETTINGS.VOL_TYPE.HINT,
                app.settings.current.volType,
                {
                    list = T.SETTINGS.LISTS[T.SETTINGS.VOL_TYPE.LABEL][VOL_TYPE.TRIM] ..
                        '\0' .. T.SETTINGS.LISTS[T.SETTINGS.VOL_TYPE.LABEL][VOL_TYPE.UI] .. '\0'
                })
            app.settings.current.createInsideFolder = app.gui:setting('checkbox', T.SETTINGS.CREATE_INSIDE_FODLER.LABEL,
                T.SETTINGS.CREATE_INSIDE_FODLER.HINT, app.settings.current.createInsideFolder)
            if app.settings.current.createInsideFolder then
                app.settings.current.sendFolderName = app.gui:setting('text_with_hint', '###sendFolderName',
                    T.SETTINGS.SEND_FOLDER_NAME.HINT, app.settings.current.sendFolderName,
                    { hint = T.SETTINGS.SEND_FOLDER_NAME.LABEL }, true)
            end
            app.settings.current.textMinimizationStyle = app.gui:setting('combo',
                T.SETTINGS.TEXT_MINIMIZATION_STYLE.LABEL, T.SETTINGS.TEXT_MINIMIZATION_STYLE.HINT,
                app.settings.current.textMinimizationStyle,
                {
                    list = T.SETTINGS.LISTS[T.SETTINGS.TEXT_MINIMIZATION_STYLE.LABEL][MINIMIZATION_STYLE.PT] ..
                        '\0' ..
                        T.SETTINGS.LISTS[T.SETTINGS.TEXT_MINIMIZATION_STYLE.LABEL][MINIMIZATION_STYLE.TRIM] .. '\0'
                })

            ImGui.SeparatorText(ctx, 'Shortcuts')
            local resetCounter = false
            app.settings.current.shortcuts.closeScript, resetCounter = app.gui:setting('shortcut',
                T.SETTINGS.SHORTCUTS.CLOSE_SCRIPT.LABEL,
                T.SETTINGS.SHORTCUTS.CLOSE_SCRIPT.HINT, app.settings.current.shortcuts.closeScript,
                {
                    existingShortcuts = OD_TableFilter(app.settings.current.shortcuts,
                        function(k, v) return k ~= 'closeScript' end)
                })
            if resetCounter then app.temp.captureCounter = 0 end
            app.settings.current.shortcuts.addSend, resetCounter = app.gui:setting('shortcut',
                T.SETTINGS.SHORTCUTS.NEW_SEND.LABEL,
                T.SETTINGS.SHORTCUTS.NEW_SEND.HINT, app.settings.current.shortcuts.addSend,
                {
                    existingShortcuts = OD_TableFilter(app.settings.current.shortcuts,
                        function(k, v) return k ~= 'addSend' end)
                })
            if resetCounter then app.temp.captureCounter = 0 end
            app.settings.current.shortcuts.addRecv, resetCounter = app.gui:setting('shortcut',
                T.SETTINGS.SHORTCUTS.NEW_RECV.LABEL,
                T.SETTINGS.SHORTCUTS.NEW_RECV.HINT, app.settings.current.shortcuts.addRecv,
                {
                    existingShortcuts = OD_TableFilter(app.settings.current.shortcuts,
                        function(k, v) return k ~= 'addRecv' end)
                })
            if resetCounter then app.temp.captureCounter = 0 end
            app.settings.current.shortcuts.addHW, resetCounter = app.gui:setting('shortcut',
                T.SETTINGS.SHORTCUTS.NEW_HW.LABEL,
                T.SETTINGS.SHORTCUTS.NEW_HW.HINT, app.settings.current.shortcuts.addHW,
                {
                    existingShortcuts = OD_TableFilter(app.settings.current.shortcuts,
                        function(k, v) return k ~= 'addHW' end)
                })
            if resetCounter then app.temp.captureCounter = 0 end
            app.settings.current.shortcuts.markFavorite, resetCounter = app.gui:setting('shortcut',
                T.SETTINGS.SHORTCUTS.MARK_FAVORITE.LABEL,
                T.SETTINGS.SHORTCUTS.MARK_FAVORITE.HINT, app.settings.current.shortcuts.markFavorite,
                {
                    existingShortcuts = OD_TableFilter(app.settings.current.shortcuts,
                        function(k, v) return k ~= 'markFavorite' end)
                })
            if resetCounter then app.temp.captureCounter = 0 end
            ImGui.SeparatorText(ctx, 'Ordering')

            app.settings.current.fxTypeOrder, app.settings.current.fxTypeVisibility = app.gui:setting('orderable_list',
                T.SETTINGS.FX_TYPE_ORDER.LABEL, T.SETTINGS.FX_TYPE_ORDER.HINT,
                { app.settings.current.fxTypeOrder, app.settings.current.fxTypeVisibility })
            app.settings.current.sendTypeOrder, app.settings.current.sendTypeVisibility = app.gui:setting(
                'orderable_list', T.SETTINGS.SEND_TYPE_ORDER.LABEL, T.SETTINGS.SEND_TYPE_ORDER.HINT,
                { app.settings.current.sendTypeOrder, app.settings.current.sendTypeVisibility })
            ImGui.SeparatorText(ctx, 'Color')
            for i, type in ipairs(app.settings.current.sendTypeOrder) do
                app.settings.current.sendTypeColor[type] = app.gui:setting('colorpicker',
                    T.SETTINGS.SEND_TYPE_COLOR.LABEL:format(T.SEND_TYPE_NAMES[type].SINGULAR),
                    T.SETTINGS.SEND_TYPE_COLOR.HINT:format(T.SEND_TYPE_NAMES[type].SINGULAR),
                    app.settings.current.sendTypeColor[type],
                    { default = app.settings.default.sendTypeColor[type] })
            end
            app.drawHint('settings')
            app:drawMsg()
            if app.temp.captureCounter > 3 and OD_IsGlobalKeyDown(OD_KEYCODES.ESCAPE) then
                app.temp.ignoreEscapeKey = true
                OD_ReleaseGlobalKeys()
                app.db:sync(true)
                ImGui.CloseCurrentPopup(ctx)
            else
                OD_ReleaseGlobalKeys()
            end
            ImGui.EndPopup(ctx)
        else
            app.temp._capturing = false
        end
        if app.temp.settingsWindowOpen and not ImGui.IsPopupOpen(ctx, Scr.name .. ' Settings##settingsWindow') then
            app.temp.settingsWindowOpen = false
            OD_ReleaseGlobalKeys()
            app.db:sync(true)
            app.settings:save()
        end
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
                    ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding) * 2
                local x = prevX - w - ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
                prevX = x
                ImGui.SetCursorPosX(ctx, x)
                if app.iconButton(ctx, btn.icon, app.gui.st.col.buttons.topBarIcon) then clicked = btn.icon end
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
        app:setHoveredHint('main', app.scr.name .. ' v' .. app.scr.version .. ' by ' .. app.scr.author)
        app.gui:popColors(app.gui.st.col.title)
        ImGui.PopFont(ctx)
        ImGui.PushFont(ctx, app.gui.st.fonts.large)
        ImGui.SameLine(ctx)
        if app.db.track and next(app.db.track) then
            ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing) * 2)
            local col = app.db.track.color
            if col ~= 0x000000ff then
                local x, y = ImGui.GetCursorScreenPos(ctx)
                local h = select(2, ImGui.CalcTextSize(ctx, app.db.track.name))
                local padding = { ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding) }
                h = h
                y = y + padding[2]
                rad = h / 4
                ImGui.DrawList_AddRectFilled(app.gui.draw_list, x - h / 4, y + h / 4, x + h / 4, y + h / (4 / 3), col, 2)
                ImGui.AlignTextToFramePadding(ctx)
                ImGui.SetCursorPosX(ctx,
                    ImGui.GetCursorPosX(ctx) + rad + ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing) * 2)
            end
            ImGui.BeginDisabled(ctx)
            ImGui.Text(ctx, app.db.track.name)
            ImGui.EndDisabled(ctx)
        end
        local caption = app.db.track and app.db.track.name or ''
        ImGui.BeginDisabled(ctx)
        if app.page == APP_PAGE.SEARCH_SEND then
            caption = ('Add %s'):format(app.temp.addSendType == SEND_TYPE.SEND and 'send' or 'receive')
            ImGui.SameLine(ctx)
            ImGui.Text(ctx, " | " .. caption)
        end
        ImGui.EndDisabled(ctx)
        local menu = {}
        if app.page == APP_PAGE.MIXER then
            table.insert(menu, { icon = 'close', hint = 'Close' })
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
            table.insert(menu, { icon = 'dock_down', hint = 'Dock' })
        end
        table.insert(menu, { icon = 'money', hint = ('%s is free, but donations are welcome :)'):format(Scr.name) })
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
                if app.settings.current.lastDockId then
                    app.gui.mainWindow.dockTo = app.settings.current.lastDockId
                else
                    app:msg(T.ERROR.NO_DOCK)
                end
            elseif btn == 'gear' then
                ImGui.OpenPopup(ctx, Scr.name .. ' Settings##settingsWindow')
            elseif btn == 'right' then
                app.setPage(APP_PAGE.MIXER)
            elseif btn == 'money' then
                OD_OpenLink(Scr.donation)
            end
        end
    end

    function app.drawHint(window)
        local ctx = app.gui.ctx
        local status, col = app:getHint(window)
        ImGui.Separator(ctx)
        if col then app.gui:pushColors(app.gui.st.col[col]) end
        ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + select(2,ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding))*2)
        ImGui.Text(ctx, status)
        if col then app.gui:popColors(app.gui.st.col[col]) end
        app:setHint(window, '')
    end

    function app.drawZoom()
        local ctx = app.gui.ctx
        local w = 100 * app.settings.current.uiScale
        local gripWidth = 12 * app.settings.current.uiScale
        local minZoom, maxZoom = 45, 110
        ImGui.PushFont(ctx, app.gui.st.fonts.small)
        app.gui:pushStyles(app.gui.st.vars.zoomSlider)
        app.gui:pushColors(app.gui.st.col.zoomSlider)
        ImGui.SetCursorPos(ctx,
            app.gui.mainWindow.size[1] - w - ImGui.GetStyleVar(ctx, ImGui.StyleVar_WindowPadding) - gripWidth,
            app.gui.mainWindow.size[2] - (app.gui.st.sizes.hintHeight + app.gui.TEXT_BASE_HEIGHT_SMALL) / 2 -
            ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding))
        ImGui.SetNextItemWidth(ctx, w)
        local rv, v = ImGui.SliderInt(ctx, '##zoom', app.settings.current.sendWidth, minZoom, maxZoom, '')
        local shouldReset, v = app.resetOnDoubleClick('##zoom', v, app.settings.default.sendWidth)

        ImGui.PopFont(ctx)
        app.gui:popColors(app.gui.st.col.zoomSlider)
        app.gui:popStyles(app.gui.st.vars.zoomSlider)
        if rv or shouldReset then
            app.settings.current.sendWidth = v
            app.db:recalculateShortNames()
            app.settings:save()
            app.refreshWindowSizeOnNextFrame = true
        end
        app:setHoveredHint('main', 'Drag to zoom horizontally')
    end

    function app.drawMainWindow()
        local ctx = app.gui.ctx

        if app.refreshWindowSizeOnNextFrame then
            app.refreshWindowSize()
        end

        ImGui.SetNextWindowPos(ctx, 100, 100, ImGui.Cond_FirstUseEver)
        ImGui.SetNextWindowSizeConstraints(app.gui.ctx, app.gui.mainWindow.min_w, app.gui.mainWindow.min_h,
            app.gui.mainWindow.max_w, app.gui.mainWindow.max_h)

        if app.gui.mainWindow.dockId == 0 and (app.gui.mainWindow.lastDockId == nil or app.gui.mainWindow.dockTo ~= nil) and app.gui.mainWindow.size ~= nil and app.gui.mainWindow.pos ~= nil and not ImGui.IsMouseDragging(ctx, 0) then
            if app.temp.framesUntilSave and app.temp.framesUntilSave > 3 then
                -- since there are two frames time between dragging to the dock and the window actually docking,
                -- we need to wait a bit before saving the size and position and only save if window is still undocked
                app.settings.current.undockedWindowSize = app.gui.mainWindow.size
                app.settings.current.undockedWindowPos = app.gui.mainWindow.pos
                app.temp.framesUntilSave = nil
            else
                app.temp.framesUntilSave = (app.temp.framesUntilSave or 0) + 1
            end
        else
            app.temp.framesUntilSave = nil
        end

        if app.gui.mainWindow.dockTo ~= nil then
            if app.gui.mainWindow.dockTo == 0 then -- undocking
                if app.settings.current.undockedWindowPos and app.settings.current.undockedWindowSize then
                    ImGui.SetNextWindowPos(ctx, app.settings.current.undockedWindowPos[1],
                        app.settings.current.undockedWindowPos[2])
                    ImGui.SetNextWindowSize(ctx, app.settings.current.undockedWindowSize[1],
                        app.settings.current.undockedWindowSize[2])
                end
            end
            ImGui.SetNextWindowDockID(ctx, app.gui.mainWindow.dockTo, ImGui.Cond_Always)
            app.gui.mainWindow.dockTo = nil
        end



        local visible, open = ImGui.Begin(ctx, Scr.name .. "###mainWindow",
            true,
            ImGui.WindowFlags_NoTitleBar |
            ImGui.WindowFlags_NoCollapse | app.page.windowFlags)
        app.gui.mainWindow.pos = { ImGui.GetWindowPos(ctx) }
        app.gui.mainWindow.size = { ImGui.GetWindowSize(ctx) }
        app.gui.screen = { size = { OD_GetScreenSize() } }
        app.settings.current.lastWindowWidth, app.settings.current.lastWindowHeight = app.gui.mainWindow.size[1],
            app.gui.mainWindow.size[2]



        if ImGui.GetWindowDockID(ctx) ~= app.gui.mainWindow.dockId then
            app.refreshWindowSizeOnNextFrame = true
            app.gui.mainWindow.dockId = ImGui.GetWindowDockID(ctx)
            if app.gui.mainWindow.dockId < 0 then
                app.settings.current.lastDockId = app.gui.mainWindow.dockId
                app.settings:save()
            end
        end

        if ImGui.IsWindowAppearing(ctx) then
            ImGui.SetConfigVar(ctx, ImGui.ConfigVar_DockingNoSplit, 1)
        end
        if visible then
            if app.gui.mainWindow.debugOverLay then
                local left, top = ImGui.GetCursorScreenPos(app.gui.ctx)
                ImGui.DrawList_AddRectFilled(ImGui.GetForegroundDrawList(ctx), app.gui.mainWindow.debugOverLay[1] + left,
                    app.gui.mainWindow.debugOverLay[2] + top,
                    app.gui.mainWindow.debugOverLay[1] + app.gui.mainWindow.debugOverLay[3] + left,
                    app.gui.mainWindow.debugOverLay[2] + app.gui.mainWindow.debugOverLay[4] + top, 0xff000088, 0,
                    ImGui.DrawFlags_Closed)
            end

            app.drawTopBar()

            if ImGui.BeginChild(ctx, '##body', 0.0, -app.gui.st.sizes.hintHeight) then
                if app.page == APP_PAGE.MIXER then
                    app.drawMixer()
                    if app.isShortcutPressed('closeScript') and not ImGui.IsPopupOpen(ctx, '', ImGui.PopupFlags_AnyPopup) and not app.temp.ignoreEscapeKey then open = false end
                    app.temp.ignoreEscapeKey = false
                elseif app.page == APP_PAGE.SEARCH_SEND or app.page == APP_PAGE.SEARCH_FX then
                    app.drawSearch()
                elseif app.page == APP_PAGE.NO_TRACK then
                    app.drawErrorNoTrack()
                end
                ImGui.EndChild(ctx)
            end
            app.drawHint('main')
            if app.page == APP_PAGE.MIXER then
                app.drawZoom()
            end
            app.drawSettings()
            app:drawMsg()


            ImGui.End(ctx)
        end
        return open
    end

    function app.loop()
        local change = app.gui:recalculateZoom(app.settings.current.uiScale)
        if change ~= 1 then
            app.settings.current.lastWindowWidth = app.settings.current.lastWindowWidth * change
            app.settings.current.lastWindowHeight = app.settings.current.lastWindowHeight * change
            app.refreshWindowSizeOnNextFrame = true
        end
        app:checkProjectChange()
        local ctx = app.gui.ctx
        app.db:syncUIVol()
        app.gui:pushColors(app.gui.st.col.main)
        app.gui:pushStyles(app.gui.st.vars.main)
        ImGui.PushFont(ctx, app.gui.st.fonts.default)

        app.handlePageSwitch()
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

    function PrintTraceback(err)
        local byLine = "([^\r\n]*)\r?\n?"
        local trimPath = "[\\/]([^\\/]-:%d+:.+)$"
        local stack = {}
        for line in string.gmatch(err, byLine) do
            local str = string.match(line, trimPath) or line
            stack[#stack + 1] = str
        end
        r.ShowConsoleMsg(
            "Error: " .. stack[1] .. "\n\n" ..
            "Stack traceback:\n\t" .. table.concat(stack, "\n\t", 3) .. "\n\n" ..
            "Reaper:       \t" .. r.GetAppVersion() .. "\n" ..
            "Platform:     \t" .. r.GetOS()
        )
    end

    -- function and concept by sexan
    function PDefer(func)
        r.defer(function()
            local status, err = xpcall(func, debug.traceback)
            if not status then
                PrintTraceback(err)
                Release() -- DO RELEASING HERE
            end
        end)
    end

    function Release()
        OD_ReleaseGlobalKeys()
    end

    function Exit()
        if app and app.settings then app.settings:save() end
        app.logger:logInfo('Exited')
        Release()
    end

    r.atexit(Exit)

    ---------------------------------------
    -- START ------------------------------
    ---------------------------------------
    -- make it so that script gets terminated on a relaunch
    reaper.set_action_options(1)

    -- app.settings:save()
    app.logger:logInfo('Started')
    app.logger:logAppInfo(app.logger.LOG_LEVEL.DEBUG, app)
    app.logger:logTable(app.logger.LOG_LEVEL.DEBUG, 'Settings', app.settings.current)
    app.db:init()
    app.db:sync()
    app.setPage(APP_PAGE.MIXER)
    PDefer(app.loop)
end
