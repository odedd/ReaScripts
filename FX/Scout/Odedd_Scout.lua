-- @description Scout
-- @author Oded Davidov
-- @version 0.0.1
-- @donation https://paypal.me/odedda
-- @license GNU GPL v3
-- @about
--   # Scout
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
    dofile(p .. 'lib/Texts.lua')
    dofile(p .. 'lib/Settings.lua')
    dofile(p .. 'lib/Tags.lua')
    dofile(p .. 'lib/Gui.lua')
    dofile(p .. 'lib/Db.lua')

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

    app.widgets = {
        calcTinyIconSize = function(icon)
            local ctx = app.gui.ctx
            app.temp.iconSizes = app.temp.iconSizes or {}
            if app.temp.iconSizes[icon] then
                return table.unpack(app.temp.iconSizes[icon])
            else
                ImGui.PushFont(ctx, app.gui.st.fonts.icons_tiny)
                local iconW, iconH = ImGui.CalcTextSize(ctx, icon)
                app.temp.iconSizes[icon] = table.pack(iconW, iconH)
                ImGui.PopFont(ctx)
                return table.unpack(app.temp.iconSizes[icon])
            end
        end,

        tinyIcon = function(id, icon, highlighted, disabled)
            local ctx = app.gui.ctx
            local clicked = false
            local textW, textH = ImGui.CalcTextSize(ctx, 'I')
            local paddingX, paddingY = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)
            local iconW, iconH = app.widgets.calcTinyIconSize(icon) --ImGui.CalcTextSize(ctx, icon)

            local x, y = ImGui.GetCursorPos(ctx)
            ImGui.SetCursorPosY(ctx, y + paddingY + (textH - iconH) / 2)
            -- ImGui.AlignTextToFramePadding(ctx)
            if ImGui.InvisibleButton(ctx, 'x##' .. id, iconW, iconH) then
                clicked = true
            end
            local col = highlighted and app.gui.st.basecolors.textDark or
                (disabled and app.gui.st.basecolors.textDark or app.gui.st.col.activeFilterButton[ImGui.Col_Button])
            if not disabled and ImGui.IsItemHovered(ctx) then
                ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand)
                if ImGui.IsItemActive(ctx) then
                    col = app.gui.st.col.activeFilterButton[ImGui.Col_ButtonActive]
                else
                    col = app.gui.st.col.activeFilterButton[ImGui.Col_ButtonHovered]
                end
            end
            -- ImGui.SetCursorPosY(ctx, y + paddingY + (textH - closeButtonSizeH) / 2)
            ImGui.SetCursorPos(ctx, x, y + paddingY + (textH - iconH) / 2)
            ImGui.PushFont(ctx, app.gui.st.fonts.icons_tiny)
            ImGui.TextColored(ctx, col, icon)
            ImGui.PopFont(ctx)
            ImGui.SetCursorPos(ctx, x + iconW, y)
            ImGui.Dummy(ctx, 0, 0)
            if not disabled then return clicked end
        end,
        iconButton = function(icon, colClass, font)
            local ctx = app.gui.ctx
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
    }
    app.selection = {
        items = {},
        count = function(self) return #self.items end,
        empty = function(self)
            self.items = {};
        end,
        add = function(self, item)
            if not self:has(item) then
                table.insert(self.items, item)
            end
        end,
        remove = function(self, item)
            OD_RemoveValue(self.items, item)
        end,
        has = function(self, item)
            return OD_HasValue(self.items, item)
        end,
        selectOnly = function(self, item)
            self:empty();
            table.insert(self.items, item)
        end,
        toggle = function(self, item)
            if self:has(item) then
                self:remove(item)
                return false
            else
                table.insert(self.items, item)
                return true
            end
        end,
        selectRange = function(self, fromIdx, toIdx)
            local from, to = math.min(fromIdx, toIdx), math.max(fromIdx, toIdx)
            for i = from, to do
                self:add(i)
            end
        end,
        results = function(self)
            local results = {}
            for _, resultIndex in pairs(self.items) do
                table.insert(results, app.temp.searchResults[resultIndex])
            end
            return results
        end
    }

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
        app.temp.searchMode = SEARCH_MODE.MAIN
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

    function app.filterResults(query)
        query = OD_DeepCopy(query) or {}
        if query.clear then
            app.temp.searchInput = ''
            app.temp.filter = {}
        end
        query.text = query.text or app.temp.filter.text or ''
        app.temp.searchResults = {}

        -- Prepare filter
        local filter = app.temp.filter or {}
        filter.text = query.text:gsub('%s+', ' ')
        filter.tags = filter.tags or {}

        -- Add/remove tags
        if query.addTags then
            for tagId, positive in pairs(query.addTags) do
                filter.tags[tagId] = positive
            end
        end
        if query.removeTags then
            for _, tagId in ipairs(query.removeTags) do
                filter.tags[tagId] = nil
            end
        end

        -- Other filter fields
        for queryType, queryValue in pairs(query) do
            if queryType ~= 'text' and queryType ~= 'addTags' and queryType ~= 'removeTags' then
                filter[queryType] = (queryValue ~= 'all') and queryValue or nil
            end
        end
        app.temp.filter = filter

        -- Filtering assets
        local assets = app.db.assets
        local tagsTable = app.db.tags
        local filterTags = filter.tags
        local filterText = filter.text:lower()

        for i = 1, #assets do
            local asset = assets[i]

            -- Type filters
            if (filter.type and asset.type ~= filter.type)
                or (filter.fx_type and asset.fx_type ~= filter.fx_type)
                or (filter.fxDeveloper and (not asset.vendor or asset.vendor ~= filter.fxDeveloper))
                or (filter.fxFolderId and (asset.type ~= ASSETS.PLUGIN or not asset:isInFolder(filter.fxFolderId)))
                or (filter.fxCategory and (asset.type ~= ASSETS.PLUGIN or not asset:isInCategory(filter.fxCategory)))
            then
                goto skip
            end

            -- Tag filters
            for tagId, positive in pairs(filterTags) do
                local hasValue = OD_HasValue(asset.tags, tagId)
                if not hasValue then
                    local tag = tagsTable[tagId]
                    if tag and tag.descendants then
                        for d = 1, #tag.descendants do
                            if OD_HasValue(asset.tags, tag.descendants[d].id) then
                                hasValue = true
                                break
                            end
                        end
                    end
                end
                if (positive and not hasValue) or (not positive and hasValue) then
                    goto skip
                end
            end

            -- Text filter
            local foundIndexes = {}
            local allWordsFound = true
            local filterWords = {}
            for word in filterText:gmatch("%S+") do
                table.insert(filterWords, word)
            end

            -- Pre-lowercase asset searchText if not already done
            if not asset._searchTextLower then
                asset._searchTextLower = {}
                for j = 1, #asset.searchText do
                    asset._searchTextLower[j] = asset.searchText[j].text:lower()
                end
            end

            for _, word in ipairs(filterWords) do
                local wordFound = false
                for j = 1, #asset._searchTextLower do
                    local assetWordLower = asset._searchTextLower[j]
                    local pos = string.find(assetWordLower, word, 1, true)
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
                app.temp.searchResults[#app.temp.searchResults + 1] = asset
            end
            ::skip::
        end

        -- make the first result selected and set the keyboard position to it
        app.temp.resultAtKeyboardPos = (#app.temp.searchResults > 0) and 1 or nil
        app.selection:empty()
        if #app.temp.searchResults > 0 then app.selection:add(1) end
        app.temp.lastInvisibleGroup = nil
    end

    function app.drawSearch()
        local ctx = app.gui.ctx
        app.gui:pushStyles(app.gui.st.vars.searchWindow)
        app.gui:pushColors(app.gui.st.col.searchWindow)

        -- Inline variable explanations for layout/UI parameters:
        local w, h = ImGui.GetContentRegionAvail(ctx)
        local tagAreaW = app.settings.current.filterPanelWidth * app.settings.current.uiScale
        local paddingX, paddingY = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)
        local spacingX, spacingY = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
        local tagAreaScreenX = select(1, ImGui.GetCursorScreenPos(ctx)) + w - tagAreaW -- X position for tag area
        local upperRowY = ImGui.GetCursorPosY(ctx)                                     -- Y position for upper row, used for "sticky" first group title
        local upperRowScreenY = select(2, ImGui.GetCursorScreenPos(ctx))               -- Y position for upper row, used for "sticky" first group title
        local fontLineHeight = ImGui.GetTextLineHeightWithSpacing(ctx)
        local filterAreaH = select(2, ImGui.GetContentRegionAvail(ctx))                -- Height available for search results

        local tagInfo = app.tags.current.tagInfo
        local searchResults = app.temp.searchResults or
            {} -- Current search results -- clear drop target hint on every frame
        local hintResult, hintContext = nil, nil, nil
        local flatRows = {}

        local tableFlags = ImGui
            .TableFlags_ScrollY -- Table flags for vertical scrolling
        local selectableFlags = ImGui.SelectableFlags_SpanAllColumns |
            ImGui
            .SelectableFlags_AllowDoubleClick -- Selectable flags for ImGui

        if app.logger.level == OD_Logger.LOG_LEVEL.DEBUG then
            ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx),
                tagAreaScreenX, 10, tagAreaScreenX + tagAreaW, 1000, 0xffffff22)
        end

        local drawActiveFilters = function()
            local x, y = ImGui.GetCursorPos(ctx)
            local lines = 1
            local height = 0
            local activeFilters = app.temp.activeFilters ~= nil and app.temp.activeFilters or {}

            local currentActiveKeys = {}
            -- local numFilters = 0
            for i, filterKey in ipairs(FILTER_CAPSULE_TYPES) do
                local filterItem = nil
                local selectedItemName
                if filterKey ~= T.FILTER_MENU.TAGS then
                    for itemName, item in pairs(FILTER_MENU[filterKey].items) do
                        for queryKey, queryValue in pairs(item.query) do
                            if app.temp.filter[queryKey] == queryValue then
                                local key = filterKey
                                table.insert(currentActiveKeys, key)
                                activeFilters[key] = activeFilters[key] or {}
                                activeFilters[key].key = key
                                activeFilters[key].type = 'filter'
                                activeFilters[key].item = item
                                activeFilters[key].itemName = itemName
                                activeFilters[key].allQuery = FILTER_MENU[filterKey].allQuery
                                if activeFilters[key].order == nil then
                                    activeFilters[key].order = OD_Tablelength(
                                        activeFilters)
                                end
                                break
                            end
                        end
                    end
                else
                    for tagKey, tagValue in pairs(app.temp.filter.tags) do
                        local key = filterKey .. tagKey
                        table.insert(currentActiveKeys, key)
                        activeFilters[key] = activeFilters[key] or {}
                        activeFilters[key].key = key
                        activeFilters[key].type = 'tag'
                        activeFilters[key].value = tagValue
                        activeFilters[key].item = app.db.tags[tagKey]
                        activeFilters[key].itemName = app.db.tags[tagKey].name

                        if activeFilters[key].order == nil then
                            activeFilters[key].order = OD_Tablelength(
                                activeFilters)
                        end
                    end
                end
            end
            local removed = false
            -- Remove inactive filters from activeFilters
            for key, filter in pairs(activeFilters) do
                local found = false
                for _, activeKey in ipairs(currentActiveKeys) do
                    if key == activeKey then
                        found = true
                        break
                    end
                end
                if not found then
                    removed = true
                    activeFilters[key] = nil
                end
            end
            if removed then
                -- Renumber activeFilters order using OD_PairsByOrder
                local order = 1
                for key, filter in OD_PairsByOrder(activeFilters) do
                    filter.order = order
                    order = order + 1
                end
            end

            app.temp.activeFilters = activeFilters

            ImGui.PushFont(ctx, app.gui.st.fonts.small)
            if OD_Tablelength(activeFilters) > 0 then
                app.gui:pushStyles(app.gui.st.vars.topBarActiveFiltersArea)
                app.gui:pushColors(app.gui.st.col.topBarActiveFiltersArea)
                ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + spacingY)
                local closeButtonSizeW, closeButtonSizeH = app.widgets.calcTinyIconSize(ICONS.CLOSE)
                local paddingX, paddingY = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)
                local filterH = ImGui.GetTextLineHeight(ctx) + paddingY * 2
                if ImGui.BeginChild(ctx, 'activeFilterArea', nil, nil, ImGui.ChildFlags_AutoResizeY) then
                    local i = 0
                    for filterKey, filter in OD_PairsByOrder(activeFilters) do
                        i = i + 1
                        local text = filter.key .. ' ' .. filter.itemName
                        local textW, textH = ImGui.CalcTextSize(ctx, text)
                        if filter.type == 'tag' then
                            text = filter.itemName
                            textW = app.widgets.calcTinyIconSize(filter.value and ICONS.PLUS or ICONS.MINUS) + spacingX *
                                2 +
                                ImGui.CalcTextSize(ctx, text)
                        end
                        local filterW = textW + spacingX + closeButtonSizeW + paddingX * 2
                        if (i ~= 1) then
                            ImGui.SameLine(ctx)
                        end
                        if (filterW > ImGui.GetContentRegionAvail(ctx)) then
                            ImGui.SetCursorPosX(ctx, x)
                            lines = lines + 1
                        end
                        ImGui.SetCursorPosY(ctx, y + (filterH + spacingY) * (lines - 1))
                        local x1, y1 = ImGui.GetCursorScreenPos(ctx)
                        local x2, y2 = x1 + filterW, y1 + filterH
                        ImGui.PushID(ctx, 'activeFilter' .. filter.key)
                        if ImGui.BeginChild(ctx, 'node', filterW, filterH, nil, ImGui.WindowFlags_NoScrollbar) then
                            ImGui.AlignTextToFramePadding(ctx)
                            ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), x1, y1, x2, y2,
                                ImGui.GetColor(ctx, ImGui.Col_Button),
                                ImGui.GetStyleVar(ctx, ImGui.StyleVar_FrameRounding))
                            ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + paddingX) --, ImGui.GetCursorPosY(ctx) + paddingY)
                            if filter.type == 'filter' then
                                ImGui.TextColored(ctx, app.gui.st.basecolors.textDark, filter.key)
                            elseif filter.type == 'tag' then
                                app.widgets.tinyIcon('tagType', filter.value and ICONS.PLUS or ICONS.MINUS, true, true)
                            end
                            ImGui.SameLine(ctx)
                            ImGui.AlignTextToFramePadding(ctx)
                            ImGui.Text(ctx, filter.itemName)
                            ImGui.SameLine(ctx)
                            if app.widgets.tinyIcon('removeFilter', ICONS.CLOSE) then
                                if filter.type == 'filter' then
                                    app.filterResults(filter.allQuery)
                                elseif filter.type == 'tag' then
                                    app.filterResults({ removeTags = { filter.item.id } })
                                end
                            end
                            ImGui.SetCursorScreenPos(ctx, x2, y2)
                            ImGui.Dummy(ctx, 0, 0)
                            ImGui.EndChild(ctx)
                        end
                        ImGui.PopID(ctx)
                    end
                    ImGui.EndChild(ctx)
                end
                app.gui:popStyles(app.gui.st.vars.topBarActiveFiltersArea)
                app.gui:popColors(app.gui.st.col.topBarActiveFiltersArea)
                height = lines * filterH + spacingY * (lines + 1)
                ImGui.SetCursorPosY(ctx, y + height)
            end
            ImGui.PopFont(ctx)
        end
        local drawResultsTable = function()
            local searchResultsH = select(2, ImGui.GetContentRegionAvail(ctx)) -
                fontLineHeight                                                   -- Height available for search results
            local maxSearchResults = math.floor(searchResultsH / fontLineHeight) -- Max results in available space
            local handleSelectedResults = function(resultContext, contextData)
                local tracks = app.db:getSelectedTracks()
                for i = 1, #tracks do
                    for _, result in pairs(app.selection:results()) do
                        tracks[i]:addInsert(result.load)
                    end
                end
            end
            local handleKeyboardEvents = function()
                if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
                    -- handle escape
                elseif app.temp.resultAtKeyboardPos then
                    hintResult = searchResults[app.temp.resultAtKeyboardPos]
                    hintContext = 'Enter'
                    if ImGui.IsKeyPressed(ctx, ImGui.Key_DownArrow) and app.temp.resultAtKeyboardPos < #searchResults then
                        app.temp.resultAtKeyboardPos = app.temp.resultAtKeyboardPos + 1
                        if ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) or OS_is.mac and ImGui.IsKeyDown(ctx, ImGui.Mod_Super) or (not OS_is.mac and ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)) then
                            app.selection:add(app.temp.resultAtKeyboardPos)
                        else
                            app.selection:selectOnly(app.temp.resultAtKeyboardPos)
                        end
                        app.temp.checkScrollDown = true
                    elseif ImGui.IsKeyPressed(ctx, ImGui.Key_PageDown) then
                        local newIdx = math.min(app.temp.resultAtKeyboardPos + maxSearchResults, #searchResults)
                        if app.temp.resultAtKeyboardPos ~= newIdx then
                            app.temp.resultAtKeyboardPos = newIdx
                            app.temp.checkScrollDown = true
                        end
                        app.selection:selectOnly(app.temp.resultAtKeyboardPos)
                    elseif ImGui.IsKeyPressed(ctx, ImGui.Key_PageUp) then
                        local newIdx = math.max(app.temp.resultAtKeyboardPos - maxSearchResults, 1)
                        if app.temp.resultAtKeyboardPos ~= newIdx then
                            app.temp.resultAtKeyboardPos = newIdx
                            app.temp.checkScrollUp = true
                        end
                        app.selection:selectOnly(app.temp.resultAtKeyboardPos)
                    elseif ImGui.IsKeyPressed(ctx, ImGui.Key_UpArrow) and app.temp.resultAtKeyboardPos > 1 then
                        app.temp.resultAtKeyboardPos = app.temp.resultAtKeyboardPos - 1
                        if ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) or OS_is.mac and ImGui.IsKeyDown(ctx, ImGui.Mod_Super) or (not OS_is.mac and ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)) then
                            app.selection:add(app.temp.resultAtKeyboardPos)
                        else
                            app.selection:selectOnly(app.temp.resultAtKeyboardPos)
                        end
                        app.temp.checkScrollUp = true
                    elseif ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
                        if ImGui.IsKeyPressed(ctx, ImGui.Mod_Alt) then
                            handleSelectedResults(RESULT_CONTEXT.ALT)
                        elseif ImGui.IsKeyPressed(ctx, ImGui.Mod_Shift) then
                            handleSelectedResults(RESULT_CONTEXT.SHIFT)
                        else
                            handleSelectedResults(RESULT_CONTEXT.MAIN)
                        end
                    elseif app.isShortcutPressed('markFavorite') and app.temp.resultAtKeyboardPos then
                        local result = searchResults[app.temp.resultAtKeyboardPos]
                        local fav = result:toggleFavorite()
                        app.filterResults()
                        if fav then
                            for i = 1, #app.temp.searchResults do
                                if app.temp.searchResults[i] == result then
                                    app.temp.resultAtKeyboardPos = i
                                    app.selection:selectOnly(app.temp.resultAtKeyboardPos)
                                    app.temp.checkScrollUp = true
                                    break
                                end
                            end
                        end
                    end
                end
            end

            local handleResultDragDrop = function(row)
                if ImGui.BeginDragDropSource(ctx) then
                    if not ImGui.GetDragDropPayload(ctx) and not app.selection:has(row.index) then
                        app.selection:selectOnly(row.index)
                        app.temp.resultAtKeyboardPos = row.index
                    end
                    local listTracks = false
                    local remove = ImGui.IsKeyDown(ctx, ImGui.Mod_Alt)
                    ImGui.SetDragDropPayload(ctx, 'ASSET', remove and 'remove' or 'add')
                    if app.temp.dragDropTagTargetName then
                        ImGui.Text(ctx,
                            (remove and 'Remove' or 'Add') ..
                            ' tag \'' ..
                            app.temp.dragDropTagTargetName .. '\' ' .. (remove and 'from:' or 'to:'))
                        ImGui.Separator(ctx)
                        listTracks = true
                    end
                    local winX, winY = table.unpack(app.gui.mainWindow.pos)
                    local winW, winH = table.unpack(app.gui.mainWindow.size)
                    local x, y = ImGui.GetCursorScreenPos(ctx)
                    if not (x >= winX and x <= winX + winW and y >= winY and y <= winY + winH) then
                        local track, context, position = r.BR_TrackAtMouseCursor()
                        if track then
                            ImGui.Text(ctx,
                                'Add to track ' .. select(2, r.GetTrackName(track)) .. ':\n')
                            app.temp.dragToTrack = track
                        else
                            ImGui.Text(ctx, 'Create new track with:\n')
                            app.temp.dragToTrack = -1
                        end
                        ImGui.Separator(ctx)
                        listTracks = true
                    else
                        app.temp.dragToTrack = nil
                        -- listTracks = false
                    end
                    if listTracks then
                        for i, itemIndex in pairs(app.selection.items) do
                            ImGui.Text(ctx, app.temp.searchResults[itemIndex].searchText[1].text)
                            if i >= 8 then
                                ImGui.Text(ctx, '+ ' .. app.selection:count() - i .. ' more...')
                                break
                            end
                        end
                    else
                        ImGui.Text(ctx, 'Drag to a track, to an empty area or to a tag')
                    end
                    if app.temp.dragDropTagTargetName and not remove then
                        ImGui.Separator(ctx)
                        ImGui.Text(ctx, 'Hold Alt to remove tag')
                    end
                    app.temp.dragDropTagTargetName = nil
                    ImGui.EndDragDropSource(ctx)
                end
                if ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Left) and app.temp.dragToTrack then
                    if app.temp.dragToTrack == -1 then
                        handleSelectedResults(RESULT_CONTEXT.DRAGGED_TO_BLANK)
                        app.logger:logDebug('Will create a new track with ' ..
                            app.selection:count() .. ' plugin(s)\n')
                    else
                        app.logger:logDebug('Will add ' ..
                            app.selection:count() ..
                            ' plugins to track ' .. select(2, r.GetTrackName(app.temp.dragToTrack)) .. '\n')
                        handleSelectedResults(RESULT_CONTEXT.DRAGGED_TO_TRACK, app.temp.dragToTrack)
                    end
                    app.temp.dragToTrack = nil
                end
            end
            local handleScrolling = function()
                local selectedRow = nil
                if app.temp.checkScrollDown or app.temp.checkScrollUp then
                    for i, row in ipairs(flatRows) do
                        if row.index == app.temp.resultAtKeyboardPos then
                            selectedRow = row
                            break
                        end
                    end

                    if selectedRow and app.temp.checkScrollDown then
                        if selectedRow.totalIndex * fontLineHeight >= app.temp.tableScrollY + searchResultsH then
                            local skip = flatRows[selectedRow.totalIndex].type == 'group'
                            ImGui.SetNextWindowScroll(ctx, 0,
                                (selectedRow.totalIndex) * fontLineHeight - searchResultsH +
                                (skip and fontLineHeight or 0))
                        end
                        app.temp.checkScrollDown = false
                    elseif selectedRow and app.temp.checkScrollUp then
                        if selectedRow.totalIndex * fontLineHeight <= app.temp.tableScrollY + fontLineHeight then
                            local skip
                            if selectedRow.totalIndex == 1 then
                                skip = false
                            else
                                skip = (flatRows[selectedRow.totalIndex - 1].type == 'group')
                            end
                            ImGui.SetNextWindowScroll(ctx, 0,
                                (selectedRow.totalIndex - 1) * fontLineHeight -
                                (skip and fontLineHeight or 0))
                        end
                        app.temp.checkScrollUp = false
                    end
                end
            end
            local drawErrorNoResults = function()
                local w, h = ImGui.GetContentRegionAvail(ctx)
                if ImGui.BeginChild(ctx, '##noResults', w, h, nil, nil) then
                    ImGui.Dummy(ctx, w, h)
                    ImGui.SetCursorPos(ctx, w / 2,
                        h / 2 - app.gui.TEXT_BASE_HEIGHT * 1)
                    app.gui:drawSadFace(4, app.gui.st.basecolors.main)
                    local text = 'No results'
                    ImGui.SetCursorPos(ctx, (w - ImGui.CalcTextSize(ctx, text)) / 2,
                        h / 2 + app.gui.TEXT_BASE_HEIGHT * 2)
                    ImGui.Text(ctx, text)
                    local text = 'Clear Filters'
                    ImGui.SetCursorPosX(ctx,
                        (w - ImGui.CalcTextSize(ctx, text) - ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding) * 2) / 2)
                    if ImGui.Button(ctx, text) then
                        app.filterResults({ clear = true })
                    end
                    ImGui.EndChild(ctx)
                end
            end

            if ImGui.BeginChild(ctx, 'resultsArea', w - tagAreaW - spacingX) then
                if app.pageSwitched then
                    app.filterResults({ text = '' })
                end

                handleKeyboardEvents()
                ImGui.SetCursorPosY(ctx, upperRowY + fontLineHeight)

                local firstGroup = nil
                if #searchResults > 0 then
                    -- Build a flat list of rows: {type="group", group=...} or {type="result", result=...}
                    local lastGroup = nil
                    local totalFlatRows = 0 -- used for scrolling positioning
                    for i = 1, #searchResults do
                        totalFlatRows = totalFlatRows + 1
                        local result = searchResults[i]
                        if result.group ~= lastGroup and i ~= 1 then
                            table.insert(flatRows,
                                { type = "group", group = result.group, groupObj = result, totalIndex = totalFlatRows })
                            totalFlatRows = totalFlatRows + 1
                        end
                        lastGroup = result.group
                        table.insert(flatRows,
                            {
                                type = "result",
                                result = result,
                                group = result.group,
                                index = i,
                                totalIndex =
                                    totalFlatRows
                            })
                    end
                    handleScrolling()

                    if ImGui.BeginTable(ctx, "##searchResults", 1, tableFlags, 0, searchResultsH) then
                        app.temp.tableScrollY = ImGui.GetScrollY(ctx)
                        if app.temp.scrollToTop then
                            ImGui.SetScrollY(ctx, 0)
                            app.temp.scrollToTop = false
                        end

                        ImGui.ListClipper_Begin(app.gui.searchResultsClipper, #flatRows)
                        firstGroup = nil
                        while ImGui.ListClipper_Step(app.gui.searchResultsClipper) do
                            local display_start, display_end = ImGui.ListClipper_GetDisplayRange(app.gui
                                .searchResultsClipper)
                            local rowIdx = display_start + 1
                            while rowIdx <= display_end do
                                local row = flatRows[rowIdx]
                                if row.type == "group" then
                                    ImGui.TableNextRow(ctx, ImGui.TableRowFlags_None, fontLineHeight)
                                    ImGui.TableSetColumnIndex(ctx, 0)
                                    ImGui.SeparatorText(ctx, row.group)
                                elseif row.type == "result" then
                                    local result = row.result
                                    if firstGroup == nil and select(2, ImGui.GetCursorScreenPos(ctx)) >= upperRowScreenY then
                                        firstGroup = result.group
                                    end
                                    ImGui.PushID(ctx, 'result' .. row.index)
                                    ImGui.TableNextRow(ctx, ImGui.TableRowFlags_None, fontLineHeight)
                                    ImGui.TableSetColumnIndex(ctx, 0)
                                    if app.temp.highlightDropAreaForAllSelectedResults and app.temp.highlightDropAreaForAllSelectedResults < ImGui.GetFrameCount(ctx) or app.temp.highlightDropAreaFor == row.index then
                                        ImGui.PushStyleColor(ctx, ImGui.Col_Header,
                                            ImGui.GetStyleColor(ctx, ImGui.Col_HeaderActive))
                                    end
                                    if ImGui.Selectable(ctx, '', app.selection:has(row.index) or app.temp.highlightDropAreaFor == row.index, selectableFlags, 0, 0) then
                                        if ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
                                            app.selection:selectRange(app.temp.resultAtKeyboardPos, row.index)
                                            app.temp.resultAtKeyboardPos = row.index
                                        elseif OS_is.mac and ImGui.IsKeyDown(ctx, ImGui.Mod_Super) or (not OS_is.mac and ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)) then
                                            if app.selection:toggle(row.index) then
                                                app.temp.resultAtKeyboardPos = row.index
                                            end
                                        else
                                            app.selection:selectOnly(row.index)
                                            app.temp.resultAtKeyboardPos = row.index
                                            if ImGui.IsMouseDoubleClicked(ctx, ImGui.MouseButton_Left) then
                                                if ImGui.IsKeyPressed(ctx, ImGui.Mod_Alt) then
                                                    handleSelectedResults(RESULT_CONTEXT.ALT)
                                                elseif ImGui.IsKeyPressed(ctx, ImGui.Mod_Shift) then
                                                    handleSelectedResults(RESULT_CONTEXT.SHIFT)
                                                else
                                                    handleSelectedResults(RESULT_CONTEXT.MAIN)
                                                end
                                            end
                                        end
                                    end
                                    if app.temp.highlightDropAreaForAllSelectedResults and app.temp.highlightDropAreaForAllSelectedResults < ImGui.GetFrameCount(ctx) or app.temp.highlightDropAreaFor == row.index then
                                        ImGui.PopStyleColor(ctx)
                                    end
                                    if ImGui.BeginDragDropTarget(ctx) then
                                        local tagDropped, tagPayload = ImGui.AcceptDragDropPayload(ctx, 'TAG', nil,
                                            ImGui.DragDropFlags_AcceptBeforeDelivery |
                                            ImGui.DragDropFlags_AcceptNoDrawDefaultRect)
                                        if tagDropped then
                                            if app.selection:has(row.index) and not app.temp.highlightDropAreaForAllSelectedResults then
                                                app.temp.highlightDropAreaForAllSelectedResults = ImGui.GetFrameCount(
                                                    ctx)
                                                app.temp.highlightDropAreaFor = nil
                                            elseif not app.selection:has(row.index) then
                                                app.temp.highlightDropAreaForAllSelectedResults = nil
                                                app.temp.highlightDropAreaFor = row.index
                                            end
                                            if ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Left) then
                                                local payloadTag = app.db.tags[tonumber(tagPayload)]

                                                local results
                                                local remove = ImGui.IsKeyDown(ctx, ImGui.Mod_Alt)

                                                if app.temp.highlightDropAreaForAllSelectedResults then
                                                    results = app.selection:results()
                                                elseif app.temp.highlightDropAreaFor then
                                                    results = { searchResults[app.temp.highlightDropAreaFor] }
                                                end
                                                for _, result in pairs(results) do
                                                    if remove then
                                                        result:removeTag(payloadTag, false)
                                                    else
                                                        result:addTag(payloadTag, false)
                                                    end
                                                end
                                                app.tags:save()
                                                app.temp.highlightDropAreaForAllSelectedResults = nil
                                                app.temp.highlightDropAreaFor = nil
                                            end
                                        end
                                        ImGui.EndDragDropTarget(ctx)
                                    end
                                    handleResultDragDrop(row)
                                    if ImGui.IsItemHovered(ctx) then
                                        hintResult = result
                                        hintContext = 'Click'
                                    end
                                    ImGui.SameLine(ctx)

                                    if result.type == ASSETS.TRACK then
                                        local size = fontLineHeight -
                                            select(2, ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)) * 2
                                        ImGui.ColorButton(ctx, 'color', result.color,
                                            ImGui.ColorEditFlags_NoBorder | ImGui.ColorEditFlags_NoTooltip, size, size)
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
                                    for j = 1, #(result.searchText) do
                                        local st = result.searchText[j]
                                        if not st.hide then
                                            if j > 1 then
                                                ImGui.Text(ctx, ' ')
                                                ImGui.SameLine(ctx)
                                                app.gui:pushColors(app.gui.st.col.search.secondaryResult)
                                            else
                                                app.gui:pushColors(app.gui.st.col.search.mainResult)
                                            end
                                            local curIndex = 1
                                            for _, highlight in OD_PairsByOrder(result.foundIndexes[j] or {}) do
                                                if curIndex <= highlight.from then
                                                    ImGui.Text(ctx, (st.text):sub(curIndex, highlight.from - 1))
                                                    ImGui.SameLine(ctx)
                                                end
                                                if curIndex <= highlight.to + 1 then
                                                    app.gui:pushColors(app.gui.st.col.search.highlight)
                                                    local txt = (st.text):sub(math.max(curIndex, highlight.from),
                                                        highlight.to)
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
                                    if #result.tags > 0 then
                                        app.gui:pushColors(app.gui.st.col.search.thirdResult)
                                        local text = '|'
                                        for t = 1, #(result.tags or {}) do
                                            local tag = tagInfo[result.tags[t]]
                                            text = text .. tag.name .. '|'
                                        end
                                        ImGui.Text(ctx, text)
                                        app.gui:popColors(app.gui.st.col.search.thirdResult)
                                    end
                                    ImGui.PopID(ctx)
                                end
                                rowIdx = rowIdx + 1
                            end
                        end
                        ImGui.ListClipper_End(app.gui.searchResultsClipper)
                        ImGui.EndTable(ctx)
                    end
                    if not ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenBlockedByActiveItem) then
                        app.temp.highlightDropAreaForAllSelectedResults = nil
                        app.temp.highlightDropAreaFor = nil
                    end
                    ImGui.SetCursorPosY(ctx, upperRowY)
                    ImGui.SeparatorText(ctx, firstGroup or '')
                else
                    drawErrorNoResults()
                end

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

                ImGui.EndChild(ctx)
            end
        end
        local drawTagSeparator = function()
            -- Separator Resize Line
            local separatorX, separatorY = ImGui.GetCursorScreenPos(ctx)
            ImGui.DrawList_AddLine(ImGui.GetForegroundDrawList(ctx), separatorX, separatorY, separatorX,
                separatorY + h,
                ImGui.GetStyleColor(ctx, ImGui.Col_Separator))
            ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) - spacingX)
            ImGui.InvisibleButton(ctx, '##separator', spacingX * 2 + 1, filterAreaH)
            if ImGui.IsItemHovered(ctx) then
                app:setHoveredHint('main', 'Drag to change tag list width', nil, nil, 1)
                ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
            end
            if ImGui.IsItemActive(ctx) then
                ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
                local mouseDeltaX = select(1, ImGui.GetMouseDragDelta(ctx, nil, nil, ImGui.MouseButton_Left))
                if mouseDeltaX ~= 0 then
                    local newWidth = (tagAreaW - mouseDeltaX) / app.settings.current.uiScale
                    if newWidth > app.settings.current.minFilterPanelWidth then
                        app.settings.current.filterPanelWidth = newWidth
                        ImGui.ResetMouseDragDelta(ctx, ImGui.MouseButton_Left)
                    else
                        app.settings.current.filterPanelWidth = app.settings.current.minFilterPanelWidth
                    end
                end
            end
        end
        local drawFilterArea = function()
            if ImGui.BeginChild(ctx, 'filterArea', tagAreaW - spacingX * 2, filterAreaH) then
                local function drawTagsOfParent(parentId, indent, parentsDragged)
                    local drawTagNode
                    local function drawDropTarget(tag, height, position, offsetY, dragTargetLineOffsetY)
                        if height > 0 then
                            local x, y = ImGui.GetCursorPos(ctx)
                            local scrX, scrY = ImGui.GetCursorScreenPos(ctx)
                            local offsetY = offsetY or 0
                            local dragTargetLineOffsetY = dragTargetLineOffsetY or 0
                            local w, h = ImGui.GetContentRegionAvail(ctx) -- * app.settings.current.uiScale
                            local triangleW = tag.hasDescendants and
                                app.gui.st.vars.tagList[ImGui.StyleVar_IndentSpacing]
                                [1] or 0
                            local tagW = ImGui.CalcTextSize(ctx, tag.name) + paddingX * 4 + triangleW
                            ImGui.SetCursorPosY(ctx, y - height - offsetY) --'#dropTargetBefore'+tag.id,w, y-spacing)
                            if app.logger.level == app.logger.LOG_LEVEL.DEBUG then
                                ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize, 2)
                                ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0xffffff11)
                                ImGui.Button(ctx, '##dropTarget' .. position .. tag.id, w, height)
                                ImGui.PopStyleColor(ctx)
                                ImGui.PopStyleVar(ctx)
                            else
                                ImGui.InvisibleButton(ctx, 'dropTarget' .. position .. tag.id, w, height)
                            end
                            if app.logger.level == app.logger.LOG_LEVEL.DEBUG and ImGui.IsItemHovered(ctx) then
                                app.logger:logDebug('Hover over target: ' .. position .. ' ' .. tag.name)
                            end

                            ImGui.SetCursorPos(ctx, x, y) --'#dropTargetBefore'+tag.id,w, y-spacing)

                            if ImGui.BeginDragDropTarget(ctx) then
                                local tagDropped, tagPayload
                                local assetDropped, assetPayload
                                tagDropped, tagPayload = ImGui.AcceptDragDropPayload(ctx, 'TAG', nil,
                                    ImGui.DragDropFlags_AcceptBeforeDelivery |
                                    ImGui.DragDropFlags_AcceptNoDrawDefaultRect)
                                if position == 'inside' then
                                    assetDropped, assetPayload = ImGui.AcceptDragDropPayload(ctx, 'ASSET', nil,
                                        ImGui.DragDropFlags_AcceptBeforeDelivery |
                                        ImGui.DragDropFlags_AcceptNoDrawDefaultRect)
                                end
                                if tagDropped then
                                    local payloadTag = app.db.tags[tonumber(tagPayload)]

                                    if position == 'inside' then
                                        ImGui.DrawList_AddRect(ImGui.GetWindowDrawList(ctx), scrX,
                                            scrY - height - offsetY,
                                            scrX + tagW, scrY - height - offsetY + ImGui.GetTextLineHeight(ctx),
                                            app.gui.st.basecolors.mainBright,
                                            app.gui.st.vars.tag[ImGui.StyleVar_FrameRounding][1],
                                            nil, 1.5 * app.settings.current.uiScale)
                                    else
                                        ImGui.DrawList_AddRect(ImGui.GetWindowDrawList(ctx), scrX,
                                            scrY - height - offsetY + dragTargetLineOffsetY, scrX + w,
                                            scrY - height - offsetY + dragTargetLineOffsetY, app.gui.st.basecolors
                                            .mainBright, 15, nil, 1.5 * app.settings.current.uiScale)
                                    end
                                    if ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Left) then
                                        payloadTag:moveTo(tag, position)
                                    end
                                end
                                if assetDropped then
                                    app.temp.dragDropTagTargetName = tag.name
                                    ImGui.DrawList_AddRect(ImGui.GetWindowDrawList(ctx), scrX, scrY - height - offsetY,
                                        scrX + tagW, scrY - height - offsetY + ImGui.GetTextLineHeight(ctx),
                                        app.gui.st.basecolors.mainBright,
                                        app.gui.st.vars.tag[ImGui.StyleVar_FrameRounding][1],
                                        nil, 1.5 * app.settings.current.uiScale)
                                    if ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Left) then
                                        local remove = (assetPayload == 'remove')
                                        for i, result in ipairs(app.selection:results()) do
                                            if remove then
                                                result:removeTag(tag, false)
                                            else
                                                result:addTag(tag, false)
                                            end
                                        end
                                        app.tags:save()
                                    end
                                end
                                ImGui.EndDragDropTarget(ctx)
                            end
                        end
                    end
                    function drawTagNode(tag, indent, parentsDragged)
                        if indent then ImGui.Indent(ctx) end
                        local dragged = parentsDragged or
                            select(3, ImGui.GetDragDropPayload(ctx)) == tostring(tag.id)
                        if not dragged then drawDropTarget(tag, spacingY, 'before', 0, 0) end
                        app.gui:pushColors(app.gui.st.col.tag)
                        app.gui:pushStyles(app.gui.st.vars.tag)
                        ImGui.PushFont(ctx, app.gui.st.fonts.small)
                        local w = select(1, ImGui.GetContentRegionAvail(ctx))
                        local globalX, globalY = ImGui.GetCursorScreenPos(ctx)
                        local x, y = ImGui.GetCursorPos(ctx)
                        local paddingX, paddingY = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)
                        local triangleW = tag.hasDescendants and app.gui.st.vars.tagList[ImGui.StyleVar_IndentSpacing]
                            [1] or 0
                        -- local triangleW = tag.hasDescendants and triangleW or 0
                        local tagName = (app.temp.tagRename == tag.id) and app.temp.tagRenameBuffer or tag.name
                        local tagNameWidth = ImGui.CalcTextSize(ctx, tagName)
                        local tagW, tagH = tagNameWidth + paddingX * 2 + triangleW,
                            ImGui.GetTextLineHeight(ctx) + paddingY * 2
                        --+app.widgets.calcTinyIconSize(ICONS.PENCIL)
                        local col = app.gui.st.col.tag[ImGui.Col_FrameBg]
                        local tagStatus = app.temp.filter.tags[tag.id]
                        local hovering = false
                        ImGui.PushID(ctx, tag.id)

                        if not dragged and not ImGui.GetDragDropPayload(ctx) and not ImGui.IsPopupOpen(ctx, '', ImGui.PopupFlags_AnyPopup) and ImGui.IsMouseHoveringRect(ctx, globalX, globalY, globalX + w, globalY + tagH) then
                            hovering = true
                            col = app.gui.st.col.tag[ImGui.Col_FrameBgHovered]
                            if ImGui.IsMouseDown(ctx, ImGui.MouseButton_Left) then
                                col = app.gui.st.col.tag[ImGui.Col_FrameBgActive]
                            end
                            if ImGui.IsMouseDoubleClicked(ctx, ImGui.MouseButton_Left) then
                                if ImGui.IsMouseHoveringRect(ctx, globalX + triangleW + paddingX, globalY, globalX + tagNameWidth + paddingX * 2 + spacingX, globalY + tagH) then
                                    app.temp.tagRename = tag.id
                                    app.temp.tagRenameBuffer = tag.name
                                end
                            end
                            if ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Right) then
                                app.temp.tagRename = nil
                                app.temp.tagRenameBuffer = nil
                                app.temp.showDeleteTagConfirmation = nil
                                ImGui.OpenPopup(ctx, 'Tag Context Menu')
                            end
                        end
                        if ImGui.BeginPopup(ctx, 'Tag Context Menu') then
                            ImGui.Text(ctx, tag.name)
                            ImGui.Separator(ctx)
                            if ImGui.MenuItem(ctx, 'Rename') then
                                app.temp.tagRename = tag.id
                                app.temp.tagRenameBuffer = tag.name
                            end
                            if ImGui.MenuItem(ctx, 'Create Nested Tag') then
                                tag:toggleOpen(true)
                                local newTag = app.db:createTag('New Tag', tag)
                                app.temp.tagRename = newTag.id
                                app.temp.tagRenameBuffer = newTag.name
                            end
                            ImGui.Separator(ctx)
                            if app.temp.showDeleteTagConfirmation then
                                if r.time_precise() - app.temp.showDeleteTagConfirmation > 3 then
                                    app.temp.showDeleteTagConfirmation = nil
                                end
                                if ImGui.MenuItem(ctx, 'Click to confirm') then
                                    app.temp.showDeleteTagConfirmation = nil
                                    tag:delete()
                                end
                            else
                                if ImGui.Selectable(ctx, 'Delete', false, ImGui.SelectableFlags_DontClosePopups) then
                                    app.temp.showDeleteTagConfirmation = r.time_precise()
                                end
                            end
                            ImGui.EndPopup(ctx)
                        end
                        -- end
                        if app.temp.tagRename ~= tag.id and (hovering or tagStatus ~= nil) then
                            local iconsWidth = 0
                            if hovering and tagStatus == nil then
                                iconsWidth = iconsWidth + app.widgets.calcTinyIconSize(ICONS.MINUS) +
                                    app.widgets.calcTinyIconSize(ICONS.PLUS)
                                tagW = tagW + spacingX * 3
                            elseif tagStatus ~= nil then
                                iconsWidth = iconsWidth +
                                    (tagStatus ~= nil and app.widgets.calcTinyIconSize(ICONS.CLOSE) or 0)
                                tagW = tagW + spacingX * 2
                            end
                            tagW = tagW + iconsWidth
                        end

                        ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), globalX, globalY, globalX + tagW,
                            globalY + tagH, col, 100)
                        if tag.hasDescendants then
                            local triPad = paddingY * 0.7
                            local triW = tagH * 0.4
                            local triH = tagH * 0.4
                            if tag.open then
                                -- Down-pointing triangle (same proportions as right one)
                                local cx = globalX + paddingX + triW / 2
                                local cy = globalY + tagH / 2
                                ImGui.DrawList_AddTriangleFilled(
                                    ImGui.GetWindowDrawList(ctx),
                                    cx - triW / 2, cy - triH / 3,
                                    cx + triW / 2, cy - triH / 3,
                                    cx, cy + triH * 2 / 3,
                                    app.gui.st.col.tag[ImGui.Col_Text]
                                )
                            else
                                -- Right-pointing triangle
                                local cx = globalX + paddingX + triW / 2
                                local cy = globalY + tagH / 2
                                ImGui.DrawList_AddTriangleFilled(
                                    ImGui.GetWindowDrawList(ctx),
                                    cx - triH / 3, cy - triW / 2 + .5 * app.settings.current.uiScale,
                                    cx - triH / 3, cy + triW / 2 - .5 * app.settings.current.uiScale,
                                    cx + triH * 2 / 3 - app.settings.current.uiScale, cy,
                                    app.gui.st.col.tag[ImGui.Col_Text]
                                )
                            end
                            if ImGui.InvisibleButton(ctx, 'showHideDescendants', triangleW + paddingX, tagH) then
                                tag:toggleOpen(not tag.open)
                            end
                            ImGui.SameLine(ctx)
                        end
                        ImGui.SetCursorPos(ctx, x + paddingX + triangleW, y + paddingY)
                        if app.temp.tagRename == tag.id then
                            local rv
                            app.temp.ignoreEscapeKey = true
                            ImGui.SetNextItemWidth(ctx, tagW)
                            rv, app.temp.tagRenameBuffer = ImGui.InputText(ctx, '##EditTagName', app.temp
                                .tagRenameBuffer, ImGui.InputTextFlags_AutoSelectAll)
                            if ImGui.IsItemActivated then
                                ImGui.SetKeyboardFocusHere(ctx, -1)
                            end
                            if ImGui.IsItemDeactivatedAfterEdit(ctx) then
                                tag:rename(app.temp.tagRenameBuffer)
                            end
                            if ImGui.IsItemDeactivated(ctx) then
                                app.temp.tagRename = nil
                                app.temp.tagRenameBuffer = nil
                            end
                        else
                            ImGui.Text(ctx, tag.name)
                        end
                        if app.temp.tagRename ~= tag.id and (hovering or tagStatus ~= nil) then
                            ImGui.PushID(ctx, 'tagEditButtons')
                            if tagStatus ~= nil then
                                ImGui.SameLine(ctx)
                                ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + spacingX)
                                if app.widgets.tinyIcon('removeTag', hovering and ICONS.CLOSE or (tagStatus and ICONS.PLUS or ICONS.MINUS)) then
                                    app.filterResults({ removeTags = { tag.id } })
                                end
                            elseif hovering then
                                ImGui.SameLine(ctx)
                                ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + spacingX)
                                if app.widgets.tinyIcon('addPositiveTag', ICONS.PLUS) then
                                    app.filterResults({ addTags = { [tag.id] = true } })
                                end
                                ImGui.SameLine(ctx)
                                ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + spacingX)
                                if app.widgets.tinyIcon('addNegative', ICONS.MINUS) then
                                    app.filterResults({ addTags = { [tag.id] = false } })
                                end
                            end
                            ImGui.PopID(ctx)
                        end
                        app.gui:popColors(app.gui.st.col.tag)
                        app.gui:popStyles(app.gui.st.vars.tag)

                        ImGui.SetCursorScreenPos(ctx, globalX, globalY)
                        ImGui.InvisibleButton(ctx, 'drag', tagW, tagH)
                        if ImGui.BeginDragDropSource(ctx) then
                            ImGui.SetDragDropPayload(ctx, 'TAG', tostring(tag.id))
                            -- ImGui.Text(ctx, tag.name)
                            if app.temp.highlightDropAreaForAllSelectedResults or app.temp.highlightDropAreaFor then
                                if ImGui.IsKeyDown(ctx, ImGui.Mod_Alt) then
                                    ImGui.Text(ctx,
                                        'Remove tag \'' ..
                                        tag.name ..
                                        '\' from' ..
                                        (app.temp.highlightDropAreaFor and (' ' .. searchResults[app.temp.highlightDropAreaFor].searchText[1].text) or
                                            ':'))
                                else
                                    ImGui.Text(ctx,
                                        'Add tag \'' ..
                                        tag.name ..
                                        '\' to' ..
                                        (app.temp.highlightDropAreaFor and (' ' .. searchResults[app.temp.highlightDropAreaFor].searchText[1].text) or ':'))
                                end
                                if app.temp.highlightDropAreaForAllSelectedResults then
                                    ImGui.Separator(ctx)
                                    for i, result in pairs(app.selection:results()) do
                                        ImGui.Text(ctx, result.searchText[1].text)
                                        if i >= 8 then
                                            ImGui.Text(ctx, '+ ' .. app.selection:count() - i .. ' more...')
                                            break
                                        end
                                    end
                                end
                                if not ImGui.IsKeyDown(ctx, ImGui.Mod_Alt) then
                                    ImGui.Separator(ctx)
                                    ImGui.Text(ctx, 'Hold alt to remove tag')
                                end
                            else
                                drawTagNode(tag, false, false, true)
                            end
                            ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - spacingY * 2)
                            ImGui.Dummy(ctx, 0, 0)
                            ImGui.EndDragDropSource(ctx)
                        end

                        if not dragged then
                            local open = (tag.hasDescendants and tag.open)
                            drawDropTarget(tag, tagH + (open and spacingY or 0), 'inside', (open and 0 or spacingY),
                                spacingY)
                        end
                        ImGui.PopFont(ctx)


                        if tag.hasDescendants and tag.open then
                            ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + spacingY)
                            drawTagsOfParent(tag.id, true, dragged)
                            -- ImGui.TreePop(ctx)
                        elseif not dragged then
                            -- ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx))
                            drawDropTarget(tag, spacingY, 'after', 0, spacingY)
                            ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + spacingY)
                            -- ImGui.Dummy(ctx, 0, 0)
                        else
                            ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + spacingY)
                        end
                        -- end
                        if indent then ImGui.Unindent(ctx) end
                        ImGui.PopID(ctx)
                    end

                    app.gui:pushStyles(app.gui.st.vars.tagList)
                    -- local lastTag = nil
                    -- Collect all tags with the given parentId, preserving order
                    local lastTag = nil
                    local firstTag = nil
                    for id, tag in OD_PairsByOrder(app.db.tags) do
                        if tag.parentId == parentId then
                            if firstTag == nil and parentId == TAGS_ROOT_PARENT then
                                local availH = ImGui.GetCursorPosY(ctx)
                                drawDropTarget(tag, availH, 'before', spacingY, 0)
                                firstTag = tag
                            end
                            drawTagNode(tag, indent, parentsDragged)
                            lastTag = tag
                        end
                    end

                    if parentId == TAGS_ROOT_PARENT then
                        local availH = select(2, ImGui.GetContentRegionAvail(ctx))
                        ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + availH)
                        drawDropTarget(lastTag, spacingY + availH, 'after', 0, 0)
                    end

                    app.gui:popStyles(app.gui.st.vars.tagList)
                end
                local function drawFilterMenu(menu, menuId)
                    for k, menuInfo in OD_PairsByOrder(menu) do
                        ImGui.PushID(ctx, menuId .. '/' .. k)
                        if ImGui.BeginMenu(ctx, k .. '##filterMenu') then
                            if menuInfo.allQuery then
                                local selected = true
                                for k, v in pairs(menuInfo.allQuery) do
                                    if app.temp.filter[k] ~= ((menuInfo.allQuery[k] ~= 'all') and menuInfo.allQuery[k] or nil) then
                                        selected = false
                                    end
                                end

                                if ImGui.MenuItem(ctx, 'All' .. "##filterMenu-All", nil, selected) then
                                    app.filterResults(menuInfo.allQuery)
                                end
                                ImGui.Separator(ctx)
                            end

                            for item, value in OD_PairsByOrder(menuInfo.items) do
                                if value.submenu then
                                    drawFilterMenu({ [item] = value.submenu }, menuId .. '-' .. item)
                                elseif value.query then
                                    local selected = true
                                    for k, v in pairs(value.query) do
                                        if app.temp.filter[k] ~= (value.query[k] == 'all' and nil or value.query[k]) then --TODO: this always results to value.query[k]
                                            selected = false
                                        end
                                    end
                                    if ImGui.MenuItem(ctx, item, nil, selected) then
                                        app.filterResults(value.query)
                                    end
                                end
                            end
                            ImGui.EndMenu(ctx)
                        end
                        ImGui.PopID(ctx)
                    end
                end

                ImGui.SeparatorText(ctx, "Filters")
                ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + spacingY)
                drawFilterMenu(FILTER_MENU, 'root')

                ImGui.SeparatorText(ctx, "Tags")
                ImGui.SameLine(ctx)
                ImGui.PushFont(ctx, app.gui.st.fonts.icons_small)
                ImGui.SetCursorPosX(ctx,
                    ImGui.GetCursorPosX(ctx) + ImGui.GetContentRegionAvail(ctx) - spacingX - paddingX * 2 -
                    ImGui.CalcTextSize(ctx, ICONS.PLUS))
                -- ImGui.AlignTextToFramePadding(ctx)
                if ImGui.Button(ctx, ICONS.PLUS .. '##CreateTag') then
                    local newTag = app.db:createTag('New Tag', TAGS_ROOT_PARENT)
                    app.temp.tagRename = newTag.id
                    app.temp.tagRenameBuffer = newTag.name
                end
                app:setHoveredHint('main', 'Create new tag', nil, nil, 1)
                ImGui.PopFont(ctx)
                ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - spacingY)
                if ImGui.BeginChild(ctx, 'TagScrollArea', tagAreaW - paddingX * 2, select(2, ImGui.GetContentRegionAvail(ctx)) - spacingY, nil) then
                    ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + spacingY)
                    drawTagsOfParent(TAGS_ROOT_PARENT, false, false)
                    ImGui.EndChild(ctx)
                end
                ImGui.Dummy(ctx, 0, 0)
                ImGui.EndChild(ctx)
            end
        end

        if ImGui.BeginChild(ctx, 'rightArea', w - tagAreaW - spacingX) then
            drawActiveFilters()
            drawResultsTable()
            ImGui.EndChild(ctx)
        end
        ImGui.SameLine(ctx)
        drawTagSeparator()
        ImGui.SameLine(ctx)
        drawFilterArea()
        -- handleSelectedResult()

        app.gui:popColors(app.gui.st.col.searchWindow)
        app.gui:popStyles(app.gui.st.vars.searchWindow)
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
            -- app.settings.current.textMinimizationStyle = app.gui:setting('combo',
            --     T.SETTINGS.TEXT_MINIMIZATION_STYLE.LABEL, T.SETTINGS.TEXT_MINIMIZATION_STYLE.HINT,
            --     app.settings.current.textMinimizationStyle,
            --     {
            --         list = T.SETTINGS.LISTS[T.SETTINGS.TEXT_MINIMIZATION_STYLE.LABEL][MINIMIZATION_STYLE.PT] ..
            --             '\0' ..
            --             T.SETTINGS.LISTS[T.SETTINGS.TEXT_MINIMIZATION_STYLE.LABEL][MINIMIZATION_STYLE.TRIM] .. '\0'
            --     })

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
        local ctx = app.gui.ctx
        app.gui:pushStyles(app.gui.st.vars.topBar)
        app.gui:pushColors(app.gui.st.col.topBar)

        local menu = {}
        local paddingX, paddingY = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)
        local winPaddingX, winPaddingY = ImGui.GetStyleVar(ctx, ImGui.StyleVar_WindowPadding)
        local spacingX, spacingY = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)

        local createMenu = function()
            local menu = {}

            table.insert(menu, { icon = 'money', hint = ('%s is free, but donations are welcome :)'):format(Scr.name) })
            if ImGui.IsWindowDocked(ctx) then
                table.insert(menu, { icon = 'undock', hint = 'Undock' })
            else
                table.insert(menu, { icon = 'dock_down', hint = 'Dock' })
            end
            if app.page == APP_PAGE.SEARCH_FX then
                table.insert(menu, { icon = 'gear', hint = 'Settings' })
            end
            return menu
        end
        local calculateDimensions = function()
            ImGui.PushFont(ctx, app.gui.st.fonts.icons_large)
            local menuW, h = 0, ImGui.GetTextLineHeight(ctx) + paddingY * 2 + winPaddingY * 2
            for i, btn in ipairs(menu) do
                menuW = menuW + select(1, ImGui.CalcTextSize(ctx, ICONS[(btn.icon):upper()])) +
                    ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding) * 2 +
                    ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
            end
            ImGui.PopFont(ctx)
            return menuW, h
        end
        menu = createMenu()
        local menuW, h = calculateDimensions()

        local drawTextSearchInput = function()
            if app.pageSwitched then
                app.filterResults({ text = '' })
                ImGui.SetKeyboardFocusHere(ctx, 0)
            end

            -- app.gui:pushColors(app.gui.st.col.topBar.background)
            local w = select(1, ImGui.GetContentRegionAvail(ctx)) - menuW +
                ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)

            ImGui.SetNextItemWidth(ctx, w)
            local rv

            rv, app.temp.searchInput = ImGui.InputTextWithHint(ctx, "##searchInput"..app.temp.searchMode,
                T.SEARCH_WINDOW.SEARCH_HINT[app.temp.searchMode], app.temp.searchInput)
            if app.temp.lastSearchMode ~= app.temp.searchMode then
                ImGui.SetKeyboardFocusHere(ctx,-1)
                app.temp.lastSearchMode = app.temp.searchMode
            end
            if ImGui.IsItemFocused(ctx) then
                if ImGui.IsKeyReleased(ctx, ImGui.Key_Tab) then
                    if app.temp.searchMode == SEARCH_MODE.MAIN then
                        app.temp.searchMode = SEARCH_MODE.FILTERS
                    else
                        app.temp.searchMode = SEARCH_MODE.MAIN
                    end
                    app.filterResults({ clear = true })
                end
            end
            if rv then
                app.filterResults({ text = app.temp.searchInput })
                app.temp.scrollToTop = true
            end
        end
        local drawIconMenu = function(ctx, buttons)
            ImGui.PushFont(ctx, app.gui.st.fonts.icons_large)
            local clicked = nil
            for i, btn in ipairs(buttons) do
                if app.widgets.iconButton(btn.icon, app.gui.st.col.buttons.topBarIcon) then clicked = btn.icon end
                app:setHoveredHint('main', btn.hint)
            end
            ImGui.PopFont(ctx)
            return clicked ~= nil, clicked
        end
        local drawLogo = function()
            app.gui:pushColors(app.gui.st.col.title)
            ImGui.PushFont(ctx, app.gui.st.fonts.icons_small)
            ImGui.AlignTextToFramePadding(ctx)
            ImGui.Text(ctx, ICONS.SEARCH)
            ImGui.PopFont(ctx)
            ImGui.SameLine(ctx)
            ImGui.PushFont(ctx, app.gui.st.fonts.large)
            ImGui.AlignTextToFramePadding(ctx)
            ImGui.Text(ctx, app.scr.name)
            app:setHoveredHint('main', app.scr.name .. ' v' .. app.scr.version .. ' by ' .. app.scr.author)
            app.gui:popColors(app.gui.st.col.title)
            ImGui.SameLine(ctx)
            local x, y = ImGui.GetCursorScreenPos(ctx)
            local width = 2 * app.settings.current.uiScale
            ImGui.DrawList_AddLine(ImGui.GetWindowDrawList(ctx), x + width / 2, y - paddingY, x + width / 2,
                y + h - paddingY * 2 - winPaddingY, app.gui.st.basecolors.main, width)
            ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + width + spacingX)
        end
        local function handleMenuButtons(rv, btn)
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
        if ImGui.BeginChild(ctx, 'topBar', nil, h, ImGui.ChildFlags_AlwaysUseWindowPadding) then
            drawLogo()
            drawTextSearchInput()
            ImGui.SameLine(ctx)
            ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + spacingX)
            local rv, btn = drawIconMenu(ctx, menu)
            ImGui.Dummy(ctx, 0, 0) -- this prevents errors on UI resizing
            ImGui.PopFont(ctx)
            ImGui.EndChild(ctx)
            handleMenuButtons(rv, btn)
        end
        app.gui:popColors(app.gui.st.col.topBar)
        app.gui:popStyles(app.gui.st.vars.topBar)
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

    function app.drawMainWindow()
        local ctx = app.gui.ctx
        if app.logger.level == app.logger.LOG_LEVEL.DEBUG then
            ImGui.ShowMetricsWindow(ctx)
            ImGui.ShowDebugLogWindow(ctx)
            ImGui.ShowIDStackToolWindow(ctx)
        end
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
