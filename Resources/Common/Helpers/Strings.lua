-- @noindex

function OD_Split (s, delimiter)
    local result = {};
    for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match);
    end
    return result;
end

function OD_EscapePattern(text)
    return text:gsub("([^%w])", "%%%1")
end

function OD_MagicFix(str)
  return str:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
end

function OD_CaseInsensitivePattern(pattern)

  
    -- find an optional '%' (group 1) followed by any character (group 2)
    local classStarted = false
    local p = pattern:gsub("(%%?)(.)", function(percent, letter)
      
      if percent ~= "" or not letter:match("%a") or classStarted then
        if letter == '[' then 
          classStarted = true
        elseif letter == ']' then
          classStarted = false
        end
        -- if the '%' matched, or `letter` is not a letter, return "as is"
        return percent .. letter
      elseif not classStarted then
        -- else, return a case-insensitive character class of the matched letter 
        return string.format("[%s%s]", letter:lower(), letter:upper())
      end
  
    end)
  
    return p
  end
function OD_Trim(s)
    return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

function OD_FormatNumberWithCommas(number)
    local s = tostring(number)
    local integer_part, fracPart = s:match("([^.]*)(.*)") -- Separate integer and fractional parts
    local formInteger = ""
    local len = #integer_part

    for i = 1, len do
        formInteger = formInteger .. integer_part:sub(i, i)
        if (len - i) % 3 == 0 and (len - i) ~= 0 then
            formInteger = formInteger .. ","
        end
    end

    return formInteger .. fracPart
end


-- function magicFix(str)
--     return str:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
--   end
  

