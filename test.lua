local r = reaper
local ctx = r.ImGui_CreateContext('test')

r.ClearConsole()

local function drawMainWindow()
    r.ImGui_SetNextWindowSize(ctx, 700, 300, r.ImGui_Cond_Appearing())
    r.ImGui_SetNextWindowPos(ctx, 100, 100, r.ImGui_Cond_FirstUseEver())
    local visible, open = r.ImGui_Begin(ctx, "test##mainWindow", true, r.ImGui_WindowFlags_MenuBar())
    if visible then
        if r.ImGui_BeginMenuBar(ctx) then
            if r.ImGui_MenuItem(ctx, 'Settings') then
                r.ImGui_OpenPopup(ctx, 'Settings')
            end
            if r.ImGui_IsPopupOpen(ctx, 'Settings') then
                if r.ImGui_BeginPopupModal(ctx, 'Settings', false, r.ImGui_WindowFlags_AlwaysAutoResize()) then
                    local halfWidth = 10
                    r.ImGui_BeginGroup(ctx)
                    r.ImGui_AlignTextToFramePadding(ctx)
                    r.ImGui_PushTextWrapPos(ctx, halfWidth)
                    r.ImGui_Text(ctx, text)
                    r.ImGui_PopTextWrapPos(ctx)
                    r.ImGui_SameLine(ctx)
                    r.ImGui_SetCursorPosX(ctx, halfWidth)
                    _, v = r.ImGui_Combo(ctx, '##question', v, 'a\0b\0c\0')
                    r.ImGui_EndGroup(ctx)


                    if r.ImGui_Button(ctx, "Cancel") or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
                        r.ImGui_CloseCurrentPopup(ctx)
                    end
                    r.ImGui_EndPopup(ctx)
                end
                -- App.drawSettings()
            end
            r.ImGui_EndMenuBar(ctx)
        end
        r.ImGui_End(ctx)
    end
    return open
end

local function loop()
    local open = drawMainWindow()
    if open then
        r.defer(loop)
    end
end

r.defer(loop)
