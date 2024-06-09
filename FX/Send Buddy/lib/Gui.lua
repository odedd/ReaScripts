-- @noindex
package.path = r.ImGui_GetBuiltinPath() .. '/?.lua'
ImGui = require 'imgui' '0.9.1'

SM_Gui = OD_Gui:new({

})

SM_Gui.init = function(self, fonts)
    OD_Gui.addFont(self, 'vertical', 'Resources/Fonts/Cousine-90deg.otf', 11)

    local small = 16
    local default = 18
    local large = 22
    self:createFonts({
        default = { file = 'Resources/Fonts/Cousine-Regular.ttf', size = default },
        small = { file = 'Resources/Fonts/Cousine-Regular.ttf', size = small },
        large = { file = 'Resources/Fonts/Cousine-Regular.ttf', size = large },
        large_bold = { file = 'Resources/Fonts/Cousine-Bold.ttf', size = large },
        icons_small = { file = 'Resources/Fonts/Icons-Regular.otf', size = small },
        icons_large = { file = 'Resources/Fonts/Icons-Regular.otf', size = large }
    })

    OD_Gui.init(self, false)

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
        textBright = 0xf7f7f7ff,
        textDark = 0x7c7c7cff,
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
    -- dofile(p .. 'lib/Gui.lua')
    self.st.col = {
        hint = {
            [ImGui.Col_Text] = 0xCCCCCCff,
        },
        insert = {
            enabled = {
                [ImGui.Col_Text] = 0x2b2b2bff,
                [ImGui.Col_Button] = self.st.basecolors.widgetBG,
                [ImGui.Col_ButtonHovered] = self.st.basecolors.hovered,
                [ImGui.Col_ButtonActive] = self.st.basecolors.active

            },
            disabled = {
                [ImGui.Col_Button] = 0x746a2cff,
                [ImGui.Col_Text] = 0xcaad08ff,
                [ImGui.Col_ButtonHovered] = 0x89804bff,
                [ImGui.Col_ButtonActive] = 0x746a2cff
            },
            offline = {
                [ImGui.Col_Button] = 0x742c39ff,
                [ImGui.Col_Text] = 0xf71659ff,
                [ImGui.Col_ButtonHovered] = 0x894b56ff,
                [ImGui.Col_ButtonActive] = 0x742c39ff
            },
            add = {
                [ImGui.Col_Button] = self.st.basecolors.darkBG,
                [ImGui.Col_Text] = 0x878787ff,
                [ImGui.Col_ButtonHovered] = self.st.basecolors.darkHovered,
                [ImGui.Col_ButtonActive] = self.st.basecolors.darkActive
            },
            blank = {
                [ImGui.Col_Button] = self.st.basecolors.darkestBG,
            },
        },
        buttons = {
            mute = {
                [true] = {
                    [ImGui.Col_Button] = 0xa63f3fFF,
                    [ImGui.Col_Text] = 0x2b2b2bff,
                    [ImGui.Col_ButtonHovered] = 0xb64f4fFF,
                    [ImGui.Col_ButtonActive] = 0xc65f5fFF
                },
                [false] = {
                    [ImGui.Col_Text] = 0x000000ff,
                    [ImGui.Col_Button] = self.st.basecolors.widgetBG,
                    [ImGui.Col_ButtonHovered] = self.st.basecolors.hovered,
                    [ImGui.Col_ButtonActive] = self.st.basecolors.active
                }
            },
            solo = {
                [SOLO_STATES.SOLO] = {
                    [ImGui.Col_Button] = 0xd6be42FF,
                    [ImGui.Col_Text] = 0x000000ff,
                    [ImGui.Col_ButtonHovered] = 0xe6ce52FF,
                    [ImGui.Col_ButtonActive] = 0xf6de62FF
                },
                [SOLO_STATES.NONE] = {
                    [ImGui.Col_Text] = 0x000000ff,
                    [ImGui.Col_Button] = self.st.basecolors.widgetBG,
                    [ImGui.Col_ButtonHovered] = self.st.basecolors.hovered,
                    [ImGui.Col_ButtonActive] = self.st.basecolors.active
                },
                [SOLO_STATES.SOLO_DEFEAT] = {
                    [ImGui.Col_Text] = 0x000000ff,
                    [ImGui.Col_Button] = 0x58d43fff,
                    [ImGui.Col_ButtonHovered] = 0x68e44fff,
                    [ImGui.Col_ButtonActive] = 0x78f45fff
                }
            },
            polarity = {
                [true] = {
                    [ImGui.Col_Button] = 0x3f67d4FF,
                    [ImGui.Col_Text] = 0x000000ff,
                    [ImGui.Col_ButtonHovered] = 0x4f77e4FF,
                    [ImGui.Col_ButtonActive] = 0x5f87f4FF
                },
                [false] = self.st.colpresets.brightButton
            },
            listen = {
                [SEND_LISTEN_MODES.NORMAL] = {
                    [false] = {
                        [ImGui.Col_Text] = 0x000000ff,
                        [ImGui.Col_Button] = self.st.basecolors.widgetBG,
                        [ImGui.Col_ButtonHovered] = self.st.basecolors.hovered,
                        [ImGui.Col_ButtonActive] = self.st.basecolors.active

                    },
                    [true] = {
                        [ImGui.Col_Button] = 0x763fd4FF,
                        [ImGui.Col_Text] = 0x000000ff,
                        [ImGui.Col_ButtonHovered] = 0x864fe4ff,
                        [ImGui.Col_ButtonActive] = 0x965ff4ff,
                    }
                },
                [SEND_LISTEN_MODES.RETURN_ONLY] = {
                    [false] = {
                        [ImGui.Col_Text] = 0x421441ff,
                        [ImGui.Col_Button] = 0x917a87ff,
                        [ImGui.Col_ButtonHovered] = 0xa18a97ff,
                        [ImGui.Col_ButtonActive] = 0xb19aa7ff

                    },
                    [true] = {
                        [ImGui.Col_Button] = 0xd43f93FF,
                        [ImGui.Col_Text] = 0x000000ff,
                        [ImGui.Col_ButtonHovered] = 0xe44fa3ff,
                        [ImGui.Col_ButtonActive] = 0xf45fb3ff,
                    }
                }
            },
            mode = {
                [0] = self.st.colpresets.midButton,
                [1] = {
                    [ImGui.Col_Button] = 0x4291d6ff,
                    [ImGui.Col_ButtonHovered] = 0x52A1e6ff,
                    [ImGui.Col_ButtonActive] = 0x62B1f6ff,
                    [ImGui.Col_Text] = 0x000000ff,
                },
                [3] = {
                    [ImGui.Col_Button] = 0x42d6b6ff,
                    [ImGui.Col_ButtonHovered] = 0x52e6c6ff,
                    [ImGui.Col_ButtonActive] = 0x62f6d6ff,
                    [ImGui.Col_Text] = 0x000000ff,
                }
            },
            autoMode = {
                [AUTO_MODE.TRACK] = self.st.colpresets.brightButton,
                [AUTO_MODE.TRIM_READ] = {
                    [ImGui.Col_Button] = 0x87bf3dff,
                    [ImGui.Col_Text] = 0x000000ff,
                    [ImGui.Col_ButtonHovered] = 0x97cf4dff,
                    [ImGui.Col_ButtonActive] = 0xa7df5dff
                },
                [AUTO_MODE.READ] = {
                    [ImGui.Col_Button] = 0xd4d43fff,
                    [ImGui.Col_Text] = 0x000000ff,
                    [ImGui.Col_ButtonHovered] = 0xe4e44fff,
                    [ImGui.Col_ButtonActive] = 0xf4f45fff
                },
                [AUTO_MODE.TOUCH] = {
                    [ImGui.Col_Button] = 0xd4a63fff,
                    [ImGui.Col_Text] = 0x000000ff,
                    [ImGui.Col_ButtonHovered] = 0xe4b64fff,
                    [ImGui.Col_ButtonActive] = 0xf4c65fff
                },
                [AUTO_MODE.WRITE] = {
                    [ImGui.Col_Button] = 0xd43f3fff,
                    [ImGui.Col_Text] = 0x000000ff,
                    [ImGui.Col_ButtonHovered] = 0xe44f4fff,
                    [ImGui.Col_ButtonActive] = 0xf45f5fff
                },
                [AUTO_MODE.LATCH] = {
                    [ImGui.Col_Button] = 0xbf803dff,
                    [ImGui.Col_Text] = 0x000000ff,
                    [ImGui.Col_ButtonHovered] = 0xcf904dff,
                    [ImGui.Col_ButtonActive] = 0xdfa05dff
                },
                [AUTO_MODE.LATCH_PREVIEW] = {
                    [ImGui.Col_Button] = 0xbf803dff,
                    [ImGui.Col_Text] = 0x000000ff,
                    [ImGui.Col_ButtonHovered] = 0xcf904dff,
                    [ImGui.Col_ButtonActive] = 0xdfa05dff
                }
            },
            mono = {
                [true] = {
                    [ImGui.Col_Button] = 0xbf803dff,
                    [ImGui.Col_Text] = 0x000000ff,
                    [ImGui.Col_ButtonHovered] = 0xcf904dff,
                    [ImGui.Col_ButtonActive] = 0xdfa05dff
                },
                [false] =
                    self.st.colpresets.brightButton

            },

            env = self.st.colpresets.darkButton,
            route = self.st.colpresets.midButton,
            add = self.st.colpresets.midButton,
            scrollToTrack = self.st.colpresets.midButton,
            addSend = {
                [ImGui.Col_Button] = self.st.basecolors.mainDark,
                [ImGui.Col_ButtonHovered] = self.st.basecolors.mainBright,
                [ImGui.Col_ButtonActive] = self.st.basecolors.mainBrighter,
                [ImGui.Col_Text] = self.st.basecolors.widgetBG,
            },
            deleteSend = {
                ['initial'] = {
                    [ImGui.Col_Button] = self.st.basecolors.midBG,
                    [ImGui.Col_ButtonHovered] = self.st.basecolors.midHovered,
                    [ImGui.Col_ButtonActive] = self.st.basecolors.midActive,
                    [ImGui.Col_Text] = self.st.basecolors.mainBrightest,
                },
                ['confirm'] = {
                    [ImGui.Col_Button] = self.st.basecolors.main,
                    [ImGui.Col_ButtonHovered] = self.st.basecolors.mainBright,
                    [ImGui.Col_ButtonActive] = self.st.basecolors.mainBrighter,
                    [ImGui.Col_Text] = 0x000000ff
                }
            },
            topBarIcon = {
                default = { [ImGui.Col_Text] = self.st.basecolors.midHovered },
                hovered = { [ImGui.Col_Text] = self.st.basecolors.active },
                active = { [ImGui.Col_Text] = self.st.basecolors.midText },
            }
        },
        sendTypeCategory = {
            [SEND_TYPE.SEND] = self.st.basecolors.mainDark,
            [SEND_TYPE.RECV] = self.st.basecolors.mainDark, --0x371f37ff,
            [SEND_TYPE.HW] = self.st.basecolors.mainDark,   --0x35371fff,
        },
        targetFader = {
            [ImGui.Col_FrameBg] = 0x1c2533ff,
            [ImGui.Col_FrameBgHovered] = 0x283b59ff,
            [ImGui.Col_FrameBgActive] = 0x2f4e80ff,
            [ImGui.Col_SliderGrab] = 0x4781deff,
            [ImGui.Col_SliderGrabActive] = 0x669cf2ff,

        },
        searchWindow = {
            [ImGui.Col_TableBorderStrong] = 0x00000000,
            [ImGui.Col_TextSelectedBg] = self.st.basecolors.main,
            [ImGui.Col_Header] = self.st.basecolors.mainDark,
            [ImGui.Col_HeaderHovered] = self.st.basecolors.mainDark,
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
            highlight = {
                [ImGui.Col_Text] = self.st.basecolors.mainBright,
            },
            favorite = {
                [ImGui.Col_Text] = self.st.basecolors.main,
            }
        },
        main = {
            [ImGui.Col_Tab] = self.st.basecolors.darkHovered,
            [ImGui.Col_TabHovered] = self.st.basecolors.darkActive,
            [ImGui.Col_TabActive] = self.st.basecolors.darkActive,
            [ImGui.Col_TabUnfocused] = self.st.basecolors.darkBG,
            [ImGui.Col_TabUnfocusedActive] = self.st.basecolors.darkBG,
            [ImGui.Col_FrameBg] = self.st.basecolors.darkBG,
            [ImGui.Col_FrameBgHovered] = self.st.basecolors.darkHovered,
            [ImGui.Col_FrameBgActive] = self.st.basecolors.darkActive,
            [ImGui.Col_SliderGrab] = self.st.basecolors.widgetBG,
            [ImGui.Col_SliderGrabActive] = self.st.basecolors.active,
            [ImGui.Col_TextSelectedBg] = self.st.basecolors.darkActive,
            [ImGui.Col_HeaderHovered] = self.st.basecolors.headerHovered,
            [ImGui.Col_Header] = self.st.basecolors.header,
            [ImGui.Col_Button] = self.st.basecolors.main,
            [ImGui.Col_ButtonHovered] = self.st.basecolors.mainBright,
            [ImGui.Col_ButtonActive] = self.st.basecolors.mainBrighter,
            [ImGui.Col_ResizeGrip] = self.st.basecolors.darkBG,
            [ImGui.Col_ResizeGripHovered] = self.st.basecolors.mainDark,
            [ImGui.Col_ResizeGripActive] = self.st.basecolors.main,
            [ImGui.Col_ScrollbarGrabHovered] = self.st.basecolors.main,
            [ImGui.Col_ScrollbarGrabActive] = self.st.basecolors.mainBright,
            [ImGui.Col_SeparatorHovered] = self.st.basecolors.main,
            [ImGui.Col_SeparatorActive] = self.st.basecolors.mainBright,
            [ImGui.Col_TitleBgActive] = self.st.basecolors.mainDark,
            [ImGui.Col_CheckMark] = self.st.basecolors.main,
            [ImGui.Col_HeaderActive] = self.st.basecolors.main,
            [ImGui.Col_DragDropTarget] = self.st.basecolors.mainBright,
        },
        title = {
            [ImGui.Col_Text] = self.st.basecolors.mainBright,
        },
        zoomSlider = {
            [ImGui.Col_SliderGrab] = self.st.basecolors.main,
            [ImGui.Col_SliderGrabActive] = self.st.basecolors.mainBright,
        }
    }

    self.updateVarsToScale = function(self)
        local scale = self.app.settings.current.uiScale
        self.st.vars = {
            pan = {
                [ImGui.StyleVar_GrabMinSize] = { 6 * scale, nil },
                [ImGui.StyleVar_GrabRounding] = { self.st.rounding * 2 * scale, nil },
            },
            vol = {
                [ImGui.StyleVar_GrabMinSize] = { 8 * scale, nil },
                [ImGui.StyleVar_GrabRounding] = { self.st.rounding * 2 * scale, nil },
            },
            main = {
                [ImGui.StyleVar_FrameRounding] = { self.st.rounding * scale, nil },
                [ImGui.StyleVar_ItemSpacing] = { 4 * scale, 4 * scale },
                [ImGui.StyleVar_WindowRounding] = { 10 * scale, nil },
                [ImGui.StyleVar_WindowPadding] = { 8 * scale, 8 * scale },
                [ImGui.StyleVar_ScrollbarSize] = { 10 * scale, nil },
                [ImGui.StyleVar_FramePadding] = { 4 * scale, 3 * scale },
                [ImGui.StyleVar_ItemInnerSpacing] = { 4 * scale, 4 * scale },
                [ImGui.StyleVar_SeparatorTextBorderSize] = { 1 * scale, nil },
            },
            searchWindow = {
                [ImGui.StyleVar_SeparatorTextAlign] = { 0, 0 },
                [ImGui.StyleVar_SeparatorTextBorderSize] = { 1 * scale, nil },
                [ImGui.StyleVar_SeparatorTextPadding] = { 0, 0 },
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
            },
            addSendButton = {
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
            sendTypeSeparatorHeight = 95 * self.app.settings.current.uiScale,
            minFaderHeight = 100 * self.app.settings.current.uiScale,
            mixerSeparatorWidth = 4 * self.app.settings.current.uiScale,
            hintHeight = ImGui.GetTextLineHeightWithSpacing(self.ctx) +
                select(2, ImGui.GetStyleVar(self.ctx, ImGui.StyleVar_ItemSpacing)) +
                select(2, ImGui.GetStyleVar(self.ctx, ImGui.StyleVar_FramePadding)) * 2
        }
        ImGui.PopFont(self.ctx)
    end
    self.recalculateZoom = function(self, scale)
        if self.scale ~= scale then
            local change = scale / (self.scale or scale) -- return change to allow for scaling of other elements (eg. Resize window)
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
        -- local sz = 20 * sizeFactor * self.app.settings.current.uiScale
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
            -- ImGui.SetCursorPos(self.ctx, posX, posY + letterspacing * (ci - 1))
            -- ImGui.Text(self.ctx, text:sub(ci, ci))
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
            widgetWidth = itemWidth
        else
            ImGui.SameLine(ctx)
            widgetWidth = itemWidth - ImGui.GetTextLineHeight(ctx) -
                ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing) * 2
        end
        ImGui.PushItemWidth(ctx, widgetWidth)

        if stType == 'combo' then
            _, retval1 = ImGui.Combo(ctx, '##' .. text, val, data.list)
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
                data.dontUnpdateWhileEnteringManually and self.app.temp.tempSettingsVal[text] or val, data.speed, data.min, data.max,
                data.format, data.flags or 0)
            if data.dontUnpdateWhileEnteringManually then
                if ImGui.IsItemActive(ctx) and not ImGui.IsMouseDragging(ctx,ImGui.MouseButton_Left) then
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
        self.app:setHoveredHint('settings', hint)
        return retval1, retval2
    end
end
