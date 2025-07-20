-- @noindex
-- Example usage of the enhanced PB_Tags:import() function with string sanitization

-- This example demonstrates how to use the import function with the new return values:
-- success, skippedAssets, mappedCount, skippedCount = tags:import(filename, mergeMode)

-- The import/export functions now include comprehensive string sanitization via OD CSV helpers:
-- - OD_EscapeCSV(): Escapes commas, colons, newlines, and backslashes in tag names and asset IDs
-- - OD_UnescapeCSV(): Safely unescapes the above characters  
-- - OD_ParseCSVLine(): Safely parses CSV with escaped characters
-- - OD_FindUnescapedChar(): Finds unescaped separators in strings
-- - Handles malformed data gracefully with detailed error reporting

-- Assuming you have a tags object initialized (like in Scout)
-- local tags = app.tags

local function demonstrateImport()
    local filename = "exported_tags.ini"
    local mergeMode = false  -- false = replace mode, true = merge mode
    
    -- Call the import function with new enhanced return values
    local success, skippedAssets, mappedCount, skippedCount = tags:import(filename, mergeMode)
    
    if success then
        print("✓ Import successful!")
        print(string.format("Assets mapped: %d, skipped: %d", mappedCount, skippedCount))
        
        -- Show detailed information about skipped assets
        if skippedCount > 0 then
            print("\nSkipped assets details:")
            for _, skippedAsset in ipairs(skippedAssets) do
                local reasonText = T.IMPORT_SKIP_REASON[skippedAsset.reason] or "Unknown reason"
                print(string.format("  - %s: %s (%s)", 
                    skippedAsset.basename, 
                    reasonText, 
                    skippedAsset.assetTypeGuess))
                print(string.format("    Original ID: %s", skippedAsset.originalAssetId))
            end
            
            print("\nTip: Skipped assets might be missing from your system or have different paths.")
        else
            print("All assets imported successfully!")
        end
        
        -- You can now use the imported tags
        print(string.format("\nTotal tagged assets in system: %d", 
            OD_CountTableItems(tags.current.taggedAssets)))
        
    else
        print("✗ Import failed!")
        -- skippedAssets contains the error message when success is false
        if type(skippedAssets) == "string" then
            print("Error: " .. skippedAssets)
        end
        print(string.format("Attempted to map: %d, failed: %d", mappedCount, skippedCount))
    end
end

-- Example output scenarios:

--[[ Successful import with some skipped assets:
✓ Import successful!
Assets mapped: 5, skipped: 2

Skipped assets details:
  - FabFilter Pro-Q 4.vst3: Asset not found in current system (plugin)
    Original ID: 1 /Library/Audio/Plug-Ins/VST3/FabFilter Pro-Q 4.vst3
  - My Custom Track.RTrackTemplate: Asset not found in current system (track template)
    Original ID: 3 My Custom Track.RTrackTemplate

Tip: Skipped assets might be missing from your system or have different paths.

Total tagged assets in system: 12
--]]

--[[ Failed import due to file error:
✗ Import failed!
Error: Failed to open file for reading
Attempted to map: 0, failed: 0
--]]

--[[ Perfect import with no skipped assets:
✓ Import successful!
Assets mapped: 7, skipped: 0
All assets imported successfully!

Total tagged assets in system: 15
--]]

-- Advanced usage: Processing skipped assets for user feedback
local function processSkippedAssets(skippedAssets)
    local assetsByType = {}
    
    -- Group skipped assets by type for better reporting
    for _, skippedAsset in ipairs(skippedAssets) do
        local assetType = skippedAsset.assetTypeGuess
        if not assetsByType[assetType] then
            assetsByType[assetType] = {}
        end
        table.insert(assetsByType[assetType], skippedAsset)
    end
    
    -- Report by asset type
    for assetType, assets in pairs(assetsByType) do
        print(string.format("Skipped %s (%d):", assetType, #assets))
        for _, asset in ipairs(assets) do
            local reasonText = T.IMPORT_SKIP_REASON[asset.reason]
            print(string.format("  • %s - %s", asset.basename, reasonText))
        end
    end
end

-- Usage in merge mode to combine tags from multiple sources
local function demonstrateMergeMode()
    print("Importing in merge mode (combines with existing tags)...")
    local success, skippedAssets, mappedCount, skippedCount = tags:import("additional_tags.ini", true)
    
    if success then
        print(string.format("Merge complete: %d new assets tagged, %d skipped", mappedCount, skippedCount))
        if skippedCount > 0 then
            processSkippedAssets(skippedAssets)
        end
    end
end

return {
    demonstrateImport = demonstrateImport,
    processSkippedAssets = processSkippedAssets,
    demonstrateMergeMode = demonstrateMergeMode
}
