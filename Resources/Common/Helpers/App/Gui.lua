-- @noindex
-- ! OD_Gui

OD_Gui = {
    font = nil,
    mainWindow = { min_w = 0, min_h = 0, max_w = select(2, reaper.ImGui_NumericLimits_Float()), max_h = select(2, reaper.ImGui_NumericLimits_Float()) },
    st = {
        col = {
            warning = 0xf58e07FF,
            ok = 0X55FF55FF,
            critical = 0xDD0000FF,
            error = 0xFF5555FF,
            hint = 0xCCCCCCFF,
        }
    },
    reaperHWND = reaper.GetMainHwnd()
}

function OD_Gui:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

function OD_Gui:createFonts(fonts)
    for k, font in pairs(fonts) do
        self:addFont(k, font.file, font.size)
    end
end

function OD_Gui:addFont(key, file, size, recalculation)
    if not recalculation then
        self.originalFonts = self.originalFonts or {}
        self.originalFonts[key] = { file = file, size = size } -- save for recalculating zoom later
    end
    self.st.fonts = self.st.fonts or {}
    local scale =  self.app.settings.current.uiScale 
    self.st.fonts[key] = r.ImGui_CreateFont(OD_LocalOrCommon(file, self.app.scr.dir), math.floor(size * scale))
end

function OD_Gui:reAddFonts()
    for key, font in pairs(self.originalFonts) do
        r.ImGui_Detach(self.ctx, self.st.fonts[key])
        self:addFont(key, font.file, font.size)
        r.ImGui_Attach(self.ctx, self.st.fonts[key])
    end
end

function OD_Gui:init(addDefaultFonts)
    local addDefaultFonts = (addDefaultFonts == nil) and (not self.st.fonts) or addDefaultFonts
    if addDefaultFonts then
        local small = 16
        local default = 18
        local medium = 20
        local large = 22
        self:createFonts({
            default = { file = 'Resources/Fonts/Cousine-Regular.ttf', size = default },
            small = { file = 'Resources/Fonts/Cousine-Regular.ttf', size = small },
            medium = { file = 'Resources/Fonts/Cousine-Regular.ttf', size = medium },
            large = { file = 'Resources/Fonts/Cousine-Regular.ttf', size = large },
            bold = { file = 'Resources/Fonts/Cousine-Bold.ttf', size = default },
            small_bold = { file = 'Resources/Fonts/Cousine-Bold.ttf', size = small },
            medium_bold = { file = 'Resources/Fonts/Cousine-Bold.ttf', size = medium },
            large_bold = { file = 'Resources/Fonts/Cousine-Bold.ttf', size = large },
            icons = { file = 'Resources/Fonts/Icons-Regular.otf', size = default },
            icons_small = { file = 'Resources/Fonts/Icons-Regular.otf', size = small },
            icons_medium = { file = 'Resources/Fonts/Icons-Regular.otf', size = medium },
            icons_large = { file = 'Resources/Fonts/Icons-Regular.otf', size = large }
        })
    end

    self.ctx = r.ImGui_CreateContext(self.app.scr.context_name) --, reaper.ImGui_ConfigFlags_DockingEnable())
    for k, font in pairs(self.st.fonts) do
        r.ImGui_Attach(self.ctx, font)
    end
    self.draw_list = r.ImGui_GetWindowDrawList(self.ctx)
    self.keyModCtrlCmd = (OS_is.mac or OS_is.mac_arm) and r.ImGui_Mod_Super() or r.ImGui_Mod_Ctrl()
    self.notKeyModCtrlCmd = (OS_is.mac or OS_is.mac_arm) and r.ImGui_Mod_Ctrl() or r.ImGui_Mod_Super()
    self.descModCtrlCmd = (OS_is.mac or OS_is.mac_arm) and 'cmd' or 'control'
    self.descModAlt = (OS_is.mac or OS_is.mac_arm) and 'opt' or 'alt'

    self.popups = {
        singleInput = {
            status = ""
        }
    }

    self.icons = {
        caution = r.ImGui_CreateImage(OD_LocalOrCommon('Resources/Icons/caution.png', self.app.scr.dir)),
        error = r.ImGui_CreateImage(OD_LocalOrCommon('Resources/Icons/error.png', self.app.scr.dir))
    }

    r.ImGui_Attach(self.ctx, self.icons.caution)
    r.ImGui_Attach(self.ctx, self.icons.error)

end

OD_Gui.recalculateZoom = function(self, scale)
    OD_Gui.updateCachedTextHeightsToScale(self)
end

OD_Gui.reloadZoomFonts = function(self) -- FIND A SMART WAY TO USE THIS
    for key, font in pairs(self.originalFonts) do
        r.ImGui_Detach(self.ctx, self.st.fonts[key])
        self:addFont(key, font.file, font.size, true)
        r.ImGui_Attach(self.ctx, self.st.fonts[key])
    end
    self:updateCachedTextHeightsToScale()
end

