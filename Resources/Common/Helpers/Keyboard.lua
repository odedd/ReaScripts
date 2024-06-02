_OD_KEYS = {}
_OD_INTERCEPTED_KEYS = {}
_OD_KEYS_CUTOFF = 0
-- taken from here https://forums.cockos.com/showpost.php?p=2608321&postcount=12
OD_KEYCODES = {
  LBUTTON     = 0x01, --  The left mouse button
  RBUTTON     = 0x02, --  The right mouse button
  CANCEL      = 0x03, --  The Cancel virtual key, used for control-break processing
  MBUTTON     = 0x04, --  The middle mouse button
  BACK        = 0x08, --  Backspace
  TAB         = 0x09, --  Tab
  CLEAR       = 0x0C, --  5 (keypad without Num Lock)
  ENTER       = 0x0D, --  Enter
  SHIFT       = 0x10, --  Shift (either one)
  CONTROL     = 0x11, --  Ctrl (either one) CMD in mac
  ALT         = 0x12, --  Alt (either one)
  PAUSE       = 0x13, --  Pause
  CAPITAL     = 0x14, --  Caps Lock
  ESCAPE      = 0x1B, --  Esc
  SPACE       = 0x20, --  Spacebar
  PAGEUP      = 0x21, --  Page Up
  PAGEDOWN    = 0x22, --  Page Down
  END         = 0x23, --  End
  HOME        = 0x24, --  Home
  LEFT        = 0x25, --  Left Arrow
  UP          = 0x26, --  Up Arrow
  RIGHT       = 0x27, --  Right Arrow
  DOWN        = 0x28, --  Down Arrow
  SELECT      = 0x29, --  Select
  PRINT       = 0x2A, --  Print (only used by Nokia keyboards)
  EXECUTE     = 0x2B, --  Execute (not used)
  SNAPSHOT    = 0x2C, --  Print Screen
  INSERT      = 0x2D, --  Insert
  DELETE      = 0x2E, --  Delete
  HELP        = 0x2F, --  Help
  ['0']       = 0x30, --  0
  ['1']       = 0x31, --  1
  ['2']       = 0x32, --  2
  ['3']       = 0x33, --  3
  ['4']       = 0x34, --  4
  ['5']       = 0x35, --  5
  ['6']       = 0x36, --  6
  ['7']       = 0x37, --  7
  ['8']       = 0x38, --  8
  ['9']       = 0x39, --  9
  A           = 0x41, --  A
  B           = 0x42, --  B
  C           = 0x43, --  C
  D           = 0x44, --  D
  E           = 0x45, --  E
  F           = 0x46, --  F
  G           = 0x47, --  G
  H           = 0x48, --  H
  I           = 0x49, --  I
  J           = 0x4A, --  J
  K           = 0x4B, --  K
  L           = 0x4C, --  L
  M           = 0x4D, --  M
  N           = 0x4E, --  N
  O           = 0x4F, --  O
  P           = 0x50, --  P
  Q           = 0x51, --  Q
  R           = 0x52, --  R
  S           = 0x53, --  S
  T           = 0x54, --  T
  U           = 0x55, --  U
  V           = 0x56, --  V
  W           = 0x57, --  W
  X           = 0x58, --  X
  Y           = 0x59, --  Y
  Z           = 0x5A, --  Z
  STARTKEY    = 0x5B, --  Start Menu key (ctrl in macos)
  CONTEXTKEY  = 0x5D, --  Context Menu key
  NUMPAD0     = 0x60, --  0 (keypad with Num Lock)
  NUMPAD1     = 0x61, --  1 (keypad with Num Lock)
  NUMPAD2     = 0x62, --  2 (keypad with Num Lock)
  NUMPAD3     = 0x63, --  3 (keypad with Num Lock)
  NUMPAD4     = 0x64, --  4 (keypad with Num Lock)
  NUMPAD5     = 0x65, --  5 (keypad with Num Lock)
  NUMPAD6     = 0x66, --  6 (keypad with Num Lock)
  NUMPAD7     = 0x67, --  7 (keypad with Num Lock)
  NUMPAD8     = 0x68, --  8 (keypad with Num Lock)
  NUMPAD9     = 0x69, --  9 (keypad with Num Lock)
  MULTIPLY    = 0x6A, --  * (keypad)
  ADD         = 0x6B, --  = 0x(keypad)
  SEPARATOR   = 0x6C, --  Separator (never generated by the keyboard)
  SUBTRACT    = 0x6D, --  - (keypad)
  DECIMAL     = 0x6E, --  . (keypad with Num Lock)
  DIVIDE      = 0x6F, --  / (keypad)
  F1          = 0x70, --  F1
  F2          = 0x71, --  F2
  F3          = 0x72, --  F3
  F4          = 0x73, --  F4
  F5          = 0x74, --  F5
  F6          = 0x75, --  F6
  F7          = 0x76, --  F7
  F8          = 0x77, --  F8
  F9          = 0x78, --  F9
  F10         = 0x79, --  F10
  F11         = 0x7A, --  F11
  F12         = 0x7B, --  F12
  F13         = 0x7C, --  F13
  F14         = 0x7D, --  F14
  F15         = 0x7E, --  F15
  F16         = 0x7F, --  F16
  F17         = 0x80, --  F17
  F18         = 0x81, --  F18
  F19         = 0x82, --  F19
  F20         = 0x83, --  F20
  F21         = 0x84, --  F21
  F22         = 0x85, --  F22
  F23         = 0x86, --  F23
  F24         = 0x87, --  F24
  NUMLOCK     = 0x90, --  Num Lock
  OEM_SCROLL  = 0x91, --  Scroll Lock
  OEM_1       = 0xBA, --  ;
  OEM_PLUS    = 0xBB, --  =
  OEM_COMMA   = 0xBC, --  ,
  OEM_MINUS   = 0xBD, --  -
  OEM_PERIOD  = 0xBE, --  .
  OEM_2       = 0xBF, --  /
  OEM_3       = 0xC0, --  `
  OEM_4       = 0xDB, --  [
  OEM_5       = 0xDC, --  \
  OEM_6       = 0xDD, --  ]
  OEM_7       = 0xDE, --  '
  OEM_8       = 0xDF, --  (unknown)
  ICO_F17     = 0xE0, --  F17 on Olivetti extended keyboard (internal use only)
  ICO_F18     = 0xE1, --  F18 on Olivetti extended keyboard (internal use only)
  OEM_102     = 0xE2, --  < or | on IBM-compatible 102 enhanced non-U.S. keyboard
  ICO_HELP    = 0xE3, --  Help on Olivetti extended keyboard (internal use only)
  ICO_00      = 0xE4, --  00 on Olivetti extended keyboard (internal use only)
  ICO_CLEAR   = 0xE6, --  Clear on Olivette extended keyboard (internal use only)
  OEM_RESET   = 0xE9, --  Reset (Nokia keyboards only)
  OEM_JUMP    = 0xEA, --  Jump (Nokia keyboards only)
  OEM_PA1     = 0xEB, --  PA1 (Nokia keyboards only)
  OEM_PA2     = 0xEC, --  PA2 (Nokia keyboards only)
  OEM_PA3     = 0xED, --  PA3 (Nokia keyboards only)
  OEM_WSCTRL  = 0xEE, --  WSCTRL (Nokia keyboards only)
  OEM_CUSEL   = 0xEF, --  CUSEL (Nokia keyboards only)
  OEM_ATTN    = 0xF0, --  ATTN (Nokia keyboards only)
  OEM_FINNISH = 0xF1, --  FINNISH (Nokia keyboards only)
  OEM_COPY    = 0xF2, --  COPY (Nokia keyboards only)
  OEM_AUTO    = 0xF3, --  AUTO (Nokia keyboards only)
  OEM_ENLW    = 0xF4, --  ENLW (Nokia keyboards only)
  OEM_BACKTAB = 0xF5, --  BACKTAB (Nokia keyboards only)
  ATTN        = 0xF6, --  ATTN
  CRSEL       = 0xF7, --  CRSEL
  EXSEL       = 0xF8, --  EXSEL
  EREOF       = 0xF9, --  EREOF
  PLAY        = 0xFA, --  PLAY
  ZOOM        = 0xFB, --  ZOOM
  NONAME      = 0xFC, --  NONAME
  PA1         = 0xFD, --  PA1
  OEM_CLEAR   = 0xFE, --  CLEAR
}

OD_KEYCODE_NAMES = {
  [OD_KEYCODES.LBUTTON] = 'Left Mouse Button',
  [OD_KEYCODES.RBUTTON] = 'Right Mouse Button',
  [OD_KEYCODES.CANCEL] = 'Cancel',
  [OD_KEYCODES.MBUTTON] = 'Middle Mouse Button',
  [OD_KEYCODES.BACK] = 'Backspace',
  [OD_KEYCODES.TAB] = 'Tab',
  [OD_KEYCODES.CLEAR] = 'Clear',
  [OD_KEYCODES.ENTER] = 'Enter',
  [OD_KEYCODES.SHIFT] = 'Shift',
  [OD_KEYCODES.CONTROL] = _OD_ISMAC and 'Command' or 'Control',
  [OD_KEYCODES.ALT] = _OD_ISMAC and 'Option' or 'Alt',
  [OD_KEYCODES.PAUSE] = 'Pause',
  [OD_KEYCODES.CAPITAL] = 'Caps Lock',
  [OD_KEYCODES.ESCAPE] = 'Escape',
  [OD_KEYCODES.SPACE] = 'Spacebar',
  [OD_KEYCODES.PAGEUP] = 'Page Up',
  [OD_KEYCODES.PAGEDOWN] = 'Page Down',
  [OD_KEYCODES.END] = 'End',
  [OD_KEYCODES.HOME] = 'Home',
  [OD_KEYCODES.LEFT] = 'Left Arrow',
  [OD_KEYCODES.UP] = 'Up Arrow',
  [OD_KEYCODES.RIGHT] = 'Right Arrow',
  [OD_KEYCODES.DOWN] = 'Down Arrow',
  [OD_KEYCODES.SELECT] = 'Select',
  [OD_KEYCODES.PRINT] = 'Print',
  [OD_KEYCODES.EXECUTE] = 'Execute',
  [OD_KEYCODES.SNAPSHOT] = 'Print Screen',
  [OD_KEYCODES.INSERT] = 'Insert',
  [OD_KEYCODES.DELETE] = 'Delete',
  [OD_KEYCODES.HELP] = 'Help',
  [OD_KEYCODES['0']] = '0',
  [OD_KEYCODES['1']] = '1',
  [OD_KEYCODES['2']] = '2',
  [OD_KEYCODES['3']] = '3',
  [OD_KEYCODES['4']] = '4',
  [OD_KEYCODES['5']] = '5',
  [OD_KEYCODES['6']] = '6',
  [OD_KEYCODES['7']] = '7',
  [OD_KEYCODES['8']] = '8',
  [OD_KEYCODES['9']] = '9',
  [OD_KEYCODES.A] = 'A',
  [OD_KEYCODES.B] = 'B',
  [OD_KEYCODES.C] = 'C',
  [OD_KEYCODES.D] = 'D',
  [OD_KEYCODES.E] = 'E',
  [OD_KEYCODES.F] = 'F',
  [OD_KEYCODES.G] = 'G',
  [OD_KEYCODES.H] = 'H',
  [OD_KEYCODES.I] = 'I',
  [OD_KEYCODES.J] = 'J',
  [OD_KEYCODES.K] = 'K',
  [OD_KEYCODES.L] = 'L',
  [OD_KEYCODES.M] = 'M',
  [OD_KEYCODES.N] = 'N',
  [OD_KEYCODES.O] = 'O',
  [OD_KEYCODES.P] = 'P',
  [OD_KEYCODES.Q] = 'Q',
  [OD_KEYCODES.R] = 'R',
  [OD_KEYCODES.S] = 'S',
  [OD_KEYCODES.T] = 'T',
  [OD_KEYCODES.U] = 'U',
  [OD_KEYCODES.V] = 'V',
  [OD_KEYCODES.W] = 'W',
  [OD_KEYCODES.X] = 'X',
  [OD_KEYCODES.Y] = 'Y',
  [OD_KEYCODES.Z] = 'Z',
  [OD_KEYCODES.STARTKEY] = _OD_ISMAC and 'Control' or 'Start Menu',
  [OD_KEYCODES.CONTEXTKEY] = 'Context Menu',
  [OD_KEYCODES.NUMPAD0] = 'Numpad 0',
  [OD_KEYCODES.NUMPAD1] = 'Numpad 1',
  [OD_KEYCODES.NUMPAD2] = 'Numpad 2',
  [OD_KEYCODES.NUMPAD3] = 'Numpad 3',
  [OD_KEYCODES.NUMPAD4] = 'Numpad 4',
  [OD_KEYCODES.NUMPAD5] = 'Numpad 5',
  [OD_KEYCODES.NUMPAD6] = 'Numpad 6',
  [OD_KEYCODES.NUMPAD7] = 'Numpad 7',
  [OD_KEYCODES.NUMPAD8] = 'Numpad 8',
  [OD_KEYCODES.NUMPAD9] = 'Numpad 9',
  [OD_KEYCODES.MULTIPLY] = 'Numpad *',
  [OD_KEYCODES.ADD] = 'Numpad +',
  [OD_KEYCODES.SEPARATOR] = 'Separator',
  [OD_KEYCODES.SUBTRACT] = 'Numpad -',
  [OD_KEYCODES.DECIMAL] = 'Numpad .',
  [OD_KEYCODES.DIVIDE] = 'Numpad /',
  [OD_KEYCODES.F1] = 'F1',
  [OD_KEYCODES.F2] = 'F2',
  [OD_KEYCODES.F3] = 'F3',
  [OD_KEYCODES.F4] = 'F4',
  [OD_KEYCODES.F5] = 'F5',
  [OD_KEYCODES.F6] = 'F6',
  [OD_KEYCODES.F7] = 'F7',
  [OD_KEYCODES.F8] = 'F8',
  [OD_KEYCODES.F9] = 'F9',
  [OD_KEYCODES.F10] = 'F10',
  [OD_KEYCODES.F11] = 'F11',
  [OD_KEYCODES.F12] = 'F12',
  [OD_KEYCODES.F13] = 'F13',
  [OD_KEYCODES.F14] = 'F14',
  [OD_KEYCODES.F15] = 'F15',
  [OD_KEYCODES.F16] = 'F16',
  [OD_KEYCODES.F17] = 'F17',
  [OD_KEYCODES.F18] = 'F18',
  [OD_KEYCODES.F19] = 'F19',
  [OD_KEYCODES.F20] = 'F20',
  [OD_KEYCODES.F21] = 'F21',
  [OD_KEYCODES.F22] = 'F22',
  [OD_KEYCODES.F23] = 'F23',
  [OD_KEYCODES.F24] = 'F24',
  [OD_KEYCODES.NUMLOCK] = 'Num Lock',
  [OD_KEYCODES.OEM_SCROLL] = 'Scroll Lock',
  [OD_KEYCODES.OEM_1] = ';',
  [OD_KEYCODES.OEM_PLUS] = '=',
  [OD_KEYCODES.OEM_COMMA] = ',',
  [OD_KEYCODES.OEM_MINUS] = '-',
  [OD_KEYCODES.OEM_PERIOD] = '.',
  [OD_KEYCODES.OEM_2] = '/',
  [OD_KEYCODES.OEM_3] = '`',
  [OD_KEYCODES.OEM_4] = '[',
  [OD_KEYCODES.OEM_5] = '\\',
  [OD_KEYCODES.OEM_6] = ']',
  [OD_KEYCODES.OEM_7] = "'",
  [OD_KEYCODES.OEM_8] = '(unknown)',
  [OD_KEYCODES.ICO_F17] = 'F17 (Olivetti extended keyboard)',
  [OD_KEYCODES.ICO_F18] = 'F18 (Olivetti extended keyboard)',
  [OD_KEYCODES.OEM_102] = '< or | (IBM-compatible 102 enhanced non-U.S. keyboard)',
  [OD_KEYCODES.ICO_HELP] = 'Help (Olivetti extended keyboard)',
  [OD_KEYCODES.ICO_00] = '00 (Olivetti extended keyboard)',
  [OD_KEYCODES.ICO_CLEAR] = 'Clear (Olivetti extended keyboard)',
  [OD_KEYCODES.OEM_RESET] = 'Reset (Nokia keyboards only)',
  [OD_KEYCODES.OEM_JUMP] = 'Jump (Nokia keyboards only)',
  [OD_KEYCODES.OEM_PA1] = 'PA1 (Nokia keyboards only)',
  [OD_KEYCODES.OEM_PA2] = 'PA2 (Nokia keyboards only)',
  [OD_KEYCODES.OEM_PA3] = 'PA3 (Nokia keyboards only)',
  [OD_KEYCODES.OEM_WSCTRL] = 'WSCTRL (Nokia keyboards only)',
  [OD_KEYCODES.OEM_CUSEL] = 'CUSEL (Nokia keyboards only)',
  [OD_KEYCODES.OEM_ATTN] = 'ATTN (Nokia keyboards only)',
  [OD_KEYCODES.OEM_FINNISH] = 'FINNISH (Nokia keyboards only)',
  [OD_KEYCODES.OEM_COPY] = 'COPY (Nokia keyboards only)',
  [OD_KEYCODES.OEM_AUTO] = 'AUTO (Nokia keyboards only)',
  [OD_KEYCODES.OEM_ENLW] = 'ENLW (Nokia keyboards only)',
  [OD_KEYCODES.OEM_BACKTAB] = 'BACKTAB (Nokia keyboards only)',
  [OD_KEYCODES.ATTN] = 'ATTN',
  [OD_KEYCODES.CRSEL] = 'CRSEL',
  [OD_KEYCODES.EXSEL] = 'EXSEL',
  [OD_KEYCODES.EREOF] = 'EREOF',
  [OD_KEYCODES.PLAY] = 'PLAY',
  [OD_KEYCODES.ZOOM] = 'ZOOM',
  [OD_KEYCODES.NONAME] = 'NONAME',
  [OD_KEYCODES.PA1] = 'PA1',
  [OD_KEYCODES.OEM_CLEAR] = 'CLEAR',
}


