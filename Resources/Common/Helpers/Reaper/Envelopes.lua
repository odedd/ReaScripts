-- @noindex

function OD_ToggleShowEnvelope(env, show, val)
    val = val or 1
    local oldVal, envelopeExists
    local ret, chunk = reaper.GetEnvelopeStateChunk(env, '', false)
    if chunk then
        local nchunk
        if show == nil and chunk:find('VIS 1') then show = false else show = true end
        if show == true then
            nchunk = string.gsub(chunk, 'ACT 0', 'ACT 1')
            nchunk = string.gsub(nchunk, 'VIS 0', 'VIS 1')
            nchunk = string.gsub(nchunk, 'ARM 0', 'ARM 1')
            if not nchunk:find('PT') then
                nchunk = nchunk:gsub('>', ('PT 0 %f 0\n>'):format(val))
            else
                envelopeExists = true
            end
        elseif show == false then
            nchunk = string.gsub(chunk, 'ACT 1', 'ACT 0')
            nchunk = string.gsub(nchunk, 'VIS 1', 'VIS 0')
            nchunk = string.gsub(nchunk, 'ARM 1', 'ARM 0')
            oldVal = tonumber(nchunk:match('PT 0 ([^%s]+) 0[\n\r]>') or '1')
            nchunk = nchunk:gsub('PT 0 [^%s]+ [^P]+[\n\r]>', '>') -- delete point if its the only one
        end
        reaper.SetEnvelopeStateChunk(env, nchunk, true)
    end
    return show, oldVal, envelopeExists
end
