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
    { id = 1, file = 'PluginAssetType.lua',          comment = 'FX' },
    { id = 2, file = 'FXChainAssetType.lua',         comment = 'FX chain files' },
    { id = 3, file = 'TrackTemplateAssetType.lua',   comment = 'Track template files' },
    { id = 4, file = 'ProjectTemplateAssetType.lua', comment = 'Project template files (.rpp)' },
    { id = 5, file = 'TrackAssetType.lua',           comment = 'Tracks' },
    { id = 6, file = 'MarkerAssetType.lua',          comment = 'Markers/Regions' },
    { id = 7, file = 'ProjectAssetType.lua',         comment = 'Project files (.rpp)' },
    { id = 8, file = 'ActionAssetType.lua',          comment = 'Reaper actions' },

    -- When adding new asset types, assign the next available ID and add here:
    -- { id = 7, file = 'NewAssetType.lua', comment = 'Description of new type' },
}
