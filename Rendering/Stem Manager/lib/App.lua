-- @noindex
App = OD_Perform_App:new()

function App:drawPopup(ctx, popupType, title, data)
    local data = data or {}
    local center = { Gui.mainWindow.pos[1] + Gui.mainWindow.size[1] / 2,
        Gui.mainWindow.pos[2] + Gui.mainWindow.size[2] / 2 } -- {r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
    if popupType == 'singleInput' then
        local okPressed = nil
        local initVal = data.initVal or ''
        local okButtonLabel = data.okButtonLabel or 'OK'
        local validation = data.validation or function(origVal, val)
            return true
        end
        local bottom_lines = 2

        r.ImGui_SetNextWindowSize(ctx, 350, 110)
        r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
        if r.ImGui_BeginPopupModal(ctx, title, false, r.ImGui_WindowFlags_AlwaysAutoResize()) then
            Gui.popups.title = title

            if r.ImGui_IsWindowAppearing(ctx) then
                r.ImGui_SetKeyboardFocusHere(ctx)
                Gui.popups.singleInput.value = initVal -- gui.popups.singleInput.stem.name
                Gui.popups.singleInput.status = ""
            end
            local width = select(1, r.ImGui_GetContentRegionAvail(ctx))
            r.ImGui_PushItemWidth(ctx, width)
            retval, Gui.popups.singleInput.value = r.ImGui_InputText(ctx, '##singleInput',
                Gui.popups.singleInput.value)

            r.ImGui_SetItemDefaultFocus(ctx)
            r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeight(ctx) * bottom_lines) -
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()))
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), Gui.st.col.error)
            r.ImGui_Text(ctx, Gui.popups.singleInput.status)
            r.ImGui_PopStyleColor(ctx)
            if r.ImGui_Button(ctx, okButtonLabel) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
                Gui.popups.singleInput.status = validation(initVal, Gui.popups.singleInput.value)
                if Gui.popups.singleInput.status == true then
                    okPressed = true
                    r.ImGui_CloseCurrentPopup(ctx)
                end
            end
            r.ImGui_SameLine(ctx)
            if r.ImGui_Button(ctx, 'Cancel') or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
                okPressed = false
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndPopup(ctx)
        end
        return okPressed, Gui.popups.singleInput.value
    elseif popupType == 'msg' then
        local okPressed = nil
        local msg = data.msg or ''
        local showCancelButton = data.showCancelButton or false
        local textWidth, textHeight = r.ImGui_CalcTextSize(ctx, msg)
        local okButtonLabel = data.okButtonLabel or 'OK'
        local cancelButtonLabel = data.cancelButtonLabel or 'Cancel'
        local bottom_lines = 1
        local closeKey = data.closeKey or r.ImGui_Key_Enter()
        local cancelKey = data.cancelKey or r.ImGui_Key_Escape()

        r.ImGui_SetNextWindowSize(ctx, math.max(220, textWidth) +
            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()) * 4, textHeight + 90)
        r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)

        if r.ImGui_BeginPopupModal(ctx, title, false,
                r.ImGui_WindowFlags_NoResize() + r.ImGui_WindowFlags_NoDocking()) then
            Gui.popups.title = title

            local width = select(1, r.ImGui_GetContentRegionAvail(ctx))
            r.ImGui_PushItemWidth(ctx, width)

            local windowWidth, windowHeight = r.ImGui_GetWindowSize(ctx);
            r.ImGui_SetCursorPos(ctx, (windowWidth - textWidth) * .5, (windowHeight - textHeight) * .5);

            r.ImGui_TextWrapped(ctx, msg)
            r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeight(ctx) * bottom_lines) -
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()))

            local buttonTextWidth = r.ImGui_CalcTextSize(ctx, okButtonLabel) +
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2

            if showCancelButton then
                buttonTextWidth = buttonTextWidth + r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()) +
                    r.ImGui_CalcTextSize(ctx, cancelButtonLabel) +
                    r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2
            end
            r.ImGui_SetCursorPosX(ctx, (windowWidth - buttonTextWidth) * .5);

            if r.ImGui_Button(ctx, okButtonLabel) or r.ImGui_IsKeyPressed(ctx, closeKey) then
                okPressed = true
                r.ImGui_CloseCurrentPopup(ctx)
            end

            if showCancelButton then
                r.ImGui_SameLine(ctx)
                if r.ImGui_Button(ctx, cancelButtonLabel) or r.ImGui_IsKeyPressed(ctx, cancelKey) then
                    okPressed = false
                    r.ImGui_CloseCurrentPopup(ctx)
                end
            end

            r.ImGui_EndPopup(ctx)
        end
        return okPressed
    elseif popupType == 'stemActionsMenu' then
        if r.ImGui_BeginPopup(ctx, title) then
            if r.ImGui_Selectable(ctx, 'Rename', false, r.ImGui_SelectableFlags_DontClosePopups()) then
                Gui.popups.object = data.stemName;
                r.ImGui_OpenPopup(ctx, 'Rename Stem')
            end
            local retval, newval = App:drawPopup(ctx, 'singleInput', 'Rename Stem', {
                initVal = data.stemName,
                okButtonLabel = 'Rename',
                validation = validators.stem.name
            })
            if retval == true then
                DB:renameStem(data.stemName, newval)
            end
            if retval ~= nil then
                Gui.popups.object = nil;
                r.ImGui_CloseCurrentPopup(ctx)
            end -- could be true (ok) or false (cancel)
            App:setHoveredHint('main', 'Rename stem')
            if r.ImGui_Selectable(ctx, 'Add stem to render queue', false) then
                App.stem_to_render = data.stemName;
                App.forceRenderAction = RENDERACTION_RENDERQUEUE_OPEN;
                App.coPerform = coroutine.create(doPerform)
            end
            App:setHoveredHint('main', "Add this stem only to the render queue")
            if r.ImGui_Selectable(ctx, 'Render stem now', false) then
                App.stem_to_render = data.stemName
                App.forceRenderAction = RENDERACTION_RENDER
                App.coPerform = coroutine.create(doPerform)
            end
            App:setHoveredHint('main', "Render this stem only")
            if r.ImGui_Selectable(ctx, ('Add group %s to queue'):format(data.renderSettingGroup), false) then
                App.renderGroupToRender = data.renderSettingGroup
                App.forceRenderAction = RENDERACTION_RENDERQUEUE_OPEN;
                App.coPerform = coroutine.create(doPerform)
            end
            App:setHoveredHint('main',
                ("Add all stems belonging to render group %s only to the render queue"):format(data
                .renderSettingGroup))
            if r.ImGui_Selectable(ctx, ("Render group %s now"):format(data.renderSettingGroup), false) then
                App.renderGroupToRender = data.renderSettingGroup
                App.forceRenderAction = RENDERACTION_RENDER
                App.coPerform = coroutine.create(doPerform)
            end
            App:setHoveredHint('main', ("Render all stems belonging render group %s"):format(data.renderSettingGroup))
            if r.ImGui_Selectable(ctx, 'Get states from tracks', false) then
                DB:reflectAllTracksOnStem(data.stemName)
            end
            App:setHoveredHint('main', "Get current solo/mute states from the project's tracks.")
            if r.ImGui_Selectable(ctx, 'Set states on tracks', false) then
                DB:reflectStemOnAllTracks(data.stemName)
            end
            App:setHoveredHint('main', "Set this stem's solo/mute states on the project's tracks.")
            if r.ImGui_Selectable(ctx, 'Clear states', false) then
                DB:resetStem(data.stemName)
            end
            App:setHoveredHint('main', "Clear current stem solo/mute states.")
            r.ImGui_Separator(ctx)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), Gui.st.col.critical)
            if r.ImGui_Selectable(ctx, 'Delete', false) then
                DB:removeStem(data.stemName)
            end
            r.ImGui_PopStyleColor(ctx)
            App:setHoveredHint('main', 'Delete stem')
            if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndPopup(ctx)
        end
    elseif popupType == 'renderPresetSelector' then
        local selectedPreset = nil
        -- r.ImGui_SetNextWindowSize(ctx,0,100)
        r.ImGui_SetNextWindowSizeConstraints(ctx, 0, 100, 1000, 250)
        if r.ImGui_BeginPopup(ctx, title) then
            Gui.popups.title = title
            local presetCount = 0
            for i, preset in pairs(DB.renderPresets) do
                presetCount = presetCount + 1
                if r.ImGui_Selectable(ctx, preset.name, false) then
                    selectedPreset = preset.name
                end
            end
            if presetCount == 0 then
                r.ImGui_Text(ctx,
                    "No render presets found.\nPlease create and add presets using\nREAPER's render window preset button.")
            end
            r.ImGui_EndPopup(ctx)
        end
        return not (selectedPreset == nil), selectedPreset
    end
    return false
