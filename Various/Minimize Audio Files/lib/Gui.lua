-- @noindex
gui = {}

do
    -- these needs to be temporarily created to be refered to from some of the gui vars
    local ctx = r.ImGui_CreateContext(scr.context_name .. '_MAIN')
    local font_default = r.ImGui_CreateFont(scr.dir .. '../../Resources/Fonts/Cousine-Regular.ttf', 16)
    r.ImGui_Attach(ctx, font_default)

    gui = {
        ctx = ctx,
        mainWindow = {},
        draw_list = r.ImGui_GetWindowDrawList(ctx),
        st = {
            fonts = {
                default = font_default
            },
            col = {
                warning = 0xf58e07FF,
                ok = 0X55FF55FF,
                critical = 0xDD0000FF,
                error = 0xFF5555FF,
                hint = 0xCCCCCCFF,
                button = {
                    [r.ImGui_Col_Text()] = 0x000000ff,
                    [r.ImGui_Col_Button()] = 0x707070ff,
                    [r.ImGui_Col_ButtonHovered()] = 0x858585FF,
                    [r.ImGui_Col_ButtonActive()] = 0x9c9c9cFF
                }
            }
        },
        popups = {
            singleInput = {
                status = ""
            }
        },
        pushColors = function(self, key)
            for k, v in pairs(key) do
                r.ImGui_PushStyleColor(self.ctx, k, v)
            end
        end,
        popColors = function(self, key)
            for k in pairs(key) do
                r.ImGui_PopStyleColor(self.ctx)
            end
        end,
        pushStyles = function(self, key)
            for k, v in pairs(key) do
                r.ImGui_PushStyleVar(self.ctx, k, v[1], v[2])
            end
        end,
        popStyles = function(self, key)
            for k in pairs(key) do
                r.ImGui_PopStyleVar(self.ctx)
            end
        end,
        updateModKeys = function(self)
            self.modKeys = ('%s%s%s%s'):format(r.ImGui_IsKeyDown(self.ctx, r.ImGui_Mod_Shift()) and 's' or '',
                r.ImGui_IsKeyDown(self.ctx, r.ImGui_Mod_Alt()) and 'a' or '',
                r.ImGui_IsKeyDown(self.ctx, self.keyModCtrlCmd) and 'c' or '',
                r.ImGui_IsKeyDown(self.ctx, self.notKeyModCtrlCmd) and 'x' or '')
            return self.modKeys
        end
    }
end

gui.setting = function(stType, text, hint, val, data, sameline)
    
    -- generalize
    local halfWidth = 230
    local itemWidth = halfWidth * 2

    local ctx = gui.ctx
    local data = data or {}
    local retval
    local widgetWidth
    if not sameline then
        r.ImGui_BeginGroup(ctx)
        r.ImGui_AlignTextToFramePadding(ctx)
        r.ImGui_PushTextWrapPos(ctx, halfWidth)
        r.ImGui_Text(ctx, text)
        r.ImGui_PopTextWrapPos(ctx)
        r.ImGui_SameLine(ctx)
        r.ImGui_SetCursorPosX(ctx, halfWidth)
        widgetWidth = itemWidth

    else
        r.ImGui_SameLine(ctx)
        r.ImGui_SetCursorPosX(ctx, r.ImGui_GetCursorPosX(ctx) -
            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemInnerSpacing()))
        widgetWidth = itemWidth - gui.TEXT_BASE_WIDTH * 2 - r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) *
                          2
    end
    r.ImGui_PushItemWidth(ctx, widgetWidth)

    if stType == 'combo' then
        _, retval = r.ImGui_Combo(ctx, '##' .. text, val, data.list)
    elseif stType == 'checkbox' then
        _, retval = r.ImGui_Checkbox(ctx, '##' .. text, val)
    elseif stType == 'dragint' then
        _, retval = r.ImGui_DragInt(ctx, '##' .. text, val, data.step, data.min, data.max)
    elseif stType == 'dragdouble' then
        _, retval = r.ImGui_DragDouble(ctx, '##' .. text, val, data.speed, data.min, data.max, data.format)    
        -- format: = "%.3f"
    elseif stType == 'button' then
        retval = r.ImGui_Button(ctx, data.label, widgetWidth)
    elseif stType == 'text' then
        _, retval = r.ImGui_InputText(ctx, '##' .. text, val)
    elseif stType == 'text_with_hint' then
        _, retval = r.ImGui_InputTextWithHint(ctx, '##' .. text, data.hint, val)
    end
    if not sameline then
        r.ImGui_EndGroup(ctx)
    end
    app.setHoveredHint('main', hint)
    return retval, retval_b
end
