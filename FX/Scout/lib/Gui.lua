-- @noindex

PB_Gui = OD_Gui:new({

})

PB_Gui.init = function(self, fonts)
    OD_Gui.addFont(self, 'vertical', 'Resources/Fonts/Cousine-90deg.otf', 11)

    local tiny = 12
    local small = 16
    local default = 18
    local large = 22
    self:createFonts({
        default = { file = 'Resources/Fonts/Cousine-Regular.ttf', size = default },
        bold = { file = 'Resources/Fonts/Cousine-Bold.ttf', size = default },
        -- tiny = { file = 'Resources/Fonts/Cousine-Regular.ttf', size = tiny },
        small = { file = 'Resources/Fonts/Cousine-Regular.ttf', size = small },
        large = { file = 'Resources/Fonts/Cousine-Regular.ttf', size = large },
        large_bold = { file = 'Resources/Fonts/Cousine-Bold.ttf', size = large },
        icons_tiny = { file = 'Resources/Fonts/Icons-Regular.otf', size = tiny },
        icons_small = { file = 'Resources/Fonts/Icons-Regular.otf', size = small },
        icons_large = { file = 'Resources/Fonts/Icons-Regular.otf', size = large }
    })

    OD_Gui.init(self, false)
    self.searchResultsClipper = ImGui.CreateListClipper(self.ctx)
    ImGui.Attach(self.ctx, self.searchResultsClipper)

    self.clearInputIfNeeded = ImGui.CreateFunctionFromEEL([[
    buflen = strlen(#Buf);
    InputTextCallback_DeleteChars(0, buflen);
]])
    ImGui.Attach(self.ctx, self.clearInputIfNeeded)
    -- self.blockNextCharacter = ImGui.CreateFunctionFromEEL([[
    --     EventChar = 0;
    -- ]])
    --     ImGui.Attach(self.ctx, self.blockNextCharacter)

    self.st.basecolors = {
        darkestBG = 0x131313ff,
        darkerBG = 0x212123ff,
        darkBG = 0x242429ff,
        darkHovered = 0x2d2d35ff,
        darkActive = 0x35353cff,
        darkText = 0xcfcfcfff,
        midBG = 0x545454ff,
        midHovered = 0x646464ff,
        midActive = 0x747474ff,
        midText = 0xcfcfcfff,
        header = 0x343434ff,
        headerHovered = 0x545454ff,
        widgetBG = 0x949494ff,
        hovered = 0xa4a4a4ff,
        active = 0xa4a4a4ff,
        main = 0x953745ff,
        mainDarkest = 0x170003ff,
        mainDarker = 0x270f13ff,
        mainDark = 0x371f23ff,
        mainBright = 0xb73849ff,
        mainBrighter = 0xc74859ff,
        mainBrightest = 0xd75869ff,
        textBright = 0xd7d7d7ff,
        textDark = 0x7c7c7cff,
        textDarker = 0x444444ff,
    }
    self.st.colpresets = {
        darkButton = {
            [ImGui.Col_Button] = self.st.basecolors.darkBG,
            [ImGui.Col_ButtonHovered] = self.st.basecolors.darkHovered,
            [ImGui.Col_ButtonActive] = self.st.basecolors.darkActive,
            [ImGui.Col_Text] = self.st.basecolors.widgetBG,
        },
        midButton = {
            [ImGui.Col_Text] = self.st.basecolors.midText,
            [ImGui.Col_Button] = self.st.basecolors.midBG,
            [ImGui.Col_ButtonHovered] = self.st.basecolors.midHovered,
            [ImGui.Col_ButtonActive] = self.st.basecolors.midActive,
        },
        brightButton = {
            [ImGui.Col_Text] = 0x000000ff,
            [ImGui.Col_Button] = self.st.basecolors.widgetBG,
            [ImGui.Col_ButtonHovered] = self.st.basecolors.hovered,
            [ImGui.Col_ButtonActive] = self.st.basecolors.active
        },
    }
    self.st.rounding = 2
    self.st.windowPadding = 8
    -- dofile(p .. 'lib/Gui.lua')
    self.st.col = {
        hint = {
            [ImGui.Col_Text] = 0xCCCCCCff,
        },
        hintError = {
            [ImGui.Col_Text] = 0xFF4444FF,
        },
        buttons = {
            topBarIcon = {
                default = { [ImGui.Col_Text] = self.st.basecolors.midHovered },
                hovered = { [ImGui.Col_Text] = self.st.basecolors.active },
                active = { [ImGui.Col_Text] = self.st.basecolors.midText },
            },
            topBarActiveIcon = {
                default = { [ImGui.Col_Text] = self.st.basecolors.main },
                hovered = { [ImGui.Col_Text] = self.st.basecolors.mainBright },
                active = { [ImGui.Col_Text] = self.st.basecolors.mainBrighter },
            },
            activeFilterAction = {
                default = { [ImGui.Col_Text] = self.st.basecolors.midHovered },
                hovered = { [ImGui.Col_Text] = self.st.basecolors.mainBright },
                active = { [ImGui.Col_Text] = self.st.basecolors.mainBrighter },
            },
            deletePreset = {
            [ImGui.Col_Button] = 0x991d30ff,
            [ImGui.Col_ButtonHovered] = 0xa3273aff,
            [ImGui.Col_ButtonActive] = 0xba364aff,
        },
        
        },
        tagButtons = {
            [ImGui.Col_Text] = self.st.basecolors.main,
            [ImGui.Col_Button] = 0x00000000,
            [ImGui.Col_ButtonHovered] = self.st.basecolors.mainDarker,
            [ImGui.Col_ButtonActive] = self.st.basecolors.mainDark
            -- [ImGui.Col_Border] = 0x00000000
        },
        tag = {
            [ImGui.Col_Text] = self.st.basecolors.textBright,
            [ImGui.Col_FrameBg] = self.st.basecolors.darkBG,
            [ImGui.Col_FrameBgHovered] = self.st.basecolors.darkHovered,
            [ImGui.Col_FrameBgActive] = self.st.basecolors.darkActive
        },
        activeFilterButton = {
            -- [ImGui.Col_Text] = self.st.basecolors.mainBrightest,
            [ImGui.Col_Button] = self.st.basecolors.main,
            [ImGui.Col_ButtonActive] = self.st.basecolors.mainBrighter,
            [ImGui.Col_ButtonHovered] = self.st.basecolors.mainBright,
        },
        searchWindow = {
            [ImGui.Col_TableBorderStrong] = 0x00000000,
            [ImGui.Col_TextSelectedBg] = self.st.basecolors.main,
            [ImGui.Col_Header] = self.st.basecolors.mainDark,
            [ImGui.Col_HeaderHovered] = self.st.basecolors.mainDark,
            [ImGui.Col_Button] = self.st.basecolors.darkBG,
            [ImGui.Col_ButtonHovered] = self.st.basecolors.darkHovered,
            [ImGui.Col_ButtonActive] = self.st.basecolors.darkActive,
        },
        settings = {
            selectable = {
                [true] = {
                    [ImGui.Col_Text] = self.st.basecolors.textBright },
                [false] = {
                    [ImGui.Col_Text] = self.st.basecolors.textDark,
                }

            }
        },
        search = {
            mainResult = {
                [ImGui.Col_Text] = self.st.basecolors.textBright,
            },
            secondaryResult = {
                [ImGui.Col_Text] = self.st.basecolors.textDark,
            },
            thirdResult = {
                [ImGui.Col_Text] = self.st.basecolors.textDarker,
            },
            highlight = {
                [ImGui.Col_Text] = self.st.basecolors.mainBright,
            },
            favorite = {
                [ImGui.Col_Text] = self.st.basecolors.main,
            }
        },
        topBar = {
            [SEARCH_MODE.FILTERS] =
            {
                [ImGui.Col_ChildBg] = 0x21191aff, --self.st.basecolors.mainDarkest,
                [ImGui.Col_FrameBg] = 0x21191aff, --self.st.basecolors.mainDarkest,
                [ImGui.Col_TextDisabled] = self.st.basecolors.midBG
            }
            ,
            [SEARCH_MODE.MAIN] = {
                [ImGui.Col_ChildBg] = self.st.basecolors.darkBG,
                [ImGui.Col_FrameBg] = self.st.basecolors.darkBG,
                [ImGui.Col_TextDisabled] = self.st.basecolors.midBG
            }
        },
        topBarActiveFiltersArea = {
            -- [ImGui.Col_ChildBg] = self.st.basecolors.darkestBG,
            [ImGui.Col_ChildBg] = 0x00000000,
            [ImGui.Col_Button] = self.st.basecolors.darkBG,
            [ImGui.Col_FrameBg] = self.st.basecolors.darkBG
        },
        main = {
            [ImGui.Col_Tab] = self.st.basecolors.darkHovered,
            [ImGui.Col_TabHovered] = self.st.basecolors.darkActive,
            -- [ImGui.Col_TabActive] = self.st.basecolors.darkActive,
            -- [ImGui.Col_TabUnfocused] = self.st.basecolors.darkBG,
            -- [ImGui.Col_TabUnfocusedActive] = self.st.basecolors.darkBG,
            [ImGui.Col_PlotHistogram] = self.st.basecolors.main,
            [ImGui.Col_FrameBg] = self.st.basecolors.darkBG,
            [ImGui.Col_FrameBgHovered] = self.st.basecolors.darkHovered,
            [ImGui.Col_FrameBgActive] = self.st.basecolors.darkActive,
            [ImGui.Col_SliderGrab] = self.st.basecolors.widgetBG,
            [ImGui.Col_SliderGrabActive] = self.st.basecolors.active,
            [ImGui.Col_Text] = self.st.basecolors.textBright,
            [ImGui.Col_TextSelectedBg] = self.st.basecolors.darkActive,
            [ImGui.Col_HeaderHovered] = self.st.basecolors.headerHovered,
            [ImGui.Col_Tab] = self.st.basecolors.darkBG,
            [ImGui.Col_TabSelected] = self.st.basecolors.header,
            [ImGui.Col_TabHovered] = self.st.basecolors.headerHovered,
            [ImGui.Col_TabDimmedSelectedOverline] = self.st.basecolors.header,
            [ImGui.Col_Header] = self.st.basecolors.header,
            [ImGui.Col_Button] = self.st.basecolors.main,
            [ImGui.Col_ButtonHovered] = self.st.basecolors.mainBright,
            [ImGui.Col_ButtonActive] = self.st.basecolors.mainBrighter,
            [ImGui.Col_ResizeGrip] = self.st.basecolors.darkBG,
            [ImGui.Col_ResizeGripHovered] = self.st.basecolors.mainDark,
            [ImGui.Col_ResizeGripActive] = self.st.basecolors.main,
            [ImGui.Col_ScrollbarBg] = 0x00000000,
            [ImGui.Col_ScrollbarGrabHovered] = self.st.basecolors.main,
            [ImGui.Col_ScrollbarGrabActive] = self.st.basecolors.mainBright,
            [ImGui.Col_SeparatorHovered] = self.st.basecolors.main,
            [ImGui.Col_SeparatorActive] = self.st.basecolors.mainBright,
            [ImGui.Col_TitleBgActive] = self.st.basecolors.mainDark,
            [ImGui.Col_CheckMark] = self.st.basecolors.main,
            [ImGui.Col_HeaderActive] = self.st.basecolors.main,
            [ImGui.Col_DragDropTarget] = self.st.basecolors.mainBright,
            [ImGui.Col_WindowBg] = 0x181818FF,
        },
        title = {
            [ImGui.Col_Text] = self.st.basecolors.mainBright,
        },
        titleUnfocused = {
            [ImGui.Col_Text] = self.st.basecolors.textDark,
        },

        zoomSlider = {
            [ImGui.Col_SliderGrab] = self.st.basecolors.main,
            [ImGui.Col_SliderGrabActive] = self.st.basecolors.mainBright,
        }
    }

    self.updateVarsToScale = function(self)
        local scale = self.scale
        self.st.vars = {
            main = {
                [ImGui.StyleVar_FrameRounding] = { self.st.rounding * scale, nil },
                [ImGui.StyleVar_ItemSpacing] = { 4 * scale, 4 * scale },
                [ImGui.StyleVar_WindowRounding] = { 12 * scale, nil },
                -- [ImGui.StyleVar_WindowPadding] = { 0 * scale, 0 * scale },
                [ImGui.StyleVar_WindowPadding] = { self.st.windowPadding * scale, self.st.windowPadding * scale },
                [ImGui.StyleVar_ScrollbarSize] = { 15 * scale, nil },
                [ImGui.StyleVar_FramePadding] = { 4 * scale, 3 * scale },
                [ImGui.StyleVar_ItemInnerSpacing] = { 4 * scale, 4 * scale },
                [ImGui.StyleVar_SeparatorTextBorderSize] = { 1 * scale, nil },
            },
            popupsTitle = {
                [ImGui.StyleVar_FramePadding] = { 4 * scale, 10 * scale },
            },
            topBar = {
                [ImGui.StyleVar_FrameRounding] = { 12 * scale, nil },
                [ImGui.StyleVar_WindowPadding] = { self.st.windowPadding * scale, self.st.windowPadding * scale },
                [ImGui.StyleVar_ChildRounding] = { 12 * scale, nil },
                -- [ImGui.StyleVar_Wind] = { 10 * scale, 30 },
            },
            topBarActiveFiltersArea = {
                [ImGui.StyleVar_FrameRounding] = { 12 * scale, nil },
                [ImGui.StyleVar_ChildRounding] = { 12 * scale, nil },
                [ImGui.StyleVar_ItemSpacing] = { select(1, ImGui.GetStyleVar(self.ctx, ImGui.StyleVar_ItemSpacing)), 0 },
                [ImGui.StyleVar_FramePadding] = { self.st.windowPadding * scale, 3 * scale },
                -- [ImGui.StyleVar_Wind] = { 10 * scale, 30 },
            },
            topBarActiveFiltersAreaCloseButton = {
                [ImGui.StyleVar_FramePadding] = { 0, 3 * scale },
                -- [ImGui.StyleVar_Wind] = { 10 * scale, 30 },
            },
            searchWindow = {
                -- [ImGui.StyleVar_WindowPadding] = { 0 * scale, self.st.windowPadding * scale },
                -- [ImGui.stylevar_child] = { 0 * scale, self.st.windowPadding * scale },
                -- [ImGui.StyleVar_ItemSpa] = { 0, 20 },
                [ImGui.StyleVar_FrameRounding] = { 12 * scale, nil },
                [ImGui.StyleVar_SeparatorTextAlign] = { 0, 0 },
                [ImGui.StyleVar_SeparatorTextBorderSize] = { 1 * scale, nil },
                [ImGui.StyleVar_SeparatorTextPadding] = { 0, 0 },
            },
            tag = {
                [ImGui.StyleVar_FrameRounding] = { 20 * scale, nil },
                [ImGui.StyleVar_FramePadding] = { 8 * scale, 0 },
            },
            tagButtons = {
                [ImGui.StyleVar_FrameRounding] = { 100 * scale, nil },
                [ImGui.StyleVar_FramePadding] = { 2 * scale, 2 * scale },
                [ImGui.StyleVar_ItemSpacing] = { 0, 0 }
                -- [ImGui.StyleVar_FrameBorderSize] = {2, nil },
            },
            tagList = {
                [ImGui.StyleVar_IndentSpacing] = { 12 * scale, nil },
            },

            bigButton = {
                [ImGui.StyleVar_FrameRounding] = { 10 * scale, nil },
                [ImGui.StyleVar_FramePadding] = { 20 * scale, 10 * scale },
            },
            zoomSlider = {
                [ImGui.StyleVar_GrabMinSize] = { 8 * scale, nil },
                [ImGui.StyleVar_FramePadding] = { -1 * scale, -1 * scale },
                [ImGui.StyleVar_GrabRounding] = { 100 * scale, nil },
                [ImGui.StyleVar_FrameRounding] = { 100 * scale, nil },
            }
        }
    end

    self.updateCachedTextHeightsToScale = function(self)
        ImGui.PushFont(self.ctx, self.st.fonts.vertical)
        self.VERTICAL_TEXT_BASE_WIDTH, self.VERTICAL_TEXT_BASE_HEIGHT = ImGui.CalcTextSize(self.ctx, 'A')
        self.VERTICAL_TEXT_BASE_HEIGHT_OFFSET = -2
        ImGui.PopFont(self.ctx)
    end

    self.updateSizesToScale = function(self)
        ImGui.PushFont(self.ctx, self.st.fonts.default) -- hint font! important!
        self.st.sizes = {
            sendTypeSeparatorWidth = self.TEXT_BASE_HEIGHT,
            sendTypeSeparatorHeight = 95 * self.scale,
            minFaderHeight = 100 * self.scale,
            mixerSeparatorWidth = 4 * self.scale,
            hintHeight = ImGui.GetTextLineHeightWithSpacing(self.ctx) +
                select(2, ImGui.GetStyleVar(self.ctx, ImGui.StyleVar_ItemSpacing)) +
                select(2, ImGui.GetStyleVar(self.ctx, ImGui.StyleVar_FramePadding)) * 2
        }
        ImGui.PopFont(self.ctx)
    end
    self.recalculateZoom = function(self, scale)
        -- local scale = self:getNormalizedScale(scale, self.st.fonts.default)
        if self.scale ~= scale then
            local change = scale /
                (self.scale or scale) -- return change to allow for scaling of other elements (eg. Resize window)
            self.scale = scale

            self:reAddFonts()

            self:updateVarsToScale()
            self:pushStyles(self.st.vars.main)
            OD_Gui.recalculateZoom(self, scale)
            self:updateCachedTextHeightsToScale()
            self:updateSizesToScale()
            self:popStyles(self.st.vars.main)
            return change
        end
        return 1
    end

    self:recalculateZoom(self.app.settings.current.uiScale)


    self.drawSadFace = function(self, sizeFactor, color)
        local x, y = ImGui.GetCursorScreenPos(self.ctx)
        local sz = self.TEXT_BASE_WIDTH * sizeFactor
        -- local sz = 20 * sizeFactor * self.scale
        ImGui.DrawList_AddCircleFilled(self.draw_list, x, y, sz, color, 36)
        ImGui.DrawList_AddCircleFilled(self.draw_list, x - sz / 3.5, y - sz / 5, sz / 9, 0x000000ff, 36)
        ImGui.DrawList_AddCircleFilled(self.draw_list, x + sz / 3.5, y - sz / 5, sz / 9, 0x000000ff, 36)
        ImGui.DrawList_AddLine(self.draw_list, x + sz / 2, y + sz / 10, x - sz / 2, y + sz / 2.5, 0x000000ff, sz / 9)
    end

    self.drawVerticalText = function(self, drawList, text, x, y, color, yIsTop, xIsRight)
        local color = color or 0xffffffff
        ImGui.PushFont(self.ctx, self.st.fonts.vertical)
        local letterspacing = (self.VERTICAL_TEXT_BASE_HEIGHT + self.VERTICAL_TEXT_BASE_HEIGHT_OFFSET)
        if yIsTop then
            y = y + letterspacing * #text
        end
        if xIsRight then
            x = x - self.VERTICAL_TEXT_BASE_WIDTH
        end
        local posX, posY = (x or select(1, ImGui.GetCursorScreenPos(self.ctx))),
            (y or select(2, ImGui.GetCursorScreenPos(self.ctx))) - letterspacing * #text
        text = text:reverse()
        for ci = 1, #text do
            ImGui.DrawList_AddText(drawList, posX, posY + letterspacing * (ci - 1), color, text:sub(ci, ci))
        end
        ImGui.PopFont(self.ctx)
    end

    self.setting = function(self, stType, text, hint, val, data, sameline)
        local ctx = self.ctx
        local w, h = ImGui.GetWindowSize(ctx)
        local thirdWidth = w / 2.5
        local itemWidth = thirdWidth * 1.5 - ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding) * 2
        local data = data or {}
        local retval1, retval2
        local widgetWidth
        if not sameline then
            ImGui.BeginGroup(ctx)
            ImGui.AlignTextToFramePadding(ctx)
            ImGui.PushTextWrapPos(ctx, thirdWidth)
            ImGui.Text(ctx, text)
            if data.help then
                ImGui.SameLine(ctx)
                ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing))
                ImGui.PushFont(ctx, self.st.fonts.icons_small)
                ImGui.TextColored(ctx, self.st.basecolors.textDarker, ICONS.QUESTION_CIRCLE)
                ImGui.PopFont(ctx)
                if ImGui.IsItemHovered(ctx) then
                    ImGui.SetTooltip(ctx, data.help)
                end
            end
            ImGui.PopTextWrapPos(ctx)
            ImGui.SameLine(ctx)
            if stType == 'orderable_list' then
                local x, y = ImGui.GetCursorPos(ctx)
                ImGui.Spacing(ctx)
                ImGui.PushStyleColor(ctx, ImGui.Col_Text, self.st.basecolors.textDark)
                ImGui.Text(ctx, 'Drag to reorder')
                ImGui.Text(ctx, 'Alt-click to disable')
                ImGui.PopStyleColor(ctx)
                ImGui.SetCursorPos(ctx, x, y)
            end
            ImGui.SetCursorPosX(ctx, thirdWidth)
            widgetWidth = data.width or ImGui.GetContentRegionAvail(ctx) --itemWidth
        else
            ImGui.SameLine(ctx)
            widgetWidth = ImGui.GetContentRegionAvail(ctx)
            -- widgetWidth = itemWidth - ImGui.GetTextLineHeight(ctx) -
            --     ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing) * 2
        end
        if data.divideWidth then
            widgetWidth = widgetWidth / data.divideWidth -
                ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing) * (data.divideWidth - 1)
        end
        ImGui.PushItemWidth(ctx, data.width or widgetWidth)

        if stType == 'combo' then
            _, retval1 = ImGui.Combo(ctx, '##' .. text, val, data.list)
        elseif stType == 'label' then
            ImGui.Dummy(ctx, 0, 0)
        elseif stType == 'checkbox' then
            _, retval1 = ImGui.Checkbox(ctx, '##' .. text, val)
        elseif stType == 'dragint' then
            _, retval1 = ImGui.DragInt(ctx, '##' .. text, val, data.step, data.min, data.max)
        elseif stType == 'dragdouble' then
            if data.dontUnpdateWhileEnteringManually then
                self.app.temp.tempSettingsVal = self.app.temp.tempSettingsVal or {}
                self.app.temp.tempSettingsVal[text] = self.app.temp.tempSettingsVal[text] or val
            end
            _, retval1 = ImGui.DragDouble(ctx, '##' .. text,
                data.dontUnpdateWhileEnteringManually and self.app.temp.tempSettingsVal[text] or val, data.speed,
                data.min, data.max,
                data.format, data.flags or 0)
            if data.dontUnpdateWhileEnteringManually then
                if ImGui.IsItemActive(ctx) and not ImGui.IsMouseDragging(ctx, ImGui.MouseButton_Left) then
                    self.app.temp.tempSettingsVal[text] = retval1
                    retval1 = val
                else
                    self.app.temp.tempSettingsVal[text] = nil
                end
            end
        elseif stType == 'button' then
            retval1 = ImGui.Button(ctx, data.label, widgetWidth)
        elseif stType == 'file' then
            retval1 = val
            if ImGui.Button(ctx, val or data.label or 'Browse...', widgetWidth) then
                local rv, file = r.GetUserFileNameForRead(data.filename or '', data.title or '', data.defext or '');
                retval1 = rv and file or nil
            end
        elseif stType == 'folder' then
            retval1 = val
            if ImGui.Button(ctx, val or data.label or 'Browse...', widgetWidth) then
                local rv, folder = r.JS_Dialog_BrowseForFolder(data.title or '', data.initialPath);
                retval1 = rv == 1 and folder or nil
            end
        elseif stType == 'text' then
            _, retval1 = ImGui.InputText(ctx, '##' .. text, val)
        elseif stType == 'oneCharacter' then
            if not ImGui.ValidatePtr(self.oneCharacterCallback, 'ImGui_Function*') then
                self.oneCharacterCallback = ImGui.CreateFunctionFromEEL([[
    buflen = strlen(#Buf);
    c = str_getchar(#Buf, buflen-1);
    // Only allow alphanumeric characters
    ((c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) ? (
        // Valid character - convert to uppercase if needed and keep only this one
        (c >= 'a' && c <= 'z') ? (
            str_setchar(#first, 0, c ~ 32);
        ) : (
            str_setchar(#first, 0, c);
        );
        str_setlen(#first, 1);
        InputTextCallback_DeleteChars(0, buflen);
        InputTextCallback_InsertChars(0, #first);
    ) : (
        // Not alphanumeric, delete all characters (reject input)
        InputTextCallback_DeleteChars(0, buflen);
    );
]])
            end
            _, retval1 = ImGui.InputText(ctx, '##' .. text, val, ImGui.InputTextFlags_CallbackEdit,
                self.oneCharacterCallback)
        elseif stType == 'colorpicker' then
            hint = data.default and (hint .. ' alt-click to reset to default.') or hint
            retval1 = val
            if ImGui.ColorButton(ctx, '##' .. text, val, ImGui.ColorEditFlags_None, widgetWidth) then
                if data.default and ImGui.IsKeyDown(ctx, ImGui.Mod_Alt) then
                    retval1 = data.default
                else
                    ImGui.OpenPopup(ctx, '##ColorPicker' .. text)
                end
            end
            ImGui.SetNextWindowPos(ctx, ImGui.GetMousePos(ctx), select(2, ImGui.GetMousePos(ctx)), ImGui.Cond_Appearing,
                0, 1)
            if ImGui.BeginPopup(ctx, '##ColorPicker' .. text) then
                local rv, tmp = ImGui.ColorPicker4(ctx, '##' .. text, val)
                if rv then retval1 = tmp end
                ImGui.EndPopup(ctx)
            end
        elseif stType == 'text_with_hint' then
            _, retval1 = ImGui.InputTextWithHint(ctx, '##' .. text, data.hint, val)
        elseif stType == 'shortcut' then
            hint = hint .. ' alt-click to remove shortcut.'
            if val and (val.key == -1) then val = nil end
            local label, newVal
            if self.app.temp._capturing == text then
                label = '...'
                retval2 = true
                hint = 'Press a key combination, or click to cancel'
                local key = OD_GetKeyPressed(OD_KEYCODES['0'], OD_KEYCODES['Z'], true) or
                    OD_GetKeyPressed(OD_KEYCODES['NUMPAD0'], OD_KEYCODES['F24'], true) or
                    OD_GetKeyPressed(OD_KEYCODES['ESCAPE'], OD_KEYCODES['DOWN'], true)
                if key then
                    local testVal = {
                        key = key,
                        ctrl = OD_IsGlobalKeyDown(OD_KEYCODES.CONTROL),
                        shift = OD_IsGlobalKeyDown(OD_KEYCODES.SHIFT),
                        alt = OD_IsGlobalKeyDown(OD_KEYCODES.ALT),
                        macCtrl = (_OD_ISMAC and OD_IsGlobalKeyDown(OD_KEYCODES.STARTKEY))
                    }
                    for k, v in pairs(data.existingShortcuts or {}) do
                        if v.key == testVal.key and v.ctrl == testVal.ctrl and v.shift == testVal.shift and v.alt == testVal.alt and v.macCtrl == testVal.macCtrl then
                            testVal = nil
                            self.app:msg('Shortcut already in use')
                            break
                        end
                    end
                    if testVal then
                        newVal = testVal
                        self.app.temp._capturing = nil
                    end
                end
            else
                if val ~= nil and OD_IsGlobalKeyDown(OD_KEYCODES.ALT) then
                    label = 'Click to remove shortcut'
                elseif val == nil then
                    label = 'Click to set shortcut'
                else
                    label = OD_KEYCODE_NAMES[val.key]
                    if val.macCtrl then label = OD_KEYCODE_NAMES[OD_KEYCODES.STARTKEY] .. '+' .. label end
                    if val.ctrl then label = OD_KEYCODE_NAMES[OD_KEYCODES.CONTROL] .. '+' .. label end
                    if val.shift then label = OD_KEYCODE_NAMES[OD_KEYCODES.SHIFT] .. '+' .. label end
                    if val.alt then label = OD_KEYCODE_NAMES[OD_KEYCODES.ALT] .. '+' .. label end
                end
            end
            ImGui.PushStyleColor(ctx, ImGui.Col_Button, ImGui.GetStyleColor(ctx, ImGui.Col_FrameBg))
            if ImGui.Button(ctx, label .. '##' .. text, widgetWidth) then
                if self.app.temp._capturing == text then
                    self.app.temp._capturing = nil
                else
                    if OD_IsGlobalKeyDown(OD_KEYCODES.ALT) then
                        if val ~= nil then val = nil end
                    else
                        self.app.temp._capturing = text
                    end
                end
            end
            ImGui.PopStyleColor(ctx)
            if val == nil then val = { key = -1, ctrl = false, shift = false, alt = false } end
            retval1 = newVal or val
        elseif stType == 'orderable_list' then
            -- ImGui.Dummy(ctx, widgetWidth, 20)
            local orderList, enabledList = val[1], val[2]
            if ImGui.BeginListBox(ctx, '##' .. text, widgetWidth, #orderList * self.TEXT_BASE_HEIGHT + select(1, ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding))) then
                for i, v in ipairs(orderList) do
                    self:pushColors(self.st.col.settings.selectable[enabledList[v]])
                    local label = T.SETTINGS.LISTS[text] and T.SETTINGS.LISTS[text][v] or v
                    if ImGui.Selectable(ctx, label, false) then
                        if ImGui.IsKeyDown(ctx, ImGui.Mod_Alt) then
                            enabledList[v] = not enabledList[v]
                        end
                    end
                    self:popColors(self.st.col.settings.selectable[enabledList[v]])
                    if ImGui.BeginDragDropSource(ctx) then
                        ImGui.SetDragDropPayload(ctx, text, i)
                        ImGui.EndDragDropSource(ctx)
                    end
                    if ImGui.BeginDragDropTarget(ctx) then
                        local payload, data = ImGui.AcceptDragDropPayload(ctx, text)
                        if payload then
                            local oldIdx = tonumber(data)
                            table.insert(orderList, i, table.remove(orderList, oldIdx))
                        end
                        ImGui.EndDragDropTarget(ctx)
                    end
                end
                ImGui.EndListBox(ctx)
            end
            retval1 = orderList
            retval2 = enabledList
            -- _, retval1 = ImGui.InputTextWithHint(ctx, '##' .. text, data.hint, val)
        end
        if not sameline then
            ImGui.EndGroup(ctx)
        end
        self.app:setHoveredHint(data.hintWindow or 'settings', hint)
        return retval1, retval2
    end
end
