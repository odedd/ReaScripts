-- @noindex

gui = {}
    do
        -- these needs to be temporarily created to be refered to from some of the gui vars
        local ctx = r.ImGui_CreateContext(scr.context_name .. '_MAIN')
        local font_default = r.ImGui_CreateFont(scr.dir .. '../../Resources/Fonts/Cousine-Regular.ttf', 16)

        r.ImGui_Attach(ctx, font_default)

        gui = {
            ctx = ctx,
            mainWindow = {},
            draw_list = r.ImGui_GetWindowDrawList(ctx),
            st = {
                fonts = {
                    default = font_default
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
                    }
                },
            },
            popups = {
                singleInput = {
                    status = ""
                }
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
    end