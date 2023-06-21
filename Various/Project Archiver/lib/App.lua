-- @noindex
App = OD_Perform_App:new({
    mediaFiles = {},
    revert = {},
    restore = {},
    popup = {}
})

function App:checkProjectChange()
    self.current_project = r.GetProjectStateChangeCount(0) -- if project changed, force reset
    local projPath, projFileName = OD_GetProjectPaths()
    OD_SetLogFile(projPath .. Scr.name..'_'..projFileName .. '.log')
    if self.current_project ~= self.previous_project then
        self.previous_project = self.current_project
        self.reset()
    end
end