-- @noindex

function OD_Wait(seconds)
    if seconds == 0 then return end
    local time = r.time_precise()
    while r.time_precise() - time < seconds do end
end

function OD_WaitAndDo(seconds, action, performOnce)
    if seconds == 0 then 
        if performOnce and action then action() end -- perform once even if time is zero
        return
    end
    local time = r.time_precise()
    while r.time_precise() - time < seconds do
        if action then action() end
    end
end
