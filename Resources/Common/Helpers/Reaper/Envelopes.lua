-- @noindex

function OD_ToggleShowEnvelope(env, show)
    local ret, chunk = reaper.GetEnvelopeStateChunk(env, '', false)
    if chunk then
        local nchunk
        if show == nil and chunk:find('VIS 1') then show = false else show = true end
        if show == true then
            nchunk = string.gsub(chunk, 'ACT 0', 'ACT 1')
            nchunk = string.gsub(nchunk, 'VIS 0', 'VIS 1')
            nchunk = string.gsub(nchunk, 'ARM 0', 'ARM 1')
            if not nchunk:find('PT') then nchunk = nchunk:gsub('>', 'PT 0 1 0\n>') end
        elseif show == false then
            nchunk = string.gsub(chunk, 'ACT 1', 'ACT 0')
            nchunk = string.gsub(nchunk, 'VIS 1', 'VIS 0')
            nchunk = string.gsub(nchunk, 'ARM 1', 'ARM 0')
        end
        reaper.SetEnvelopeStateChunk(env, nchunk, true)
    end
end