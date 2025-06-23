-- @noindex

function OD_HslToRgb(h, s, l)
    if s == 0 then
        return l, l, l
    end
    local function to(p, q, t)
        if t < 0 then
            t = t + 1
        end
        if t > 1 then
            t = t - 1
        end
        if t < .16667 then
            return p + (q - p) * 6 * t
        end
        if t < .5 then
            return q
        end
        if t < .66667 then
            return p + (q - p) * (.66667 - t) * 6
        end
        return p
    end
    local q = l < .5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    return to(p, q, h + .33334), to(p, q, h), to(p, q, h - .33334)
end

function OD_RgbToHsl(r, g, b)
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local b = max + min
    local h = b / 2
    if max == min then
        return 0, 0, h
    end
    local s, l = h, h
    local d = max - min
    s = l > .5 and d / (2 - b) or d / b
    if max == r then
        h = (g - b) / d + (g < b and 6 or 0)
    elseif max == g then
        h = (b - r) / d + 2
    elseif max == b then
        h = (r - g) / d + 4
    end
    return h * .16667, s, l
end

-- Taken from here: https://github.com/norcalli/nvim-colorizer.lua/blob/master/lua/colorizer.lua
--- Determine whether to use black or white text
-- Ref: https://stackoverflow.com/a/1855903/837964
-- https://stackoverflow.com/questions/596216/formula-to-determine-brightness-of-rgb-color
function OD_ColorIsBright(col)
    local r, g, b = OD_Int2Rgb(col)
	-- Counting the perceptive luminance - human eye favors green color
	local luminance = (0.299*r + 0.587*g + 0.114*b)/255
	if luminance > 0.5 then
		return true -- Bright colors, black font
	else
		return false -- Dark colors, white font
	end
end

-- taken from here: https://gist.github.com/jasonbradley/4357406



function OD_Int2Rgb(i)
    if i > 0xffffff then
        i = i >> 8 % 0x1000000
    end

    local r = math.floor(i / 65536) % 256
    local g = math.floor(i / 256) % 256
    local b = i % 256
    return r, g, b
end