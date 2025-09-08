-- @noindex
package.path = r.ImGui_GetBuiltinPath() .. '/?.lua'
ImGui = require 'imgui' '0.9.1'

PA_Gui = OD_Gui:new({

})
PA_Gui.init = function(self, fonts)
    do
        -- these needs to be temporarily created to be refered to from some of the gui vars
        local ctx = r.ImGui_CreateContext(Scr.context_name .. '_MAIN')--, reaper.ImGui_ConfigFlags_DockingEnable())
        local font_default = r.ImGui_CreateFont(OD_LocalOrCommon('Resources/Fonts/Cousine-Regular.ttf', Scr.dir), 16)
        r.ImGui_Attach(ctx, font_default)
        
        self.ctx = ctx
        self.mainWindow = {}
        self.draw_list = r.ImGui_GetWindowDrawList(ctx)
        self.st = {
            fonts = {
                default = font_default
            },
            col = {
                warning = 0xf58e07FF,
                ok = 0X55FF55FF,
                critical = 0xDD0000FF,
                error = 0xFF5555FF,
                hint = 0xCCCCCCFF,
            }
        }
        self.popups = {
            singleInput = {
                status = ""
            }
        }
        self.pushColors = function(self, key)
                for k, v in pairs(key) do
                    r.ImGui_PushStyleColor(self.ctx, k, v)
                end
            end
        self.popColors = function(self, key)
            for k in pairs(key) do
                r.ImGui_PopStyleColor(self.ctx)
            end
        end
        self.pushStyles = function(self, key)
            for k, v in pairs(key) do
                r.ImGui_PushStyleVar(self.ctx, k, v[1], v[2])
            end
        end
        self.popStyles = function(self, key)
            for k in pairs(key) do
                r.ImGui_PopStyleVar(self.ctx)
            end
        end
        self.updateModKeys = function(self)
            self.modKeys = ('%s%s%s%s'):format(r.ImGui_IsKeyDown(self.ctx, r.ImGui_Mod_Shift()) and 's' or '',
                r.ImGui_IsKeyDown(self.ctx, r.ImGui_Mod_Alt()) and 'a' or '',
                r.ImGui_IsKeyDown(self.ctx, self.keyModCtrlCmd) and 'c' or '',
                r.ImGui_IsKeyDown(self.ctx, self.notKeyModCtrlCmd) and 'x' or '')
            return self.modKeys
        end

        r.ImGui_PushFont(ctx, self.st.fonts.default)
        self.TEXT_BASE_WIDTH, self.TEXT_BASE_HEIGHT = r.ImGui_CalcTextSize(ctx, 'A'),
            r.ImGui_GetTextLineHeightWithSpacing(ctx)
        r.ImGui_PopFont(ctx)

        self.icons = {
            caution = r.ImGui_CreateImage(OD_LocalOrCommon('Resources/Icons/caution.png', Scr.dir)),
            error = r.ImGui_CreateImage(OD_LocalOrCommon('Resources/Icons/error.png', Scr.dir))
        }
        r.ImGui_Attach(ctx, self.icons.caution)
        r.ImGui_Attach(ctx, self.icons.error)

    end

    -- creates the space of one "setting" line
    self.settingSpacing = function()
        local ctx = self.ctx
        r.ImGui_AlignTextToFramePadding(ctx)
        r.ImGui_Spacing(ctx)
    end

    self.setting = function(stType, text, hint, val, data, sameline)
        -- generalize
        local ctx = self.ctx
        local thirdWidth = self.mainWindow.size[1] / 3
        local itemWidth = thirdWidth * 2 - r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2

        local data = data or {}
        local retval
        local widgetWidth
        if not sameline then
            r.ImGui_BeginGroup(ctx)
            r.ImGui_AlignTextToFramePadding(ctx)
            r.ImGui_PushTextWrapPos(ctx, thirdWidth)
            r.ImGui_Text(ctx, text)
            r.ImGui_PopTextWrapPos(ctx)
            r.ImGui_SameLine(ctx)
            r.ImGui_SetCursorPosX(ctx, thirdWidth)
            widgetWidth = itemWidth
        else
            r.ImGui_SameLine(ctx)
            r.ImGui_SetCursorPosX(ctx, r.ImGui_GetCursorPosX(ctx) -
                r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemInnerSpacing()))
            widgetWidth = itemWidth - self.TEXT_BASE_WIDTH * 2 - r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2
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
        elseif stType == 'file' then
            retval = val
            if r.ImGui_Button(ctx, val or data.label or 'Browse...', widgetWidth) then
                local rv, file = r.GetUserFileNameForRead(data.filename or '', data.title or '', data.defext or '');
                retval = rv and file or nil
            end
        elseif stType == 'folder' then
            retval = val
            if r.ImGui_Button(ctx, val or data.label or 'Browse...', widgetWidth) then
                local rv, folder = r.JS_Dialog_BrowseForFolder(data.title or '', data.initialPath);
                retval = rv == 1 and folder or nil
            end
        elseif stType == 'text' then
            _, retval = r.ImGui_InputText(ctx, '##' .. text, val)
        elseif stType == 'text_with_hint' then
            _, retval = r.ImGui_InputTextWithHint(ctx, '##' .. text, data.hint, val)
        end
        if not sameline then
            r.ImGui_EndGroup(ctx)
        end
        self.app:setHoveredHint('main', hint)
        return retval
    end

    self.bitwise_setting = function(stType, val, list)
        if not OD_HasValue({ "checkbox" }, stType) then
            return
        end
        local tmpVal = val
        for bwVal, option in OD_PairsByOrder(list) do
            local op = self.setting(stType, option.label, option.hint, (val & bwVal ~= 0))
            tmpVal = OD_BfSet(tmpVal, bwVal, op)
        end

        return tmpVal
    end

    function self.settingIcon(icon, text)
        local ctx = self.ctx
        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FramePadding(),0,0)
        local origX, origY = r.ImGui_GetCursorPos(ctx)
        local yOffset = 3
        local xOffset = 4
        local img_w, img_h = r.ImGui_Image_GetSize(icon)
        local w = 15
        local h = img_h * (w / img_w) 
        r.ImGui_SetCursorPosY(ctx, origY + yOffset)
        r.ImGui_SetCursorPosX(ctx, origX + xOffset)
        r.ImGui_Image(ctx, icon, w, h)
        if r.ImGui_IsItemHovered(ctx, r.ImGui_HoveredFlags_AllowWhenDisabled()) then
        r.ImGui_SetTooltip(ctx, text)
        end
        r.ImGui_SetCursorPosY(ctx, origY)
        r.ImGui_SetCursorPosX(ctx, origX+ r.ImGui_GetTreeNodeToLabelSpacing(ctx) + r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()))
        r.ImGui_PopStyleVar(ctx)
    end
end