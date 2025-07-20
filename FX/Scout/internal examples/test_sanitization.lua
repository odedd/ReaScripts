-- @noindex
-- Test script for string sanitization functions
-- Note: This file requires the Common helpers to be loaded for OD_EscapeCSV, OD_UnescapeCSV, etc.

-- Test the escaping functions
local function testEscaping()
    print("Testing string sanitization...")
    
    -- Test cases
    local testCases = {
        "Normal text",
        "Text with, comma",
        "Text with: colon", 
        "Text with\nnewline",
        "Text with\\backslash",
        "Complex: text, with\nmultiple\\special chars",
        "",  -- Empty string
        nil  -- Nil value
    }
    
    print("\n--- Escape/Unescape Tests ---")
    for i, original in ipairs(testCases) do
        local escaped = OD_EscapeCSV(original)
        local unescaped = OD_UnescapeCSV(escaped)
        
        print(string.format("Test %d:", i))
        print(string.format("  Original : %s", tostring(original)))
        print(string.format("  Escaped  : %s", escaped))
        print(string.format("  Unescaped: %s", unescaped))
        print(string.format("  Match    : %s", tostring(original == unescaped)))
        print()
    end
    
    -- Test CSV parsing
    print("--- CSV Parsing Tests ---")
    local csvTests = {
        "1,Simple tag,0,1",
        "2,Tag\\, with comma,0,2", 
        "3,Tag\\: with colon,0,3",
        "4,Tag\\nwith\\nnewlines,0,4",
        "5,Complex\\, tag\\: with\\nmany\\\\chars,0,5"
    }
    
    for i, csvLine in ipairs(csvTests) do
        print(string.format("CSV Test %d: %s", i, csvLine))
        local fields = OD_ParseCSVLine(csvLine, ",")
        for j, field in ipairs(fields) do
            print(string.format("  Field %d: %s", j, field))
        end
        print()
    end
end

-- Test asset line parsing
local function testAssetParsing()
    print("--- Asset Line Parsing Tests ---")
    local assetTests = {
        "1 /path/to/plugin.vst3:1,2,3",
        "1 /path\\:with\\:colons/plugin.vst3:4,5",
        "2 FX\\,Chain.rfxchain:6,7,8",
        "0 Track\\nwith\\nnewline:9"
    }
    
    for i, line in ipairs(assetTests) do
        print(string.format("Asset Test %d: %s", i, line))
        
        -- Use the new helper function
        local colonPos = OD_FindUnescapedChar(line, ":")
        
        if colonPos then
            local asset = OD_UnescapeCSV(line:sub(1, colonPos - 1))
            local tagsStr = line:sub(colonPos + 1)
            print(string.format("  Asset: %s", asset))
            print(string.format("  Tags : %s", tagsStr))
        else
            print("  ERROR: No colon found")
        end
        print()
    end
end

return {
    testEscaping = testEscaping,
    testAssetParsing = testAssetParsing
}
