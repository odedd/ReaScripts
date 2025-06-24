-- @description Plugin Buddy
-- @author Oded Davidov
-- @version 0.0.1
-- @donation https://paypal.me/odedda
-- @license GNU GPL v3
-- @about
--   # Plugin Buddy
--   Plugin selector with advanced tagging capabilities.
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
--   v0

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
    dofile(p .. 'lib/Tags.lua')
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
        level = OD_Logger.LOG_LEVEL.ERROR,
        output = OD_Logger.LOG_OUTPUT.CONSOLE,
        filename = projPath .. Scr.name .. '_' .. projFileName .. '.log'
    })

    local gui = PB_Gui:new({})

    app:connect('gui', gui)
    app:connect('logger', logger)
    app:connect('scr', Scr)
    app:connect('db', DB)
    app:init()
    app.logger:init()
    function app:checkProjectChange(force)
        if force or OD_DidProjectGUIDChange() then
            local projPath, projFileName = OD_GetProjectPaths()
            logger:setLogFile(projPath .. Scr.name .. '_' .. projFileName .. '.log')
        end
    end

    local settings = PB_Settings:new({})
    local tags = PB_Tags:new({})

    app:connect('settings', settings)
    app:connect('tags', tags)
    app.settings:load()
    app.tags:load()
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
        if page ~= app.page then
            app.page = page
            app.pageSwitched = true
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
                -- if app.temp.addSendType == SEND_TYPE.RECV and asset.type ~= ASSETS.TRACK then skip = true end
                -- if asset.type == ASSETS.TRACK and asset.load == app.db.track.guid then skip = true end
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
        end

        local ctx = app.gui.ctx
        local h = select(2, ImGui.GetContentRegionAvail(ctx))
        local w = app.settings.current.keywordPanelWidth * app.settings.current.uiScale
        local node_flags = ImGui.TreeNodeFlags_OpenOnArrow | ImGui.TreeNodeFlags_OpenOnDoubleClick
            | ImGui.TreeNodeFlags_Framed | ImGui.TreeNodeFlags_SpanAllColumns
        -- Keyword Area
        local paddingX = select(1, ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)) * app.settings.current.uiScale
        local paddingY = select(2, ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)) * app.settings.current.uiScale
        if ImGui.BeginChild(ctx, 'keywordArea', w, h) then
            local function drawTagsOfParent(parentId, indent)
                local function drawTagNode(tag)
                    app.gui:pushColors(tag.colors)
                    app.gui:pushStyles(app.gui.st.vars.tag)
                    ImGui.PushFont(ctx, app.gui.st.fonts.small)
                    local globalX, globalY = ImGui.GetCursorScreenPos(ctx)
                    local x, y = ImGui.GetCursorPos(ctx)
                    local triangleW = app.gui.st.vars.tagList[ImGui.StyleVar_IndentSpacing][1] 
                    local extraW = tag.hasChildren and triangleW or 0
                    local tagW, tagH = ImGui.CalcTextSize(ctx, tag.name) + paddingX*2 + extraW, ImGui.GetTextLineHeight(ctx)
                    ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx),globalX, globalY, globalX+tagW, globalY+tagH, tag.colors[ImGui.Col_Button],10)
                    if tag.hasChildren then
                        if tag.open then
                            ImGui.DrawList_AddTriangleFilled(ImGui.GetWindowDrawList(ctx),globalX+paddingX,globalY+paddingY,globalX+paddingX+tagH/2,globalY+paddingY,globalX+paddingX/4+tagH/2,globalY+triangleW, tag.colors[ImGui.Col_Text])
                        else   
                            ImGui.DrawList_AddTriangleFilled(ImGui.GetWindowDrawList(ctx),globalX+paddingX,globalY+paddingY,globalX+paddingX,globalY+tagH-paddingY,globalX+triangleW,globalY+tagH/2, tag.colors[ImGui.Col_Text])
                        end
                    end
                    ImGui.SetCursorPosX(ctx, x+paddingX+extraW)
                    ImGui.Text(ctx, tag.name)
                    ImGui.SetCursorPos(ctx, x, y)
                    if ImGui.InvisibleButton(ctx, tag.id,tagW,tagH) then
                        tag:toggleOpen(not tag.open)
                    end
                    ImGui.PopFont(ctx)
                    app.gui:popColors(tag.colors)
                    app.gui:popStyles(app.gui.st.vars.tag)
                    
                    if tag.open then
                        drawTagsOfParent(tag.id, true)
                        -- ImGui.TreePop(ctx)
                    end
                end
                
                app.gui:pushStyles(app.gui.st.vars.tagList)
                for id, tag in OD_PairsByOrder(app.db.tags) do
                    if tag.parentId == parentId then
                        if indent then
                            ImGui.Indent(ctx)
                        end
                        drawTagNode(tag)
                        if indent then
                            ImGui.Unindent(ctx)
                        end
                    end
                end
                app.gui:popStyles(app.gui.st.vars.tagList)
            end
            drawTagsOfParent(nil, false)

            ImGui.EndChild(ctx)
        end
        ImGui.SameLine(ctx)
        -- Separator Resize Line
        local origX = select(1, ImGui.GetCursorPosX(ctx))
        local separatorX = select(1, ImGui.GetCursorScreenPos(ctx)) + paddingX
        local separatorY = select(2, ImGui.GetCursorScreenPos(ctx))

        ImGui.DrawList_AddLine(ImGui.GetForegroundDrawList(ctx), separatorX, separatorY, separatorX, separatorY + h,
            ImGui.GetStyleColor(ctx, ImGui.Col_Separator))
        ImGui.InvisibleButton(ctx, '##separator', paddingX * 2 + 1, h)
        if ImGui.IsItemHovered(ctx) then
            app:setHoveredHint('main', 'Drag to change keyword list width', nil, nil, 1)
            ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
        end
        if ImGui.IsItemActive(ctx) then
            ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
            local mouseDeltaX, mouseDeltaY = ImGui.GetMouseDragDelta(ctx, nil,
                nil,
                ImGui.MouseButton_Left)
            if mouseDeltaX ~= 0 then
                -- local newWidth = (origX - paddingX) + mouseDeltaX/app.settings.current.uiScale
                local newWidth = (w + mouseDeltaX)/app.settings.current.uiScale
                if newWidth > app.settings.current.minKeywordPanelWidth * app.settings.current.uiScale then
                    app.settings.current.keywordPanelWidth = newWidth
                    ImGui.ResetMouseDragDelta(ctx, ImGui.MouseButton_Left)
                else
                    app.settings.current.keywordPanelWidth = app.settings.current.minKeywordPanelWidth * app.settings.current.uiScale
                end
            end
        end
        ImGui.SameLine(ctx)

        -- Search Area
        local selectedResult = nil
        local hintResult = nil
        local hintContext = nil
        local w = select(1, ImGui.GetContentRegionAvail(ctx))
        if ImGui.BeginChild(ctx, 'searchArea', w) then
            local fontLineHeight = ImGui.GetTextLineHeightWithSpacing(ctx)
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

            local h = select(2, ImGui.GetContentRegionAvail(ctx))
            local maxSearchResults = math.floor(h / (fontLineHeight))

            if rv then
                filterResults(searchInput)
                app.temp.scrollToTop = true
            end

            if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
                -- app.temp.ignoreEscapeKey = true
                -- app.setPage(APP_PAGE.MIXER)
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
                    for i, tagId in ipairs(result.tags) do
                        local tag = app.tags.current.tagInfo[tagId]
                        ImGui.PushStyleColor(ctx, ImGui.Col_Button, tag.color)
                        ImGui.SmallButton(ctx, tag.name)
                        ImGui.PopStyleColor(ctx)
                        ImGui.SameLine(ctx)
                    end
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
                local action = (hintResult.type == ASSETS.TRACK and 'add a send to track %s' or 'add %s to selected track(s)')
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
                    local tracks = app.db:getSelectedTracks()
                    for i, trk in ipairs(tracks) do
                        trk:addInsert(selectedResult.load)
                    end
                end
            end
            ImGui.EndChild(ctx)
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
            app.settings.current.mouseScrollReversed = app.gui:setting('checkbox', T.SETTINGS.MW_REVERSED.LABEL,
                T.SETTINGS.MW_REVERSED.HINT, app.settings.current.mouseScrollReversed)
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
        -- if app.db.track and next(app.db.track) then
        --     ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing) * 2)
        --     local col = app.db.track.color
        --     if col ~= 0x000000ff then
        --         local x, y = ImGui.GetCursorScreenPos(ctx)
        --         local h = select(2, ImGui.CalcTextSize(ctx, app.db.track.name))
        --         local padding = { ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding) }
        --         h = h
        --         y = y + padding[2]
        --         rad = h / 4
        --         ImGui.DrawList_AddRectFilled(app.gui.draw_list, x - h / 4, y + h / 4, x + h / 4, y + h / (4 / 3), col, 2)
        --         ImGui.AlignTextToFramePadding(ctx)
        --         ImGui.SetCursorPosX(ctx,
        --             ImGui.GetCursorPosX(ctx) + rad + ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing) * 2)
        --     end
        --     ImGui.BeginDisabled(ctx)
        --     ImGui.Text(ctx, app.db.track.name)
        --     ImGui.EndDisabled(ctx)
        -- end
        -- local caption = app.db.track and app.db.track.name or ''
        ImGui.BeginDisabled(ctx)
        -- if app.page == APP_PAGE.SEARCH_SEND then
        --     caption = ('Add %s'):format(app.temp.addSendType == SEND_TYPE.SEND and 'send' or 'receive')
        --     ImGui.SameLine(ctx)
        --     ImGui.Text(ctx, " | " .. caption)
        -- end
        ImGui.EndDisabled(ctx)
        local menu = {}
        if app.page == APP_PAGE.SEARCH_FX then
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
        ImGui.SetCursorPosY(ctx,
            ImGui.GetCursorPosY(ctx) + select(2, ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)) * 2)
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
                if app.page == APP_PAGE.SEARCH_FX then
                    app.drawSearch()
                    if app.isShortcutPressed('closeScript') and not ImGui.IsPopupOpen(ctx, '', ImGui.PopupFlags_AnyPopup) and not app.temp.ignoreEscapeKey then open = false end
                    app.temp.ignoreEscapeKey = false
                end
                ImGui.EndChild(ctx)
            end
            app.drawHint('main')
            -- if app.page == APP_PAGE.MIXER then
            --     app.drawZoom()
            -- end
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
    app.setPage(APP_PAGE.SEARCH_FX)
    PDefer(app.loop)
end
