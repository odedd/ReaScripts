-- @noindex

r = reaper
function run()
    r.Undo_BeginBlock()


    -- Get the edit cursor position
    local editCursorPos = reaper.GetCursorPosition()

    -- Get the total number of regions in the project
    local numRegions = reaper.CountProjectMarkers(0)

    -- Create a table to store the regions
    local regions = {}

    -- Iterate through all the regions
    for i = 0, numRegions - 1 do
        local _, isRegion, regionStart, regionEnd, regionName, regionIdx, regionCol = reaper.EnumProjectMarkers3(0, i)
        -- Check if it's a region and if it's above the edit cursor
        if isRegion and regionEnd >= editCursorPos and regionStart <= editCursorPos then
            table.insert(regions, regionIdx)
        end
    end

    if not next(regions) then
        r.ShowMessageBox("No regions found above the edit cursor!", 'Error', 0)
        return false
    end

    -- Check if there is more than one selected item
    local numSelectedItems = reaper.CountSelectedMediaItems(0)
    if numSelectedItems > 1 then
        r.ShowMessageBox("More than one item selected!", 'Error', 0)
        return false
    end

    -- Get the currently selected item
    local selectedItem = reaper.GetSelectedMediaItem(0, 0)

    -- Check if there is a selected item
    if not selectedItem then
        r.ShowMessageBox("No selected item found!", 'Error', 0)
        return false
    end

    for i, regionIdx in ipairs(regions) do
        -- Get the start and end positions of the selected item
        local itemStart = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
        local itemEnd = itemStart + reaper.GetMediaItemInfo_Value(selectedItem, "D_LENGTH")

        -- Set the region start and end positions to match the item bounds
        reaper.SetProjectMarker2(0, regionIdx, true, itemStart, itemEnd, '' )
    end
end

run()