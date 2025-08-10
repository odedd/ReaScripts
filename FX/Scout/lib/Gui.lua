-- @noindex

PB_Gui = OD_Gui:new({

})

PB_Gui.init = function(self, fonts)
    self.scaledFonts = {}
    self:createFontsImGui010({
        -- default = { },
        default = { file = 'Resources/Fonts/Cousine-Regular.ttf' },
        bold = { file = 'Resources/Fonts/Cousine-Regular.ttf', flags = ImGui.FontFlags_Bold },
        -- default = {},
        -- bold = { flags = ImGui.FontFlags_Bold },
        icons = { file = 'Resources/Fonts/Icons-Regular.otf' },
    }, { default = 18, small = 16, smaller = 14, tiny = 12, large = 22 })

    OD_Gui.init(self)

    self.searchTagsFilter = ImGui.CreateTextFilter('')
    ImGui.Attach(self.ctx, self.searchTagsFilter)

    self.searchResultsClipper = ImGui.CreateListClipper(self.ctx)
    ImGui.Attach(self.ctx, self.searchResultsClipper)

    self.clearInputIfNeeded = ImGui.CreateFunctionFromEEL([[
    buflen = strlen(#Buf);
    InputTextCallback_DeleteChars(0, buflen);
]])
    ImGui.Attach(self.ctx, self.clearInputIfNeeded)

    -- self.rejectCharacter = ImGui.CreateFunctionFromEEL('rejectCharacter ? EventChar = 0;')
    self.rejectCharacter = ImGui.CreateFunctionFromEEL('EventChar = 0;')
    ImGui.Attach(self.ctx, self.rejectCharacter)

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
        highlight = 0x42f595ff,
        textBright = 0xd7d7d7ff,
        textMid = 0xA8A8A8ff,
        textDark = 0x686868ff,
        textDarker = 0x444444ff,
        textDarkest = 0x303030ff,
    }
    self.st.searchColor = {
        results = { self.st.basecolors.textBright, self.st.basecolors.textDark, self.st.basecolors.textDarker },
        separator = self.st.basecolors.textDarkest,
        tagDefault = self.st.basecolors.main,
        tagDefaultBG = self.st.basecolors.darkerBG
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
            delete = {
                [ImGui.Col_Button] = 0x991d30ff,
                [ImGui.Col_ButtonHovered] = 0xa3273aff,
                [ImGui.Col_ButtonActive] = 0xba364aff,
            },
            default = {
                [ImGui.Col_Button] = self.st.basecolors.main,
                [ImGui.Col_ButtonHovered] = self.st.basecolors.mainBright,
                [ImGui.Col_ButtonActive] = self.st.basecolors.mainBrighter,
            }
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
        quickChainActive = {
            [ImGui.Col_FrameBg] = self.st.basecolors.mainDark,
            [ImGui.Col_FrameBgHovered] = self.st.basecolors.mainDark,
            [ImGui.Col_FrameBgActive] = self.st.basecolors.mainDark,
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
            additionalText = {
                [ImGui.Col_Text] = self.st.basecolors.textDarker,
            },
            shortcutText = {
                [ImGui.Col_Text] = self.st.basecolors.textDarker,
            },
            defaultTagColor = {
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
            ,
            [SEARCH_MODE.SEND_BUDDY] = {
                [ImGui.Col_ChildBg] = 0x19211aff,
                [ImGui.Col_FrameBg] = 0x19211aff,
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
            [ImGui.Col_NavCursor] = 0x00000000,
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
            searchResultsTable = {
                [ImGui.StyleVar_ItemInnerSpacing] = { 0, 0 },
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

    self.updateSizesToScale = function(self)
        self:pushFont(self.st.fonts.default) -- hint font! important!
        self.st.sizes = {
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


            self:updateFontsToScale()
            self:updateVarsToScale()
            self:pushStyles(self.st.vars.main)
            -- OD_Gui.recalculateZoom(self, scale)
            self:updateSizesToScale()
            self:popStyles(self.st.vars.main)
            return change
        end
        return 1
    end

    self:recalculateZoom(self.app.settings.current.uiScale)


    self.drawSadFace = function(self, sizeFactor, color)
        local x, y = ImGui.GetCursorScreenPos(self.ctx)
        local sz = ImGui.CalcTextSize(self.ctx, 'X') * sizeFactor
        -- local sz = 20 * sizeFactor * self.scale
        ImGui.DrawList_AddCircleFilled(self.draw_list, x, y, sz, color, 36)
        ImGui.DrawList_AddCircleFilled(self.draw_list, x - sz / 3.5, y - sz / 5, sz / 9, 0x000000ff, 36)
        ImGui.DrawList_AddCircleFilled(self.draw_list, x + sz / 3.5, y - sz / 5, sz / 9, 0x000000ff, 36)
        ImGui.DrawList_AddLine(self.draw_list, x + sz / 2, y + sz / 10, x - sz / 2, y + sz / 2.5, 0x000000ff, sz / 9)
    end

    self.getTagColors = function(col)
        local col = (ImGui.ColorConvertNative(col) * 0x100 | 0xff)
        local colBG = OD_SetHSLInRGB(OD_MultiplyHSLInRGB(col, 1, 1, 1), nil, math.min(0.25, select(2, OD_Int2Hsl(col))),
            math.min(0.2, select(3, OD_Int2Hsl(col)) / 3))
        return col, colBG
    end
    self.colorPalette = function(self, ctx, id, color, width)
        local width = width or 250 * self.scale
        local color = color
        local steps = 16
        -- local w = ImGui.GetContentRegionAvail(ctx)
        local btnW = (width or ImGui.GetContentRegionAvail(ctx)) / steps
        local selColor = nil
        local colH = {}
        for i = 1, steps do
            table.insert(colH, (1 / steps) * i)
        end
        local colL = { { 0.15, 0.75 }, { 0.25, 0.25 }, { 0.375, 0.375 }, { 0.45, 0.45 }, { 0.55, 0.55 } }
        local colS = { 0, 0.35, 0.4, 0.45, 0.50 }
        local sIndex = 0
        local spacing = math.ceil(1 * self.scale)
        local numCols, numRows = steps, #colL
        if ImGui.BeginChild(ctx, '##colorSelector' .. tostring(id), btnW * numCols + spacing * (numCols - 1), btnW * numRows + spacing * (numRows - 1)) then
            ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, spacing, spacing)
            for row = 1, #colL do
                for col = 1, steps do
                    local h = colH[col]
                    local s = colS[row]
                    local lRange = colL[row]
                    local l = lRange[1] + (lRange[2] - lRange[1]) / steps * col
                    local rr, g, b = OD_HslToRgb(h, s, l)
                    local btnColor = (rr << 24) | (g << 16) | (b << 8) | 0xff
                    local nativeColor = r.ColorToNative(rr, g, b)
                    ImGui.PushStyleColor(ctx, ImGui.Col_Button, btnColor)

                    local sX, sY = ImGui.GetCursorScreenPos(ctx)
                    ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), sX, sY,
                        sX + btnW, sY + btnW, btnColor)
                    if color == nativeColor then
                        ImGui.DrawList_AddRect(
                            ImGui.GetForegroundDrawList(ctx), sX - spacing,
                            sY - spacing,
                            sX + btnW + spacing, sY + btnW + spacing,
                            0xffffffff, nil, nil, spacing)
                    end
                    if ImGui.InvisibleButton(ctx, 'colorPick' .. row .. col, btnW, btnW) then
                        selColor = nativeColor
                    end
                    if ImGui.IsItemHovered(ctx) then
                        ImGui.DrawList_AddRect(
                            ImGui.GetForegroundDrawList(ctx), sX - spacing,
                            sY - spacing,
                            sX + btnW + spacing, sY + btnW + spacing,
                            0xBBBBBBff, nil, nil, spacing)
                    end
                    ImGui.PopStyleColor(ctx)
                    ImGui.SameLine(ctx)
                end
                sIndex = sIndex + 1

                ImGui.NewLine(ctx)
            end
            ImGui.PopStyleVar(ctx)
            ImGui.EndChild(ctx)
        end
        if selColor then return true, selColor end
    end

    self.setting = function(self, stType, text, hint, val, data, sameline)
        local ctx = self.ctx
        local w, h = ImGui.GetWindowSize(ctx)
        local thirdWidth = w / 2
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
                self:pushFont(self.st.fonts.icons, 'tiny')
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
            -- elseif stType == 'widget_label' then
            -- ImGui.Dummy(ctx, 0, 0)
            -- ImGui.PushTextWrapPos(ctx, widgetWidth)
            -- local _, h = ImGui.CalcTextSize(ctx, text)
            -- if ImGui.BeginChild(ctx, '##' .. text .. 'label', widgetWidth, h) then
            --     ImGui.TextWrapped(ctx, val)
            --     ImGui.EndChild(ctx)
            -- end
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
        elseif stType == 'color_palette' then
            retval1 = val
            local BGcolorToUse = val
            local nativeBGColor = data.colorBG or (ImGui.ColorConvertNative(val) * 0x100 | 0xff)
            ImGui.PushStyleColor(ctx, ImGui.Col_Button, nativeBGColor)
            ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, OD_MultiplyHSLInRGB(nativeBGColor, 1, 1, 1.2))
            ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, OD_MultiplyHSLInRGB(nativeBGColor, 1, 1, 1.3))
            local colorIsBright = OD_ColorIsBright(val)
            if colorIsBright or data.color then
                ImGui.PushStyleColor(ctx, ImGui.Col_Text, data.color or 0x000000ff)
            end
            if ImGui.Button(ctx, data.label or 'Click to select', widgetWidth) then
                ImGui.OpenPopup(ctx, 'ColorPalettePopup##' .. text)
            end
            if ImGui.BeginPopup(ctx, 'ColorPalettePopup##' .. text) then
                local rv, color = self:colorPalette(ctx, 'ColorPalette##' .. text, val)
                if rv then
                    retval1 = color
                end
                ImGui.EndPopup(ctx)
            end
            ImGui.PopStyleColor(ctx, 3)
            if data.colorBG or colorIsBright then
                ImGui.PopStyleColor(ctx)
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
            if val and val == -1 then val = nil end
            local label, newVal
            if self.app.temp._capturing == text then
                label = '...'
                retval2 = true
                hint = 'Press a key combination, or click to cancel'
                local key = OD_GetImguiKeysPressed(ctx)
                if key then
                    local testVal = key | ImGui.GetKeyMods(ctx)
                    for key, shortcut in pairs(data.existingShortcuts or {}) do
                        if shortcut == testVal then
                            testVal = nil
                            self.app.flow.msg('Shortcut already in use')
                            break
                        end
                    end
                    if testVal then
                        newVal = testVal
                        self.app.temp._capturing = nil
                    end
                end
            else
                if val ~= nil and ImGui.IsKeyDown(ctx, ImGui.Mod_Alt) then
                    label = 'Click to remove shortcut'
                elseif val == nil then
                    label = 'Click to set shortcut'
                else
                    label = self.app.guiHelpers.shortCutToText(val)
                end
            end
            ImGui.PushStyleColor(ctx, ImGui.Col_Button, ImGui.GetStyleColor(ctx, ImGui.Col_FrameBg))
            if ImGui.Button(ctx, label .. '##' .. text, widgetWidth) then
                if self.app.temp._capturing == text then
                    self.app.temp._capturing = nil
                else
                    if ImGui.IsKeyDown(ctx, ImGui.Mod_Alt) then
                        if val ~= nil then val = nil end
                    else
                        self.app.temp._capturing = text
                    end
                end
            end
            ImGui.PopStyleColor(ctx)
            -- if val == nil then val = { key = -1, ctrl = false, shift = false, alt = false } end
            retval1 = newVal or val or -1
        elseif stType == 'orderable_list' then
            -- ImGui.Dummy(ctx, widgetWidth, 20)
            ImGui.BeginGroup(ctx)
            if sameline and data.listTopLabel then
                ImGui.PushTextWrapPos(ctx, widgetWidth)
                local _, h = ImGui.CalcTextSize(ctx, data.listTopLabel)
                if ImGui.BeginChild(ctx, '##' .. text .. 'label', widgetWidth, h) then
                    ImGui.TextWrapped(ctx, data.listTopLabel)
                    ImGui.EndChild(ctx)
                end
                ImGui.PopTextWrapPos(ctx)
            end
            local orderList, enabledList = val[1], val[2]
            if ImGui.BeginListBox(ctx, '##' .. text, widgetWidth, #orderList * ImGui.GetTextLineHeightWithSpacing(ctx) + select(1, ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding))) then
                for i, v in ipairs(orderList) do
                    self:pushColors(self.st.col.settings.selectable[enabledList[v]])
                    local label = T.SETTINGS.LISTS[text] and T.SETTINGS.LISTS[text][v] or v
                    if data.formatter then
                        local success, rv = pcall(data.formatter, label)
                        if success then label = rv end
                    end
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
            ImGui.EndGroup(ctx)
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
