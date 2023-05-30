app = {
    open = true,
    coPerform = nil,
    mediaFiles = {},
    perform = {
        status = nil
    },
    hint = {
        main = {},
        settings = {}
    }
}

function app.getStatus(window)
    if window == 'main' then
        --  if db.error == 'no stemsFolder' then return "Stems folder not defined", 'error' end
        if app.coPerform then
            return app.perform.status
        end
        return app.hint.main.text, app.hint.main.color
    elseif window == 'settings' then
        return app.hint.settings.text, app.hint.settings.color
    end
end

function app.setHoveredHint(window, text, color, ctx)
    local ctx = ctx or gui.ctx
    if r.ImGui_IsItemHovered(ctx, r.ImGui_HoveredFlags_AllowWhenDisabled()) then
        app.setHint(window, text, color, ctx)
    end
end

function app.setHint(window, text, color, ctx)
    local ctx = ctx or gui.ctx
    color = color or 'hint'
    if (app.error or app.coPerform) and not (text == '') and text then
        app.hint[window] = {
            window = {}
        }
        if color then
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), gui.st.col[color])
        end
        r.ImGui_SetTooltip(ctx, text)
        if color then
            r.ImGui_PopStyleColor(ctx)
        end
    else
        app.hint[window] = {
            text = text,
            color = color
        }
    end
end