-- @noindex

function OD_GetRegionManagerWindow()
    local title = r.JS_Localize('Region/Marker Manager', 'common')
    return r.JS_Window_Find(title, true)
end

function OD_OpenAndGetRegionManagerWindow()
    local title = r.JS_Localize('Region/Marker Manager', 'common')
    local manager = OD_GetRegionManagerWindow()
    if not manager then
        r.Main_OnCommand(40326, 0) -- View: Show region/marker manager window
        manager = r.JS_Window_Find(title, true)
    end
    return manager
end

function OD_GetAllRegionsOrMarkers(m_type, close)
    if close == nil then
        close = true
    end
    local manager = OD_OpenAndGetRegionManagerWindow()
    local lv = r.JS_Window_FindChildByID(manager, 1071)
    local cnt = r.JS_ListView_GetItemCount(lv)
    local t = {}
    if m_type == '' then
        m_type = nil
    end
    for i = 0, cnt - 1 do
        local matchstring = ("%s%%d+"):format(m_type and (m_type:upper()) or ".")
        for rId in r.JS_ListView_GetItemText(lv, i, 1):gmatch(matchstring) do
            t[#t + 1] = {
                is_rgn = rId:sub(1, 1) == 'R',
                id = rId,
                name = r.JS_ListView_GetItemText(lv, i, 2),
                selected = (r.JS_ListView_GetItemState(lv, i) ~= 0)
            }
        end
    end
    if close then
        r.Main_OnCommand(40326, 0)
    end -- View: Show region/marker manager window
    return t, lv
end

function OD_GetSelectedRegionsOrMarkers(m_type)
    local markeregions = OD_GetAllRegionsOrMarkers(m_type)
    local selected_markeregions = {}
    for i, markeregion in ipairs(markeregions) do
        if markeregion.selected then
            table.insert(selected_markeregions, markeregion)
        end
    end
    return selected_markeregions
end

function OD_SelectRegionsOrMarkers(selection, close)
    if close == nil then
        close = true
    end
    local markeregions, lv = OD_GetAllRegionsOrMarkers(nil, false)
    r.JS_ListView_SetItemState(lv, -1, 0x0, 0x2) -- unselect all items
    for _, markeregion_to_select in ipairs(selection) do
        for i, markeregion in ipairs(markeregions) do
            if markeregion.id == tostring(markeregion_to_select.id) then
                r.JS_ListView_SetItemState(lv, i - 1, 0xF, 0x2) -- select item @ index
            end
        end
    end
    if close then
        r.Main_OnCommand(40326, 0)
    end -- View: Show region/marker manager window
end

function OD_GetAllRegions(close)
    return OD_GetAllRegionsOrMarkers('R', close)
end

function OD_GetAllMarkers(close)
    return OD_GetAllRegionsOrMarkers('M', close)
end

function OD_GetSelectedRegions()
    return OD_GetSelectedRegionsOrMarkers('R')
end

function OD_GetSelectedMarkers()
    return OD_GetSelectedRegionsOrMarkers('M')
end

function OD_SelectRegions(selection, close)
    OD_SelectRegionsOrMarkers(selection, close)
end

function OD_SelectMarkers(selection, close)
    OD_SelectRegionsOrMarkers(selection, close)
end
