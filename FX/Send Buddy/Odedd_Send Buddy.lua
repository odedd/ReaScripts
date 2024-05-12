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
        reaper_version = 6.76, -- required for APPLYFX_FORMAT and OPENCOPY_CFGIDX
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
            local width = app.page.width
            if app.page == APP_PAGE.MIXER then
                local shouldScroll = app.db.maxNumInserts > app.settings.current.maxNumInserts
                width = app.settings.current.sendWidth * (app.db.numSends + 1) +
                    r.ImGui_GetStyleVar(app.gui.ctx, r.ImGui_StyleVar_WindowPadding()) +
                    (shouldScroll and r.ImGui_GetStyleVar(app.gui.ctx, r.ImGui_StyleVar_ScrollbarSize()) or 0)
            end
            r.ImGui_SetNextWindowSize(app.gui.ctx, math.max(width, app.page.width), 0)
            app.refreshWindowSizeOnNextFrame = false
        end
    end

    function app.handlePageSwitch()
        if app.pageSwitched then
            app.framesSincePageSwitch = (app.framesSincePageSwitch or 0) + 1
        end
        if app.framesSincePageSwitch == 1 then
            --  different pages have different window sizes. since the window gets automatically resized, we need to set the size to a small value first
            app.refreshWindowSize()
        end
        if app.framesSincePageSwitch and app.framesSincePageSwitch > 1 then
            app.pageSwitched = false
            app.framesSincePageSwitch = nil
        end
    end

    function app.setPage(page)
        app.page = page
        app.pageSwitched = true
    end

    function app.drawMixer()
        local ctx = app.gui.ctx
        app.db:sync()
        r.ImGui_PushFont(ctx, app.gui.st.fonts.small)
        local drawSend = function(s, part, label)
            local drawFader = function()
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
                    app.settings.current.faderHeight,
                    scaledV,
                    app.settings.current.minSendVol,
                    app.settings.current.maxSendVol * app.settings.current.scaleFactor,
                    '')
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
                        if v < app.settings.current.minSendVol then
                            v = app.settings.current.minSendVol
                        end
                        local newV = v + (app.settings.current.mouseScrollReversed and -mw or mw) * scale
                        s:setVolDB(newV)
                    end
                end
            end

            local drawPan = function()
                local mw = r.ImGui_GetMouseWheel(ctx)
                r.ImGui_SetNextItemWidth(ctx, app.settings.current.sendWidth)
                app.gui:pushStyles(app.gui.st.vars.pan)
                local rv, v2 = r.ImGui_SliderDouble(ctx, '##p', s.pan, -1, 1, '')
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
                if rv then
                    s:setVolDB(v3)
                end
            end

            local drawSoloMute = function()
                local w = app.settings.current.sendWidth / 2 -
                    r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) / 2
                app.gui:pushColors(app.gui.st.col.buttons.mute[s.mute])
                if r.ImGui_Button(ctx, 'M##mute' .. s.order, w) then
                    s:setMute(s.mute == 0.0)
                end
                app.gui:popColors(app.gui.st.col.buttons.mute[s.mute])
                r.ImGui_SameLine(ctx)
                local soloed = app.db.soloedSends[s.order] ~= nil
                app.gui:pushColors(app.gui.st.col.buttons.solo[soloed and 1 or 0])
                if r.ImGui_Button(ctx, 'S##solo' .. s.order, w) then
                    s:setSolo(not soloed, not r.ImGui_IsKeyDown(ctx, app.gui.keyModCtrlCmd))
                end
                app.gui:popColors(app.gui.st.col.buttons.solo[soloed and 1 or 0])
            end
            local drawModeButton = function()
                local w = app.settings.current.sendWidth
                app.gui:pushColors(app.gui.st.col.buttons.mode[s.mode])
                local label = s.mode == 0 and "post" or (s.mode == 1 and "pre-fx" or "post-fx")
                if r.ImGui_Button(ctx, label .. '##mode' .. s.order, w) then
                    s:setMode(s.mode == 0 and 1 or (s.mode == 1 and 3 or 0))
                    -- s:setSolo(not soloed, not r.ImGui_IsKeyDown(ctx, app.gui.keyModCtrlCmd))
                end
                app.gui:popColors(app.gui.st.col.buttons.mode[s.mode])
            end
            local drawRouteButton = function()
                local w = app.settings.current.sendWidth
                app.gui:pushColors(app.gui.st.col.buttons.route)
                r.ImGui_BeginGroup(ctx)
                if r.ImGui_Button(ctx, SRC_CHANNELS[s.srcChan].label .. '##srcChan' .. s.order, w) then
                    r.ImGui_OpenPopup(ctx, '##srcChanMenu' .. s.order)
                end
                local label = s.srcChan == -1 and '' or
                    (s.destChan < 1024) and (s.destChan + 1 .. '/' .. (s.destChan + SRC_CHANNELS[s.srcChan].numChannels)) or
                    s.destChan + 1 - 1024
                if s.srcChan == -1 then
                    r.ImGui_BeginDisabled(ctx)
                end
                if r.ImGui_Button(ctx, label .. '##destChan' .. s.order, w) then
                    r.ImGui_OpenPopup(ctx, '##destChanMenu' .. s.order)
                end
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
                if shortened then
                    app:setHoveredHint('main', s.name)
                end
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
                    app:setHoveredHint('main', insert.name)
                end
                app.gui:pushColors(app.gui.st.col.insert.add)
                r.ImGui_PushFont(ctx, app.gui.st.fonts.icons_small)
                if r.ImGui_Button(ctx, "P##", app.settings.current.sendWidth) then
                    app.temp.addFxToSend = s
                    app.setPage(APP_PAGE.SEARCH_FX)
                end
                r.ImGui_PopFont(ctx)
                app.gui:popColors(app.gui.st.col.insert.add)
            end

            r.ImGui_PushID(ctx, 's' .. (s and s.order or -1))
            -- r.ImGui_BeginGroup(ctx)

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
                elseif part == 'modebutton' then
                    drawModeButton()
                elseif part == 'routebutton' then
                    drawRouteButton()
                elseif part == 'fader' then
                    drawFader()
                elseif part == 'volLabel' then
                    drawVolLabel()
                elseif part == 'sendName' then
                    drawSendName()
                end
            end

            r.ImGui_PopID(ctx)
            -- r.ImGui_EndGroup(ctx)
        end

        -- r.ImGui_SetWindowSize(ctx, (app.settings.current.sendWidth + r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2) * app.db.numSends + (r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding())), app.gui.mainWindow.size[2])
        local btnHeight, btnStartPosY = 0, 0
        if next(app.db.sends) then
            local h = -app.gui.vars.framePaddingY +
                (math.min(app.db.maxNumInserts, app.settings.current.maxNumInserts) + 1) *
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
            local parts = {
                { name = 'solomute',    label = 'S/M' },
                { name = 'modebutton',  label = 'Mode' },
                { name = 'routebutton', label = 'Route' },
                { name = 'pan',         label = 'Pan' },
                { name = 'fader',       label = 'Send\nVolume' },
                { name = 'volLabel' },
                { name = 'sendName' }
            }
            r.ImGui_BeginGroup(ctx)
            btnStartPosY = r.ImGui_GetCursorPosY(ctx)
            for j, part in ipairs(parts) do
                if part.name == 'solomute' then
                    btnStartPosY = r.ImGui_GetCursorPosY(ctx)
                end
                r.ImGui_BeginGroup(ctx)
                for i, s in OD_PairsByOrder(app.db.sends) do
                    drawSend(s, part.name)
                    r.ImGui_SameLine(ctx)
                end
                r.ImGui_EndGroup(ctx)
                if part.name == 'volLabel' then
                    btnHeight = r.ImGui_GetCursorPosY(ctx) - btnStartPosY -
                        select(2, r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()))
                end
            end
            r.ImGui_EndGroup(ctx)
            r.ImGui_SameLine(ctx)
        end
        if btnHeight == 0 then btnHeight = app.settings.current.faderHeight end

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
            filterResults('')
            r.ImGui_SetKeyboardFocusHere(ctx, 0)
        end
        r.ImGui_SetNextItemWidth(ctx, w)
        local rv, searchInput = r.ImGui_InputText(ctx, "##searchInput", app.temp.searchInput)
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
        local outer_size = { 0.0, app.gui.TEXT_BASE_HEIGHT_LARGE * app.settings.current.maxSearchResults }
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
                    r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) - 1)
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
            if app.temp.checkScrollDown and highlightedY > upperRowY + app.settings.current.maxSearchResults * app.gui.TEXT_BASE_HEIGHT_LARGE then
                r.ImGui_SetScrollY(ctx,
                    r.ImGui_GetScrollY(ctx) +
                    (highlightedY - (upperRowY + (app.settings.current.maxSearchResults - 1) * app.gui.TEXT_BASE_HEIGHT_LARGE) - 1))
                app.temp.checkScrollDown = false
            end
            if app.temp.checkScrollUp and highlightedY <= upperRowY + app.gui.TEXT_BASE_HEIGHT_LARGE then
                r.ImGui_SetScrollY(ctx,
                    r.ImGui_GetScrollY(ctx) - (upperRowY - highlightedY + 1) - app.gui.TEXT_BASE_HEIGHT_LARGE)
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
            app.setPage(APP_PAGE.MIXER)
        end
    end

    function app.drawErrorNoSends()
        local ctx = app.gui.ctx
        app.db:sync()
        local w, h = app.page.width - r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()) * 2,
            app.page.width * 3 / 4
        if r.ImGui_BeginChild(ctx, '##noSends', w, h, nil, nil) then
            r.ImGui_Dummy(ctx, w, h)
            r.ImGui_PushFont(ctx, app.gui.st.fonts.icons_huge)
            local text = 'H'
            r.ImGui_SetCursorPos(ctx, (w - r.ImGui_CalcTextSize(ctx, text)) / 2,
                h / 2 - app.gui.TEXT_BASE_HEIGHT * 5)
            r.ImGui_TextColored(ctx, app.gui.st.basecolors.main, text)
            r.ImGui_PopFont(ctx)
            local text = 'No sends here yet...'
            r.ImGui_SetCursorPos(ctx, (w - r.ImGui_CalcTextSize(ctx, text)) / 2,
                h / 2)
            r.ImGui_Text(ctx, text)
            text = 'Why not add one?'
            -- app.gui:pushStyles(app.gui.st.vars.bigButton)
            r.ImGui_SetCursorPos(ctx, w / 2 - r.ImGui_CalcTextSize(ctx, text) / 2, h / 2 + app.gui.TEXT_BASE_HEIGHT * 2)
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

            -- app.gui:popStyles(app.gui.st.vars.bigButton)
            r.ImGui_EndChild(ctx)
        end
    end

    function app.drawErrorNoTrack()
        local ctx = app.gui.ctx
        app.db:sync()
        local w, h = app.page.width - r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()) * 2,
            app.page.width * 3 / 4
        if r.ImGui_BeginChild(ctx, '##noTrack', w, h, nil, nil) then
            r.ImGui_Dummy(ctx, w, h)
            r.ImGui_PushFont(ctx, app.gui.st.fonts.icons_huge)
            local text = 'H'
            r.ImGui_SetCursorPos(ctx, (w - r.ImGui_CalcTextSize(ctx, text)) / 2,
                h / 2 - app.gui.TEXT_BASE_HEIGHT * 5)
            r.ImGui_TextColored(ctx, app.gui.st.basecolors.main, text)
            r.ImGui_PopFont(ctx)
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
            local windowEnd = app.gui.mainWindow.size[1] - r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding())
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
        local rv, btn = beginRightIconMenu(ctx, menu)
        r.ImGui_PopFont(ctx)
        r.ImGui_EndGroup(ctx)
        r.ImGui_Separator(ctx)
        if rv then
            if btn == 'plus' then
                app.setPage(APP_PAGE.SEARCH_SEND)
            elseif btn == 'close' then
                app.setPage(APP_PAGE.CLOSE)
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

        local max_w, max_h = r.ImGui_Viewport_GetSize(r.ImGui_GetMainViewport(ctx))
        app.warningCount = 0

        if app.refreshWindowSizeOnNextFrame then app.refreshWindowSize() end

        r.ImGui_SetNextWindowPos(ctx, 100, 100, r.ImGui_Cond_FirstUseEver())
        local visible, open = r.ImGui_Begin(ctx, "###mainWindow",
            true,
            r.ImGui_WindowFlags_NoDocking() | r.ImGui_WindowFlags_NoCollapse() |
            r.ImGui_WindowFlags_NoTitleBar() | app.page.windowFlags)
        -- r.ImGui_WindowFlags_NoResize()
        app.gui.mainWindow = {
            pos = { r.ImGui_GetWindowPos(ctx) },
            size = { r.ImGui_GetWindowSize(ctx) }
        }

        if visible then
            app.drawTopBar()
            if app.page == APP_PAGE.CLOSE then
                return false
            elseif app.page == APP_PAGE.MIXER then
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

        if app.open and not (app.page == APP_PAGE.CLOSE) then
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
