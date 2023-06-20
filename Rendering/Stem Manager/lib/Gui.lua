-- @noindex
Gui = {}
do
    -- these needs to be temporarily created to be refered to from some of the gui vars
    local ctx = r.ImGui_CreateContext(Scr.context_name .. '_MAIN')
    local cellSize = 25

    local font_vertical = r.ImGui_CreateFont(OD_LocalOrCommon('Resources/Fonts/Cousine-90deg.otf', Scr.dir), 11)
    local font_default = r.ImGui_CreateFont(OD_LocalOrCommon('Resources/Fonts/Cousine-Regular.ttf', Scr.dir), 16)
    local font_bold = r.ImGui_CreateFont(OD_LocalOrCommon('Resources/Fonts/Cousine-Regular.ttf', Scr.dir), 16,
        r.ImGui_FontFlags_Bold())

    r.ImGui_Attach(ctx, font_default)
    r.ImGui_Attach(ctx, font_vertical)
    r.ImGui_Attach(ctx, font_bold)

    Gui = {
        ctx = ctx,
        mainWindow = {},
        draw_list = r.ImGui_GetWindowDrawList(ctx),
        keyModCtrlCmd = (OS_is.mac or OS_is.mac_arm) and r.ImGui_Mod_Super() or r.ImGui_Mod_Ctrl(),
        notKeyModCtrlCmd = (OS_is.mac or OS_is.mac_arm) and r.ImGui_Mod_Ctrl() or r.ImGui_Mod_Super(),
        descModCtrlCmd = (OS_is.mac or OS_is.mac_arm) and 'cmd' or 'control',
        descModAlt = (OS_is.mac or OS_is.mac_arm) and 'opt' or 'alt',
        st = {
            fonts = {
                default = font_default,
                vertical = font_vertical,
                bold = font_bold
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
                },
                stemSyncBtn = {
                    [SYNCMODE_MIRROR] = {
                        inactive = {
                            [r.ImGui_Col_Text()] = 0xb5301fff,
                            [r.ImGui_Col_Button()] = 0x1e241eff,
                            [r.ImGui_Col_ButtonHovered()] = 0x293229FF,
                            [r.ImGui_Col_ButtonActive()] = 0x273827FF
                        },
                        active = {
                            [r.ImGui_Col_Text()] = 0x000000ff,
                            [r.ImGui_Col_Button()] = 0x3c9136ff,
                            [r.ImGui_Col_ButtonHovered()] = 0x45a33eFF,
                            [r.ImGui_Col_ButtonActive()] = 0x4eba47FF
                        }
                    },
                    [SYNCMODE_SOLO] = {
                        inactive = {
                            [r.ImGui_Col_Text()] = 0xb5301fff,
                            [r.ImGui_Col_Button()] = 0x1e2024FF,
                            [r.ImGui_Col_ButtonHovered()] = 0x292c32FF,
                            [r.ImGui_Col_ButtonActive()] = 0x272c38FF
                        },
                        active = {
                            [r.ImGui_Col_Text()] = 0x000000ff,
                            [r.ImGui_Col_Button()] = 0x365f91ff,
                            [r.ImGui_Col_ButtonHovered()] = 0x3e6ba3FF,
                            [r.ImGui_Col_ButtonActive()] = 0x477fbaFF
                        }
                    }
                },
                hasChildren = {
                    [STATES.SOLO_IN_PLACE] = {
                        [r.ImGui_Col_Text()] = 0x00000099
                    },
                    [STATES.SOLO_IGNORE_ROUTING] = {
                        [r.ImGui_Col_Text()] = 0x00000099
                    },
                    [STATES.MUTE_SOLO_IN_PLACE] = {
                        [r.ImGui_Col_Text()] = 0x00000099
                    },
                    [STATES.MUTE_SOLO_IGNORE_ROUTING] = {
                        [r.ImGui_Col_Text()] = 0x00000099
                    },
                    [STATES.MUTE] = {
                        [r.ImGui_Col_Text()] = 0x00000099
                    },
                    [' '] = {
                        [r.ImGui_Col_Text()] = 0xffffff22
                    }
                },
                render_setting_groups = {},
                stemState = {
                    ['sync_0'] = {
                        [r.ImGui_Col_Text()] = 0x000000ff,
                        [r.ImGui_Col_Button()] = 0x1e241eff,
                        [r.ImGui_Col_ButtonHovered()] = 0x273827FF
                    },
                    ['sync_1'] = {
                        [r.ImGui_Col_Text()] = 0x000000ff,
                        [r.ImGui_Col_Button()] = 0x1e1f24FF,
                        [r.ImGui_Col_ButtonHovered()] = 0x272c38FF
                    },
                    [STATES.SOLO_IN_PLACE] = {
                        [r.ImGui_Col_Text()] = 0x000000ff,
                        [r.ImGui_Col_Button()] = 0xd6be42FF,
                        [r.ImGui_Col_ButtonHovered()] = 0xe3d382FF
                    },
                    [STATES.SOLO_IGNORE_ROUTING] = {
                        [r.ImGui_Col_Text()] = 0x000000ff,
                        [r.ImGui_Col_Button()] = 0x48ab9cFF,
                        [r.ImGui_Col_ButtonHovered()] = 0x7ac7bcFF
                    },
                    [STATES.MUTE] = {
                        [r.ImGui_Col_Text()] = 0x000000ff,
                        [r.ImGui_Col_Button()] = 0xa63f3fFF,
                        [r.ImGui_Col_ButtonHovered()] = 0xc35555FF
                    },
                    [' '] = {
                        [r.ImGui_Col_Text()] = 0x000000FF,
                        [r.ImGui_Col_Button()] = 0x00000000,
                        [r.ImGui_Col_ButtonHovered()] = 0xFFFFFF22
                    }
                },
                trackname = {
                    [r.ImGui_Col_HeaderHovered()] = 0xFFFFFF22,
                    [r.ImGui_Col_HeaderActive()] = 0xFFFFFF66
                }
            },
            vars = {
                mtrx = {
                    cellSize = cellSize,
                    table = {
                        [r.ImGui_StyleVar_IndentSpacing()] = { cellSize },
                        [r.ImGui_StyleVar_CellPadding()] = { 0, 0 },
                        [r.ImGui_StyleVar_ItemSpacing()] = { 1, 0 }
                    },

                    stemState = {
                        [r.ImGui_StyleVar_FramePadding()] = { 0, -1 }
                    }
                }
            }
        },
        mtrxTbl = {
            drgState = nil
        },
        stWnd = {}, -- settings window states
        caWnd = {}, -- create action window states
        popups = {
            singleInput = {
                status = ""
            }
        },
        tables = {
            horizontal = {
                flags1 = r.ImGui_TableFlags_ScrollX() | r.ImGui_TableFlags_ScrollY() |
                    r.ImGui_TableFlags_BordersOuter() | r.ImGui_TableFlags_Borders() |
                    r.ImGui_TableFlags_NoHostExtendX() | r.ImGui_TableFlags_SizingFixedFit()
            }
        },
        treeflags = {
            base = r.ImGui_TreeNodeFlags_SpanFullWidth() | r.ImGui_TreeNodeFlags_FramePadding(),
            leaf = r.ImGui_TreeNodeFlags_FramePadding() | r.ImGui_TreeNodeFlags_SpanFullWidth() |
                r.ImGui_TreeNodeFlags_DefaultOpen() | r.ImGui_TreeNodeFlags_Leaf() |
                r.ImGui_TreeNodeFlags_NoTreePushOnOpen()
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

    r.ImGui_PushFont(ctx, Gui.st.fonts.default)
    Gui.TEXT_BASE_WIDTH, Gui.TEXT_BASE_HEIGHT = r.ImGui_CalcTextSize(ctx, 'A'),
        r.ImGui_GetTextLineHeightWithSpacing(ctx)
    r.ImGui_PopFont(ctx)
    r.ImGui_PushFont(ctx, Gui.st.fonts.vertical)
    Gui.VERTICAL_TEXT_BASE_WIDTH, Gui.VERTICAL_TEXT_BASE_HEIGHT = r.ImGui_CalcTextSize(ctx, 'A')
    Gui.VERTICAL_TEXT_BASE_HEIGHT_OFFSET = -2
    r.ImGui_PopFont(ctx)
    Gui.st.vars.mtrx.table[r.ImGui_StyleVar_FramePadding()] = { 1, (cellSize - Gui.TEXT_BASE_HEIGHT) / 2 + 2 }
    -- iterate render setting group colors

    local base_color = 0xff66d6ff
    local lightnessSteps = .1
    local hueStep = 0.2

    for i = 1, RENDER_SETTING_GROUPS_SLOTS do
        local re, g, b, a = r.ImGui_ColorConvertU32ToDouble4(base_color)
        local h, s, v = r.ImGui_ColorConvertRGBtoHSV(re, g, b)
        local shiftedCol = {
            [r.ImGui_Col_Text()] = 0x000000ff,
            [r.ImGui_Col_Button()] = base_color,
            [r.ImGui_Col_ButtonHovered()] = 0xFFFFFF33,
            [r.ImGui_Col_ButtonActive()] = 0xFFFFFF88
        }
        table.insert(Gui.st.col.render_setting_groups, shiftedCol)
        -- shift to next base color
        re, g, b = r.ImGui_ColorConvertHSVtoRGB((h + hueStep), s, v)
        base_color = r.ImGui_ColorConvertNative(r.ImGui_ColorConvertDouble4ToU32(re, g, b, a))
    end
end