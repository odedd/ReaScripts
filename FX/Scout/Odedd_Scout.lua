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

LOG_LEVEL = OD_Logger.LOG_LEVEL.NONE

OD_Init()

if LOG_LEVEL > OD_Logger.LOG_LEVEL.NONE then
    r.ClearConsole()
end

r.SetExtState(Scr.ext_name, 'SCRIPT_VERSION', Scr.version, false)

RunApp = function()
    if r.GetExtState(Scr.ext_name, 'RUNNING') ~= 'TRUE' and OD_PrereqsOK({
            reaimgui_version = '0.9.2',
            js_version = 1.310,    -- required for JS_Window_Find and JS_VKeys_GetState
            reaper_version = 7.03, -- required for set_action_options
        }) then
        package.path = r.ImGui_GetBuiltinPath() .. '/?.lua'
        ImGui = require 'imgui' '0.9.2'

        dofile(p .. 'lib/Constants.lua')
        dofile(p .. 'lib/Texts.lua')
        dofile(p .. 'lib/Settings.lua')
        dofile(p .. 'lib/UserData.lua')
        dofile(p .. 'lib/Gui.lua')
        dofile(p .. 'lib/DataEngine.lua')

        -- @noindex

        local app = OD_Gui_App:new({
            mediaFiles = {},
            revert = {},
            restore = {},
            popup = {},
            faderReset = {},
            -- focusMainReaperWindow = true
        })

        local projPath, projFileName = OD_GetProjectPaths()

        local logger = OD_Logger:new({
            level = LOG_LEVEL,
            output = OD_Logger.LOG_OUTPUT.CONSOLE,
            filename = projPath .. Scr.name .. '_' .. projFileName .. '.log',
            -- filename = p .. Scr.name .. '_' .. projFileName .. '.log',
            showImGuiDebugWindows = false,
            profile = false
        })

        local gui = PB_Gui:new({})

        app:connect('gui', gui)
        app:connect('logger', logger)
        app:connect('scr', Scr)
        app:connect('engine', PB_DataEngine)
        app:init()
        app.logger:init()

        if app.logger.profile then
            Profile = dofile(p .. '../../Resources/Common/Helpers/Lua/Profiler.lua')
        end

        local settings = PB_Settings:new({})
        local userdata = PB_UserData:new({})

        app:connect('settings', settings)
        app:connect('userdata', userdata)
        app.settings:load({ 'fxTypeOrder', 'groupOrder' })
        app.userdata:load()
        app.gui:init();

        ---------------------------------------
        -- Functions --------------------------
        ---------------------------------------


        app.selection = {
            items = {},
            keyboardPos = 1,
            count = function(self) return OD_TableLength(self.items) end,
            empty = function(self)
                self.items = {};
                -- self:setKeyboardPos(nil);
            end,
            add = function(self, itemIdx)
                -- Check if the result doesn't allow multiple selection
                local result = app.temp.searchResults[itemIdx]
                if result and result.allowMultiple == false then
                    -- If this result doesn't allow multiple, clear all others and select only this one
                    self.items = {}
                    self.items[itemIdx] = true
                else
                    -- Check if any currently selected result doesn't allow multiple
                    for selectedIdx, _ in pairs(self.items) do
                        local selectedResult = app.temp.searchResults[selectedIdx]
                        if selectedResult and selectedResult.allowMultiple == false then
                            -- Clear all selections if any selected result doesn't allow multiple
                            self.items = {}
                            break
                        end
                    end
                    self.items[itemIdx] = true
                end
            end,
            remove = function(self, itemIdx)
                if not (self.keyboardPos == itemIdx and self:count() == 1) then
                    self.items[itemIdx] = nil
                    if self.keyboardPos == itemIdx then
                        local closest = nil
                        for i, _ in pairs(self.items) do
                            if i < itemIdx then closest = i end
                            if i > itemIdx then
                                if (closest == nil) or ((i - itemIdx) < (itemIdx - closest)) then
                                    closest = i
                                end
                                -- break
                            end
                        end
                        self:setKeyboardPos(closest, false)
                    end
                end
            end,
            has = function(self, itemIdx)
                return self.items[itemIdx] ~= nil
            end,
            selectOnly = function(self, itemIdx)
                self:empty()
                self:add(itemIdx)
                self:setKeyboardPos(itemIdx)
            end,
            toggle = function(self, itemIdx)
                local result = app.temp.searchResults[itemIdx]

                if self:has(itemIdx) then
                    self:remove(itemIdx)
                    return false
                else
                    -- Check if the result being added doesn't allow multiple selection
                    if result and result.allowMultiple == false then
                        -- If this result doesn't allow multiple, select only this one
                        self:selectOnly(itemIdx)
                        return true
                    else
                        -- Check if any currently selected result doesn't allow multiple
                        for selectedIdx, _ in pairs(self.items) do
                            local selectedResult = app.temp.searchResults[selectedIdx]
                            if selectedResult and selectedResult.allowMultiple == false then
                                -- Clear all and select only the new item if any current selection doesn't allow multiple
                                self:selectOnly(itemIdx)
                                return true
                            end
                        end

                        -- Normal toggle - add to selection
                        self:add(itemIdx)
                        return true
                    end
                end
            end,
            selectRange = function(self, fromIdx, toIdx)
                local from, to = math.min(fromIdx, toIdx), math.max(fromIdx, toIdx)

                -- Check if the target item allows multiple selection
                local targetResult = app.temp.searchResults[toIdx]
                if targetResult and targetResult.allowMultiple == false then
                    -- If target doesn't allow multiple, select only the target
                    self:selectOnly(toIdx)
                    return
                end

                -- Store current selection that's outside the new range
                local preservedSelection = {}
                for selectedIdx, _ in pairs(self.items) do
                    -- Preserve items that are outside the range from keyboard position to target
                    if (selectedIdx < from or selectedIdx > to) then
                        local selectedResult = app.temp.searchResults[selectedIdx]
                        if selectedResult and selectedResult.allowMultiple ~= false then
                            preservedSelection[selectedIdx] = true
                        end
                    end
                end

                -- Clear existing selection
                self:empty()

                -- Restore preserved selection
                for idx, _ in pairs(preservedSelection) do
                    self.items[idx] = true
                end

                -- Add the new range, but only items that allow multiple selection
                for i = from, to do
                    local result = app.temp.searchResults[i]
                    if result and result.allowMultiple ~= false then
                        self.items[i] = true
                    end
                end

                self:setKeyboardPos(toIdx)
            end,
            setKeyboardPos = function(self, itemIdx, scroll)
                local scroll = (scroll == nil) and true or scroll
                self.keyboardPos = itemIdx
                if scroll then app.temp.scrollIfNeeded = true end
            end,
            results = function(self)
                local results = {}
                for resultIndex, _ in pairs(self.items) do
                    table.insert(results, app.temp.searchResults[resultIndex])
                end
                return results
            end,
            execute = function(self, resultContext, contextData, confirm)
                local results = self:results()

                -- Group results by asset type
                local resultsByType = {}
                for _, result in pairs(results) do
                    if result.execute then
                        local assetType = result.type
                        if not resultsByType[assetType] then
                            resultsByType[assetType] = {}
                        end
                        table.insert(resultsByType[assetType], result)
                    end
                end
                r.Undo_BeginBlock()
                -- Execute each asset type group sequentially
                for assetType, typeResults in pairs(resultsByType) do
                    local total = #typeResults
                    for i, result in ipairs(typeResults) do
                        result:execute(ImGui.GetKeyMods(app.gui.ctx), resultContext or 0, contextData, confirm, total,
                            i)
                    end
                end
                r.Undo_EndBlock('', -1)
            end
        }

        -- Cache invalidation helpers for optimized filtering
        app.cacheHelpers = {
            invalidateAssetSearchCache = function(self, asset)
                -- Invalidate search text cache for a single asset
                if asset then
                    asset._searchTextConcat = nil
                    asset._searchTextLower = nil
                    asset._searchTextInvalid = true
                end
            end,
            invalidateAllAssetSearchCaches = function(self)
                -- Invalidate search text caches for all assets
                if app.engine and app.engine.assets then
                    for i = 1, #app.engine.assets do
                        local asset = app.engine.assets[i]
                        asset._searchTextConcat = nil
                        asset._searchTextLower = nil
                        asset._searchTextInvalid = true
                    end
                end
                if app.engine and app.engine.filterAssets then
                    for i = 1, #app.engine.filterAssets do
                        local asset = app.engine.filterAssets[i]
                        asset._searchTextConcat = nil
                        asset._searchTextLower = nil
                        asset._searchTextInvalid = true
                    end
                end
            end
        }

        app.flow = {
            close = function()
                app.hide = true
            end,
            resetTemp = function()
                app.temp.confirmation = {}
                app.temp.searchMode = SEARCH_MODE.MAIN
            end,
            setPage = function(page)
                if page ~= app.page then
                    app.page = page
                    app.pageSwitched = true
                end
            end,
            setSearchMode = function(mode, filter)
                app.temp.searchMode = mode
                app.temp.searchInput = ''
                app.flow.filterResults(filter or { text = '' })
            end,
            filterResults = function(query, skipReset, maintainSelection)
                local reset = (skipReset == nil) and true or (not skipReset)
                local assets = app.temp.searchMode == SEARCH_MODE.MAIN and app.engine.assets or app.engine.filterAssets
                local tagsTable = app.engine.tags
                local oldResults, oldKeyboardPosResult, validatedFilter, hasIssues, filter, maintainTargets
                local init = function()
                    app.temp.filter = app.temp.filter or {}
                    if not reset then
                        oldResults = app.selection:results()
                        oldKeyboardPosResult = oldResults[app.selection.keyboardPos]
                    end
                    if maintainSelection then
                        -- Handle target assets selection (can be single asset, multiple assets, or nil)
                        maintainTargets = maintainSelection and app.selection:results() or nil
                    end
                    query = OD_DeepCopy(query) or {}
                    if query.clear then
                        -- app.temp.searchInput = ''
                        app.guiHelpers.clearSearchInputText()
                        app.temp.filter = {}
                    end
                    if query.clearText then
                        app.guiHelpers.clearSearchInputText()
                        -- app.temp.searchInput = ''
                        app.temp.filter.text = ''
                    end
                    query.text = query.text or app.temp.filter.text or ''
                    app.temp.searchResults = {}
                end
                local handlePreset = function()
                    if query and query.preset then
                        local presetId = query.preset
                        local preset = app.engine.presets[presetId]
                        if preset then
                            preset:apply()
                            return true -- Exit early, preset handles its own filtering
                        else
                            app.logger:logError('Preset not found: ' .. tostring(presetId))
                            return true
                        end
                    end
                end
                local queryToFilter = function()
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

                    -- Other filter fields with validation
                    for queryType, queryValue in pairs(query) do
                        if queryType ~= 'text' and queryType ~= 'addTags' and queryType ~= 'removeTags' then
                            if queryValue == 'all' then
                                filter[queryType] = nil
                            else
                                filter[queryType] = queryValue
                            end
                        end
                    end
                    return filter
                end
                local filterAssets = function()
                    -- Optimization 1: Pre-compute and cache expensive operations
                    local filterTextLower = validatedFilter.text:lower()
                    local filterWords = {}
                    if filterTextLower ~= "" then
                        for word in filterTextLower:gmatch("%S+") do
                            table.insert(filterWords, word)
                        end
                    end

                    -- Optimization 2: Early exit strategies - check if we have any filters
                    local hasTextFilter = #filterWords > 0
                    local hasTypeFilters = validatedFilter.type or validatedFilter.fx_type or
                        validatedFilter.fxDeveloper or validatedFilter.fxFolderId or
                        validatedFilter.fxCategory or validatedFilter.untagged or validatedFilter.recentlyAdded
                    local hasTagFilters = next(validatedFilter.tags) ~= nil

                    -- If no filters at all, return all assets (or handle based on search mode)
                    if not hasTextFilter and not hasTypeFilters and not hasTagFilters and app.temp.searchMode == SEARCH_MODE.MAIN then
                        for i = 1, #assets do
                            local asset = assets[i]
                            -- Set empty foundIndexes to prevent nil access errors
                            asset.foundIndexes = {}
                            app.temp.searchResults[#app.temp.searchResults + 1] = asset
                        end
                        return
                    end

                    -- Optimization 3: Batch asset filtering by type (group common type checks)
                    local typeFilterChecks = {}
                    if hasTypeFilters then
                        typeFilterChecks.type = validatedFilter.type
                        typeFilterChecks.fx_type = validatedFilter.fx_type
                        typeFilterChecks.fxDeveloper = validatedFilter.fxDeveloper
                        typeFilterChecks.fxFolderId = validatedFilter.fxFolderId
                        typeFilterChecks.fxCategory = validatedFilter.fxCategory
                        typeFilterChecks.untagged = validatedFilter.untagged
                        typeFilterChecks.recentlyAdded = validatedFilter.recentlyAdded
                    end

                    -- Cache filter tags for faster access
                    local filterTags = validatedFilter.tags

                    for i = 1, #assets do
                        local asset = assets[i]

                        -- Ensure foundIndexes is always initialized to prevent nil access
                        if not asset.foundIndexes then
                            asset.foundIndexes = {}
                        end

                        if app.temp.searchMode == SEARCH_MODE.MAIN then
                            -- Optimization 2: Early exit on first failed type condition
                            if hasTypeFilters then
                                if (typeFilterChecks.type and asset.type ~= typeFilterChecks.type) then
                                    goto skip
                                end
                                if (typeFilterChecks.fx_type and asset.fx_type ~= typeFilterChecks.fx_type) then
                                    goto skip
                                end
                                if (typeFilterChecks.untagged and (#asset.tags > 0)) then
                                    goto skip
                                end
                                if (typeFilterChecks.recentlyAdded and (not asset.addedAt or asset.addedAt < (os.time() - app.settings.current.recentlyAddedDays * 86400))) then
                                    goto skip
                                end
                                if (typeFilterChecks.fxDeveloper and (not asset.vendor or asset.vendor ~= typeFilterChecks.fxDeveloper)) then
                                    goto skip
                                end
                                if (typeFilterChecks.fxFolderId and (asset.type ~= ASSET_TYPE.PluginAssetType or not asset:isInFolder(typeFilterChecks.fxFolderId))) then
                                    goto skip
                                end
                                if (typeFilterChecks.fxCategory and (asset.type ~= ASSET_TYPE.PluginAssetType or not asset:isInCategory(typeFilterChecks.fxCategory))) then
                                    goto skip
                                end
                            end

                            -- Tag filters with early exit
                            if hasTagFilters then
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
                            end
                        end

                        -- Optimization 4: Optimize text search
                        if hasTextFilter then
                            -- Optimization 1: Pre-compute search text concatenation with cache invalidation
                            if not asset._searchTextConcat or asset._searchTextInvalid then
                                local parts = {}
                                for j = 1, #asset.searchText do
                                    parts[j] = asset.searchText[j].text
                                end
                                asset._searchTextConcat = table.concat(parts, " "):lower()
                                asset._searchTextInvalid = false -- Mark as valid
                            end

                            -- Use single concatenated string search instead of multiple searches
                            local searchTarget = asset._searchTextConcat
                            local allWordsFound = true

                            for _, word in ipairs(filterWords) do
                                if not searchTarget:find(word, 1, true) then -- plain text search
                                    allWordsFound = false
                                    break
                                end
                            end

                            if allWordsFound then
                                -- Only compute foundIndexes if we need highlighting (lazy computation)
                                if not asset._searchTextLower or asset._searchTextInvalid then
                                    asset._searchTextLower = {}
                                    for j = 1, #asset.searchText do
                                        asset._searchTextLower[j] = asset.searchText[j].text:lower()
                                    end
                                end

                                local foundIndexes = {}
                                for _, word in ipairs(filterWords) do
                                    for j = 1, #asset._searchTextLower do
                                        local assetWordLower = asset._searchTextLower[j]
                                        local pos = string.find(assetWordLower, word, 1, true)
                                        if pos then
                                            foundIndexes[j] = foundIndexes[j] or {}
                                            table.insert(foundIndexes[j],
                                                { from = pos, to = pos + #word - 1, order = pos })
                                        end
                                    end
                                end

                                asset.foundIndexes = foundIndexes
                                app.temp.searchResults[#app.temp.searchResults + 1] = asset
                            end
                        else
                            -- No text filter, add asset if it passed other filters
                            -- Set empty foundIndexes to prevent nil access errors
                            asset.foundIndexes = {}
                            app.temp.searchResults[#app.temp.searchResults + 1] = asset
                        end
                        ::skip::
                    end
                end
                local resetOrRestoreSelection = function()
                    if reset then
                        -- If targetAssets is a single asset (not a table), convert it to a table
                        if maintainTargets and type(maintainTargets) ~= "table" then
                            maintainTargets = { maintainTargets }
                        end

                        if maintainTargets and #maintainTargets > 0 and #app.temp.searchResults > 0 then
                            app.selection:empty()
                            local firstTargetIndex = nil

                            for i, result in ipairs(app.temp.searchResults) do
                                for _, targetAsset in ipairs(maintainTargets) do
                                    if result.type == targetAsset.type and result.load == targetAsset.load then
                                        app.selection:add(i)
                                        if not firstTargetIndex then
                                            firstTargetIndex = i
                                        end
                                        break
                                    end
                                end
                            end

                            if firstTargetIndex then
                                app.selection:setKeyboardPos(firstTargetIndex)
                            else
                                -- Target assets not found in results, fall back to first result
                                app.selection:selectOnly(1)
                            end
                        else
                            -- Default behavior: make the first result selected and set the keyboard position to it
                            if #app.temp.searchResults > 0 then
                                app.selection:selectOnly(1)
                            else
                                app.selection:empty()
                            end
                        end
                    else
                        app.selection:empty()
                        for i, result in ipairs(app.temp.searchResults) do
                            for j, oldResult in ipairs(oldResults) do
                                if oldResult == result then
                                    app.selection:add(i)
                                    if oldKeyboardPosResult == result then app.selection:setKeyboardPos(i) end
                                    break
                                end
                            end
                        end
                    end
                end

                if handlePreset() then return end
                init()
                filter = queryToFilter()
                validatedFilter, hasIssues = app.engine:validateFilter(filter)
                app.temp.filter = validatedFilter
                filterAssets()
                resetOrRestoreSelection()
            end,
            executeSelectedResults = function(ctx, resultContext, contextData, confirm)
                local resultCount = app.selection:count()
                if resultCount >= app.settings.current.numberOfResultsThatRequireConfirmation and not (confirm and confirm.multipleResults) then
                    app.temp.confirmMultipleResults = {
                        count = resultCount,
                        resultContext = resultContext,
                        contextData = contextData
                    }
                elseif confirm or resultCount < app.settings.current.numberOfResultsThatRequireConfirmation then
                    app.selection:execute(resultContext, contextData, confirm)
                end
            end,
            executeRandomResult = function()
                -- local randomResult = app.temp.searchResults[math.random(#app.temp.searchResults)]
                app.selection:selectOnly(math.random(#app.temp.searchResults))
                app.selection:execute(RESULT_CONTEXT['IGNORE_KEYS'])
            end,
            createAction = function(actionName, cmd)
                local snActionName = OD_SanitizeFilename(actionName)
                local filename = ('%s - %s'):format(Scr.no_ext, snActionName)

                local outputFn = string.format('%s/%s.lua', Scr.dir, filename)
                local code = (EXPORTED_ACTION):gsub('$(%w+)', {
                    context = Scr.ext_name,
                    scriptname = Scr.basename,
                    cmd = cmd
                })
                code = ('-- This file was created by %s on %s\n\n'):format(Scr.name, os.date('%c')) .. code
                local file = assert(io.open(outputFn, 'w'))
                file:write(code)
                file:close()

                if r.AddRemoveReaScript(true, 0, outputFn, true) == 0 then
                    return false
                end
                return filename .. '.lua'
            end,
            createFilterAction = function(actionName, actionType, filter)
                if EXPORT_ACTIONS[actionType] then
                    return app.flow.createAction(actionName,
                        EXPORT_ACTIONS[actionType] .. " \'..\n[[" .. pickle(filter) .. "\n]]..\'")
                end
            end,
            checkExternalCommand = function()
                local raw_cmd = r.GetExtState(Scr.ext_name, 'EXTERNAL_COMMAND')
                local cmd, arg = raw_cmd:match('^([%w_]+)%s*(.*)$')
                if cmd ~= '' and cmd ~= nil then
                    if cmd == "APPLY_FILTER" then
                        local filter = unpickle(arg)
                        app.flow.filterResults(filter)
                        r.SetExtState(Scr.ext_name, 'EXTERNAL_COMMAND', '', false)
                    end
                    if cmd == "RUN_RANDOM" then
                        local filter = unpickle(arg)
                        local shouldClose = (r.GetExtState(Scr.ext_name, 'RUNNING') ~= 'TRUE')
                        r.SetExtState(Scr.ext_name, 'EXTERNAL_COMMAND', '', false)
                        if shouldClose then
                            app.flow.filterResults(filter)
                            app.flow.executeRandomResult()
                            app.flow.close()
                        else
                            local currentFilter = OD_DeepCopy(app.temp.filter)
                            app.flow.filterResults(filter, true, true)
                            app.flow.executeRandomResult()
                            app.temp.filter = currentFilter
                        end
                    end
                end
            end,
            hibernate = function()
                local cmd = r.GetExtState(Scr.ext_name, 'WAKEUP')
                if cmd == 'EXIT' then
                    -- Check if script was updated while hibernating
                    -- local currentVersion = r.GetExtState(Scr.ext_name, 'SCRIPT_VERSION')
                    -- Version mismatch: script was updated, exit gracefully
                    app.logger:logInfo(('Script version changed while hibernating for %.2f. Exiting to allow new version to start')
                        :format(r.time_precise() - app.temp.hibernationStart))
                    r.SetExtState(Scr.ext_name, 'WAKEUP', '', false)
                    r.SetExtState(Scr.ext_name, 'HIBERNATING_VERSION', '', false)
                    r.SetExtState(Scr.ext_name, 'RUNNING', '', false)
                elseif cmd ~= 'WAITING' and cmd ~= '' and cmd ~= nil then
                    -- Normal wakeup
                    app.logger:logInfo(('Woke up after hibernating for %.2f seconds'):format(r.time_precise() -
                        app.temp.hibernationStart))
                    app.temp.hibernationStart = nil
                    r.SetExtState(Scr.ext_name, 'RUNNING', 'WAKING UP', false)    -- This is needed for the wakeup check in checkExternalCommand's RUN_RANDOM, even though it's not referenced directly
                    r.SetExtState(Scr.ext_name, 'WAKEUP', '', false)
                    r.SetExtState(Scr.ext_name, 'HIBERNATING_VERSION', '', false) -- Clear hibernating version
                    app.flow.setSearchMode(SEARCH_MODE.MAIN, { clear = true })
                    PDefer(app.loop)
                else
                    -- without this code the context gets invalidated, so it needs to be kept alive
                    local ctx = app.gui.ctx
                    ImGui.PushFont(ctx, app.gui.st.fonts.default)
                    ImGui.PopFont(ctx)
                    PDefer(app.flow.hibernate)
                end
            end
        }
        app.guiHelpers = {
            initFrame = function(ctx)
                local function refreshWindowSize()
                    if app.page then
                        local width = app.page.width
                        local minHeight = (app.page.minHeight * app.gui.scale) or 0
                        app.gui.mainWindow.min_w, app.gui.mainWindow.min_h = app.page.width * app.gui.scale,
                            ((minHeight or (app.page.minHeight * app.gui.scale) or 0) or 0)
                        ImGui.SetNextWindowSize(app.gui.ctx,
                            math.max(app.settings.current.lastWindowWidth or 0, app.page.width * app.gui.scale),
                            math.max(app.settings.current.lastWindowHeight or 0,
                                (app.page.height or 0) * app.gui.scale))
                        app.refreshWindowSizeOnNextFrame = false
                    end
                end
                local function checkProjectChange(force)
                    if force or OD_DidProjectGUIDChange() then
                        local projPath, projFileName = OD_GetProjectPaths()
                        logger:setLogFile(projPath .. Scr.name .. '_' .. projFileName .. '.log')
                    end
                end
                local function handlePageSwitch()
                    if app.pageSwitched then
                        app.flow.resetTemp()
                        app.framesSincePageSwitch = (app.framesSincePageSwitch or 0) + 1
                    end
                    if app.framesSincePageSwitch == 1 or app.refreshWindowSizeOnNextFrame then
                        refreshWindowSize()
                    end
                    if app.framesSincePageSwitch and app.framesSincePageSwitch > 1 then
                        app.pageSwitched = false
                        app.framesSincePageSwitch = nil
                    end
                end

                local change = app.gui:recalculateZoom(app.settings.current.uiScale)
                if change ~= 1 then
                    app.settings.current.lastWindowWidth = app.settings.current.lastWindowWidth * change
                    app.settings.current.lastWindowHeight = app.settings.current.lastWindowHeight * change
                    app.refreshWindowSizeOnNextFrame = true
                end
                if app.temp.waitingForDoubleClick and (r.time_precise() - app.temp.waitingForDoubleClick) > 0.5 then
                    app.temp.waitingForDoubleClick = nil
                end


                -- reset keyboard cuttoff time when getting focus,
                -- to prevent keys that were pressed before coming into focus from being captured
                -- app.gui.mainWindow.focused = ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_AnyWindow)
                -- if (not app.temp.prevWindowIsFocused) and app.gui.mainWindow.focused then
                --     app.temp.prevWindowIsFocused = true
                -- elseif not app.gui.mainWindow.focused and app.temp.prevWindowIsFocused then
                --     app.temp.prevWindowIsFocused = false
                -- end

                if app.logger.showImGuiDebugWindows then
                    ImGui.ShowMetricsWindow(ctx)
                    ImGui.ShowDebugLogWindow(ctx)
                    ImGui.ShowIDStackToolWindow(ctx)
                end
                checkProjectChange()
                app.engine:sync()
                handlePageSwitch()
            end,
            saveWindowDimensions = function(ctx)
                app.gui.mainWindow.pos = { ImGui.GetWindowPos(ctx) }
                app.gui.mainWindow.size = { ImGui.GetWindowSize(ctx) }
                app.gui.screen = { size = { OD_GetScreenSize() } }
                app.settings.current.lastWindowWidth, app.settings.current.lastWindowHeight = app.gui.mainWindow.size[1],
                    app.gui.mainWindow.size[2]
            end,
            handleDocking = function(ctx, pos)
                if pos == 1 then -- before window has been created
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
                elseif pos == 2 then --after a window has been created
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
                        ImGui.SetConfigVar(ctx, ImGui.ConfigVar_HoverDelayNormal, 0.6)
                    end
                end
            end,
            isShortcutPressed = function(key, global)
                local shortcut = app.settings.current.shortcuts[key]
                if shortcut and shortcut.key == -1 then return false end
                local keyChord = app.settings.shortCutToKeyChord(shortcut)
                return ImGui.Shortcut(app.gui.ctx, keyChord,
                    global and ImGui.InputFlags_RouteAlways or ImGui.InputFlags_None)
            end,
            getShortcutDescription = function(key)
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
            end,
            selectSearchInputText = function()
                app.temp.selectSearchInputText = true
            end,
            clearSearchInputText = function()
                app.temp.clearSearchInputText = true
            end,
            keyModsToText = function(mods)
                local modKeys = {}
                if OD_BfCheck(mods, ImGui.Mod_Ctrl) then table.insert(modKeys, OS_is.mac and 'Cmd' or 'Ctrl') end
                if OD_BfCheck(mods, ImGui.Mod_Alt) then table.insert(modKeys, OS_is.mac and 'Option' or 'alt') end
                if OD_BfCheck(mods, ImGui.Mod_Shift) then table.insert(modKeys, 'Shift') end
                if OD_BfCheck(mods, RESULT_CONTEXT.DRAGGED_TO_BLANK) then
                    table.insert(modKeys, 'Drag to empty area')
                elseif OD_BfCheck(mods, RESULT_CONTEXT.DRAGGED_TO_OBJECT) then
                    table.insert(modKeys, 'Drag to track')
                else
                    if OD_BfCheck(mods, RESULT_CONTEXT.KEYBOARD) then table.insert(modKeys, 'Enter') end
                    if OD_BfCheck(mods, RESULT_CONTEXT.MOUSE_CLICK) then table.insert(modKeys, 'Click') end
                    if OD_BfCheck(mods, RESULT_CONTEXT.MOUSE_DOUBLE_CLICK) then table.insert(modKeys, 'Double-Click') end
                end
                return table.concat(modKeys, '+')
            end,
            getHintFor = function(asset, context, count)
                local mods = ImGui.GetKeyMods(app.gui.ctx)
                local assetHint, usedMods = asset:getInteractionHintFor(mods, context, nil,
                    count)
                if assetHint then
                    local action = assetHint
                    local actionKey = app.guiHelpers.keyModsToText(usedMods)
                    local hint = ('%s to %s.'):format(actionKey, action)
                    return hint
                end
            end,
            calcTinyIconSize = function(ctx, icon)
                app.temp.iconSizes = app.temp.iconSizes or {}
                app.temp.iconSizesCacheZoom = app.temp.iconSizesCacheZoom or {}
                if app.temp.iconSizes[icon] and app.temp.iconSizesCacheZoom[icon] == app.gui.scale then
                    return table.unpack(app.temp.iconSizes[icon])
                else
                    app.temp.iconSizesCacheZoom[icon] = app.gui.scale
                    ImGui.PushFont(ctx, app.gui.st.fonts.icons_tiny)
                    local iconW, iconH = ImGui.CalcTextSize(ctx, icon)
                    app.temp.iconSizes[icon] = table.pack(iconW, iconH)
                    ImGui.PopFont(ctx)
                    return table.unpack(app.temp.iconSizes[icon])
                end
            end,
            tinyIcon = function(ctx, id, icon, highlighted, disabled, hint, hintLevel)
                local clicked = false
                local textH = ImGui.GetTextLineHeight(ctx)
                local paddingX, paddingY = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)
                local iconW, iconH = app.guiHelpers.calcTinyIconSize(ctx, icon) --ImGui.CalcTextSize(ctx, icon)

                ImGui.BeginGroup(ctx)
                local x, y = ImGui.GetCursorPos(ctx)
                ImGui.SetCursorPosY(ctx, y + paddingY + (textH - iconH) / 2)
                if ImGui.InvisibleButton(ctx, 'x##' .. id, iconW, iconH) then
                    clicked = true
                end
                local col = highlighted and app.gui.st.basecolors.textDark or
                    (disabled and app.gui.st.basecolors.textDark or app.gui.st.col.activeFilterButton[ImGui.Col_Button])
                if ImGui.IsItemHovered(ctx) and not disabled then
                    if hint then
                        app:setHint('main', hint, nil, nil, hintLevel)
                    end
                    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand)
                    if ImGui.IsItemActive(ctx) then
                        col = app.gui.st.col.activeFilterButton[ImGui.Col_ButtonActive]
                    else
                        col = app.gui.st.col.activeFilterButton[ImGui.Col_ButtonHovered]
                    end
                end
                ImGui.SetCursorPos(ctx, x, y + paddingY + (textH - iconH) / 2)
                ImGui.PushFont(ctx, app.gui.st.fonts.icons_tiny)
                ImGui.TextColored(ctx, col, icon)
                ImGui.PopFont(ctx)
                ImGui.EndGroup(ctx)
                if not disabled then return clicked end
            end,
            iconButton = function(ctx, icon, colClass, hint, font)
                local font = font or app.gui.st.fonts.icons_large
                ImGui.PushFont(ctx, font)
                local x, y = ImGui.GetCursorPos(ctx)
                local w = select(1, ImGui.CalcTextSize(ctx, ICONS[(icon):upper()])) +
                    ImGui.GetStyleVar(app.gui.ctx, ImGui.StyleVar_FramePadding) * 2
                local clicked
                if ImGui.InvisibleButton(ctx, '##menuBtn' .. icon, w, ImGui.GetTextLineHeightWithSpacing(ctx)) then
                    clicked = true
                end
                if hint then
                    app:setHoveredHint('main', hint)
                end
                if ImGui.IsItemHovered(ctx) then
                    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand)
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
            end,
        }
        app.draw = {
            search = function(ctx)
                app.gui:pushStyles(app.gui.st.vars.searchWindow)
                app.gui:pushColors(app.gui.st.col.searchWindow)
                -- Inline variable explanations for layout/UI parameters:
                local w, h = ImGui.GetContentRegionAvail(ctx)
                local paddingX, paddingY = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)
                local spacingX, spacingY = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
                local sideBarMinimizedW = 0
                local sideBarW, sideBarH =
                    app.settings.current.showSideBar and (app.settings.current.sideBarWidth * app.gui.scale) or
                    sideBarMinimizedW,
                    select(2, ImGui.GetContentRegionAvail(ctx))
                local sideBarScreenX = select(1, ImGui.GetCursorScreenPos(ctx)) + w - sideBarW -- X position for tag area
                local upperRowY = ImGui.GetCursorPosY(ctx)                                     -- Y position for upper row, used for "sticky" first group title
                local upperRowScreenY = select(2, ImGui.GetCursorScreenPos(ctx))               -- Y position for upper row, used for "sticky" first group title
                local fontLineHeight = ImGui.GetTextLineHeightWithSpacing(ctx)

                local tagInfo = app.userdata.current.tagInfo
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
                        sideBarScreenX, 10, sideBarScreenX + sideBarW, 1000, 0xffffff22)
                end

                local drawActiveFilters = function()
                    local x, y = ImGui.GetCursorPos(ctx)
                    local lines = 1
                    local height = 0
                    local activeFilters = app.temp.activeFilters ~= nil and app.temp.activeFilters or {}

                    local currentActiveKeys = {}
                    -- local numFilters = 0
                    for i, filterKey in pairs(FILTER_TYPES) do
                        local filterItem = nil
                        local selectedItemName
                        if filterKey ~= FILTER_TYPES.TAG then
                            for itemName, item in pairs(FILTER_MENU[filterKey].items) do
                                for queryKey, queryValue in pairs(item.query) do
                                    if app.temp.filter[queryKey] == queryValue then
                                        local key = filterKey .. item.order
                                        table.insert(currentActiveKeys, key)
                                        activeFilters[key] = activeFilters[key] or {}
                                        activeFilters[key].key = key
                                        activeFilters[key].type = filterKey
                                        activeFilters[key].item = item
                                        activeFilters[key].itemName = itemName
                                        activeFilters[key].allQuery = item.allQuery or FILTER_MENU[filterKey].allQuery
                                        if activeFilters[key].order == nil then
                                            activeFilters[key].order = OD_Tablelength(
                                                activeFilters)
                                        end
                                    end
                                end
                            end
                        else
                            for tagKey, tagValue in pairs(app.temp.filter.tags) do
                                if app.engine.tags[tagKey] then
                                    local key = filterKey .. tagKey
                                    table.insert(currentActiveKeys, key)
                                    activeFilters[key] = activeFilters[key] or {}
                                    activeFilters[key].key = key
                                    activeFilters[key].type = FILTER_TYPES.TAG
                                    activeFilters[key].value = tagValue
                                    activeFilters[key].item = app.engine.tags[tagKey]
                                    activeFilters[key].itemName = app.engine.tags[tagKey].name

                                    if activeFilters[key].order == nil then
                                        activeFilters[key].order = OD_Tablelength(
                                            activeFilters)
                                    end
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
                        ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx))

                        if app.guiHelpers.iconButton(ctx, 'CLOSE', app.gui.st.col.buttons.activeFilterAction) then
                            app.flow.filterResults({ clear = true })
                        end
                        app:setHoveredHint('main', T.HINTS.RESET_FILTERS)
                        if app.guiHelpers.iconButton(ctx, 'DISK', app.gui.st.col.buttons.activeFilterAction) then
                            ImGui.OpenPopup(ctx, 'Save Filter Set Context Menu')
                        end
                        app:setHoveredHint('main', T.HINTS.SAVE_FILTERS)
                        if ImGui.BeginPopup(ctx, 'Save Filter Set Context Menu') then
                            app:setHint('main', '')
                            if ImGui.MenuItem(ctx, 'Save preset...') then
                                app.temp.showCreatePresetDialog = true
                                app.temp.presetName = ""
                                app.temp.presetWord = ""
                            end
                            app:setHoveredHint('main', T.HINTS.SAVE_FILTERS_PRESET)
                            if ImGui.MenuItem(ctx, 'Create Reaper action...') then
                                app.temp.showExportActionDialog = true
                                app.temp.actionName = ""
                            end
                            app:setHoveredHint('main', T.HINTS.SAVE_FILTERS_ACTION)
                            ImGui.EndPopup(ctx)
                        end
                        if app.guiHelpers.iconButton(ctx, 'DICE', app.gui.st.col.buttons.activeFilterAction) then
                            app.flow.executeRandomResult()
                        end
                        app:setHoveredHint('main', T.HINTS.RANDOM_ACTION)
                        ImGui.SameLine(ctx)
                        ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + spacingX)
                        app.gui:pushStyles(app.gui.st.vars.topBarActiveFiltersArea)
                        app.gui:pushColors(app.gui.st.col.topBarActiveFiltersArea)


                        local closeButtonSizeW, closeButtonSizeH = app.guiHelpers.calcTinyIconSize(ctx, ICONS.CLOSE)
                        local paddingX, paddingY = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)
                        local filterH = ImGui.GetTextLineHeight(ctx) + paddingY * 2

                        if ImGui.BeginChild(ctx, 'activesideBar', nil, nil, ImGui.ChildFlags_AutoResizeY) then
                            local i = 0
                            for filterKey, filter in OD_PairsByOrder(activeFilters) do
                                i = i + 1
                                local text = filter.itemName
                                local textW, textH = ImGui.CalcTextSize(ctx, text)
                                if filter.type == FILTER_TYPES.TAG then
                                    text = filter.itemName
                                    -- textW = app.guiHelpers.calcTinyIconSize(ctx,
                                    --         filter.value and ICONS.PLUS or ICONS.MINUS) +

                                    ImGui.CalcTextSize(ctx, text)
                                end
                                local iconWidth = app.guiHelpers.calcTinyIconSize(ctx, FILTER_ICONS[filter.type])
                                local tagIconWidth = filter.type == FILTER_TYPES.TAG and
                                    (app.guiHelpers.calcTinyIconSize(ctx, (filter.value and ICONS.PLUS or ICONS.MINUS)) + spacingX) or
                                    0
                                local filterW = paddingX + iconWidth + tagIconWidth + spacingX + textW + spacingX * 2 +
                                    closeButtonSizeW +
                                    paddingX
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
                                    app.guiHelpers.tinyIcon(ctx, 'filterType',
                                        FILTER_ICONS[filter.type],
                                        true,
                                        true)
                                    ImGui.SameLine(ctx, 0, spacingX)

                                    -- ImGui.AlignTextToFramePadding(ctx)
                                    -- ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + iconWidth + spacingX * 2) --, ImGui.GetCursorPosY(ctx) + paddingY)
                                    if filter.type == FILTER_TYPES.TAG then
                                        -- ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) - spacingX)
                                        app.guiHelpers.tinyIcon(ctx, 'tagType',
                                            filter.value and ICONS.PLUS or ICONS.MINUS,
                                            true,
                                            true)
                                        ImGui.SameLine(ctx, 0, spacingX)
                                        -- ImGui.Dummy(ctx, 0, 0)
                                        -- ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) - spacingX)
                                        -- ImGui.TextColored(ctx, app.gui.st.basecolors.textDark, T.FILTER_NAMES[filter.key])
                                    end
                                    ImGui.AlignTextToFramePadding(ctx)
                                    ImGui.Text(ctx, filter.itemName)
                                    ImGui.SameLine(ctx, 0, spacingX * 2)
                                    if app.guiHelpers.tinyIcon(ctx, 'removeFilter', ICONS.CLOSE, nil, nil, T.HINTS.ACTIVE_FILTER_REMOVE, 2) then
                                        if filter.type == FILTER_TYPES.TAG then
                                            app.flow.filterResults({ removeTags = { filter.item.id } })
                                        else
                                            app.flow.filterResults(filter.allQuery)
                                        end
                                    end
                                    ImGui.SetCursorScreenPos(ctx, x2, y2)
                                    ImGui.Dummy(ctx, 0, 0)
                                    ImGui.EndChild(ctx)
                                end
                                -- if ImGui.IsItemHovered(ctx) then
                                if filter.type == FILTER_TYPES.TAG then
                                    if filter.value then
                                        app:setHoveredHint('main', (T.HINTS.TAG_POSITIVE):format(filter.itemName), nil,
                                            nil, 0)
                                    else
                                        app:setHoveredHint('main', (T.HINTS.TAG_NEGATIVE):format(filter.itemName), nil,
                                            nil, 0)
                                    end
                                else
                                    app:setHoveredHint('main',
                                        (T.HINTS.LOAD_FILTER_DEFAULT):format(T.FILTER_NAMES[filter.type], filter
                                            .itemName), nil, nil, 0)
                                end
                                -- end
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
                    -- AFTER TESTING: THIS IS UNNECCESSARY - Round fontLineHeight to avoid floating point precision issues with scrolling
                    -- local fontLineHeight = math.floor(fontLineHeight + 0.5) THAT IS DEFINITELY NOT THE ISSUE

                    local searchResultsH = select(2, ImGui.GetContentRegionAvail(ctx)) - fontLineHeight
                    local maxSearchResults = math.floor(searchResultsH / fontLineHeight) -- Max results in available space

                    local handleKeyboardNavigation = function()
                        -- handle escape
                        if app.selection.keyboardPos then
                            hintResult = searchResults[app.selection.keyboardPos]
                            hintContext = RESULT_CONTEXT.KEYBOARD
                            local newIdx = nil
                            if ImGui.IsKeyPressed(ctx, ImGui.Key_DownArrow) and app.selection.keyboardPos < #searchResults then
                                newIdx =
                                    app.selection.keyboardPos + 1
                            end
                            if ImGui.IsKeyPressed(ctx, ImGui.Key_UpArrow) and app.selection.keyboardPos > 1 then
                                newIdx = app
                                    .selection.keyboardPos - 1
                            end
                            if ImGui.IsKeyPressed(ctx, ImGui.Key_PageDown) then
                                newIdx = math.min(
                                    app.selection.keyboardPos + maxSearchResults, #searchResults)
                            end
                            if ImGui.IsKeyPressed(ctx, ImGui.Key_PageUp) then
                                newIdx = math.max(
                                    app.selection.keyboardPos - maxSearchResults, 1)
                            end
                            if ImGui.IsKeyPressed(ctx, ImGui.Key_Home) then
                                newIdx = 1
                            end
                            if ImGui.IsKeyPressed(ctx, ImGui.Key_End) then
                                newIdx = #searchResults
                            end
                            if newIdx then
                                if ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
                                    app.selection:selectRange(app.selection.keyboardPos, newIdx)
                                elseif ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl) then
                                    -- For Cmd/Ctrl navigation, add to selection if item allows multiple
                                    local targetResult = app.temp.searchResults[newIdx]
                                    if targetResult and targetResult.allowMultiple ~= false then
                                        -- Only add if it allows multiple selection
                                        app.selection:add(newIdx)
                                        app.selection:setKeyboardPos(newIdx)
                                    else
                                        -- If target doesn't allow multiple, select only it
                                        app.selection:selectOnly(newIdx)
                                    end
                                else
                                    app.selection:selectOnly(newIdx)
                                end
                            end
                        end
                    end

                    local handleResultDragDrop = function(row)
                        if ImGui.BeginDragDropTarget(ctx) then
                            local tagDropped, tagPayload = ImGui.AcceptDragDropPayload(ctx, 'TAG', nil,
                                ImGui.DragDropFlags_AcceptBeforeDelivery |
                                ImGui.DragDropFlags_AcceptNoDrawDefaultRect)
                            if tagDropped then
                                local payloadTag = app.engine.tags[tonumber(tagPayload)]

                                if app.selection:has(row.index) and not app.temp.highlightDropAreaForAllSelectedResults then
                                    app.temp.highlightDropAreaForAllSelectedResults = ImGui.GetFrameCount(
                                        ctx)
                                    app.temp.highlightDropAreaFor = nil
                                elseif not app.selection:has(row.index) then
                                    app.temp.highlightDropAreaForAllSelectedResults = nil
                                    app.temp.highlightDropAreaFor = row.index
                                end
                                local remove = ImGui.IsKeyDown(ctx, ImGui.Mod_Alt)
                                local numItemsSelected = app.selection:count()
                                local resultName = app.temp.highlightDropAreaFor and
                                    searchResults[app.temp.highlightDropAreaFor].searchText[1].text or
                                    (numItemsSelected == 1 and app.selection:results()[1].searchText[1].text or app.selection:count() .. ' items')
                                app:setHint('main',
                                    (remove and T.HINTS.DRAG_RESULT_TO_REMOVE_TAG or T.HINTS.DRAG_RESULT_TO_ADD_TAG)
                                    :format(payloadTag.name, resultName,
                                        OS_is.mac and 'Option' or 'Alt'), nil, nil, 2)

                                if ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Left) then
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
                                    app.userdata:save()
                                    app.flow.filterResults(nil, true)
                                    app.temp.highlightDropAreaForAllSelectedResults = nil
                                    app.temp.highlightDropAreaFor = nil
                                end
                            end
                            ImGui.EndDragDropTarget(ctx)
                        end
                        if ImGui.BeginDragDropSource(ctx) then
                            app:setHint('main', T.HINTS.DRAG_RESULT_DEFAULT)
                            if not ImGui.GetDragDropPayload(ctx) and not app.selection:has(row.index) then
                                app.selection:selectOnly(row.index)
                            end
                            local remove = ImGui.IsKeyDown(ctx, ImGui.Mod_Alt)
                            ImGui.SetDragDropPayload(ctx, 'ASSET', remove and 'remove' or 'add')
                            local numItemsSelected = app.selection:count()
                            local firstResult = app.selection:results()[1]
                            local resultName = (numItemsSelected == 1) and firstResult.searchText[1].text or
                                numItemsSelected .. ' items'
                            local winX, winY = table.unpack(app.gui.mainWindow.pos)
                            local winW, winH = table.unpack(app.gui.mainWindow.size)
                            local x, y = ImGui.GetCursorScreenPos(ctx)
                            if not (x >= winX and x <= winX + winW and y >= winY and y <= winY + winH) then
                                local object = r.BR_ItemAtMouseCursor() or r.BR_TrackAtMouseCursor()
                                local mods = ImGui.GetKeyMods(ctx)
                                local hintContext = object and RESULT_CONTEXT.DRAGGED_TO_OBJECT or
                                    RESULT_CONTEXT.DRAGGED_TO_BLANK
                                local assetHint = (firstResult:getInteractionHintFor(mods, hintContext, object,
                                    app.selection:count())):gsub("^%l", string.upper)
                                app:setHint('main', assetHint, nil, nil, 2)
                                app.temp.dragToObject = object or
                                    -1 -- either store the dragged track or -1 to signify blank
                            else
                                app.temp.dragToObject = nil
                            end
                            ImGui.Text(ctx, resultName)
                            ImGui.EndDragDropSource(ctx)
                        end
                        if ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Left) and app.temp.dragToObject then
                            if app.temp.dragToObject == -1 then
                                app.flow.executeSelectedResults(ctx, RESULT_CONTEXT.DRAGGED_TO_BLANK)
                                app.logger:logDebug('Will create a new track with ' ..
                                    app.selection:count() .. ' plugin(s)\n')
                            else
                                if app.logger.level >= app.logger.LOG_LEVEL.DEBUG then
                                    local itemName
                                    if app.temp.dragToObject and r.ValidatePtr(app.temp.dragToObject, "MediaItem*") then
                                        local take = r.GetActiveTake(app.temp.dragToObject)
                                        itemName = r.GetTakeName(take)
                                    else
                                        itemName = select(2, r.GetTrackName(app.temp.dragToObject))
                                    end
                                    app.logger:logDebug('Will add ' ..
                                        app.selection:count() ..
                                        ' plugins to track ' .. itemName .. '\n')
                                end
                                app.flow.executeSelectedResults(ctx, RESULT_CONTEXT.DRAGGED_TO_OBJECT, app.temp
                                    .dragToObject)
                            end
                            app.temp.dragToObject = nil
                        end
                    end
                    local handleScrolling = function()
                        local selectedRow = nil
                        if app.temp.scrollIfNeeded then
                            for i, row in ipairs(flatRows) do
                                if row.index == app.selection.keyboardPos then
                                    selectedRow = row
                                    break
                                end
                            end
                            if selectedRow then
                                app.temp.scrollIfNeeded = false
                                app.temp.tableScrollY = app.temp.tableScrollY or 0

                                -- Use the same line height for scrolling as for rendering

                                local rowPosition = (selectedRow.totalIndex - 1) * fontLineHeight
                                local currentScroll = app.temp.tableScrollY

                                -- Check if item is fully visible
                                local itemTop = rowPosition
                                local itemBottom = rowPosition + fontLineHeight
                                local viewTop = currentScroll
                                local viewBottom = currentScroll + searchResultsH

                                -- If item extends below the visible area, scroll to show it fully
                                if itemBottom > viewBottom then
                                    -- Scroll so the item's bottom aligns with the bottom of searchResultsH
                                    ImGui.SetNextWindowScroll(ctx, 0, itemBottom - searchResultsH)
                                    -- If item is above the visible area, scroll to show it at the top
                                elseif itemTop < viewTop then
                                    ImGui.SetNextWindowScroll(ctx, 0, math.max(0, itemTop))
                                end
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
                                (w - ImGui.CalcTextSize(ctx, text) - ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding) * 2) /
                                2)
                            if ImGui.Button(ctx, text) then
                                app.flow.filterResults({ clear = true })
                            end
                            app:setHoveredHint('main', T.HINTS.RESET_FILTERS)
                            ImGui.EndChild(ctx)
                        end
                    end

                    if ImGui.BeginChild(ctx, 'resultsArea', w - sideBarW - spacingX) then
                        if app.pageSwitched then
                            app.flow.filterResults({ text = '' })
                        end

                        handleKeyboardNavigation()
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
                                        {
                                            type = "group",
                                            group = result.group,
                                            groupObj = result,
                                            totalIndex =
                                                totalFlatRows
                                        })
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

                                ImGui.ListClipper_Begin(app.gui.searchResultsClipper, #flatRows, fontLineHeight)
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
                                                if not app.temp.waitingForDoubleClick then
                                                    app.temp.waitingForDoubleClick =
                                                        r.time_precise()
                                                end
                                                if ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
                                                    app.selection:selectRange(app.selection.keyboardPos, row.index)
                                                elseif ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl) then
                                                    if app.selection:toggle(row.index) then
                                                        app.selection.keyboardPos = row.index
                                                    end
                                                else
                                                    app.selection:selectOnly(row.index)
                                                end
                                                if ImGui.IsMouseDoubleClicked(ctx, ImGui.MouseButton_Left) then
                                                    app.flow.executeSelectedResults(ctx,
                                                        RESULT_CONTEXT.MOUSE_DOUBLE_CLICK)
                                                end
                                            end
                                            if app.temp.highlightDropAreaForAllSelectedResults and app.temp.highlightDropAreaForAllSelectedResults < ImGui.GetFrameCount(ctx) or app.temp.highlightDropAreaFor == row.index then
                                                ImGui.PopStyleColor(ctx)
                                            end
                                            if app.temp.searchMode == SEARCH_MODE.MAIN then
                                                handleResultDragDrop(row)
                                            end
                                            if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_ForTooltip) then
                                                -- local hint = app.guiHelpers.getHintFor(result, RESULT_CONTEXT.MOUSE_DOUBLE_CLICK, 1)
                                                -- if hint then
                                                --     ImGui.SetTooltip(ctx, hint)
                                                -- end
                                                -- hintResult = result
                                                -- hintContext = RESULT_CONTEXT.MOUSE_DOUBLE_CLICK
                                            end
                                            ImGui.SameLine(ctx)
                                            -- if result.type == ASSET_TYPE.TrackAssetType and result.color then
                                            if result.color then
                                                local size = fontLineHeight -
                                                    select(2, ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)) * 2
                                                ImGui.ColorButton(ctx, 'color', result.color,
                                                    ImGui.ColorEditFlags_NoBorder | ImGui.ColorEditFlags_NoTooltip, size,
                                                    size)
                                                ImGui.SameLine(ctx)
                                            end

                                            if result.favorite then
                                                -- if result.group == SPECIAL_GROUPS.FAVORITES then
                                                ImGui.PushFont(ctx, app.gui.st.fonts.icons_small)
                                                app.gui:pushColors(app.gui.st.col.search.favorite)
                                                ImGui.Text(ctx, ICONS.STAR)
                                                app.gui:popColors(app.gui.st.col.search.favorite)
                                                ImGui.PopFont(ctx)
                                                ImGui.SameLine(ctx)
                                            end
                                            if app.temp.searchMode == SEARCH_MODE.FILTERS then
                                                -- if result.group == SPECIAL_GROUPS.FAVORITES then
                                                ImGui.PushFont(ctx, app.gui.st.fonts.icons_small)
                                                app.gui:pushColors(app.gui.st.col.search.favorite)
                                                ImGui.Text(ctx, FILTER_ICONS[result.type])
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
                                            if (result.shortcuts and #result.shortcuts > 0) then
                                                app.gui:pushColors(app.gui.st.col.search.thirdResult)
                                                local text = ' ' .. table.concat(result.shortcuts, ', ')
                                                ImGui.Text(ctx, text)
                                                app.gui:popColors(app.gui.st.col.search.thirdResult)
                                            end
                                            if (result.tags and #result.tags > 0) then
                                                if (result.shortcuts and #result.shortcuts > 0) then
                                                    ImGui.SameLine(ctx)
                                                end
                                                app.gui:pushColors(app.gui.st.col.search.thirdResult)
                                                local text = '|'
                                                for t = 1, #(result.tags or {}) do
                                                    local tag = tagInfo[result.tags[t]]
                                                    text = text .. tag.name .. '|'
                                                end
                                                ImGui.Text(ctx, text)
                                                app.gui:popColors(app.gui.st.col.search.thirdResult)
                                            end
                                            if (result.parents and #result.parents > 0) then
                                                app.gui:pushColors(app.gui.st.col.search.thirdResult)
                                                local text = ' < '
                                                for i = #result.parents, 1, -1 do
                                                    local parent = result.parents[i]
                                                    text = text .. parent.name .. ' < '
                                                end
                                                ImGui.Text(ctx, text:sub(1, -3))
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
                            local hint = app.guiHelpers.getHintFor(hintResult, hintContext, app.selection:count())
                            if hint then
                                app:setHint('main', hint, nil, nil, -1)
                            end
                        else
                            app:setHint('main', '', nil, nil, -1)
                        end

                        ImGui.EndChild(ctx)
                    end
                end
                local drawSideBarSeparator = function()
                    -- Separator Resize Line
                    local separatorX, separatorY = ImGui.GetCursorScreenPos(ctx)
                    ImGui.DrawList_AddLine(ImGui.GetWindowDrawList(ctx), separatorX, separatorY, separatorX,
                        separatorY + h,
                        ImGui.GetStyleColor(ctx, ImGui.Col_Separator))
                    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) - spacingX)
                    ImGui.InvisibleButton(ctx, '##separator', spacingX * 2, sideBarH)
                    if ImGui.IsItemHovered(ctx) then
                        app:setHoveredHint('main', 'Drag to change tag list width')
                        ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
                    end
                    if ImGui.IsItemActive(ctx) then
                        ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
                        local mouseDeltaX = select(1, ImGui.GetMouseDragDelta(ctx, nil, nil, ImGui.MouseButton_Left))
                        if mouseDeltaX ~= 0 then
                            local newWidth = (sideBarW - mouseDeltaX) / app.gui.scale
                            if newWidth > app.settings.current.minSideBarWidth then
                                app.settings.current.sideBarWidth = newWidth
                                ImGui.ResetMouseDragDelta(ctx, ImGui.MouseButton_Left)
                            else
                                app.settings.current.sideBarWidth = app.settings.current.minSideBarWidth
                            end
                        end
                    end
                end
                local drawsideBar = function()
                    if ImGui.BeginChild(ctx, 'sideBar', sideBarW - spacingX * 2, sideBarH) then
                        local function drawTagsOfParent(parentId, indent, parentsDragged)
                            local drawTagNode
                            local function drawDropTarget(tag, height, position, offsetY, dragTargetLineOffsetY)
                                if height > 0 then
                                    local x, y = ImGui.GetCursorPos(ctx)
                                    local scrX, scrY = ImGui.GetCursorScreenPos(ctx)
                                    local offsetY = offsetY or 0
                                    local dragTargetLineOffsetY = dragTargetLineOffsetY or 0
                                    local w, h = ImGui.GetContentRegionAvail(ctx) -- * app.gui.scale
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
                                        if (tagDropped or assetDropped) and ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenBlockedByActiveItem | ImGui.HoveredFlags_DelayNormal | ImGui.HoveredFlags_NoSharedDelay) then
                                            tag:toggleOpen(true)
                                        end
                                        if tagDropped then
                                            local payloadTag = app.engine.tags[tonumber(tagPayload)]
                                            if position == 'inside' then
                                                app:setHint('main',
                                                    (T.HINTS.DRAG_TAG_INTO_TAG):format(payloadTag.name, tag.name), nil,
                                                    nil, 2)
                                                ImGui.DrawList_AddRect(ImGui.GetWindowDrawList(ctx), scrX,
                                                    scrY - height - offsetY,
                                                    scrX + tagW, scrY - height - offsetY + ImGui.GetTextLineHeight(ctx),
                                                    app.gui.st.basecolors.mainBright,
                                                    app.gui.st.vars.tag[ImGui.StyleVar_FrameRounding][1],
                                                    nil, 1.5 * app.gui.scale)
                                            else
                                                app:setHint('main',
                                                    (T.HINTS.DRAG_TAG_TO_POSITION_RELATIVE_TO_TAG):format(
                                                        payloadTag.name, position or '', tag.name), nil,
                                                    nil, 2)
                                                ImGui.DrawList_AddRect(ImGui.GetWindowDrawList(ctx), scrX,
                                                    scrY - height - offsetY + dragTargetLineOffsetY, scrX + w,
                                                    scrY - height - offsetY + dragTargetLineOffsetY,
                                                    app.gui.st.basecolors
                                                    .mainBright, 15, nil, 1.5 * app.gui.scale)
                                            end
                                            if ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Left) then
                                                payloadTag:moveTo(tag, position)
                                            end
                                        end
                                        if assetDropped then
                                            local remove = (assetPayload == 'remove')
                                            local numItemsSelected = app.selection:count()
                                            local resultName = (numItemsSelected == 1) and
                                                app.selection:results()[1].searchText[1].text or
                                                numItemsSelected .. ' items'
                                            app:setHint('main',
                                                (remove and T.HINTS.DRAG_RESULT_TO_REMOVE_TAG or T.HINTS.DRAG_RESULT_TO_ADD_TAG)
                                                :format(tag.name, resultName, OS_is.mac and 'Option' or 'Alt'))
                                            ImGui.DrawList_AddRect(ImGui.GetWindowDrawList(ctx), scrX,
                                                scrY - height - offsetY,
                                                scrX + tagW, scrY - height - offsetY + ImGui.GetTextLineHeight(ctx),
                                                app.gui.st.basecolors.mainBright,
                                                app.gui.st.vars.tag[ImGui.StyleVar_FrameRounding][1],
                                                nil, 1.5 * app.gui.scale)
                                            if ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Left) then
                                                for i, result in ipairs(app.selection:results()) do
                                                    if remove then
                                                        result:removeTag(tag, false)
                                                    else
                                                        result:addTag(tag, false)
                                                    end
                                                end
                                                app.userdata:save()
                                                app.flow.filterResults(nil, true)
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
                                local triangleW = tag.hasDescendants and
                                    app.gui.st.vars.tagList[ImGui.StyleVar_IndentSpacing]
                                    [1] or 0
                                -- local triangleW = tag.hasDescendants and triangleW or 0
                                local tagName = (app.temp.tagRename == tag.id) and app.temp.tagRenameBuffer or tag.name
                                local tagNameWidth = ImGui.CalcTextSize(ctx, tagName)
                                local tagW, tagH = tagNameWidth + paddingX * 2 + triangleW,
                                    ImGui.GetTextLineHeight(ctx) + paddingY * 2
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
                                    app:setHint('main', (T.HINTS.TAG_DEFAULT):format(tag.name))
                                end
                                if ImGui.BeginPopup(ctx, 'Tag Context Menu') then
                                    app:setHint('main', '')
                                    ImGui.Text(ctx, tag.name)
                                    ImGui.Separator(ctx)
                                    if ImGui.MenuItem(ctx, 'Rename') then
                                        app.temp.tagRename = tag.id
                                        app.temp.tagRenameBuffer = tag.name
                                    end
                                    app:setHoveredHint('main', T.HINTS.TAG_CONTEXT_MENU_RENAME)
                                    if ImGui.MenuItem(ctx, 'Create Nested Tag') then
                                        tag:toggleOpen(true)
                                        local newTag = app.userdata:createTag('New Tag', tag)
                                        app.temp.tagRename = newTag.id
                                        app.temp.tagRenameBuffer = newTag.name
                                    end
                                    app:setHoveredHint('main',
                                        (T.HINTS.TAG_CONTEXT_MENU_CREATE_NESTED_TAG):format(tag.name))
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
                                    app:setHoveredHint('main', (T.HINTS.TAG_CONTEXT_MENU_DELETE):format(tag.name))

                                    ImGui.EndPopup(ctx)
                                end
                                -- end
                                if app.temp.tagRename ~= tag.id and (hovering or tagStatus ~= nil) then
                                    local iconsWidth = 0
                                    if hovering and tagStatus == nil then
                                        iconsWidth = iconsWidth + app.guiHelpers.calcTinyIconSize(ctx, ICONS.MINUS) +
                                            app.guiHelpers.calcTinyIconSize(ctx, ICONS.PLUS)
                                        tagW = tagW + spacingX * 3
                                    elseif tagStatus ~= nil then
                                        iconsWidth = iconsWidth +
                                            (tagStatus ~= nil and app.guiHelpers.calcTinyIconSize(ctx, ICONS.CLOSE) or 0)
                                        tagW = tagW + spacingX * 2
                                    end
                                    tagW = tagW + iconsWidth
                                end

                                ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), globalX, globalY,
                                    globalX + tagW,
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
                                            cx - triH / 3, cy - triW / 2 + .5 * app.gui.scale,
                                            cx - triH / 3, cy + triW / 2 - .5 * app.gui.scale,
                                            cx + triH * 2 / 3 - app.gui.scale, cy,
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
                                    -- app.temp.ignoreEscapeKey = true
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
                                        -- app.temp.ignoreEscapeKey = nil
                                    end
                                else
                                    ImGui.Text(ctx, tag.name)
                                end
                                if app.temp.tagRename ~= tag.id and (hovering or tagStatus ~= nil) then
                                    ImGui.PushID(ctx, 'tagEditButtons')
                                    if tagStatus ~= nil then
                                        ImGui.SameLine(ctx)
                                        ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + spacingX)
                                        if app.guiHelpers.tinyIcon(ctx, 'removeTag', hovering and ICONS.CLOSE or (tagStatus and ICONS.PLUS or ICONS.MINUS), nil, nil, (T.HINTS.TAG_REMOVE):format(tag.name)) then
                                            app.flow.filterResults({ removeTags = { tag.id } })
                                        end
                                    elseif hovering then
                                        ImGui.SameLine(ctx)
                                        ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + spacingX)
                                        if app.guiHelpers.tinyIcon(ctx, 'addPositiveTag', ICONS.PLUS, nil, nil, (T.HINTS.TAG_POSITIVE):format(tag.name)) then
                                            app.flow.filterResults({ addTags = { [tag.id] = true } })
                                        end
                                        ImGui.SameLine(ctx)
                                        ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + spacingX)
                                        if app.guiHelpers.tinyIcon(ctx, 'addNegative', ICONS.MINUS, nil, nil, (T.HINTS.TAG_NEGATIVE):format(tag.name)) then
                                            app.flow.filterResults({ addTags = { [tag.id] = false } })
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
                                    app:setHint('main', T.HINTS.DRAG_TAG_DEFAULT)
                                    ImGui.Text(ctx, tag.name)
                                    ImGui.EndDragDropSource(ctx)
                                end

                                if not dragged then
                                    local open = (tag.hasDescendants and tag.open)
                                    drawDropTarget(tag, tagH + (open and spacingY or 0), 'inside',
                                        (open and 0 or spacingY),
                                        spacingY)
                                end
                                ImGui.PopFont(ctx)


                                if tag.hasDescendants and tag.open then
                                    ImGui.Spacing(ctx)
                                    drawTagsOfParent(tag.id, true, dragged)
                                elseif not dragged then
                                    drawDropTarget(tag, spacingY, 'after', 0, spacingY)
                                    ImGui.Spacing(ctx)
                                else
                                    ImGui.Spacing(ctx)
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
                            for id, tag in OD_PairsByOrder(app.engine.tags) do
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
                                if OD_TableLength(menuInfo.items) > 0 then
                                    ImGui.PushID(ctx, menuId .. '/' .. k)
                                    if k ~= FILTER_TYPES.PRESET or (k == FILTER_TYPES.PRESET and OD_Tablelength(app.engine.presets) > 0) then
                                        if ImGui.BeginMenu(ctx, T.FILTER_NAMES[k] .. '##filterMenu') then
                                            app:setHint('main', '')
                                            -- Special handling for Presets menu
                                            if k == FILTER_TYPES.PRESET then
                                                -- "Save Preset..." - only show when filters are active
                                                local hasActiveFilters = false
                                                if app.temp.filter then
                                                    -- Check if any filters are active
                                                    for filterKey, filterValue in pairs(app.temp.filter) do
                                                        if filterKey == 'tags' then
                                                            if OD_Tablelength(filterValue) > 0 then
                                                                hasActiveFilters = true
                                                                break
                                                            end
                                                        elseif filterKey ~= 'text' and filterValue ~= nil and filterValue ~= '' then
                                                            hasActiveFilters = true
                                                            break
                                                        end
                                                    end
                                                end

                                                -- "Edit Preset >" - show submenu with all presets
                                                if ImGui.BeginMenu(ctx, 'Edit Preset...##editPreset') then
                                                    for presetId, preset in OD_PairsByOrder(app.engine.presets) do
                                                        if ImGui.MenuItem(ctx, preset.name .. '##editPreset_' .. presetId) then
                                                            app.temp.showCreatePresetDialog = true
                                                            app.temp.presetName = preset.name
                                                            app.temp.presetWord = preset.word
                                                            app.temp.editingPresetId = presetId
                                                            app.temp.originalPresetFilter = preset
                                                                .filter -- Store original filter
                                                        end
                                                        app:setHoveredHint('main',
                                                            (T.HINTS.EDIT_PRESET_DEFAULT):format(preset.name))
                                                    end
                                                    ImGui.EndMenu(ctx)
                                                end

                                                ImGui.Separator(ctx)
                                            end

                                            for item, value in OD_PairsByOrder(menuInfo.items) do
                                                if value.submenu then
                                                    drawFilterMenu({ [item] = value.submenu }, menuId .. '-' .. item)
                                                elseif value.query then
                                                    local selected = true
                                                    for k, v in pairs(value.query) do
                                                        if app.temp.filter[k] ~= value.query[k] then
                                                            selected = false
                                                        end
                                                    end
                                                    if ImGui.MenuItem(ctx, item, value.shortcut, selected) then
                                                        app.flow.filterResults(value.query)
                                                    end
                                                    if ImGui.IsItemHovered(ctx) then
                                                        if k == FILTER_TYPES.PRESET then
                                                            if value.shortcut then
                                                                app:setHint('main',
                                                                    (T.HINTS.PRESET_WITH_WORD_DEFAULT):format(item,
                                                                        value.shortcut))
                                                            else
                                                                app:setHint('main', (T.HINTS.PRESET_DEFAULT):format(item))
                                                            end
                                                        elseif k == FILTER_TYPES.OTHER then
                                                            app:setHint('main', T.HINTS.OTHER_FILTERS[item])
                                                        else
                                                            app:setHint('main',
                                                                (T.HINTS.LOAD_FILTER_DEFAULT):format(T.FILTER_NAMES[k],
                                                                    item))
                                                        end
                                                    end
                                                end
                                            end
                                            ImGui.EndMenu(ctx)
                                        end
                                    end

                                    ImGui.PopID(ctx)
                                end
                            end
                        end

                        ImGui.SeparatorText(ctx, "Filters")
                        ImGui.Spacing(ctx)
                        drawFilterMenu(FILTER_MENU, 'root')

                        ImGui.SeparatorText(ctx, "Tags")
                        ImGui.SameLine(ctx)
                        ImGui.PushFont(ctx, app.gui.st.fonts.icons_small)
                        ImGui.SetCursorPosX(ctx,
                            ImGui.GetCursorPosX(ctx) + ImGui.GetContentRegionAvail(ctx) - spacingX - paddingX * 2 -
                            ImGui.CalcTextSize(ctx, ICONS.PLUS))
                        -- ImGui.AlignTextToFramePadding(ctx)
                        if ImGui.Button(ctx, ICONS.PLUS .. '##CreateTag') then
                            local newTag = app.userdata:createTag('New Tag', TAGS_ROOT_PARENT)
                            app.temp.tagRename = newTag.id
                            app.temp.tagRenameBuffer = newTag.name
                        end
                        app:setHoveredHint('main', 'Create new tag')
                        ImGui.PopFont(ctx)
                        ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - spacingY)
                        ImGui.SetNextWindowScroll(ctx, 0, -1)
                        if ImGui.BeginChild(ctx, 'TagScrollArea', sideBarW - paddingX * 2, select(2, ImGui.GetContentRegionAvail(ctx)) - spacingY) then
                            ImGui.Spacing(ctx)
                            drawTagsOfParent(TAGS_ROOT_PARENT, false, false)
                            ImGui.Dummy(ctx, 0, 0)
                            ImGui.EndChild(ctx)
                        end
                        ImGui.Dummy(ctx, 0, 0)
                        ImGui.EndChild(ctx)
                    end
                end

                if ImGui.BeginChild(ctx, 'mainArea', w - sideBarW - spacingX) then
                    drawActiveFilters()
                    drawResultsTable()
                    ImGui.EndChild(ctx)
                end
                if app.settings.current.showSideBar then
                    ImGui.SameLine(ctx)
                    drawSideBarSeparator()
                    ImGui.SameLine(ctx)
                    drawsideBar()
                end

                app.gui:popColors(app.gui.st.col.searchWindow)
                app.gui:popStyles(app.gui.st.vars.searchWindow)
            end,
            topBar = function(ctx)
                app.gui:pushStyles(app.gui.st.vars.topBar)
                app.gui:pushColors(app.gui.st.col.topBar[app.temp.searchMode])

                local menu = {}
                local paddingX, paddingY = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)
                local winPaddingX, winPaddingY = ImGui.GetStyleVar(ctx, ImGui.StyleVar_WindowPadding)
                local spacingX, spacingY = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)

                local createMenu = function()
                    local menu = {}

                    table.insert(menu,
                        { icon = 'money', hint = ('%s is free, but donations are welcome :)'):format(Scr.name) })
                    if ImGui.IsWindowDocked(ctx) then
                        table.insert(menu, { icon = 'undock', hint = 'Undock' })
                    else
                        table.insert(menu, { icon = 'dock_down', hint = 'Dock' })
                    end
                    table.insert(menu, {
                        icon = 'question',
                        hint = 'Help',
                        active = app.temp.showHelpWindow
                    })
                    table.insert(menu, {
                        icon = 'gear',
                        hint = 'Settings',
                        active = ImGui.IsPopupOpen(ctx, Scr.name .. ' Settings##settingsWindow')
                    })
                    table.insert(menu,
                        {
                            icon = 'sidebar',
                            hint = app.settings.current.showSideBar and 'Hide side bar' or
                                'Show side bar',
                            active = app.settings.current.showSideBar
                        })
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

                local handleSpecialKeys = function()
                    if not ImGui.IsPopupOpen(ctx, '', ImGui.PopupFlags_AnyPopup) and ImGui.IsWindowFocused(ctx) then
                        -- local pressed = false
                        if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
                            -- if not app.temp.ignoreEscapeKey then
                            if app.temp.searchInput == '' then
                                if app.temp.activeFilters and OD_TableLength(app.temp.activeFilters) > 0 then
                                    app.flow.filterResults({ clear = true })
                                else
                                    app.flow.close()
                                end
                            end
                        elseif ImGui.IsKeyPressed(ctx, ImGui.Key_Enter, false) then
                            if not app.temp.tagRename then
                                app.flow.executeSelectedResults(ctx, RESULT_CONTEXT.KEYBOARD)
                            end
                            -- pressed = true
                        elseif app.guiHelpers.isShortcutPressed('selectAllResults', true) then
                            app.selection:selectRange(1, #app.temp.searchResults)
                            -- pressed = true
                        elseif app.guiHelpers.isShortcutPressed('hardCloseScript', true) then
                            app.hardExit = true
                            -- pressed = true
                        elseif app.guiHelpers.isShortcutPressed('runRandomResult', true) then
                            if #app.temp.searchResults > 0 then
                                app.flow.executeRandomResult()
                            end
                            -- pressed = true
                        elseif app.temp.searchMode == SEARCH_MODE.MAIN and app.guiHelpers.isShortcutPressed('markFavorite', true) and app.selection.keyboardPos then
                            -- pressed = true
                            -- Toggle favorite status for all selected assets
                            local selectedResults = app.selection:results()
                            if #selectedResults > 0 then
                                -- Use the first selected asset to determine the action (favorite or unfavorite)
                                local firstResult = selectedResults[1]
                                local willFavorite = not firstResult.favorite

                                -- Use the batch operation for efficiency
                                local changed = firstResult:batchToggleFavorites(selectedResults, willFavorite)

                                if changed then
                                    -- Use filterResults to maintain selection on all affected assets
                                    app.flow.filterResults(nil, nil, true)
                                end
                            end
                        end
                        -- if pressed then app.guiHelpers.blockNextCharacter() end
                    end
                end
                local drawTextSearchInput = function()
                    if app.pageSwitched then
                        app.flow.filterResults({ text = '' })
                    end

                    local w = select(1, ImGui.GetContentRegionAvail(ctx)) - menuW +
                        ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)

                    ImGui.SetNextItemWidth(ctx, w)
                    local rv
                    if not ImGui.IsAnyItemActive(ctx) and not app.temp.waitingForDoubleClick and not ImGui.IsPopupOpen(ctx, '', ImGui.PopupFlags_AnyPopup) and not app.temp.tagRename and ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_RootAndChildWindows) then
                        ImGui.SetKeyboardFocusHere(ctx, 0)
                    end
                    handleSpecialKeys()
                    local callback = nil
                    local inputFlags = ImGui.InputTextFlags_EscapeClearsAll
                    if app.temp.selectSearchInputTextOnNextFrame then
                        inputFlags = inputFlags | ImGui.InputTextFlags_AutoSelectAll
                    end
                    if app.temp.clearSearchInputText then
                        inputFlags = inputFlags | ImGui.InputTextFlags_CallbackAlways
                        callback = app.gui.clearInputIfNeeded
                    end
                    rv, app.temp.searchInput = ImGui.InputTextWithHint(ctx, "##searchInput" .. app.temp.searchMode,
                        T.SEARCH_WINDOW.SEARCH_HINT[app.temp.searchMode], app.temp.searchInput,
                        inputFlags, callback)
                    if not app.temp.selectSearchInputText then -- wait 1 frame for selection to work
                        app.temp.lastSearchMode = app.temp.searchMode
                        app.temp.selectSearchInputTextOnNextFrame = nil
                    else
                        app.temp.selectSearchInputText = nil
                        app.temp.selectSearchInputTextOnNextFrame = true
                    end
                    -- handleSpecialKeys()
                    -- app.temp.blockNextCharacter = nil
                    app.temp.clearSearchInputText = nil
                    if ImGui.IsItemFocused(ctx) then
                        if ImGui.IsKeyReleased(ctx, ImGui.Key_Tab) then
                            if app.temp.searchMode == SEARCH_MODE.MAIN then
                                app.flow.setSearchMode(SEARCH_MODE.FILTERS)
                            else
                                app.flow.setSearchMode(SEARCH_MODE.MAIN)
                            end
                        end
                    end
                    if rv then
                        -- if app.temp.searchMode == SEARCH_MODE.MAIN then
                        local wordKey, wordAction = app.temp.searchInput:upper():match('(.+)([%s%?])$')
                        local wordFilter = app.engine.magicWords[wordKey]
                        if wordFilter then
                            app.flow.filterResults(wordFilter)
                            if wordAction == '?' then app.flow.executeRandomResult() end
                            app.guiHelpers.clearSearchInputText()
                        else
                            app.flow.filterResults({ text = app.temp.searchInput })
                        end
                        -- -- else
                        -- --     app.flow.filterResults({ text = app.temp.searchInput })
                        -- end
                    end
                end
                local drawIconMenu = function(ctx, buttons)
                    ImGui.PushFont(ctx, app.gui.st.fonts.icons_large)
                    local clicked = nil
                    for i, btn in ipairs(buttons) do
                        local col = btn.active and app.gui.st.col.buttons.topBarActiveIcon or
                            app.gui.st.col.buttons.topBarIcon
                        if app.guiHelpers.iconButton(ctx, btn.icon, col, btn.hint) then
                            clicked = btn
                                .icon
                        end
                    end
                    ImGui.PopFont(ctx)
                    return clicked ~= nil, clicked
                end
                local drawLogo = function()
                    local col
                    if ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_RootAndChildWindows) then
                        col = app.gui.st.col.title[ImGui.Col_Text]
                    else
                        col = app.gui.st.col.titleUnfocused[ImGui.Col_Text]
                    end
                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, col)
                    ImGui.PushFont(ctx, app.gui.st.fonts.icons_small)
                    ImGui.AlignTextToFramePadding(ctx)
                    ImGui.Text(ctx, ICONS.SEARCH)
                    ImGui.PopFont(ctx)
                    ImGui.SameLine(ctx)
                    ImGui.PushFont(ctx, app.gui.st.fonts.large)
                    ImGui.AlignTextToFramePadding(ctx)
                    ImGui.Text(ctx, app.scr.name)
                    app:setHoveredHint('main', app.scr.name .. ' v' .. app.scr.version .. ' by ' .. app.scr.author)
                    ImGui.PopStyleColor(ctx)
                    ImGui.SameLine(ctx)
                    local x, y = ImGui.GetCursorScreenPos(ctx)
                    local width = 2 * app.gui.scale
                    ImGui.DrawList_AddLine(ImGui.GetWindowDrawList(ctx), x + width / 2, y - paddingY, x + width / 2,
                        y + h - paddingY * 2 - winPaddingY, col, width)
                    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + width + spacingX)
                end
                local function handleMenuButtons(rv, btn)
                    if rv then
                        if btn == 'close' then
                            -- app.exit = true
                        elseif btn == 'undock' then
                            app.gui.mainWindow.dockTo = 0
                        elseif btn == 'dock_down' then
                            if app.settings.current.lastDockId then
                                app.gui.mainWindow.dockTo = app.settings.current.lastDockId
                            else
                                app:msg(T.ERROR.NO_DOCK)
                            end
                        elseif btn == 'question' then
                            app.temp.showHelpWindow = app.temp.showHelpWindow == nil and true or nil
                        elseif btn == 'gear' then
                            ImGui.OpenPopup(ctx, Scr.name .. ' Settings##settingsWindow')
                        elseif btn == 'sidebar' then
                            app.settings.current.showSideBar = not app.settings.current.showSideBar
                            app.settings:save()
                        elseif btn == 'money' then
                            OD_OpenLink(Scr.donation)
                        end
                    end
                end
                if ImGui.BeginChild(ctx, 'topBar', nil, h, ImGui.ChildFlags_AlwaysUseWindowPadding, ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse) then
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
                app.gui:popColors(app.gui.st.col.topBar[app.temp.searchMode])
                app.gui:popStyles(app.gui.st.vars.topBar)
            end,
            settings = function(ctx)
                app.gui:pushStyles(app.gui.st.vars.popupsTitle)
                -- local numOfPreferences = 14
                -- local numOfSeparators = 5
                -- local numOfAssetTypes = #app.engine.assetTypeManager.assetTypes + 2
                -- local lineHeightWithSpacing = ImGui.GetTextLineHeightWithSpacing(ctx)
                local lineHeight = ImGui.GetTextLineHeight(ctx)
                local paddingX, paddingY = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)
                -- local spacingX, spacingY = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
                local w = 730 * app.gui.scale
                local h = 890 * app.gui.scale + #app.settings.current.projectScanFolders * (lineHeight + paddingY)
                -- local h = select(2, ImGui.GetStyleVar(ctx, ImGui.StyleVar_WindowPadding)) * 2
                -- h = h + select(2, ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)) + lineHeight
                -- h = h + (numOfPreferences + numOfSeparators + #app.settings.current.projectScanFolders) *
                --     (lineHeight+paddingY)
                -- h = h + numOfAssetTypes * lineHeightWithSpacing + spacingY * 2
                -- h = h + app.gui.st.sizes.hintHeight
                local maxH = app.gui.screen.size[2] * .9
                -- since sometimes we need to capture Escape, we need to make sure it doesn't trigger
                -- closing this window. So we increment a counter which will be reset if the shortcut is
                -- being captured, so that we can know to ignore the captured key unless some frames have passed.
                app.temp.captureCounter = app.temp.captureCounter and app.temp.captureCounter + 1 or 0
                ImGui.SetNextWindowSize(ctx, w, h)
                ImGui.SetNextWindowSizeConstraints(ctx, w, 0.0, w, maxH)
                local shouldScroll = true
                if maxH > h then shouldScroll = false end
                -- end
                -- ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0)
                local visible, open = ImGui.BeginPopupModal(ctx, Scr.name .. ' Settings##settingsWindow', true,
                    ImGui.WindowFlags_NoDocking | ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse |
                    ImGui.WindowFlags_NoResize)
                -- ImGui.PopStyleVar(ctx, 1)
                app.gui:popStyles(app.gui.st.vars.popupsTitle)

                if visible then
                    local w = w - ImGui.GetStyleVar(ctx, ImGui.StyleVar_WindowPadding) * 2
                    if ImGui.BeginChild(ctx, 'SettingsMainArea', w, -app.gui.st.sizes.hintHeight) then --math.min(500*app.gui.scale, h - hintHeight)) then
                        if ImGui.IsWindowAppearing(ctx) then
                            app.temp.groupOrder = {}
                            app.temp.groupVisibility = {}
                            for i, group in ipairs(app.settings.current.groupOrder) do
                                table.insert(app.temp.groupOrder, app.engine.assetGroupNameCache[group])
                                app.temp.groupVisibility[app.engine.assetGroupNameCache[group]] = app.settings
                                    .current.groupVisibility[group]
                            end
                        end
                        app.temp.settingsWindowOpen = true
                        ImGui.SeparatorText(ctx, 'General')
                        app.settings.current.uiScale = app.gui:setting('dragdouble', T.SETTINGS.UI_SCALE.LABEL,
                                T.SETTINGS.UI_SCALE.HINT,
                                app.settings.current.uiScale * 100,
                                {
                                    default = app.settings.default.uiScale * 100,
                                    min = 50,
                                    max = 200,
                                    speed = 1,
                                    format =
                                    '%.f%%',
                                    dontUnpdateWhileEnteringManually = true,
                                    flags = (ImGui.SliderFlags_AlwaysClamp)
                                }) /
                            100
                        app.settings.current.closeAfterExecute = not app.gui:setting('checkbox',
                            T.SETTINGS.CLOSE_AFTER_EXECUTE.LABEL,
                            T.SETTINGS.CLOSE_AFTER_EXECUTE.HINT, not app.settings.current.closeAfterExecute)
                        app.settings.current.sleepMode = app.gui:setting('checkbox',
                            T.SETTINGS.SLEEP_MODE.LABEL,
                            T.SETTINGS.SLEEP_MODE.HINT, app.settings.current.sleepMode,
                            { help = T.SLEEP_MODE_EXPLANATION })
                        ImGui.SeparatorText(ctx, 'Shortcuts')
                        local resetCounter = false
                        local key = app.settings.current.sleepMode and T.SETTINGS.SHORTCUTS.ENTER_SLEEP_MODE or
                            T.SETTINGS.SHORTCUTS.CLOSE_SCRIPT
                        app.settings.current.shortcuts.closeScript, resetCounter = app.gui:setting('shortcut',
                            key.LABEL,
                            key.HINT, app.settings.current.shortcuts.closeScript,
                            {
                                existingShortcuts = OD_TableFilter(app.settings.current.shortcuts,
                                    function(k, v) return k ~= 'closeScript' end)
                            })
                        if resetCounter then app.temp.captureCounter = 0 end
                        if app.settings.current.sleepMode then
                            app.settings.current.shortcuts.hardCloseScript, resetCounter = app.gui:setting('shortcut',
                                T.SETTINGS.SHORTCUTS.HARD_CLOSE_SCRIPT.LABEL,
                                T.SETTINGS.SHORTCUTS.HARD_CLOSE_SCRIPT.HINT,
                                app.settings.current.shortcuts.hardCloseScript,
                                {
                                    existingShortcuts = OD_TableFilter(app.settings.current.shortcuts,
                                        function(k, v) return k ~= 'hardCloseScript' end)
                                })
                            if resetCounter then app.temp.captureCounter = 0 end
                        end
                        app.settings.current.shortcuts.markFavorite, resetCounter = app.gui:setting('shortcut',
                            T.SETTINGS.SHORTCUTS.MARK_FAVORITE.LABEL,
                            T.SETTINGS.SHORTCUTS.MARK_FAVORITE.HINT, app.settings.current.shortcuts.markFavorite,
                            {
                                existingShortcuts = OD_TableFilter(app.settings.current.shortcuts,
                                    function(k, v) return k ~= 'markFavorite' end)
                            })
                        app.settings.current.shortcuts.runRandomResult, resetCounter = app.gui:setting('shortcut',
                            T.SETTINGS.SHORTCUTS.RANDOM_RESULT.LABEL,
                            T.SETTINGS.SHORTCUTS.RANDOM_RESULT.HINT, app.settings.current.shortcuts.runRandomResult,
                            {
                                existingShortcuts = OD_TableFilter(app.settings.current.shortcuts,
                                    function(k, v) return k ~= 'runRandomResult' end)
                            })
                        if resetCounter then app.temp.captureCounter = 0 end
                        ImGui.SeparatorText(ctx, 'Ordering')

                        app.settings.current.showOnlyHighestPriorityPlugin = app.gui:setting('checkbox',
                            T.SETTINGS.SHOW_ONLY_HIGHEST_PRIORITY_FX.LABEL, T.SETTINGS.SHOW_ONLY_HIGHEST_PRIORITY_FX
                            .HINT, app.settings.current.showOnlyHighestPriorityPlugin)
                        app.temp.groupOrder, app.temp.groupVisibility = app.gui:setting(
                            'orderable_list',
                            T.SETTINGS.GROUP_ORDER.LABEL, T.SETTINGS.GROUP_ORDER.HINT,
                            { app.temp.groupOrder, app.temp.groupVisibility }, { divideWidth = 2 })

                        app.settings.current.fxTypeOrder, app.settings.current.fxTypeVisibility = app.gui:setting(
                            'orderable_list',
                            'FXTypeOrder', T.SETTINGS.FX_TYPE_ORDER.HINT,
                            { app.settings.current.fxTypeOrder, app.settings.current.fxTypeVisibility }, {}, true)


                        ImGui.SeparatorText(ctx, 'Item specific settings')
                        app.settings.current.recentlyAddedDays = app.gui:setting('dragdouble',
                            T.SETTINGS.RECENTLY_ADDED_DAYS.LABEL,
                            T.SETTINGS.RECENTLY_ADDED_DAYS.HINT, app.settings.current.recentlyAddedDays,
                            {
                                speed = 1,
                                min = 1,
                                max = 60,
                                format = "%.0f",
                                help = T.RECENTLY_ADDED_EXPLANATION
                            })
                        app.settings.current.showFxUI = app.gui:setting(
                            'combo',
                            T.SETTINGS.SHOW_FX_UI.LABEL,
                            T.SETTINGS.SHOW_FX_UI.HINT,
                            app.settings.current.showFxUI, {
                                list = T.SHOW_FX_UI_LIST
                            })
                        app.settings.current.addInstrumentsAsInstrumentTracks = app.gui:setting(
                            'checkbox',
                            T.SETTINGS.USE_VIRTUAL_INSTRUMENT_TRACKS.LABEL,
                            T.SETTINGS.USE_VIRTUAL_INSTRUMENT_TRACKS.HINT,
                            app.settings.current.addInstrumentsAsInstrumentTracks
                        )
                        app.settings.current.createSendsInsideFolder = app.gui:setting('checkbox',
                            T.SETTINGS.CREATE_INSIDE_FODLER.LABEL,
                            T.SETTINGS.CREATE_INSIDE_FODLER.HINT, app.settings.current.createSendsInsideFolder)
                        if app.settings.current.createSendsInsideFolder then
                            app.settings.current.sendFolderName = app.gui:setting('text_with_hint', '###sendFolderName',
                                T.SETTINGS.SEND_FOLDER_NAME.HINT, app.settings.current.sendFolderName,
                                { hint = T.SETTINGS.SEND_FOLDER_NAME.LABEL }, true)
                        end


                        local removePath = nil
                        local path = app.gui:setting('folder', T.SETTINGS.PROJECT_SCAN_FOLDER.LABEL,
                            T.SETTINGS.PROJECT_SCAN_FOLDER.HINT, nil,
                            { label = T.SETTINGS.PROJECT_SCAN_FOLDER.LABEL_BUTTON })
                        if path then
                            if not OD_HasValue(app.settings.current.projectScanFolders, path) then
                                table.insert(app.settings.current.projectScanFolders, path)
                            end
                        end
                        for i, path in ipairs(app.settings.current.projectScanFolders) do
                            if app.gui:setting('button', nil, T.SETTINGS.PROJECT_SCAN_FOLDER.HINT_DELETE, nil, { label = 'X##' .. i, width = ImGui.CalcTextSize(ctx, 'X') + ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding) * 2 }) then
                                removePath = i
                            end
                            ImGui.SameLine(ctx)
                            local tooLong = ImGui.CalcTextSize(ctx, path) > ImGui.GetContentRegionAvail(ctx)
                            if ImGui.BeginChild(ctx, 'path' .. i, ImGui.GetContentRegionAvail(ctx), ImGui.GetTextLineHeightWithSpacing(ctx), nil, ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoMouseInputs) then
                                ImGui.AlignTextToFramePadding(ctx)

                                ImGui.Text(ctx, path)
                                ImGui.EndChild(ctx)
                            end
                            app:setHoveredHint('settings', path)
                            -- if tooLong and ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_ForTooltip) then
                            --     ImGui.SetTooltip(ctx, path)
                            -- end
                            -- path = app.gui:setting('folder', path,T.SETTINGS.PROJECT_SCAN_FOLDER.HINT, path, {}, true)
                        end
                        if removePath then
                            table.remove(app.settings.current.projectScanFolders, removePath)
                            removePath = nil
                        end

                        ImGui.SeparatorText(ctx, 'Tags, Presets and Favorites')

                        -- Export button
                        if app.gui:setting('button', T.SETTINGS.EXPORT_TAGS.LABEL, T.SETTINGS.EXPORT_TAGS.HINT, nil, { label = T.SETTINGS.EXPORT_TAGS.BUTTON_LABEL, divideWidth = 2 }) then
                            local rv, filename = r.JS_Dialog_BrowseForSaveFile(
                                'Export Tags, Presets and Favorites', '',
                                '',
                                'Scout Tags files (*.scout)\0*.scout\0\0')
                            if rv == 1 and filename then
                                local success, errorMsg = app.userdata:export(filename)
                                if success then
                                    app:msg('Export successful: ' .. filename)
                                else
                                    app:msg('Export failed: ' .. (errorMsg or 'Unknown error'), 'error')
                                end
                            end
                        end
                        -- app:setHoveredHint('settings', T.SETTINGS.EXPORT_TAGS.HINT)

                        -- Import button
                        local overwriteMode = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)
                        local importButtonText = overwriteMode and T.SETTINGS.IMPORT_TAGS.BUTTON_LABEL or
                            T.SETTINGS.IMPORT_TAGS.BUTTON_LABEL_MERGE
                        if app.gui:setting('button', T.SETTINGS.IMPORT_TAGS.LABEL, T.SETTINGS.IMPORT_TAGS.HINT, nil, { label = importButtonText }, true) then
                            local rv, filename = r.GetUserFileNameForRead('',
                                'Import Tags, Presets and Favorites',
                                'scout')
                            if rv and filename then
                                local success, skippedAssets, mappedCount, skippedCount = app.userdata:import(filename,
                                    not overwriteMode)
                                if success then
                                    local msg = string.format('Import successful: %d assets mapped, %d assets skipped',
                                        mappedCount or 0, skippedCount or 0)
                                    if overwriteMode then
                                        msg = msg .. ' (existing data overwritten)'
                                    end
                                    app:msg(msg)
                                else
                                    app:msg('Import failed: ' .. (skippedAssets or 'Unknown error'), 'error')
                                end
                            end
                        end
                        app:setHoveredHint('settings', T.SETTINGS.IMPORT_TAGS.HINT)
                        ImGui.EndChild(ctx)
                    end
                    app.draw.hint(ctx, 'settings')
                    if app.temp.captureCounter > 3 and ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
                        ImGui.CloseCurrentPopup(ctx)
                    else
                        OD_ReleaseGlobalKeys()
                    end
                    ImGui.EndPopup(ctx)
                else
                    app.temp._capturing = false
                end
                if app.temp.settingsWindowOpen and not (open or ImGui.IsPopupOpen(ctx, Scr.name .. ' Settings##settingsWindow')) then
                    app.temp.settingsWindowOpen = nil
                    OD_ReleaseGlobalKeys()

                    -- Convert temp group order and visibility back to settings format
                    if app.temp.groupOrder and app.temp.groupVisibility then
                        app.settings.current.groupOrder = {}
                        app.settings.current.groupVisibility = {}
                        for i, groupName in ipairs(app.temp.groupOrder) do
                            -- Find the group ID by name
                            for groupId, cachedName in pairs(app.engine.assetGroupNameCache) do
                                if cachedName == groupName then
                                    table.insert(app.settings.current.groupOrder, groupId)
                                    app.settings.current.groupVisibility[groupId] = app.temp.groupVisibility[groupName]
                                    break
                                end
                            end
                        end
                    end

                    app.settings:save()
                    app.engine:init(true)
                    -- app.engine:assembleAssets(true)
                    -- app.engine:updateFilterMenus()
                    -- app.engine:assembleFilterAssets()
                    app.flow.filterResults()
                end
            end,
            help = function(ctx)
                if app.temp.showHelpWindow then
                    -- FIXME: Window should resize when changing zoom?
                    local w = 810 * app.gui.scale
                    local h = 530 * app.gui.scale
                    local maxH = app.gui.screen.size[2] * .8
                    -- since sometimes we need to capture Escape, we need to make sure it doesn't trigger
                    -- closing this window. So we increment a counter which will be reset if the shortcut is
                    -- being captured, so that we can know to ignore the captured key unless some frames have passed.
                    ImGui.SetNextWindowSize(ctx, w, h, ImGui.Cond_Appearing)
                    -- ImGui.SetNextWindowPos(ctx, app.gui.screen.size[1] / 2, app.gui.screen.size[2] / 2,
                    --     ImGui.Cond_Appearing,
                    --     0.5,
                    --     0.5)
                    ImGui.SetNextWindowSizeConstraints(ctx, w * .7, 0.0, FLT_MAX, maxH)
                    app.gui:pushStyles(app.gui.st.vars.popupsTitle)
                    local visible, open = ImGui.Begin(ctx, Scr.name .. ' Help##helpWindow', true,
                        ImGui.WindowFlags_NoDocking |
                        ImGui.WindowFlags_NoNav |
                        ImGui.WindowFlags_NoCollapse)
                    -- ImGui.WindowFlags_NoFocusOnAppearing)
                    app.gui:popStyles(app.gui.st.vars.popupsTitle)

                    if visible then
                        if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) and ImGui.IsWindowFocused(ctx) then
                            app.temp.showHelpWindow = nil
                        end
                        if ImGui.BeginChild(ctx, '##help') then
                            if ImGui.BeginTabBar(ctx, 'Help Bar') then
                                local tabFlags = ImGui.TabItemFlags_None
                                if ImGui.IsWindowAppearing(ctx) then
                                    tabFlags = tabFlags | ImGui.TabItemFlags_SetSelected
                                end
                                if ImGui.BeginTabItem(ctx, 'Key Commands', false, tabFlags) then
                                    for i, group in ipairs(app.settings.current.groupOrder) do
                                        if group ~= SPECIAL_GROUPS.RECENTS and group ~= SPECIAL_GROUPS.FAVORITES then
                                            ImGui.PushID(ctx, i)
                                            if ImGui.CollapsingHeader(ctx, app.engine.assetGroupNameCache[group], false, ImGui.TreeNodeFlags_DefaultOpen | ImGui.Cond_Appearing) then
                                                if ImGui.BeginTable(ctx, "keyCommands", 2, nil, 0) then
                                                    ImGui.TableSetupColumn(ctx, 'Key Commands',
                                                        ImGui.TableColumnFlags_WidthFixed, 210 * app.gui.scale)
                                                    ImGui.TableSetupColumn(ctx, 'Description',
                                                        ImGui.TableColumnFlags_WidthStretch)
                                                    for keymod, hint in OD_PairsByOrder(_G[group].interactionHints) do
                                                        ImGui.TableNextRow(ctx)
                                                        ImGui.TableNextColumn(ctx)
                                                        local description = hint.text
                                                        local mod = keymod == 0 and 'Click' or
                                                            app.guiHelpers.keyModsToText(keymod |
                                                                RESULT_CONTEXT.MOUSE_CLICK)
                                                        local assetType = app.engine.assetTypeManager
                                                            :getAssetTypeByClassName(group)

                                                        local text = BaseAssetType:parseInteractionHintTemplate(
                                                                description,
                                                                -1, nil,
                                                                assetType.name,
                                                                (assetType.allowMultiple and (assetType.group):gsub('s$', '(s)'):lower() or (assetType.name):lower()))
                                                            :gsub(
                                                                "^%l", string.upper)
                                                        ImGui.PushFont(ctx, app.gui.st.fonts.bold)
                                                        -- ImGui.TextWrapped(ctx, mod .. ': ')
                                                        ImGui.TextColored(ctx, app.gui.st.basecolors.mainBrightest,
                                                            mod .. ': ')
                                                        ImGui.PopFont(ctx)
                                                        ImGui.TableNextColumn(ctx)

                                                        -- ImGui.SameLine(ctx)
                                                        ImGui.TextWrapped(ctx, text)
                                                    end
                                                    ImGui.EndTable(ctx)
                                                end
                                            end
                                            ImGui.PopID(ctx)
                                        end
                                    end
                                    ImGui.EndTabItem(ctx)
                                end
                                if ImGui.BeginTabItem(ctx, 'Another Menu', false) then
                                    ImGui.EndTabItem(ctx)
                                end
                                ImGui.EndTabBar(ctx)
                            end
                            ImGui.EndChild(ctx)
                        end
                        ImGui.End(ctx)
                    end

                    if not open or not app.temp.showHelpWindow then
                        app.temp.showHelpWindow = nil
                        local scriptHwnd = r.JS_Window_Find(Scr.context_name, true) or r.JS_Window_FindTop('Scout', true)
                        if scriptHwnd then
                            r.JS_Window_SetFocus(scriptHwnd)
                        end
                    end
                end
            end,
            hint = function(ctx, window)
                local status, col = app:getHint(window)
                ImGui.Separator(ctx)
                if ImGui.BeginChild(ctx, window .. 'Hint', nil, ImGui.GetTextLineHeightWithSpacing(ctx), nil, ImGui.WindowFlags_NoScrollWithMouse) then
                    if col then app.gui:pushColors(app.gui.st.col[col]) end
                    ImGui.Spacing(ctx)
                    ImGui.Text(ctx, status)
                    if col then app.gui:popColors(app.gui.st.col[col]) end
                    ImGui.EndChild(ctx)
                end
                app:setHint(window, '')
            end,
            popup = function(ctx, id, text)
                local center = { app.gui.mainWindow.pos[1] + app.gui.mainWindow.size[1] / 2,
                    app.gui.mainWindow.pos[2] + app.gui.mainWindow.size[2] / 2 } -- {ImGui.Viewport_GetCenter(ImGui.GetMainViewport(ctx))}
                local okButtonLabel = 'Yes'
                local cancelButtonLabel = 'No'
                local okPressed = false
                local bottom_lines = 1
                local id = id or 'confirmationPopup'

                local textWidth, textHeight = ImGui.CalcTextSize(ctx, text)

                ImGui.SetNextWindowSize(ctx,
                    math.max(220, textWidth) + ImGui.GetStyleVar(ctx, ImGui.StyleVar_WindowPadding) * 4,
                    textHeight + 90 + ImGui.GetTextLineHeightWithSpacing(ctx))

                ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing, 0.5, 0.5)
                ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowTitleAlign, 0.5, 0.5)
                app.gui:pushStyles(app.gui.st.vars.popupsTitle)

                local open, visible = ImGui.BeginPopupModal(ctx, id, nil, ImGui.WindowFlags_NoResize)
                app.gui:popStyles(app.gui.st.vars.popupsTitle)

                if open then
                    local width = select(1, ImGui.GetContentRegionAvail(ctx))
                    ImGui.PushItemWidth(ctx, width)

                    local windowWidth, windowHeight = ImGui.GetWindowSize(ctx);
                    ImGui.SetCursorPos(ctx, (windowWidth - textWidth) * .5, (windowHeight - textHeight) * .5);
                    ImGui.TextWrapped(ctx, text)

                    ImGui.SetCursorPosY(ctx, ImGui.GetWindowHeight(ctx) - (ImGui.GetFrameHeight(ctx) * bottom_lines) -
                        ImGui.GetStyleVar(ctx, ImGui.StyleVar_WindowPadding))

                    local buttonTextWidth = ImGui.CalcTextSize(ctx, okButtonLabel) +
                        ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding) * 2

                    buttonTextWidth = buttonTextWidth + ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing) +
                        ImGui.CalcTextSize(ctx, cancelButtonLabel) +
                        ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding) * 2
                    ImGui.SetCursorPosX(ctx, (windowWidth - buttonTextWidth) * .5);

                    if ImGui.Button(ctx, okButtonLabel) or ImGui.Shortcut(ctx, ImGui.Key_Enter, ImGui.InputFlags_RouteFocused) then
                        okPressed = true
                        open = false
                        ImGui.CloseCurrentPopup(ctx)
                    end

                    ImGui.SameLine(ctx)
                    if ImGui.Button(ctx, cancelButtonLabel) or ImGui.Shortcut(ctx, ImGui.Key_Escape, ImGui.InputFlags_RouteFocused) then
                        app.popup.secondWarningShown = false
                        open = false
                        ImGui.CloseCurrentPopup(ctx)
                    end
                    ImGui.EndPopup(ctx)
                end
                ImGui.PopStyleVar(ctx)
                return open, okPressed
            end,

            confirmations = function(ctx)
                if app.temp.confirmMultipleResults then
                    if not ImGui.IsPopupOpen(ctx, 'Multiple search results selected') then
                        ImGui.OpenPopup(ctx, 'Multiple search results selected')
                    end
                    local open, confirm = app.draw.popup(app.gui.ctx, 'Multiple search results selected',
                        'You selected ' ..
                        app.temp.confirmMultipleResults.count .. ' items.\nAre you sure you want to continue?')
                    if confirm then
                        app.flow.executeSelectedResults(ctx, app.temp.confirmMultipleResults.resultContext,
                            app.temp.confirmMultipleResults.contextData, { multipleResults = true })
                    end
                    if not open then
                        app.temp.confirmMultipleResults = nil
                    end
                end
                if app.temp.confirmMultipleTracks or app.temp.confirmMultipleMediaItems then
                    local text = app.temp.confirmMultipleTracks and 'tracks' or 'media items'
                    local object = app.temp.confirmMultipleTracks or app.temp.confirmMultipleMediaItems
                    if not ImGui.IsPopupOpen(ctx, 'Multiple ' .. text .. ' selected') then
                        ImGui.OpenPopup(ctx, 'Multiple ' .. text .. ' selected')
                    end
                    local open, confirm = app.draw.popup(app.gui.ctx, 'Multiple ' .. text .. ' selected',
                        'There are ' ..
                        object.count .. ' ' .. text .. ' selected.\nAre you sure you want to continue?')
                    if confirm then
                        local confirmations = object.confirm or {}
                        confirmations[app.temp.confirmMultipleTracks and 'multipleTracks' or 'multipleMediaItems'] = true
                        app.flow.executeSelectedResults(ctx, object.resultContext,
                            object.contextData,
                            confirmations)
                    end
                    if not open then
                        app.temp.confirmMultipleTracks = nil
                        app.temp.confirmMultipleMediaItems = nil
                    end
                end
            end,
            welcomeDialog = function(ctx)
                if not app.settings.current.welcomeScreenShown then
                    local title = 'Welcome to ' .. Scr.name
                    if not ImGui.IsPopupOpen(ctx, title) then
                        ImGui.OpenPopup(ctx, title)
                    end
                    local open, confirm = app.draw.popup(app.gui.ctx, title,
                        T.SLEEP_MODE_EXPLANATION .. '\n\n' .. T.TURN_ON_SLEEP_MODE)
                    if confirm then
                        app.settings.current.sleepMode = true
                        app.settings.current.welcomeScreenShown = true
                        app.settings:save()
                    elseif not open then
                        app.settings.current.sleepMode = false
                        app.settings.current.welcomeScreenShown = true
                        app.settings:save()
                    end
                end
            end,
            createPresetDialog = function(ctx)
                if app.temp.showCreatePresetDialog then
                    local isEditing = app.temp.editingPresetId ~= nil
                    local title = isEditing and 'Edit Preset' or 'Create Preset'
                    if not ImGui.IsPopupOpen(ctx, title) then
                        ImGui.OpenPopup(ctx, title)
                        if not app.temp.presetName then
                            app.temp.presetName = ""
                        end
                        if not app.temp.presetWord then
                            app.temp.presetWord = ""
                        end
                    end

                    ImGui.SetNextWindowSize(ctx, 350 * app.gui.scale, 0, ImGui.Cond_Always)
                    ImGui.SetNextWindowPos(ctx, app.gui.mainWindow.pos[1] + (app.gui.mainWindow.size[1] / 2),
                        app.gui.mainWindow.pos[2] + (app.gui.mainWindow.size[2] / 2), ImGui.Cond_Appearing, 0.5, 0.5)
                    app.gui:pushStyles(app.gui.st.vars.popupsTitle)

                    local visible, open = ImGui.BeginPopupModal(ctx, title, true,
                        ImGui.WindowFlags_AlwaysAutoResize)
                    app.gui:popStyles(app.gui.st.vars.popupsTitle)

                    if visible then
                        if ImGui.IsWindowAppearing(ctx) then
                            ImGui.SetKeyboardFocusHere(ctx, 0)
                        end
                        app.temp.presetName = app.gui:setting('text', T.EDIT_PRESET_DIALOG.PRESET_NAME.LABEL,
                            T.EDIT_PRESET_DIALOG.PRESET_NAME.HINT, app.temp.presetName,
                            { hintWindow = 'editFilterWindow' })
                        local trimmedName = OD_Trim(app.temp.presetName)
                        local canSavePreset = trimmedName ~= ""
                        local errorMessage = ""

                        app.temp.presetWord = app.gui:setting('text', T.EDIT_PRESET_DIALOG.PRESET_WORD.LABEL,
                            T.EDIT_PRESET_DIALOG.PRESET_WORD.HINT, app.temp.presetWord,
                            { hintWindow = 'editFilterWindow' })

                        local trimmedMagicWord = OD_Trim(app.temp.presetWord)


                        if canSavePreset then
                            -- Check for duplicate name (excluding self when editing)
                            for presetId, preset in pairs(app.engine.presets) do
                                if preset.name:lower() == trimmedName:lower() and presetId ~= app.temp.editingPresetId then
                                    canSavePreset = false
                                    errorMessage = "A preset with this name exists"
                                    break
                                end

                                if preset.word ~= nil and preset.word ~= '' and (preset.word or ''):lower() == trimmedMagicWord:lower() and presetId ~= app.temp.editingPresetId then
                                    canSavePreset = false
                                    errorMessage = "A preset with this word exists"
                                    break
                                end
                            end
                        end
                        -- Show error message if any
                        if errorMessage ~= "" then
                            app:setHint('editFilterWindow', errorMessage, 'hintError')
                        end

                        -- Buttons
                        if not canSavePreset then
                            ImGui.BeginDisabled(ctx)
                        end

                        if (ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) and canSavePreset) or app.gui:setting('button', T.EDIT_PRESET_DIALOG.SAVE_PRESET.LABEL,
                                T.EDIT_PRESET_DIALOG.SAVE_PRESET.HINT, nil,
                                { label = isEditing and T.EDIT_PRESET_DIALOG.SAVE_PRESET.BUTTON_EDIT or T.EDIT_PRESET_DIALOG.SAVE_PRESET.BUTTON_CREATE, hintWindow = 'editFilterWindow' }) then
                            -- Create new preset - use current active filters
                            if not isEditing then
                                local preset = app.userdata:createPreset(trimmedName, app.temp.filter, trimmedMagicWord)
                                if preset then
                                    app.logger:logInfo('Created preset "' .. preset.name .. '"')
                                end
                            else
                                local preset = app.userdata:updatePreset(app.temp.editingPresetId, trimmedName,
                                    app.temp.originalPresetFilter, trimmedMagicWord)
                                if preset then
                                    app.logger:logInfo('Updated preset "' .. preset.name .. '"')
                                end
                            end
                            app.temp.showCreatePresetDialog = false
                            ImGui.CloseCurrentPopup(ctx)
                        end

                        if not canSavePreset then
                            ImGui.EndDisabled(ctx)
                        end

                        if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) or app.gui:setting('button', T.EDIT_PRESET_DIALOG.CLOSE.LABEL,
                                T.EDIT_PRESET_DIALOG.CLOSE.HINT, nil,
                                { label = T.EDIT_PRESET_DIALOG.CLOSE.BUTTON, hintWindow = 'editFilterWindow' }) then
                            app.temp.showCreatePresetDialog = false
                            ImGui.CloseCurrentPopup(ctx)
                        end

                        -- Delete button (only when editing)
                        if isEditing then
                            app.gui:pushColors(app.gui.st.col.buttons.deletePreset)
                            if app.gui:setting('button', T.EDIT_PRESET_DIALOG.DELETE.LABEL,
                                    T.EDIT_PRESET_DIALOG.DELETE.HINT, nil,
                                    { label = T.EDIT_PRESET_DIALOG.DELETE.BUTTON, hintWindow = 'editFilterWindow' }) then
                                local preset = app.engine.presets[app.temp.editingPresetId]
                                if preset then
                                    app.userdata:deletePreset(app.temp.editingPresetId)
                                    app.logger:logInfo('Deleted preset "' .. preset.name .. '"')
                                end
                                app.temp.showCreatePresetDialog = false
                                ImGui.CloseCurrentPopup(ctx)
                            end
                            app.gui:popColors(app.gui.st.col.buttons.deletePreset)
                        end

                        app.draw.hint(ctx, 'editFilterWindow')
                        -- hintWindow = 'editFilterWindow'
                        ImGui.EndPopup(ctx)
                    end

                    if not open then
                        app.temp.showCreatePresetDialog = false
                        app.temp.presetName = nil
                        app.temp.presetWord = nil
                        app.temp.editingPresetId = nil
                        app.temp.originalPresetFilter = nil
                    end
                end
            end,
            exportActionDialog = function(ctx)
                if app.temp.showExportActionDialog then
                    if not ImGui.IsPopupOpen(ctx, 'Export Reaper Action') then
                        ImGui.OpenPopup(ctx, 'Export Reaper Action')
                        if not app.temp.actionName then
                            app.temp.actionName = ""
                            app.temp.exportActionType = EXPORT_ACTION_TYPE.APPLY_FILTER
                        end
                    end

                    ImGui.SetNextWindowSize(ctx, 550 * app.gui.scale, 0, ImGui.Cond_Always)
                    ImGui.SetNextWindowPos(ctx, app.gui.mainWindow.pos[1] + (app.gui.mainWindow.size[1] / 2),
                        app.gui.mainWindow.pos[2] + (app.gui.mainWindow.size[2] / 2), ImGui.Cond_Appearing, 0.5, 0.5)
                    app.gui:pushStyles(app.gui.st.vars.popupsTitle)

                    local visible, open = ImGui.BeginPopupModal(ctx, 'Export Reaper Action', true,
                        ImGui.WindowFlags_AlwaysAutoResize)
                    app.gui:popStyles(app.gui.st.vars.popupsTitle)

                    if visible then
                        if ImGui.IsWindowAppearing(ctx) then
                            ImGui.SetKeyboardFocusHere(ctx, 0)
                        end
                        ImGui.TextWrapped(ctx, T.EXPORT_ACTION_DIALOG.INFO)
                        ImGui.Spacing(ctx)

                        app.temp.exportActionType = app.gui:setting(
                            'combo',
                            T.EXPORT_ACTION_DIALOG.ACTION_TYPE.LABEL,
                            T.EXPORT_ACTION_DIALOG.ACTION_TYPE.HINT,
                            app.temp.exportActionType, {
                                list = T.EXPORT_ACTION_TYPE_LIST,
                                hintWindow = 'editFilterWindow'
                            })

                        app.temp.actionName = app.gui:setting('text', T.EXPORT_ACTION_DIALOG.NAME.LABEL,
                            T.EXPORT_ACTION_DIALOG.NAME.HINT, app.temp.actionName,
                            { hintWindow = 'editFilterWindow' })


                        local trimmedActionName = OD_Trim(app.temp.actionName)
                        local canExportAction = trimmedActionName ~= ""

                        if not canExportAction then ImGui.BeginDisabled(ctx) end
                        if (ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) and canExportAction) or app.gui:setting('button', T.EXPORT_ACTION_DIALOG.EXPORT.LABEL,
                                T.EXPORT_ACTION_DIALOG.EXPORT.HINT, nil,
                                { label = T.EXPORT_ACTION_DIALOG.EXPORT.BUTTON, hintWindow = 'editFilterWindow' }) then
                            local createdActionName = app.flow.createFilterAction(trimmedActionName,
                                app.temp.exportActionType, app.temp.filter)
                            if createdActionName then
                                app:msg((T.EXPORT_ACTION_DIALOG.EXPORT.SUCCESS):format(createdActionName))
                            end
                            app.temp.showExportActionDialog = false
                            ImGui.CloseCurrentPopup(ctx)
                        end
                        if not canExportAction then ImGui.EndDisabled(ctx) end

                        if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) or app.gui:setting('button', T.EXPORT_ACTION_DIALOG.CLOSE.LABEL,
                                T.EXPORT_ACTION_DIALOG.CLOSE.HINT, nil,
                                { label = T.EXPORT_ACTION_DIALOG.CLOSE.BUTTON, hintWindow = 'editFilterWindow' }) then
                            app.temp.showExportActionDialog = false
                            ImGui.CloseCurrentPopup(ctx)
                        end
                        app.draw.hint(ctx, 'editFilterWindow')
                        ImGui.EndPopup(ctx)
                    end

                    if not open then
                        app.temp.showExportActionDialog = false
                        app.temp.actionName = nil
                        app.temp.exportActionType = nil
                    end
                end
            end,
            mainWindow = function(ctx)
                ImGui.SetNextWindowPos(ctx, 100, 100, ImGui.Cond_FirstUseEver)
                ImGui.SetNextWindowSizeConstraints(app.gui.ctx, app.gui.mainWindow.min_w, app.gui.mainWindow.min_h,
                    app.gui.mainWindow.max_w, app.gui.mainWindow.max_h)

                app.guiHelpers.handleDocking(ctx, 1)

                local visible, open = ImGui.Begin(ctx, Scr.name .. "###mainWindow",
                    true,
                    ImGui.WindowFlags_NoTitleBar |
                    ImGui.WindowFlags_NoCollapse)
                app.guiHelpers.saveWindowDimensions(ctx)

                app.guiHelpers.handleDocking(ctx, 2)

                if visible then
                    if app.gui.mainWindow.debugOverLay then
                        local left, top = ImGui.GetCursorScreenPos(app.gui.ctx)
                        ImGui.DrawList_AddRectFilled(ImGui.GetForegroundDrawList(ctx),
                            app.gui.mainWindow.debugOverLay[1] + left,
                            app.gui.mainWindow.debugOverLay[2] + top,
                            app.gui.mainWindow.debugOverLay[1] + app.gui.mainWindow.debugOverLay[3] + left,
                            app.gui.mainWindow.debugOverLay[2] + app.gui.mainWindow.debugOverLay[4] + top, 0xff000088, 0,
                            ImGui.DrawFlags_Closed)
                    end

                    app.draw.topBar(ctx)

                    if ImGui.BeginChild(ctx, '##body', 0.0, -app.gui.st.sizes.hintHeight) then
                        app.draw.search(ctx)

                        ImGui.EndChild(ctx)
                    end
                    app.draw.hint(ctx, 'main')
                    app.draw.confirmations(ctx)
                    app.draw.createPresetDialog(ctx)
                    app.draw.exportActionDialog(ctx)
                    app.draw.settings(ctx)
                    app.draw.help(ctx)
                    app.draw.welcomeDialog(ctx)
                    app:drawMsg()
                    ImGui.End(ctx)
                end
            end
        }

        function app.loop()
            local ctx = app.gui.ctx


            app.hide = false
            app.guiHelpers.initFrame(ctx)

            app.flow.checkExternalCommand()
            r.SetExtState(Scr.ext_name, 'RUNNING', 'TRUE', false)

            if not app.hide then
                app.gui:pushColors(app.gui.st.col.main)
                app.gui:pushStyles(app.gui.st.vars.main)
                ImGui.PushFont(ctx, app.gui.st.fonts.default)
                if app.logger.profile then Profile.start() end

                app.draw.mainWindow(ctx)

                if app.logger.profile then
                    Profile.stop()
                end
                ImGui.PopFont(ctx)
                app.gui:popColors(app.gui.st.col.main)
                app.gui:popStyles(app.gui.st.vars.main)
            end

            if not app.hide and not app.hardExit then
                PDefer(app.loop)
            elseif not app.hardExit and app.settings.current.sleepMode then
                if app and app.settings then app.settings:save() end
                -- Store current version before hibernating for version checking on wakeup
                app.logger:logInfo('Entering hibernation')
                app.temp.hibernationStart = r.time_precise()
                r.SetExtState(Scr.ext_name, 'HIBERNATING_VERSION', Scr.version, false)
                r.SetExtState(Scr.ext_name, 'WAKEUP', 'WAITING', false)
                PDefer(app.flow.hibernate)
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
            app.logger:logDebug('Release')
            if app.logger.profile then r.ShowConsoleMsg(Profile.report(10)) end

            r.SetExtState(Scr.ext_name, 'RUNNING', '', false)
            OD_ReleaseGlobalKeys()
        end

        function Exit()
            if app and app.settings then app.settings:save() end
            app.logger:logInfo('Exited (v' .. Scr.version .. ')')
            Release()
        end

        r.atexit(Exit)


        ---------------------------------------
        -- START ------------------------------
        ---------------------------------------
        -- app.settings:save()
        app.logger:logInfo('Started (v' .. Scr.version .. ')')
        app.logger:logAppInfo(app.logger.LOG_LEVEL.DEBUG, app)
        app.logger:logTable(app.logger.LOG_LEVEL.DEBUG, 'Settings', app.settings.current)
        app.engine:init()

        -- Hook cache invalidation into engine operations
        local originalAssembleAssets = app.engine.assembleAssets
        app.engine.assembleAssets = function(self, ...)
            originalAssembleAssets(self, ...)
            -- Invalidate search caches when assets are reassembled
            app.cacheHelpers:invalidateAllAssetSearchCaches()
        end

        local originalAssembleFilterAssets = app.engine.assembleFilterAssets
        app.engine.assembleFilterAssets = function(self, ...)
            originalAssembleFilterAssets(self, ...)
            -- Invalidate search caches when filter assets are reassembled
            app.cacheHelpers:invalidateAllAssetSearchCaches()
        end
        app.flow.setPage(APP_PAGE.SEARCH)
        PDefer(app.loop)
    end
