-- @noindex

function OD_CreateSafeCoroutine(func, traceback)
                local wrappedFunc = function(...)
                    local success, result
                    if traceback then
                        success, result = xpcall(func, debug.traceback, ...)
                    else
                        success, result = pcall(func, ...)
                    end
                    if not success then
                        -- Error occurred, yield error information and return
                        coroutine.yield({
                            error = true,
                            msg = "Error: " .. tostring(result)
                        })
                        return { error = true, msg = tostring(result) }
                    end
                    -- Function completed successfully, return its result
                    return result
                end
                return coroutine.create(wrappedFunc)
            end