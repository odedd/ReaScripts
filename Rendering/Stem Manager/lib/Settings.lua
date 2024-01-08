-- @noindex

Settings = {}
function GetDefaultSettings(factory)
    if factory == nil then
        factory = false
    end
    local settings = {
        default = {
            renderaction = RENDERACTION_RENDER,
            overwrite_without_asking = false,
            wait_time = 5,
            reflect_on_add = REFLECT_ON_ADD_TRUE,
            syncmode = SYNCMODE_MIRROR,
            render_setting_groups = {},
            show_hidden_tracks = false,
            play_sound_when_done = false
        }
    }

    local default_render_settings = {
        description = '',
        render_preset = nil,
        skip_empty_stems = true,
        put_in_folder = false,
        folder = '',
        override_filename = false,
        filename = '',
        make_timeSel = false,
        timeSelStart = 0,
        timeSelEnd = 0,
        select_regions = false,
        selected_regions = {},
        select_markers = false,
        selected_markers = {},
        run_actions = false,
        actions_to_run = {},
        run_actions_after = false,
        actions_to_run_after = {},
        ignore_warnings = false
    }
    for i = 1, RENDER_SETTING_GROUPS_SLOTS do
        table.insert(settings.default.render_setting_groups, OD_DeepCopy(default_render_settings))
    end

    if not factory then
        local loaded_ext_settings = table.load(Scr.dfsetfile) or
            {} -- unpickle(r.GetExtState(scr.ext_name, 'DEFAULT SETTINGS') or '')
        -- merge default settings from extstates with script defaults
        for k, v in pairs(loaded_ext_settings or {}) do
            if not (k == 'render_setting_groups') then
                settings.default[k] = v
            else
                for rgIdx, val in ipairs(v) do
                    for rgSetting, rgV in pairs(val or {}) do
                        if not settings.default.render_setting_groups[rgIdx] then -- if more render were saved than there are by default, create them by loading default vaules first
                            settings.default.render_setting_groups[rgIdx] = OD_DeepCopy(default_render_settings)
                        end
                        settings.default.render_setting_groups[rgIdx][rgSetting] = rgV
                    end
                end
            end
        end
    end

    return settings
end

function LoadSettings()
    Settings = GetDefaultSettings()
    -- take merged updated default settings and merge project specific settings into them
    local loaded_project_settings = unpickle(OD_LoadLongProjExtKey(Scr.ext_name, 'PROJECT SETTINGS'))
    -- Settings.project = Settings.project or {}
    Settings.project = OD_DeepCopy(Settings.default)
    -- OD_MergeTables(Settings.project,Settings.default)
    for k, v in pairs(loaded_project_settings or {}) do
        if not (k == 'render_setting_groups') then
            Settings.project[k] = v
        else
            for rgIdx, val in ipairs(v) do
                if rgIdx < RENDER_SETTING_GROUPS_SLOTS then
                    for rgSetting, rgV in pairs(val or {}) do
                        Settings.project.render_setting_groups[rgIdx][rgSetting] = rgV
                    end
                end
            end
        end
    end
end

function SaveSettings()
    table.save(Settings.default, Scr.dfsetfile)
    OD_SaveLongProjExtState(Scr.ext_name, 'PROJECT SETTINGS', pickle(Settings.project))
    r.MarkProjectDirty(0)
end

function UpdateSettings()
    for rgIdx, val in ipairs(Settings.project.render_setting_groups) do
        for rgAIdx, command_id in pairs(Settings.project.render_setting_groups[rgIdx].actions_to_run or {}) do
            if type(command_id) ~= "string" then
                local named_command = r.ReverseNamedCommandLookup(command_id)
                if named_command then
                    Settings.project.render_setting_groups[rgIdx].actions_to_run[rgAIdx] = named_command
                end
            end
        end
        for rgAIdx, command_id in pairs(Settings.project.render_setting_groups[rgIdx].actions_to_run_after or {}) do
            if type(command_id) ~= "string" then
                local named_command = r.ReverseNamedCommandLookup(command_id)
                if named_command then
                    Settings.project.render_setting_groups[rgIdx].actions_to_run_after[rgAIdx] = named_command
                end
            end
        end
    end
    SaveSettings()
end