end

CheckIfHybernating = function()
    if r.GetExtState(Scr.ext_name, 'WAKEUP') == 'WAITING' or r.GetExtState(Scr.ext_name, 'WAKEUP') == 'EXIT' then
        -- Check if script version has changed while hibernating
        local hibernatingVersion = r.GetExtState(Scr.ext_name, 'HIBERNATING_VERSION')
        if hibernatingVersion ~= '' and hibernatingVersion ~= Scr.version then
            -- Version mismatch: script was updated while hibernating
            -- Clear hibernation state and let new version start fresh
            r.SetExtState(Scr.ext_name, 'WAKEUP', 'EXIT', false)
            local function waitForScriptToTerminate()
                if r.GetExtState(Scr.ext_name, 'WAKEUP') == nil or r.GetExtState(Scr.ext_name, 'WAKEUP') == '' then
                    RunApp()
                else
                    r.defer(waitForScriptToTerminate)
                end
            end
            waitForScriptToTerminate()
        else
            -- Same version: wakeup running script
            r.SetExtState(Scr.ext_name, 'WAKEUP', 'GO', false)
            return -- Exit early, hibernating script will wake up
        end
    elseif r.GetExtState(Scr.ext_name, 'RUNNING') == 'TRUE' then
        -- Script is already running, just bring it to focus
        local scriptHwnd = r.JS_Window_Find(Scr.context_name, true) or r.JS_Window_FindTop('Scout', true)
        if scriptHwnd then
            r.JS_Window_SetFocus(scriptHwnd)
        end
        return
    end
end

CheckIfHybernating()
RunApp()
