-- @noindex

function OD_OpenLink(url)
    if r.APIExists('CF_ShellExecute') then
        r.CF_ShellExecute(url)
    else
        local command
        if OS_is.mac then
            command = 'open "%s"'
        elseif OS_is.win then
            command = 'start "URL" /B "%s"'
        elseif OS_is.lin then
            command = 'xdg-open "%s"'
        end
        if command then
            os.execute(command:format(url))
        end
    end
end