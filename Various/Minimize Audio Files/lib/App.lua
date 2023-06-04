app = {
    open = true,
    coPerform = nil,
    mediaFiles = {},
    perform = {
        status = nil
    },
    hint = {
        main = {},
        settings = {}
    },
    popup = {}
}

function app.getStatus(window)
    if window == 'main' then
        --  if db.error == 'no stemsFolder' then return "Stems folder not defined", 'error' end
        if app.coPerform then
            return app.perform.status
        end
        return app.hint.main.text, app.hint.main.color
    elseif window == 'settings' then
        return app.hint.settings.text, app.hint.settings.color
    end
end

function app.setHoveredHint(window, text, color, ctx)
    local ctx = ctx or gui.ctx
    if r.ImGui_IsItemHovered(ctx, r.ImGui_HoveredFlags_AllowWhenDisabled()) then
        app.setHint(window, text, color, ctx)
    end
end

function app.setHint(window, text, color, ctx)
    local ctx = ctx or gui.ctx
    color = color or 'hint'
    if (app.error or app.coPerform) and not (text == '') and text then
        app.hint[window] = {
            window = {}
        }
        if color then
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), gui.st.col[color])
        end
        r.ImGui_SetTooltip(ctx, text)
        if color then
            r.ImGui_PopStyleColor(ctx)
        end
    else
        app.hint[window] = {
            text = text,
            color = color
        }
    end
end

app.drawPopup = function(popupType, title, data)
    local ctx = gui.ctx
    local data = data or {}
    local center = {gui.mainWindow.pos[1] + gui.mainWindow.size[1] / 2,
                    gui.mainWindow.pos[2] + gui.mainWindow.size[2] / 2} -- {r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
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
            gui.popups.title = title

            if r.ImGui_IsWindowAppearing(ctx) then
                r.ImGui_SetKeyboardFocusHere(ctx)
                gui.popups.singleInput.value = initVal -- gui.popups.singleInput.stem.name
                gui.popups.singleInput.status = ""
            end
            local width = select(1, r.ImGui_GetContentRegionAvail(ctx))
            r.ImGui_PushItemWidth(ctx, width)
            retval, gui.popups.singleInput.value = r.ImGui_InputText(ctx, '##singleInput', gui.popups.singleInput.value)

            r.ImGui_SetItemDefaultFocus(ctx)
            r.ImGui_SetCursorPosY(ctx, r.ImGui_GetWindowHeight(ctx) - (r.ImGui_GetFrameHeight(ctx) * bottom_lines) -
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()))
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), gui.st.col.error)
            r.ImGui_Text(ctx, gui.popups.singleInput.status)
            r.ImGui_PopStyleColor(ctx)
            if r.ImGui_Button(ctx, okButtonLabel) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
                gui.popups.singleInput.status = validation(initVal, gui.popups.singleInput.value)
                if gui.popups.singleInput.status == true then
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
        return okPressed, gui.popups.singleInput.value
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

        if r.ImGui_BeginPopupModal(ctx, title, false, r.ImGui_WindowFlags_NoResize() + r.ImGui_WindowFlags_NoDocking()) then
            gui.popups.title = title

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
    end
    return false
end

app.msg = function(msg, title)
    app.popup.msg = app.popup.msg or msg
    app.popup.title = app.popup.title or scr.name
end

app.drawMsg = function()
    if next(app.popup) ~= nil then
        r.ImGui_OpenPopup(gui.ctx, app.popup.title .. "##msg")
        local rv = app.drawPopup('msg', app.popup.title .. "##msg", {
            msg = app.popup.msg
        })

        if rv then
            app.popup = {}
        end
    end
end