OD_Gui.updateCachedTextHeightsToScale = function(self)

    if self.st.fonts.default then
        r.ImGui_PushFont(self.ctx, self.st.fonts.default)
        self.TEXT_BASE_WIDTH, self.TEXT_BASE_HEIGHT = r.ImGui_CalcTextSize(self.ctx, 'A'),
            r.ImGui_GetTextLineHeightWithSpacing(self.ctx)
        r.ImGui_PopFont(self.ctx)
    end
    if self.st.fonts.small then
        r.ImGui_PushFont(self.ctx, self.st.fonts.small)
        self.TEXT_BASE_WIDTH_SMALL, self.TEXT_BASE_HEIGHT_SMALL = r.ImGui_CalcTextSize(self.ctx, 'A'),
            r.ImGui_GetTextLineHeightWithSpacing(self.ctx)
        r.ImGui_PopFont(self.ctx)
    end
    if self.st.fonts.medium then
        r.ImGui_PushFont(self.ctx, self.st.fonts.medium)
        self.TEXT_BASE_WIDTH_MEDIUM, self.TEXT_BASE_HEIGHT_MEDIUM = r.ImGui_CalcTextSize(self.ctx, 'A'),
            r.ImGui_GetTextLineHeightWithSpacing(self.ctx)
        r.ImGui_PopFont(self.ctx)
    end
    if self.st.fonts.bold then
        r.ImGui_PushFont(self.ctx, self.st.fonts.bold)
        self.TEXT_BASE_WIDTH_BOLD, self.TEXT_BASE_HEIGHT_BOLD = r.ImGui_CalcTextSize(self.ctx, 'A'),
            r.ImGui_GetTextLineHeightWithSpacing(self.ctx)
        r.ImGui_PopFont(self.ctx)
    end
    if self.st.fonts.large then
        r.ImGui_PushFont(self.ctx, self.st.fonts.large)
        self.TEXT_BASE_WIDTH_LARGE, self.TEXT_BASE_HEIGHT_LARGE = r.ImGui_CalcTextSize(self.ctx, 'A'),
            r.ImGui_GetTextLineHeightWithSpacing(self.ctx)
        r.ImGui_PopFont(self.ctx)
    end
    if self.st.fonts.large_bold then
        r.ImGui_PushFont(self.ctx, self.st.fonts.large_bold)
        self.TEXT_BASE_WIDTH_LARGE_BOLD, self.TEXT_BASE_HEIGHT_LARGE_BOLD = r.ImGui_CalcTextSize(self.ctx, 'A'),
            r.ImGui_GetTextLineHeightWithSpacing(self.ctx)
        r.ImGui_PopFont(self.ctx)
    end
end

function OD_Gui:pushColors(key)
    for k, v in pairs(key) do
        r.ImGui_PushStyleColor(self.ctx, k, v)
    end
end

function OD_Gui:popColors(key)
    for k in pairs(key) do
        r.ImGui_PopStyleColor(self.ctx)
    end
end

function OD_Gui:pushStyles(key)
    for k, v in pairs(key) do
        r.ImGui_PushStyleVar(self.ctx, k, v[1], v[2])
    end
end

function OD_Gui:popStyles(key)
    for k in pairs(key) do
        r.ImGui_PopStyleVar(self.ctx)
    end
end

function OD_Gui:updateModKeys()
    self.modKeys = ('%s%s%s%s'):format(r.ImGui_IsKeyDown(self.ctx, r.ImGui_Mod_Shift()) and 's' or '',
        r.ImGui_IsKeyDown(self.ctx, r.ImGui_Mod_Alt()) and 'a' or '',
        r.ImGui_IsKeyDown(self.ctx, self.keyModCtrlCmd) and 'c' or '',
        r.ImGui_IsKeyDown(self.ctx, self.notKeyModCtrlCmd) and 'x' or '')
    return self.modKeys
end

-- creates the space of one "setting" line
function OD_Gui:settingSpacing()
    r.ImGui_AlignTextToFramePadding(self.ctx)
    r.ImGui_Spacing(self.ctx)
end

function OD_Gui:setting(stType, text, hint, val, data, sameline)
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
        widgetWidth = itemWidth - ImGui.GetTextLineHeight(ctx) -
            r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()) * 2
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

function OD_Gui:bitwise_setting(stType, val, list)
    if not OD_HasValue({ "checkbox" }, stType) then
        return
    end
    local tmpVal = val
    for bwVal, option in OD_PairsByOrder(list) do
        local op = self:setting(stType, option.label, option.hint, (val & bwVal ~= 0))
        tmpVal = OD_BfSet(tmpVal, bwVal, op)
    end

    return tmpVal
end

function OD_Gui:settingIcon(icon, text)
    local ctx = self.ctx
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FramePadding(), 0, 0)
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
    r.ImGui_SetCursorPosX(ctx,
        origX + r.ImGui_GetTreeNodeToLabelSpacing(ctx) + r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing()))
    r.ImGui_PopStyleVar(ctx)
end
