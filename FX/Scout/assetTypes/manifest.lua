-- @noindex
-- Asset Types Manifest
-- This file defines which asset types to load and their assigned IDs
-- 
-- ⚠️  WARNING: DO NOT CHANGE EXISTING IDs! ⚠️
-- Once an asset type has been assigned an ID, it should NEVER be changed
-- as this would break existing saved data (favorites, tags, etc.)
-- Only add new asset types with new IDs at the end.
--
-- Format: { id = <number>, file = '<filename>', comment = '<description>' }

return {
    { id = 0, file = 'PluginAssetType.lua',        comment = 'FX' },
    { id = 1, file = 'FXChainAssetType.lua',       comment = 'FX chain files' },
    { id = 2, file = 'TrackTemplateAssetType.lua', comment = 'Track template files' },
    { id = 3, file = 'TrackAssetType.lua',         comment = 'Tracks' },
    { id = 4, file = 'ActionAssetType.lua',        comment = 'Reaper actions' },
    { id = 5, file = 'ProjectAssetType.lua',       comment = 'Project files (.rpp)' },
    
    -- When adding new asset types, assign the next available ID and add here:
    -- { id = 6, file = 'NewAssetType.lua', comment = 'Description of new type' },
}
