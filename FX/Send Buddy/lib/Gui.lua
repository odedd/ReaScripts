-- @noindex
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
ImGui = require 'imgui' '0.9.1'

SM_Gui = OD_Gui:new({

})

SM_Gui.init = function(self, fonts)
    OD_Gui.addFont(self, 'vertical', 'Resources/Fonts/Cousine-90deg.otf', 11)
    OD_Gui.init(self, true)
    ImGui.PushFont(self.ctx, self.st.fonts.default)
    self.mainWindow.hintHeight = ImGui.GetTextLineHeightWithSpacing(self.ctx) +
        select(2, ImGui.GetStyleVar(self.ctx, ImGui.StyleVar_FramePadding)) +
        select(2, ImGui.GetStyleVar(self.ctx, ImGui.StyleVar_ItemSpacing)) +
        select(2, ImGui.GetStyleVar(self.ctx, ImGui.StyleVar_WindowPadding))-1

    ImGui.PopFont(self.ctx)

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
        mainDark = 0x371f23ff,
        mainBright = 0xb73849ff,
        mainBrighter = 0xc74859ff,
        textBright = 0xf7f7f7ff,
        textDark = 0x7c7c7cff,
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
                [false] = {
                    [ImGui.Col_Text] = 0x000000ff,
                    [ImGui.Col_Button] = self.st.basecolors.widgetBG,
                    [ImGui.Col_ButtonHovered] = self.st.basecolors.hovered,
                    [ImGui.Col_ButtonActive] = self.st.basecolors.active
                }
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
            env = {
                [ImGui.Col_Button] = self.st.basecolors.darkBG,
                [ImGui.Col_ButtonHovered] = self.st.basecolors.darkHovered,
                [ImGui.Col_ButtonActive] = self.st.basecolors.darkActive,
                [ImGui.Col_Text] = self.st.basecolors.widgetBG,
            },
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
                    [ImGui.Col_Button] = self.st.basecolors.darkBG,
                    [ImGui.Col_ButtonHovered] = self.st.basecolors.darkHovered,
                    [ImGui.Col_ButtonActive] = self.st.basecolors.darkActive,
                    [ImGui.Col_Text] = self.st.basecolors.mainBright,
                },
                ['confirm'] = {
                    [ImGui.Col_Button] = self.st.basecolors.main,
                    [ImGui.Col_ButtonHovered] = self.st.basecolors.mainBright,
                    [ImGui.Col_ButtonActive] = self.st.basecolors.mainBrighter,
                    [ImGui.Col_Text] = 0x000000ff
                }
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
        },
    }
    ImGui.PushFont(self.ctx, self.st.fonts.vertical)
    self.VERTICAL_TEXT_BASE_WIDTH, self.VERTICAL_TEXT_BASE_HEIGHT = ImGui.CalcTextSize(self.ctx, 'A')
    self.VERTICAL_TEXT_BASE_HEIGHT_OFFSET = -2
    ImGui.PopFont(self.ctx)

    self.st.sizes = {
        sendTypeSeparatorWidth = self.TEXT_BASE_HEIGHT,
        sendTypeSeparatorHeight = 95,
        minFaderHeight = 100
    }
    self.st.vars.addSendButton = {
        [ImGui.StyleVar_FrameRounding] = { self.st.sizes.sendTypeSeparatorWidth, nil },
    }

    self.drawSadFace = function(self, sizeFactor, color)
        local x, y = ImGui.GetCursorScreenPos(self.ctx)
        local sz = self.TEXT_BASE_WIDTH * sizeFactor
        ImGui.DrawList_AddCircleFilled(self.draw_list, x, y, sz, color, 36)
        ImGui.DrawList_AddCircleFilled(self.draw_list, x - sz / 3.5, y - sz / 5, sz / 9, 0x000000ff, 36)
        ImGui.DrawList_AddCircleFilled(self.draw_list, x + sz / 3.5, y - sz / 5, sz / 9, 0x000000ff, 36)
        ImGui.DrawList_AddLine(self.draw_list, x + sz / 2, y + sz / 10, x - sz / 2, y + sz / 2.5, 0x000000ff, sz / 9)
    end

    self.verticalText = function(self, text)
        ImGui.PushFont(self.ctx, self.st.fonts.vertical)
        local letterspacing = (self.VERTICAL_TEXT_BASE_HEIGHT + self.VERTICAL_TEXT_BASE_HEIGHT_OFFSET)
        local posX, posY = ImGui.GetCursorPosX(self.ctx), ImGui.GetCursorPosY(self.ctx) - letterspacing * #text
        text = text:reverse()
        for ci = 1, #text do
            ImGui.SetCursorPos(self.ctx, posX, posY + letterspacing * (ci - 1))
            ImGui.Text(self.ctx, text:sub(ci, ci))
        end
        ImGui.PopFont(self.ctx)
    end
    self.drawVerticalText = function(self, drawList, text, x, y, color)
        local color = color or 0xffffffff
        ImGui.PushFont(self.ctx, self.st.fonts.vertical)
        local letterspacing = (self.VERTICAL_TEXT_BASE_HEIGHT + self.VERTICAL_TEXT_BASE_HEIGHT_OFFSET)
        local posX, posY = (x or select(1,ImGui.GetCursorScreenPos(self.ctx))), (y or select(2,ImGui.GetCursorScreenPos(self.ctx))) - letterspacing * #text
        text = text:reverse()
        for ci = 1, #text do
            -- ImGui.SetCursorPos(self.ctx, posX, posY + letterspacing * (ci - 1))
            -- ImGui.Text(self.ctx, text:sub(ci, ci))
            ImGui.DrawList_AddText(drawList, posX, posY + letterspacing * (ci - 1), color, text:sub(ci, ci))
        end
        ImGui.PopFont(self.ctx)
    end

end
