-- @noindex
SM_Gui = OD_Gui:new({

})

SM_Gui.init = function(self, fonts)
    OD_Gui.init(self)
    ImGui.PushFont(self.ctx, self.st.fonts.default)
    self.mainWindow.hintHeight = ImGui.GetTextLineHeightWithSpacing(self.ctx) +
        select(2, ImGui.GetStyleVar(self.ctx, ImGui.StyleVar_FramePadding))*2 +
        select(2, ImGui.GetStyleVar(self.ctx, ImGui.StyleVar_WindowPadding)) +
        select(2, ImGui.GetStyleVar(self.ctx, ImGui.StyleVar_ItemSpacing))
    ImGui.PopFont(self.ctx)

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
            [ImGui.Col_Text] = self.st.basecolors.midText,
            [ImGui.Col_Button] = self.st.basecolors.midBG,
            [ImGui.Col_ButtonHovered] = self.st.basecolors.midHovered,
            [ImGui.Col_ButtonActive] = self.st.basecolors.midActive,
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
                [true] = {
                    [ImGui.Col_Button] = 0xd6be42FF,
                    [ImGui.Col_Text] = 0x000000ff,
                    [ImGui.Col_ButtonHovered] = 0xe6ce52FF,
                    [ImGui.Col_ButtonActive] = 0xf6de62FF
                },
                [false] = {
                    [ImGui.Col_Text] = 0x000000ff,
                    [ImGui.Col_Button] = self.st.basecolors.widgetBG,
                    [ImGui.Col_ButtonHovered] = self.st.basecolors.hovered,
                    [ImGui.Col_ButtonActive] = self.st.basecolors.active
                }
            },
            polarity = {
                [true] = {
                    [ImGui.Col_Button] = 0x3f67d4FF,
                    [ImGui.Col_Text] = 0x000000ff,
                    [ImGui.Col_ButtonHovered] = 0x4f77e4FF,
                    [ImGui.Col_ButtonActive] = 0x5f87f4FF
                },
                [false] = {
                    [ImGui.Col_Text] = 0x000000ff,
                    [ImGui.Col_Button] = self.st.basecolors.widgetBG,
                    [ImGui.Col_ButtonHovered] = self.st.basecolors.hovered,
                    [ImGui.Col_ButtonActive] = self.st.basecolors.active
                }
            },
            mode = {
                [0] = {
                    [ImGui.Col_Text] = 0x000000ff,
                    [ImGui.Col_Button] = self.st.basecolors.widgetBG,
                    [ImGui.Col_ButtonHovered] = self.st.basecolors.hovered,
                    [ImGui.Col_ButtonActive] = self.st.basecolors.active
                },
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
            env = {
                [ImGui.Col_Button] = self.st.basecolors.darkBG,
                [ImGui.Col_ButtonHovered] = self.st.basecolors.darkHovered,
                [ImGui.Col_ButtonActive] = self.st.basecolors.darkActive,
                [ImGui.Col_Text] = self.st.basecolors.widgetBG,    
            },
            route = self.st.colpresets.midButton,
            add = self.st.colpresets.midButton,
            deleteSend = {
                [ImGui.Col_Button] = self.st.basecolors.main,
                [ImGui.Col_ButtonHovered] = self.st.basecolors.mainBright,
                [ImGui.Col_ButtonActive] = self.st.basecolors.mainBrighter,  
                [ImGui.Col_Text] = 0x000000ff  
            },
            topBarIcon = {
                default = { [ImGui.Col_Text] = self.st.basecolors.midBG },
                hovered = { [ImGui.Col_Text] = self.st.basecolors.active },
                active = { [ImGui.Col_Text] = self.st.basecolors.midText },
            }
        },
        searchWindow = {
            [ImGui.Col_TableBorderStrong] = 0x00000000,
            [ImGui.Col_TextSelectedBg] = self.st.basecolors.main,
            [ImGui.Col_Header] = self.st.basecolors.mainDark,
            [ImGui.Col_HeaderHovered] = self.st.basecolors.mainDark,
        },
        search = {
            highlight = {
                [ImGui.Col_Text] = self.st.basecolors.mainBright,
            },
            favorite = {
                [ImGui.Col_Text] = self.st.basecolors.main,
            }
        },
        main = {
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
        },
        title = {
            [ImGui.Col_Text] = self.st.basecolors.mainBright,
        }
    }
    self.st.vars = {
        pan = {
            [ImGui.StyleVar_GrabMinSize] = { 6, nil },
            [ImGui.StyleVar_GrabRounding] = { self.st.rounding * 2, nil },
        },
        vol = {
            [ImGui.StyleVar_GrabMinSize] = { 8, nil },
            [ImGui.StyleVar_GrabRounding] = { self.st.rounding * 2, nil },
        },
        main = {
            [ImGui.StyleVar_FrameRounding] = { self.st.rounding, nil },
            [ImGui.StyleVar_ItemSpacing] = { 4, 4 },
            [ImGui.StyleVar_WindowRounding] = { 10, nil },
        },
        searchWindow = {
            [ImGui.StyleVar_SeparatorTextAlign] = { 0, 0 },
            [ImGui.StyleVar_SeparatorTextBorderSize] = { 1, nil },
            [ImGui.StyleVar_SeparatorTextPadding] = { 0, 0 },
        },
        bigButton = {
            [ImGui.StyleVar_FrameRounding] = { 10, nil },
            [ImGui.StyleVar_FramePadding] = { 20, 10 },
        }
    }

    self.drawSadFace = function(self, sizeFactor, color)
        local x, y = ImGui.GetCursorScreenPos(self.ctx)
        local sz = self.TEXT_BASE_WIDTH * sizeFactor
        ImGui.DrawList_AddCircleFilled(self.draw_list, x, y, sz, color, 36)
        ImGui.DrawList_AddCircleFilled(self.draw_list, x - sz / 3.5, y - sz / 5, sz / 9, 0x000000ff, 36)
        ImGui.DrawList_AddCircleFilled(self.draw_list, x + sz / 3.5, y - sz / 5, sz / 9, 0x000000ff, 36)
        ImGui.DrawList_AddLine(self.draw_list, x + sz / 2, y + sz / 10, x - sz / 2, y + sz / 2.5, 0x000000ff, sz / 9)
    end
end
