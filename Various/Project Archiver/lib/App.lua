-- @noindex
App = {
    open = true,
    coPerform = nil,
    mediaFiles = {},
    revert = {},
    restore = {},
    temp = {},
    perform = {
        status = nil,
        pos = 0,
        total = 1,
        mediaFileCount = 0
    },
    hint = {
        main = {},
        settings = {}
    },
    popup = {}
}

function App.getStatus(window)
    if window == 'main' then
        --  if db.error == 'no stemsFolder' then return "Stems folder not defined", 'error' end
        if App.coPerform then
            return App.perform.status
        end
        return App.hint.main.text, App.hint.main.color
    elseif window == 'settings' then
        return App.hint.settings.text, App.hint.settings.color
    end
end

function App.setHoveredHint(window, text, color, ctx)
    local ctx = ctx or Gui.ctx
    if r.ImGui_IsItemHovered(ctx, r.ImGui_HoveredFlags_AllowWhenDisabled()) then
        App.setHint(window, text, color, ctx)
    end
end

function App.setHint(window, text, color, ctx)
    local ctx = ctx or Gui.ctx
    color = color or 'hint'
    if (App.error or App.coPerform) and not (text == '') and text then
        App.hint[window] = {
            window = {}
        }
        if color then
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), Gui.st.col[color])
        end
        r.ImGui_SetTooltip(ctx, text)
        if color then
            r.ImGui_PopStyleColor(ctx)
        end
    else
        App.hint[window] = {
            text = text,
            color = color
        }
    end
end

App.drawPopup = function(popupType, title, data)
    local ctx = Gui.ctx
    local data = data or {}
    local center = {Gui.mainWindow.pos[1] + Gui.mainWindow.size[1] / 2,
                    Gui.mainWindow.pos[2] + Gui.mainWindow.size[2] / 2} -- {r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
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
            _, Gui.popups.singleInput.value = r.ImGui_InputText(ctx, '##singleInput', Gui.popups.singleInput.value)

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
        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowTitleAlign(), 0.5, 0.5)
        if r.ImGui_BeginPopupModal(ctx, title, false, r.ImGui_WindowFlags_NoResize() + r.ImGui_WindowFlags_NoDocking()) then
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
        r.ImGui_PopStyleVar(ctx)
        return okPressed
    end
    return false
end

App.msg = function(msg, title)
    App.popup.msg = App.popup.msg or msg
    App.popup.title = App.popup.title or title or Scr.name
    if coroutine.isyieldable(App.coPerform) then
        coroutine.yield('', 0, 1)
        coroutine.yield('', 0, 1)
    end
end

App.drawMsg = function()
    if next(App.popup) ~= nil and App.popup.msg ~= nil then
        r.ImGui_OpenPopup(Gui.ctx, App.popup.title .. "##msg")
        local rv = App.drawPopup('msg', App.popup.title .. "##msg", {
            msg = App.popup.msg
        })

        if rv then
            App.popup = {}
        end
    end
end
