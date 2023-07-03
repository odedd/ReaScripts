-- @noindex

PA_Settings = OD_Settings:new({
    default = {
        backup = true,
        minimize = true,
        cleanMediaFolder = true,
        keepActiveTakesOnly = true,
        minimizeSourceTypes = MINIMIZE_SOURCE_TYPES.UNCOMPRESSED_AND_LOSSLESS,
        deleteMethod = DELETE_METHOD.MOVE_TO_TRASH,
        collect = COLLECT.RS5K + COLLECT.VIDEO + COLLECT.EXTERNAL,
        collectOperation = COLLECT_OPERATION.COPY,
        freezeHandling = FREEZE_HANDLING.REMOVE,
        keepMediaFolderStructure = true,
        glueFormat = GLUE_FORMATS.FLAC24,
        padding = 1,
        suffix = '_m',
        showBetaWarning = true,
        targetPaths = {
            [FILE_TYPES.VIDEO] = 'Video Files',
            [FILE_TYPES.RS5K] = 'RS5K Samples'
        }
    },
    dfsetfile = Scr.dfsetfile
})

-- * local

function PA_Settings:check()
    local errors = {}
    if not (self.current.backup or self.current.keepActiveTakesOnly or self.current.minimize or self.current.cleanMediaFolder or (self.freezeHandling == FREEZE_HANDLING.KEEP) or (self.current.collect ~= 0)) then
        table.insert(errors, T.ERROR_NOTHING_TO_DO)
        return false, errors
    end
    local projectName = r.GetProjectName(0, '')
    if projectName == '' then
        table.insert(errors, 'Project must be saved')
        return false, errors
    end
    if r.CountMediaItems(0) == 0 then
        table.insert(errors, 'Project is empty')
        return false, errors
    end
    if OD_BfCheck(r.GetPlayState(), 1) then
        table.insert(errors, "Reaper must be stopped while the script is running")
        return false, errors
    end
    if self.current.backup then
        if self.current.backupDestination == nil then
            table.insert(errors, T.ERROR_NO_BACKUP_DESTINATION)
        elseif not OD_FolderExists(self.current.backupDestination) then
            table.insert(errors, T.ERROR_BACKUP_DESTINATION_MISSING)
        elseif not OD_IsFolderEmpty(self.current.backupDestination) then
            table.insert(errors, T.ERROR_BACKUP_DESTINATION_MUST_BE_EMPTY)
        end
    else
        if self.current.cleanMediaFolder and self.current.deleteMethod == DELETE_METHOD.KEEP_IN_FOLDER then
            table.insert(errors, T.ERROR_KEEP_IN_FOLDER)
        end
    end
    return #errors == 0, errors
end