OD_IsGlobalKeyDown = function(key)
  return r.JS_VKeys_GetState(_OD_KEYS_CUTOFF):byte(key) == 1
end
OD_ReleaseGlobalKeys = function()
  for _, key in ipairs(_OD_INTERCEPTED_KEYS) do
    r.JS_VKeys_Intercept(key, -1)
    _OD_INTERCEPTED_KEYS[key] = nil
  end
end
OD_IsGlobalKeyPressed = function(key, intercept)
  intercept = intercept or false
  if intercept and not _OD_INTERCEPTED_KEYS[key] then
    table.insert(_OD_INTERCEPTED_KEYS, key)
    r.JS_VKeys_Intercept(key, 1)
  end
  if r.JS_VKeys_GetState(_OD_KEYS_CUTOFF):byte(key) ~= 0 then
    if _OD_KEYS[key] == nil then
      _OD_KEYS[key] = true
      return true
    end
  else
    if _OD_KEYS[key] then
      _OD_KEYS[key] = nil
    end
  end
  return false
end

OD_GetKeyPressed = function(from, to)
  from = from or 0
  to = to or 255
  for i = from, to do
    if r.JS_VKeys_GetState(_OD_KEYS_CUTOFF):byte(i) == 1 then
      return i
    end
  end
end

OD_PrintKeysPressed = function()
  local escapePressed = false
    for i = 0, 255 do
      if r.JS_VKeys_GetState(_OD_KEYS_CUTOFF):byte(OD_KEYCODES.ESCAPE) ~= 0 then
        escapePressed = true
      elseif r.JS_VKeys_GetState(0):byte(i) == 1 then
        r.ShowConsoleMsg(OD_KEYCODE_NAMES[i] .. '\n')
      end
    end
    if not escapePressed then reaper.defer(OD_PrintKeysPressed) end
end