end

function App:drawBtn(btnType, data)
    local ctx = self.gui.ctx
    local cellSize = Gui.st.vars.mtrx.cellSize
    local headerRowHeight = Gui.st.vars.mtrx.headerRowHeight
    local modKeys = Gui.modKeys
    local clicked = false
    if btnType == 'stemSync' then
        local stemSyncMode = data.stemSyncMode
        local generalSyncMode = data.generalSyncMode
        local isSyncing = ((stemSyncMode ~= SYNCMODE_OFF) and (stemSyncMode ~= nil))
        local displayedSyncMode = isSyncing and stemSyncMode or
            generalSyncMode -- if stem is syncing, show its mode, otherwise, show mode based on preferences+alt key
        local altSyncMode = (displayedSyncMode == SYNCMODE_SOLO) and SYNCMODE_SOLO or SYNCMODE_MIRROR
        local btnColor = isSyncing and Gui.st.col.stemSyncBtn[displayedSyncMode].active or
            Gui.st.col.stemSyncBtn[displayedSyncMode].inactive
        local circleColor = isSyncing and Gui.st.col.stemSyncBtn[displayedSyncMode].active[r.ImGui_Col_Text()] or
            Gui.st.col.stemSyncBtn[displayedSyncMode].active[r.ImGui_Col_Button()]
        local centerPosX, centerPosY = select(1, r.ImGui_GetCursorScreenPos(ctx)) + cellSize / 2,
            select(2, r.ImGui_GetCursorScreenPos(ctx)) + cellSize / 2
        r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) + 1)
        Gui:pushColors(btnColor)
        if r.ImGui_Button(ctx, " ", cellSize, cellSize) then
            clicked = true
        end
        if r.ImGui_IsItemHovered(ctx) then
            r.ImGui_SetMouseCursor(ctx, 7)
        end
        r.ImGui_DrawList_AddCircle(Gui.draw_list, centerPosX, centerPosY, 5, circleColor, 0, 2)
        Gui:popColors(btnColor)
        if isSyncing then
            App:setHoveredHint('main', ("Stem is mirrored (%s). Click to stop mirroring."):format(
                SYNCMODE_DESCRIPTIONS[displayedSyncMode]))
        else
            if modKeys == 'a' then
                App:setHoveredHint('main', ("%s+click to mirror stem (%s)."):format(
                    Gui.descModAlt:gsub("^%l", string.upper), SYNCMODE_DESCRIPTIONS[altSyncMode]))
            else
                App:setHoveredHint('main',
                    ("Click to mirror stem (%s)."):format(SYNCMODE_DESCRIPTIONS[displayedSyncMode]))
            end
        end
    elseif btnType == 'stemActions' then
        local topLeftX, topLeftY = data.topLeftX, data.topLeftY
        local centerPosX, centerPosY = topLeftX + cellSize / 2, topLeftY + cellSize / 2
        local sz, radius = 4.5, 1.5
        local color = Gui.st.col.button[r.ImGui_Col_Text()]
        Gui:pushColors(Gui.st.col.button)
        if r.ImGui_Button(ctx, '##stemActions', cellSize, cellSize) then
            r.ImGui_OpenPopup(ctx, '##stemActions')
        end
        Gui:popColors(Gui.st.col.button)
        r.ImGui_DrawList_AddCircleFilled(Gui.draw_list, centerPosX - sz, centerPosY, radius, color, 8)
        r.ImGui_DrawList_AddCircleFilled(Gui.draw_list, centerPosX, centerPosY, radius, color, 8)
        r.ImGui_DrawList_AddCircleFilled(Gui.draw_list, centerPosX + sz, centerPosY, radius, color, 8)
        App:setHoveredHint('main', 'Stem actions')
    elseif btnType == 'addStem' then
        Gui:pushColors(Gui.st.col.button)
        r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) + 1)
        if r.ImGui_Button(ctx, '##addStem', cellSize, headerRowHeight) then
            clicked = true
        end
        Gui:popColors(Gui.st.col.button)
        local centerPosX = select(1, r.ImGui_GetCursorScreenPos(ctx)) + cellSize / 2
        local centerPosY = select(2, r.ImGui_GetCursorScreenPos(ctx)) - headerRowHeight / 2
        local color = Gui.st.col.button
            [r.ImGui_Col_Text()] -- gui.st.col.stemSyncBtn.active[r.ImGui_Col_Text()] or gui.st.col.stemSyncBtn.active[r.ImGui_Col_Button()]
        r.ImGui_DrawList_AddLine(Gui.draw_list, centerPosX - cellSize / 5, centerPosY, centerPosX + cellSize / 5,
            centerPosY, color, 2)
        r.ImGui_DrawList_AddLine(Gui.draw_list, centerPosX, centerPosY - cellSize / 5, centerPosX,
            centerPosY + cellSize / 5, color, 2)
        if modKeys ~= "c" then
            App:setHoveredHint('main', ('Click to create a new stem %s.'):format(
                REFLECT_ON_ADD_DESCRIPTIONS[Settings.project.reflect_on_add]))
        else
            App:setHoveredHint('main',
                ('%s+click to create a new stem %s.'):format(Gui.descModCtrlCmd:gsub("^%l", string.upper),
                    REFLECT_ON_ADD_DESCRIPTIONS[(Settings.project.reflect_on_add == REFLECT_ON_ADD_TRUE) and
                    REFLECT_ON_ADD_FALSE or REFLECT_ON_ADD_TRUE]))
        end
    elseif btnType == 'renderGroupSelector' then
        local stemName = data.stemName
        local stGrp = data.stGrp
        Gui:pushColors(Gui.st.col.render_setting_groups[stGrp])
        Gui:pushStyles(Gui.st.vars.mtrx.stemState)
        local origPosX, origPosY = r.ImGui_GetCursorPos(ctx)
        origPosY = origPosY + 1
        r.ImGui_SetCursorPosY(ctx, origPosY)
        local color = Gui.st.col.render_setting_groups[stGrp][r.ImGui_Col_Button()]
        local topLeftX, topLeftY = r.ImGui_GetCursorScreenPos(ctx)
        r.ImGui_DrawList_AddRectFilled(Gui.draw_list, topLeftX, topLeftY, topLeftX + cellSize, topLeftY + cellSize,
            color)
        r.ImGui_SetCursorPosY(ctx, origPosY)
        r.ImGui_Dummy(ctx, cellSize, cellSize)
        App:setHoveredHint('main',
            'Stem to be rendered by settings group ' .. stGrp .. '. Click arrows to change group.')
        if r.ImGui_IsItemHovered(ctx) then
            local description = Settings.project.render_setting_groups[stGrp].description
            if description ~= nil and description ~= '' then
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(),
                    Gui.st.col.render_setting_groups[stGrp][r.ImGui_Col_Button()])
                r.ImGui_SetTooltip(ctx, description)
                r.ImGui_PopStyleColor(ctx)
            end
            local centerX = r.ImGui_GetCursorScreenPos(ctx) + cellSize / 2
            local color = Gui.st.col.render_setting_groups[stGrp][r.ImGui_Col_Text()]
            local sz = 5
            r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) - cellSize)
            local startY = select(2, r.ImGui_GetCursorScreenPos(ctx))
            r.ImGui_Button(ctx, '###up' .. stemName, cellSize, cellSize / 3)
            if r.ImGui_IsItemClicked(ctx) then
                DB.stems[stemName].render_setting_group = (stGrp == RENDER_SETTING_GROUPS_SLOTS) and 1 or stGrp + 1
                DB:save()
            end
            if r.ImGui_IsItemHovered(ctx) then
                r.ImGui_SetMouseCursor(ctx, 7)
            end
            r.ImGui_DrawList_AddTriangleFilled(Gui.draw_list, centerX, startY, centerX - sz * .5, startY + sz,
                centerX + sz * .5, startY + sz, color)
            App:setHoveredHint('main', ('Change to setting group %d.'):format(
                (stGrp == RENDER_SETTING_GROUPS_SLOTS) and 1 or stGrp + 1))
            sz = sz + 1
            r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) + cellSize / 3)
            local startY = select(2, r.ImGui_GetCursorScreenPos(ctx)) + cellSize / 3 - sz
            r.ImGui_Button(ctx, '###down' .. stemName, cellSize, cellSize / 3)
            if r.ImGui_IsItemClicked(ctx) then
                DB.stems[stemName].render_setting_group = (stGrp == 1) and RENDER_SETTING_GROUPS_SLOTS or stGrp - 1
                DB:save()
            end
            if r.ImGui_IsItemHovered(ctx) then
                r.ImGui_SetMouseCursor(ctx, 7)
            end
            r.ImGui_DrawList_AddTriangleFilled(Gui.draw_list, centerX - sz * .5, startY, centerX + sz * .5, startY,
                centerX, startY + sz, color)
            App:setHoveredHint('main', ('Change to setting group %d.'):format(
                (stGrp == 1) and RENDER_SETTING_GROUPS_SLOTS or stGrp - 1))
        end
        local textSizeX, textSizeY = r.ImGui_CalcTextSize(ctx, tostring(stGrp))
        r.ImGui_SetCursorPos(ctx, origPosX + (cellSize - textSizeX) / 2, origPosY + (cellSize - textSizeY) / 2)
        r.ImGui_Text(ctx, stGrp)
        Gui:popColors(Gui.st.col.render_setting_groups[stGrp])
        Gui:popStyles(Gui.st.vars.mtrx.stemState)
    elseif btnType == 'stemState' then
        local state = data.state
        local track = data.track
        local stemName = data.stemName
        local stem = DB.stems[stemName]
        local color_state = ((state == ' ') and (stem.sync ~= SYNCMODE_OFF) and (stem.sync ~= nil)) and
            { 'sync_' .. stem.sync, 'sync_' .. stem.sync } or STATE_COLORS[state]
        local curScrPos = { r.ImGui_GetCursorScreenPos(ctx) }
        curScrPos[2] = curScrPos[2] + 1
        local text_size = { r.ImGui_CalcTextSize(ctx, STATE_LABELS[state]) }
        r.ImGui_SetCursorScreenPos(ctx, curScrPos[1], curScrPos[2])
        r.ImGui_Dummy(ctx, cellSize, cellSize)
        local col_a, col_b
        if r.ImGui_IsItemHovered(ctx, r.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem()) then
            col_a = Gui.st.col.stemState[color_state[1]][r.ImGui_Col_ButtonHovered()]
            col_b = Gui.st.col.stemState[color_state[2]][r.ImGui_Col_ButtonHovered()]
        else
            col_a = Gui.st.col.stemState[color_state[1]][r.ImGui_Col_Button()]
            col_b = Gui.st.col.stemState[color_state[2]][r.ImGui_Col_Button()]
        end
        r.ImGui_DrawList_AddRectFilled(Gui.draw_list, curScrPos[1], curScrPos[2], curScrPos[1] + cellSize / 2,
            curScrPos[2] + cellSize, col_a)
        r.ImGui_DrawList_AddRectFilled(Gui.draw_list, curScrPos[1] + cellSize / 2, curScrPos[2],
            curScrPos[1] + cellSize, curScrPos[2] + cellSize, col_b)
        r.ImGui_SetCursorScreenPos(ctx, curScrPos[1] + (cellSize - text_size[1]) / 2,
            curScrPos[2] + (cellSize - text_size[2]) / 2)
        r.ImGui_TextColored(ctx, Gui.st.col.stemState[color_state[1]][r.ImGui_Col_Text()], STATE_LABELS[state])
        r.ImGui_SetCursorScreenPos(ctx, curScrPos[1], curScrPos[2])
        r.ImGui_InvisibleButton(ctx, '##' .. track.name .. state .. stemName, cellSize, cellSize)
        if r.ImGui_IsItemHovered(ctx, r.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem()) then
            r.ImGui_SetMouseCursor(ctx, 7)
            local defaultSolo = DB.prefSoloIP and STATES.SOLO_IN_PLACE or STATES.SOLO_IGNORE_ROUTING
            local otherSolo = DB.prefSoloIP and STATES.SOLO_IGNORE_ROUTING or STATES.SOLO_IN_PLACE
            local defaultMSolo = DB.prefSoloIP and STATES.MUTE_SOLO_IN_PLACE or STATES.MUTE_SOLO_IGNORE_ROUTING
            local otherMSolo = DB.prefSoloIP and STATES.MUTE_SOLO_IGNORE_ROUTING or STATES.MUTE_SOLO_IN_PLACE
            local currentStateDesc = (state ~= ' ') and ('Track is %s. '):format(STATE_DESCRIPTIONS[state][2]) or ''
            local stateSwitches = {
                [''] = {
                    state = defaultSolo,
                    hint = ('%sClick to %s.'):format(currentStateDesc, (state == defaultSolo) and 'clear' or
                        STATE_DESCRIPTIONS[defaultSolo][1])
                },
                ['s'] = {
                    state = STATES.MUTE,
                    hint = ('%sShift+click to %s.'):format(currentStateDesc, (state == STATES.MUTE) and 'clear' or
                        STATE_DESCRIPTIONS[STATES.MUTE][1])
                },
                ['c'] = {
                    state = otherSolo,
                    hint = ('%s%s+click to %s.'):format(currentStateDesc,
                        Gui.descModCtrlCmd:gsub("^%l", string.upper), (state == otherSolo) and 'clear' or
                        STATE_DESCRIPTIONS[otherSolo][1])
                },
                ['sa'] = {
                    state = defaultMSolo,
                    hint = ('%sShift+%s+click to %s.'):format(currentStateDesc, Gui.descModAlt, (state ==
                        defaultMSolo) and 'clear' or STATE_DESCRIPTIONS[defaultMSolo][1])
                },
                ['sc'] = {
                    state = otherMSolo,
                    hint = ('%sShift+%s+click to %s.'):format(currentStateDesc, Gui.descModCtrlCmd, (state ==
                        otherMSolo) and 'clear' or STATE_DESCRIPTIONS[otherMSolo][1])
                },
                ['a'] = {
                    state = ' ',
                    hint = ('%s%s'):format(currentStateDesc,
                        ('%s+click to clear.'):format(Gui.descModAlt:gsub("^%l", string.upper)))
                }
            }
            if stateSwitches[modKeys] then
                App:setHint('main', stateSwitches[modKeys].hint)
                if Gui.mtrxTbl.drgState == nil and r.ImGui_IsMouseClicked(ctx, r.ImGui_MouseButton_Left()) then
                    Gui.mtrxTbl.drgState = (state == stateSwitches[modKeys]['state']) and ' ' or
                        stateSwitches[modKeys]['state']
                elseif Gui.mtrxTbl.drgState and Gui.mtrxTbl.drgState ~= state then
                    DB:setTrackStateInStem(track, stemName, Gui.mtrxTbl.drgState)
                end
            end
        end
    end
    return clicked
end