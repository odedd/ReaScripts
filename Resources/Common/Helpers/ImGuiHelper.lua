-- @noindex

if reaper.ImGui_CreateContext then

  OD_IMGUI_KEY_NAMES = {
    [reaper.ImGui_Mod_Alt()] = _OD_ISMAC and 'Option' or 'Alt',
    [reaper.ImGui_Mod_Ctrl()] = _OD_ISMAC and 'Cmd' or 'Ctrl',
    [reaper.ImGui_Mod_None()] = 'None',
    [reaper.ImGui_Mod_Shift()] = 'Shift',
    [reaper.ImGui_Mod_Super()] = _OD_ISMAC and 'Ctrl' or 'Win',
    [reaper.ImGui_Key_0()] = '0',
    [reaper.ImGui_Key_1()] = '1',
    [reaper.ImGui_Key_2()] = '2',
    [reaper.ImGui_Key_3()] = '3',
    [reaper.ImGui_Key_4()] = '4',
    [reaper.ImGui_Key_5()] = '5',
    [reaper.ImGui_Key_6()] = '6',
    [reaper.ImGui_Key_7()] = '7',
    [reaper.ImGui_Key_8()] = '8',
    [reaper.ImGui_Key_9()] = '9',
    [reaper.ImGui_Key_A()] = 'A',
    [reaper.ImGui_Key_Apostrophe()] = '\'',
    [reaper.ImGui_Key_AppBack()] = 'Back',
    [reaper.ImGui_Key_AppForward()] = 'Forward',
    [reaper.ImGui_Key_B()] = 'B',
    [reaper.ImGui_Key_Backslash()] = '\\',
    [reaper.ImGui_Key_Backspace()] = 'Backspace',
    [reaper.ImGui_Key_C()] = 'C',
    [reaper.ImGui_Key_CapsLock()] = 'Caps Lock',
    [reaper.ImGui_Key_Comma()] = ',',
    [reaper.ImGui_Key_D()] = 'D',
    [reaper.ImGui_Key_Delete()] = 'Delete',
    [reaper.ImGui_Key_DownArrow()] = 'Down Arrow',
    [reaper.ImGui_Key_E()] = 'E',
    [reaper.ImGui_Key_End()] = 'End',
    [reaper.ImGui_Key_Enter()] = 'Enter',
    [reaper.ImGui_Key_Equal()] = '=',
    [reaper.ImGui_Key_Escape()] = 'Esc',
    [reaper.ImGui_Key_F()] = 'F',
    [reaper.ImGui_Key_F1()] = 'F1',
    [reaper.ImGui_Key_F2()] = 'F2',
    [reaper.ImGui_Key_F3()] = 'F3',
    [reaper.ImGui_Key_F4()] = 'F4',
    [reaper.ImGui_Key_F5()] = 'F5',
    [reaper.ImGui_Key_F6()] = 'F6',
    [reaper.ImGui_Key_F7()] = 'F7',
    [reaper.ImGui_Key_F8()] = 'F8',
    [reaper.ImGui_Key_F9()] = 'F9',
    [reaper.ImGui_Key_F10()] = 'F10',
    [reaper.ImGui_Key_F11()] = 'F11',
    [reaper.ImGui_Key_F12()] = 'F12',
    [reaper.ImGui_Key_F13()] = 'F13',
    [reaper.ImGui_Key_F14()] = 'F14',
    [reaper.ImGui_Key_F15()] = 'F15',
    [reaper.ImGui_Key_F16()] = 'F16',
    [reaper.ImGui_Key_F17()] = 'F17',
    [reaper.ImGui_Key_F18()] = 'F18',
    [reaper.ImGui_Key_F19()] = 'F19',
    [reaper.ImGui_Key_F20()] = 'F20',
    [reaper.ImGui_Key_F21()] = 'F21',
    [reaper.ImGui_Key_F22()] = 'F22',
    [reaper.ImGui_Key_F23()] = 'F23',
    [reaper.ImGui_Key_F24()] = 'F24',
    [reaper.ImGui_Key_G()] = 'G',
    [reaper.ImGui_Key_GraveAccent()] = '`',
    [reaper.ImGui_Key_H()] = 'H',
    [reaper.ImGui_Key_Home()] = 'Home',
    [reaper.ImGui_Key_I()] = 'I',
    [reaper.ImGui_Key_Insert()] = 'Insert',
    [reaper.ImGui_Key_J()] = 'J',
    [reaper.ImGui_Key_K()] = 'K',
    [reaper.ImGui_Key_Keypad0()] = 'Keypad 0',
    [reaper.ImGui_Key_Keypad1()] = 'Keypad 1',
    [reaper.ImGui_Key_Keypad2()] = 'Keypad 2',
    [reaper.ImGui_Key_Keypad3()] = 'Keypad 3',
    [reaper.ImGui_Key_Keypad4()] = 'Keypad 4',
    [reaper.ImGui_Key_Keypad5()] = 'Keypad 5',
    [reaper.ImGui_Key_Keypad6()] = 'Keypad 6',
    [reaper.ImGui_Key_Keypad7()] = 'Keypad 7',
    [reaper.ImGui_Key_Keypad8()] = 'Keypad 8',
    [reaper.ImGui_Key_Keypad9()] = 'Keypad 9',
    [reaper.ImGui_Key_KeypadAdd()] = 'Keypad +',
    [reaper.ImGui_Key_KeypadDecimal()] = 'Keypad .',
    [reaper.ImGui_Key_KeypadDivide()] = 'Keypad /',
    [reaper.ImGui_Key_KeypadEnter()] = 'Keypad Enter',
    [reaper.ImGui_Key_KeypadEqual()] = 'Keypad =',
    [reaper.ImGui_Key_KeypadMultiply()] = 'Keypad *',
    [reaper.ImGui_Key_KeypadSubtract()] = 'Keypad -',
    [reaper.ImGui_Key_L()] = 'L',
    [reaper.ImGui_Key_LeftAlt()] = 'Left Alt',
    [reaper.ImGui_Key_LeftArrow()] = 'Left Arrow',
    [reaper.ImGui_Key_LeftBracket()] = 'Left Bracket',
    [reaper.ImGui_Key_LeftCtrl()] = 'Left Ctrl',
    [reaper.ImGui_Key_LeftShift()] = 'Left Shift',
    [reaper.ImGui_Key_LeftSuper()] = 'Left Super',
    [reaper.ImGui_Key_M()] = 'M',
    [reaper.ImGui_Key_Menu()] = 'Menu',
    [reaper.ImGui_Key_Minus()] = 'Minus',
    [reaper.ImGui_Key_N()] = 'N',
    [reaper.ImGui_Key_NumLock()] = 'Num Lock',
    [reaper.ImGui_Key_O()] = 'O',
    [reaper.ImGui_Key_P()] = 'P',
    [reaper.ImGui_Key_PageDown()] = 'Page Down',
    [reaper.ImGui_Key_PageUp()] = 'Page Up',
    [reaper.ImGui_Key_Pause()] = 'Pause',
    [reaper.ImGui_Key_Period()] = '.',
    [reaper.ImGui_Key_PrintScreen()] = 'Print Screen',
    [reaper.ImGui_Key_Q()] = 'Q',
    [reaper.ImGui_Key_R()] = 'R',
    [reaper.ImGui_Key_RightAlt()] = 'Right Alt',
    [reaper.ImGui_Key_RightArrow()] = 'Right Arrow',
    [reaper.ImGui_Key_RightBracket()] = 'Right Bracket',
    [reaper.ImGui_Key_RightCtrl()] = 'Right Ctrl',
    [reaper.ImGui_Key_RightShift()] = 'Right Shift',
    [reaper.ImGui_Key_RightSuper()] = 'Right Super',
    [reaper.ImGui_Key_S()] = 'S',
    [reaper.ImGui_Key_ScrollLock()] = 'Scroll Lock',
    [reaper.ImGui_Key_Semicolon()] = ';',
    [reaper.ImGui_Key_Slash()] = '/',
    [reaper.ImGui_Key_Space()] = 'Space',
    [reaper.ImGui_Key_T()] = 'T',
    [reaper.ImGui_Key_Tab()] = 'Tab',
    [reaper.ImGui_Key_U()] = 'U',
    [reaper.ImGui_Key_UpArrow()] = 'Up Arrow',
    [reaper.ImGui_Key_V()] = 'V',
    [reaper.ImGui_Key_W()] = 'W',
    [reaper.ImGui_Key_X()] = 'X',
    [reaper.ImGui_Key_Y()] = 'Y',
    [reaper.ImGui_Key_Z()] = 'Z',
  }

  OD_CAPTURABLE_KEYS = {
    reaper.ImGui_Key_0(),
    reaper.ImGui_Key_1(),
    reaper.ImGui_Key_2(),
    reaper.ImGui_Key_3(),
    reaper.ImGui_Key_4(),
    reaper.ImGui_Key_5(),
    reaper.ImGui_Key_6(),
    reaper.ImGui_Key_7(),
    reaper.ImGui_Key_8(),
    reaper.ImGui_Key_9(),
    reaper.ImGui_Key_A(),
    reaper.ImGui_Key_Apostrophe(),
    reaper.ImGui_Key_AppBack(),
    reaper.ImGui_Key_AppForward(),
    reaper.ImGui_Key_B(),
    reaper.ImGui_Key_Backslash(),
    reaper.ImGui_Key_Backspace(),
    reaper.ImGui_Key_C(),
    reaper.ImGui_Key_CapsLock(),
    reaper.ImGui_Key_Comma(),
    reaper.ImGui_Key_D(),
    reaper.ImGui_Key_Delete(),
    reaper.ImGui_Key_DownArrow(),
    reaper.ImGui_Key_E(),
    reaper.ImGui_Key_End(),
    reaper.ImGui_Key_Enter(),
    reaper.ImGui_Key_Equal(),
    reaper.ImGui_Key_Escape(),
    reaper.ImGui_Key_F(),
    reaper.ImGui_Key_F1(),
    reaper.ImGui_Key_F2(),
    reaper.ImGui_Key_F3(),
    reaper.ImGui_Key_F4(),
    reaper.ImGui_Key_F5(),
    reaper.ImGui_Key_F6(),
    reaper.ImGui_Key_F7(),
    reaper.ImGui_Key_F8(),
    reaper.ImGui_Key_F9(),
    reaper.ImGui_Key_F10(),
    reaper.ImGui_Key_F11(),
    reaper.ImGui_Key_F12(),
    reaper.ImGui_Key_F13(),
    reaper.ImGui_Key_F14(),
    reaper.ImGui_Key_F15(),
    reaper.ImGui_Key_F16(),
    reaper.ImGui_Key_F17(),
    reaper.ImGui_Key_F18(),
    reaper.ImGui_Key_F19(),
    reaper.ImGui_Key_F20(),
    reaper.ImGui_Key_F21(),
    reaper.ImGui_Key_F22(),
    reaper.ImGui_Key_F23(),
    reaper.ImGui_Key_F24(),
    reaper.ImGui_Key_G(),
    reaper.ImGui_Key_GraveAccent(),
    reaper.ImGui_Key_H(),
    reaper.ImGui_Key_Home(),
    reaper.ImGui_Key_I(),
    reaper.ImGui_Key_Insert(),
    reaper.ImGui_Key_J(),
    reaper.ImGui_Key_K(),
    reaper.ImGui_Key_Keypad0(),
    reaper.ImGui_Key_Keypad1(),
    reaper.ImGui_Key_Keypad2(),
    reaper.ImGui_Key_Keypad3(),
    reaper.ImGui_Key_Keypad4(),
    reaper.ImGui_Key_Keypad5(),
    reaper.ImGui_Key_Keypad6(),
    reaper.ImGui_Key_Keypad7(),
    reaper.ImGui_Key_Keypad8(),
    reaper.ImGui_Key_Keypad9(),
    reaper.ImGui_Key_KeypadAdd(),
    reaper.ImGui_Key_KeypadDecimal(),
    reaper.ImGui_Key_KeypadDivide(),
    reaper.ImGui_Key_KeypadEnter(),
    reaper.ImGui_Key_KeypadEqual(),
    reaper.ImGui_Key_KeypadMultiply(),
    reaper.ImGui_Key_KeypadSubtract(),
    reaper.ImGui_Key_L(),
    reaper.ImGui_Key_LeftArrow(),
    reaper.ImGui_Key_LeftBracket(),
    reaper.ImGui_Key_M(),
    reaper.ImGui_Key_Minus(),
    reaper.ImGui_Key_N(),
    reaper.ImGui_Key_O(),
    reaper.ImGui_Key_P(),
    reaper.ImGui_Key_PageDown(),
    reaper.ImGui_Key_PageUp(),
    reaper.ImGui_Key_Period(),
    reaper.ImGui_Key_Q(),
    reaper.ImGui_Key_R(),
    reaper.ImGui_Key_RightArrow(),
    reaper.ImGui_Key_RightBracket(),
    reaper.ImGui_Key_S(),
    reaper.ImGui_Key_ScrollLock(),
    reaper.ImGui_Key_Semicolon(),
    reaper.ImGui_Key_Slash(),
    reaper.ImGui_Key_Space(),
    reaper.ImGui_Key_T(),
    reaper.ImGui_Key_Tab(),
    reaper.ImGui_Key_U(),
    reaper.ImGui_Key_UpArrow(),
    reaper.ImGui_Key_V(),
    reaper.ImGui_Key_W(),
    reaper.ImGui_Key_X(),
    reaper.ImGui_Key_Y(),
    reaper.ImGui_Key_Z(),
    reaper.ImGui_Key_0(),
    reaper.ImGui_Key_1(),
    reaper.ImGui_Key_2(),
    reaper.ImGui_Key_3(),
    reaper.ImGui_Key_4(),
    reaper.ImGui_Key_5(),
  }

  -- by cfillion
  local OD_TEXT_COMMANDS = {
    f = function(ctx, arg, fonts, sizeKey)
      local sizeKey = sizeKey or 'default'
      reaper.ImGui_PushFont(ctx, fonts[arg].font, fonts[arg].scaledSizes[sizeKey])
    end,
    F = function(ctx)
      reaper.ImGui_PopFont(ctx)
    end,
    ['-'] = function(ctx)
      reaper.ImGui_Bullet(ctx)
      reaper.ImGui_SameLine(ctx)
    end,
    c = function(ctx, arg)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), tonumber(arg, 16))
    end,
    C = function(ctx)
      reaper.ImGui_PopStyleColor(ctx)
    end,
  }

  -- based on function by cfillion
  OD_ImGuiRichText = function(ctx, text, fonts)
    text:gsub('[^\n]*', function(line)
      if line == '' then
        -- Handle empty lines by adding spacing
        reaper.ImGui_Text(ctx,'')
        return
      end
      
      local concat = false
      line:gsub('\0?[^\0]+', function(chunk)
        if chunk:sub(1, 1) == '\0' then
          local eoc = chunk:find(';', 3)
          local cmd = chunk:sub(2, 2)
          local arg = chunk:sub(3, eoc - 1)
          if OD_TEXT_COMMANDS[cmd] then
          OD_TEXT_COMMANDS[cmd](ctx, arg, fonts)
          end
          chunk = chunk:sub(eoc + 1)
        end
        if concat then
          reaper.ImGui_SameLine(ctx, nil, 0)
        else
          concat = true
        end
        reaper.ImGui_Text(ctx, chunk)
      end)
    end)
  end

  -- Rich text with word-wrapping support, based on cfillion's function
  OD_ImGuiRichTextWrapped = function(ctx, text, fonts, wrapWidth)
    local wrapWidth = wrapWidth or reaper.ImGui_GetContentRegionAvail(ctx)
    text:gsub('[^\n]*', function(line)
      if line == '' then
        reaper.ImGui_Text(ctx,'')
        return
      end

      local chunks = {}
      line:gsub('\0?[^\0]+', function(chunk)
        local cmd, arg
        if chunk:sub(1, 1) == '\0' then
          local eoc = chunk:find(';', 3)
          cmd = chunk:sub(2, 2)
          arg = chunk:sub(3, eoc - 1)
          chunk = chunk:sub(eoc + 1)
        end
        table.insert(chunks, {
          cmd = cmd,
          arg = arg,
          text = chunk
        })
      end)

      local currentLineWidth = 0
      local currentLineChunks = {}
      local fontStack = {}
      local function pushFont(arg, sizeKey)
        local sizeKey = sizeKey or 'default'
        local font = fonts[arg].font
        local size = fonts[arg].scaledSizes[sizeKey]
        table.insert(fontStack, {font=font, size=size})
        reaper.ImGui_PushFont(ctx, font, size)
      end
      local function popFont()
        table.remove(fontStack)
        reaper.ImGui_PopFont(ctx)
      end
      local function getCurrentFont()
        if #fontStack > 0 then
          return fontStack[#fontStack].font, fontStack[#fontStack].size
        end
        return nil, nil
      end

      for _, chunk in ipairs(chunks) do
        -- Handle font/color commands for width calculation
        if chunk.cmd == 'f' then
          pushFont(chunk.arg)
          table.insert(currentLineChunks, {type = 'cmd', cmd = chunk.cmd, arg = chunk.arg})
        elseif chunk.cmd == 'F' then
          popFont()
          table.insert(currentLineChunks, {type = 'cmd', cmd = chunk.cmd, arg = chunk.arg})
        elseif chunk.cmd then
          table.insert(currentLineChunks, {type = 'cmd', cmd = chunk.cmd, arg = chunk.arg})
        end

        if chunk.text ~= '' then
          local words = {}
          local remainingText = chunk.text
          while remainingText ~= '' do
            local wordStart = remainingText:find('%S')
            if not wordStart then
              table.insert(words, remainingText)
              break
            end
            if wordStart > 1 then
              table.insert(words, remainingText:sub(1, wordStart - 1))
            end
            local wordEnd = remainingText:find('%s', wordStart) or (#remainingText + 1)
            local word = remainingText:sub(wordStart, wordEnd - 1)
            table.insert(words, word)
            remainingText = remainingText:sub(wordEnd)
          end

          for _, segment in ipairs(words) do
            -- Use the current font for width calculation
            local font, size = getCurrentFont()
            if font then
              reaper.ImGui_PushFont(ctx, font, size)
            end
            local segmentWidth, _ = reaper.ImGui_CalcTextSize(ctx, segment)
            if font then
              reaper.ImGui_PopFont(ctx)
            end

            if currentLineWidth + segmentWidth > wrapWidth and currentLineWidth > 0 and segment:match('%S') then
              -- Render current line
              local concat = false
              for _, lineChunk in ipairs(currentLineChunks) do
                if lineChunk.type == 'cmd' then
                  if OD_TEXT_COMMANDS[lineChunk.cmd] then
                    OD_TEXT_COMMANDS[lineChunk.cmd](ctx, lineChunk.arg, fonts)
                  end
                else
                  if concat then
                    reaper.ImGui_SameLine(ctx, nil, 0)
                  else
                    concat = true
                  end
                  reaper.ImGui_Text(ctx, lineChunk.content)
                end
              end
              currentLineChunks = {}
              currentLineWidth = 0
            end

            table.insert(currentLineChunks, {type = 'text', content = segment})
            currentLineWidth = currentLineWidth + segmentWidth
          end
        end
      end

      -- Render final line
      if #currentLineChunks > 0 then
        local concat = false
        for _, lineChunk in ipairs(currentLineChunks) do
          if lineChunk.type == 'cmd' then
            if OD_TEXT_COMMANDS[lineChunk.cmd] then
              OD_TEXT_COMMANDS[lineChunk.cmd](ctx, lineChunk.arg, fonts)
            end
          else
            if concat then
              reaper.ImGui_SameLine(ctx, nil, 0)
            else
              concat = true
            end
            reaper.ImGui_Text(ctx, lineChunk.content)
          end
        end
      end
      -- Restore font stack if needed
      while #fontStack > 0 do
        reaper.ImGui_PopFont(ctx)
        table.remove(fontStack)
      end
    end)
  end

  
  OD_GetImguiKeysPressed = function(ctx)
    for _, key in ipairs(OD_CAPTURABLE_KEYS) do
      if reaper.ImGui_IsKeyDown(ctx, key) then
        return key
      end
    end
  end
end
