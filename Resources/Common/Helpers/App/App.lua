-- @noindex
-- ! OD_App
OD_App = {
    logLevel = OD_Logger.LOG_LEVEL.NONE,
    temp = {},
    connect = function(self, objectname, o)
        for k,v in pairs(self) do
            if k == objectname then
                error('OD_App:connect: object with name '..objectname..' already exists')
            end
        end
        self[objectname] = o
        o.app = self
    end
}

function OD_App:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

-- ! OD_Gui_App
OD_Gui_App = OD_App:new({
    open = true,
    hint = {
        main = {},
        settings = {}
    },
    popup = {}
})

function OD_Gui_App:init()
    if self.gui == nil then error('OD_App:new: gui is a required param') end
end

function OD_Gui_App:setHint(window, text, color, ctx)
    local ctx = ctx or self.gui.ctx
    color = color or 'hint'
    if (self.error or self.coPerform) and not (text == '') and text then
        self.hint[window] = {
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
        self.hint[window] = {
            text = text,
            color = color
        }
    end
end
function OD_Gui_App:setHoveredHint(window, text, color, ctx)
    local ctx = ctx or self.gui.ctx
    if r.ImGui_IsItemHovered(ctx, r.ImGui_HoveredFlags_AllowWhenDisabled()) then
        self:setHint(window, text, color, ctx)
    end
end

function OD_Gui_App:drawPopup (popupType, title, data)
    local ctx = self.gui.ctx
    local data = data or {}
    local center = { Gui.mainWindow.pos[1] + Gui.mainWindow.size[1] / 2,
        Gui.mainWindow.pos[2] + Gui.mainWindow.size[2] / 2 }            -- {r.ImGui_Viewport_GetCenter(r.ImGui_GetMainViewport(ctx))}
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

function OD_Gui_App:msg (msg, title)
    self.popup.msg = self.popup.msg or msg
    self.popup.title = self.popup.title or title or Scr.name
    -- if coroutine.isyieldable(self.coPerform) then
        -- coroutine.yield('', 0, 1)
        -- coroutine.yield('', 0, 1)
    -- end
end

function OD_Gui_App:drawMsg()
    if next(self.popup) ~= nil and self.popup.msg ~= nil then
        r.ImGui_OpenPopup(self.gui.ctx, self.popup.title .. "##msg")
        local rv = self:drawPopup('msg', self.popup.title .. "##msg", {
            msg = self.popup.msg
        })

        if rv then
            self.popup = {}
        end
    end
end

-- ! OD_Perform_App
OD_Perform_App = OD_Gui_App:new({
    coPerform = nil,
    perform = {
        status = nil,
        pos = 0,
        total = 1,
        mediaFileCount = 0
    },
})

function OD_Perform_App:getStatus(window)
    if window == 'main' then
        if self.coPerform then
            return self.perform.status
        end
        return self.hint[window].text, self.hint[window].color
    else
        return self.hint[window].text, self.hint[window].color
    end
end

function OD_Perform_App:checkPerform()
    if self.coPerform then
        if coroutine.status(self.coPerform) == "suspended" then
            local retval
            retval, self.perform.status = coroutine.resume(self.coPerform)
            if not retval then
                if type(self.onCancel) == 'function' then self.onCancel() end 
            end
        elseif coroutine.status(self.coPerform) == "dead" then
            if type(self.onDone) == 'function' then self.onDone() end 
            self.coPerform = nil
        end
    end
  end