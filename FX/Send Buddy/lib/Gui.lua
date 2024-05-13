-- @noindex
SM_Gui = OD_Gui:new({

})

SM_Gui.init = function(self, fonts)
    OD_Gui.init(self)
    r.ImGui_PushFont(self.ctx, self.st.fonts.large)
    self.mainWindow.hintHeight = r.ImGui_GetTextLineHeightWithSpacing(self.ctx) +
    select(2, r.ImGui_GetStyleVar(self.ctx, r.ImGui_StyleVar_FramePadding())) +
    select(2, r.ImGui_GetStyleVar(self.ctx, r.ImGui_StyleVar_WindowPadding())) +
    select(2, r.ImGui_GetStyleVar(self.ctx, r.ImGui_StyleVar_ItemSpacing()))
    r.ImGui_PopFont(self.ctx)

    self.st.basecolors = {
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
        mainDark = 0x371f23ff,
        mainBright = 0xb73849ff,
        mainBrighter = 0xc74859ff,
    }
    self.st.colpresets = {
        midButton = {
            [r.ImGui_Col_Text()] = self.st.basecolors.midText,
            [r.ImGui_Col_Button()] = self.st.basecolors.midBG,
            [r.ImGui_Col_ButtonHovered()] = self.st.basecolors.midHovered,
            [r.ImGui_Col_ButtonActive()] = self.st.basecolors.midActive,
        },
    }
    self.st.rounding = 2
    -- dofile(p .. 'lib/Gui.lua')
    self.st.col = {
        hint = {
            [r.ImGui_Col_Text()] = 0xCCCCCCff,
        },
        insert = {
            enabled = {
                [r.ImGui_Col_Text()] = 0x2b2b2bff,
                [r.ImGui_Col_Button()] = self.st.basecolors.widgetBG,
                [r.ImGui_Col_ButtonHovered()] = self.st.basecolors.hovered,
                [r.ImGui_Col_ButtonActive()] = self.st.basecolors.active
    
            },
            disabled = {
                [r.ImGui_Col_Button()] = 0x746a2cff,
                [r.ImGui_Col_Text()] = 0xcaad08ff,
                [r.ImGui_Col_ButtonHovered()] = 0x89804bff,
                [r.ImGui_Col_ButtonActive()] = 0x746a2cff
            },
            offline = {
                [r.ImGui_Col_Button()] = 0x742c39ff,
                [r.ImGui_Col_Text()] = 0xf71659ff,
                [r.ImGui_Col_ButtonHovered()] = 0x894b56ff,
                [r.ImGui_Col_ButtonActive()] = 0x742c39ff
            },
            add = {
                [r.ImGui_Col_Button()] = self.st.basecolors.darkBG,
                [r.ImGui_Col_Text()] = 0x878787ff,
                [r.ImGui_Col_ButtonHovered()] = self.st.basecolors.darkHovered,
                [r.ImGui_Col_ButtonActive()] = self.st.basecolors.darkActive
            },
        },
        buttons = {
            mute = {
                [1] = {
                    [r.ImGui_Col_Button()] = 0xa63f3fFF,
                    [r.ImGui_Col_Text()] = 0x2b2b2bff,
                    [r.ImGui_Col_ButtonHovered()] = 0xb64f4fFF,
                    [r.ImGui_Col_ButtonActive()] = 0xc65f5fFF
                },
                [0] = {
                    [r.ImGui_Col_Text()] = 0x000000ff,
                    [r.ImGui_Col_Button()] = self.st.basecolors.widgetBG,
            [r.ImGui_Col_ButtonHovered()] = self.st.basecolors.hovered,
            [r.ImGui_Col_ButtonActive()] = self.st.basecolors.active
                }
            },
            solo = {
                [1] = {
                    [r.ImGui_Col_Button()] = 0xd6be42FF,
                    [r.ImGui_Col_Text()] = 0x000000ff,
                    [r.ImGui_Col_ButtonHovered()] = 0xe6ce52FF,
                    [r.ImGui_Col_ButtonActive()] = 0xf6de62FF
                },
                [0] = {
                    [r.ImGui_Col_Text()] = 0x000000ff,
                    [r.ImGui_Col_Button()] = self.st.basecolors.widgetBG,
            [r.ImGui_Col_ButtonHovered()] = self.st.basecolors.hovered,
            [r.ImGui_Col_ButtonActive()] = self.st.basecolors.active
                }
            },
            mode = {
                [0] = {
                    [r.ImGui_Col_Text()] = 0x000000ff,
                    [r.ImGui_Col_Button()] = self.st.basecolors.widgetBG,
            [r.ImGui_Col_ButtonHovered()] = self.st.basecolors.hovered,
            [r.ImGui_Col_ButtonActive()] = self.st.basecolors.active
                },
                [1] = {
                    [r.ImGui_Col_Button()] = 0x4291d6ff,
                    [r.ImGui_Col_ButtonHovered()] = 0x52A1e6ff,
                    [r.ImGui_Col_ButtonActive()] = 0x62B1f6ff,
                    [r.ImGui_Col_Text()] = 0x000000ff,
                },
                [3] = {
                    [r.ImGui_Col_Button()] = 0x42d6b6ff,
                    [r.ImGui_Col_ButtonHovered()] = 0x52e6c6ff,
                    [r.ImGui_Col_ButtonActive()] = 0x62f6d6ff,
                    [r.ImGui_Col_Text()] = 0x000000ff,
                }
            },
            route = self.st.colpresets.midButton,
            add = self.st.colpresets.midButton,
            topBarIcon = {
                default = { [r.ImGui_Col_Text()] = self.st.basecolors.midBG },
                hovered = { [r.ImGui_Col_Text()] = self.st.basecolors.active },
                active = { [r.ImGui_Col_Text()] = self.st.basecolors.midText },
            }
        },
        searchWindow = {
            [r.ImGui_Col_TableBorderStrong()] = 0x00000000,
            [r.ImGui_Col_TextSelectedBg()] = self.st.basecolors.main,
            [r.ImGui_Col_Header()] = self.st.basecolors.mainDark,
            [r.ImGui_Col_HeaderHovered()] = self.st.basecolors.mainDark,
        },
        search = {
            highlight = {
                [r.ImGui_Col_Text()] = self.st.basecolors.mainBright,
            },
            favorite = {
                [r.ImGui_Col_Text()] = self.st.basecolors.main,
            }
        },
        main = {
            [r.ImGui_Col_FrameBg()] = self.st.basecolors.darkBG,
            [r.ImGui_Col_FrameBgHovered()] = self.st.basecolors.darkHovered,
            [r.ImGui_Col_FrameBgActive()] = self.st.basecolors.darkActive,
            [r.ImGui_Col_SliderGrab()] = self.st.basecolors.widgetBG,
            [r.ImGui_Col_SliderGrabActive()] = self.st.basecolors.active,
            [r.ImGui_Col_TextSelectedBg()] = self.st.basecolors.darkActive,
            [r.ImGui_Col_HeaderHovered()] = self.st.basecolors.headerHovered,
            [r.ImGui_Col_Header()] = self.st.basecolors.header,
            [r.ImGui_Col_Button()] = self.st.basecolors.main,
            [r.ImGui_Col_ButtonHovered()] = self.st.basecolors.mainBright,
            [r.ImGui_Col_ButtonActive()] = self.st.basecolors.mainBrighter,
            [r.ImGui_Col_ResizeGrip()]= self.st.basecolors.darkBG,
            [r.ImGui_Col_ResizeGripHovered()]= self.st.basecolors.mainDark,
            [r.ImGui_Col_ResizeGripActive()]= self.st.basecolors.main,
        },
        title = {
            [r.ImGui_Col_Text()] = self.st.basecolors.mainBright,
        }
    }
    self.st.vars = {
        pan = {
            [r.ImGui_StyleVar_GrabMinSize()] = { 6, nil },
            [r.ImGui_StyleVar_GrabRounding()] = { self.st.rounding * 2, nil },
        },
        vol = {
            [r.ImGui_StyleVar_GrabMinSize()] = { 8, nil },
            [r.ImGui_StyleVar_GrabRounding()] = { self.st.rounding * 2, nil },
        },
        main = {
            [r.ImGui_StyleVar_FrameRounding()] = { self.st.rounding, nil },
            [r.ImGui_StyleVar_ItemSpacing()] = { 4, 4 },
            [r.ImGui_StyleVar_WindowRounding()] = { 10, nil },
        },
        searchWindow = {
            [r.ImGui_StyleVar_SeparatorTextAlign()] = { 0, 0 },
            [r.ImGui_StyleVar_SeparatorTextBorderSize()] = { 1, nil },
            [r.ImGui_StyleVar_SeparatorTextPadding()] = { 0, 0 },
        },
        bigButton = {
            [r.ImGui_StyleVar_FrameRounding()] = { 10, nil },
            [r.ImGui_StyleVar_FramePadding()] = { 20, 10 },
        }
    }

    self.drawSadFace = function(self, sizeFactor,color)
            local x, y = r.ImGui_GetCursorScreenPos(self.ctx)
            local sz = self.TEXT_BASE_WIDTH *sizeFactor
            r.ImGui_DrawList_AddCircleFilled(self.draw_list, x, y, sz, color, 36)
            r.ImGui_DrawList_AddCircleFilled(self.draw_list, x-sz/3.5, y-sz/5, sz/9, 0x000000ff, 36)
            r.ImGui_DrawList_AddCircleFilled(self.draw_list, x+sz/3.5, y-sz/5, sz/9, 0x000000ff, 36)
            r.ImGui_DrawList_AddLine(self.draw_list, x+sz/2, y+sz/10, x-sz/2, y+sz/2.5, 0x000000ff, sz/9)
    end
end
