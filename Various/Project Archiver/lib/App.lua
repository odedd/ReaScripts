-- @noindex
App = OD_Perform_App:new({
    mediaFiles = {},
    revert = {},
    restore = {},
    popup = {}
})

function App:checkProjectChange()
    if OD_DidProjectGUIDChange() then
        local projPath, projFileName = OD_GetProjectPaths()
        OD_SetLogFile(projPath .. Scr.name..'_'..projFileName .. '.log')
        self.reset()
    end
end