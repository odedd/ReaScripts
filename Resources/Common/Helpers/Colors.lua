-- @noindex
function OD_RgbToHsl(r, g, b)
    r = r / 255
    g = g / 255
    b = b / 255

    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local h, s, l

    l = (max + min) / 2

    if max == min then
        h, s = 0, 0 -- achromatic
    else
        local d = max - min
        s = l > 0.5 and d / (2 - max - min) or d / (max + min)

        if max == r then
            h = (g - b) / d + (g < b and 6 or 0)
        elseif max == g then
            h = (b - r) / d + 2
        else
            h = (r - g) / d + 4
        end

        h = h / 6
    end

    return h, s, l
end

function OD_HslToRgb(h, s, l)
    local function hueToRgb(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1/6 then return p + (q - p) * 6 * t end
        if t < 1/2 then return q end
        if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
        return p
    end

    local r, g, b

    if s == 0 then
        r = l
        g = l
        b = l
    else
        local q = l < 0.5 and l * (1 + s) or l + s - l * s
        local p = 2 * l - q
        r = hueToRgb(p, q, h + 1/3)
        g = hueToRgb(p, q, h)
        b = hueToRgb(p, q, h - 1/3)
    end

    return math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)
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

function OD_Int2Rgba(i)
    if i > 0xffffffff then
        i = i >> 8 % 0x100000000
    end

    local a = math.floor(i / 0x1000000) % 256
    local r = math.floor(i / 0x10000) % 256
    local g = math.floor(i / 0x100) % 256
    local b = i % 256
    return r, g, b, a
end

function OD_Rgb2Int(r, g, b)
    r = math.floor(r + 0.5)
    g = math.floor(g + 0.5)
    b = math.floor(b + 0.5)
    return (r << 16) | (g << 8) | b
end

function OD_Rgba2Int(r, g, b, a)
    r = math.floor(r + 0.5)
    g = math.floor(g + 0.5)
    b = math.floor(b + 0.5)
    a = math.floor(a + 0.5)
    return (a << 24) | (r << 16) | (g << 8) | b
end

function OD_OffsetRgbaByHSL(col, hOffset,sOffset,lOffset)
    local r,g, b,a = OD_Int2Rgba(col)
    local h,s,l = OD_RgbToHsl(r, g, b)
    r, g, b = OD_HslToRgb(math.max(0,math.min(1,h+hOffset)),math.max(0,math.min(1,s+sOffset)),math.max(0,math.min(1,l+lOffset)))
    return OD_Rgba2Int(r,g,b,a)

end