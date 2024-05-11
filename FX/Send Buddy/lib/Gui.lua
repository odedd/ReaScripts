-- @noindex
SM_Gui = OD_Gui:new({

})

SM_Gui.init = function(self, fonts)
    OD_Gui.init(self)
    self.st.basecolors = {
        darkBG = 0x242429ff,
        darkHovered = 0x29292fff,
        darkActive = 0x2d2d35ff,
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
        main = 0x8a3e38ff,
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
            }
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
                }
            },
            mode = {
                [0] = {
                    [r.ImGui_Col_Text()] = 0x000000ff,
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
                default = {[r.ImGui_Col_Text()] = self.st.basecolors.midBG},
                hovered = {[r.ImGui_Col_Text()] = self.st.basecolors.active},
                active = {[r.ImGui_Col_Text()] = self.st.basecolors.midText},
            }
        },
        searchWindow ={
            [r.ImGui_Col_TableBorderStrong()] = 0x00000000,
        },
        searchHighligh = {
            [r.ImGui_Col_Text()] = self.st.basecolors.main,
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
            [r.ImGui_Col_Button()] = self.st.basecolors.widgetBG,
            [r.ImGui_Col_ButtonHovered()] = self.st.basecolors.hovered,
            [r.ImGui_Col_ButtonActive()] = self.st.basecolors.active
        },
        title = {
            [r.ImGui_Col_Text()] = self.st.basecolors.main,
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
            [r.ImGui_StyleVar_SeparatorTextAlign()] = {0,0},
            [r.ImGui_StyleVar_SeparatorTextBorderSize()] = {1,nil},
            [r.ImGui_StyleVar_SeparatorTextPadding()] = {0,0},
        }
    }
end
