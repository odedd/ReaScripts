-- @noindex

 STATES = {
    SOLO_IN_PLACE = 'SIP',
    SOLO_IGNORE_ROUTING = 'SIR',
    MUTE = 'M',
    MUTE_SOLO_IN_PLACE = 'MSIP',
    MUTE_SOLO_IGNORE_ROUTING = 'MSIR'
}

 STATE_COLORS = {
    [STATES.SOLO_IN_PLACE] = { STATES.SOLO_IN_PLACE, STATES.SOLO_IN_PLACE },
    [STATES.SOLO_IGNORE_ROUTING] = { STATES.SOLO_IGNORE_ROUTING, STATES.SOLO_IGNORE_ROUTING },
    [STATES.MUTE] = { STATES.MUTE, STATES.MUTE },
    [STATES.MUTE_SOLO_IN_PLACE] = { STATES.MUTE, STATES.SOLO_IN_PLACE },
    [STATES.MUTE_SOLO_IGNORE_ROUTING] = { STATES.MUTE, STATES.SOLO_IGNORE_ROUTING },
    [' '] = { ' ', ' ' }
}

 STATE_LABELS = {
    [STATES.SOLO_IN_PLACE] = 'S',
    [STATES.SOLO_IGNORE_ROUTING] = 'S',
    [STATES.MUTE] = 'M',
    [STATES.MUTE_SOLO_IN_PLACE] = 'MS',
    [STATES.MUTE_SOLO_IGNORE_ROUTING] = 'MS'
}

 STATE_DESCRIPTIONS = {
    [STATES.SOLO_IN_PLACE] = { 'solo in place', 'soloed in place' },
    [STATES.SOLO_IGNORE_ROUTING] = { 'solo (ignore routing)', 'soloed (ignores routing)' },
    [STATES.MUTE] = { 'mute', 'muted' },
    [STATES.MUTE_SOLO_IN_PLACE] = { 'mute & solo in place', 'muted and soloed in place' },
    [STATES.MUTE_SOLO_IGNORE_ROUTING] = { 'mute & solo (ignore routing)', 'muted and soloed (ignores routing)' }
}

 STATE_RPR_CODES = {
    [STATES.SOLO_IN_PLACE] = {
        ['I_SOLO'] = 2,
        ['B_MUTE'] = 0
    },
    [STATES.SOLO_IGNORE_ROUTING] = {
        ['I_SOLO'] = 1,
        ['B_MUTE'] = 0
    },
    [STATES.MUTE] = {
        ['I_SOLO'] = 0,
        ['B_MUTE'] = 1
    },
    [STATES.MUTE_SOLO_IN_PLACE] = {
        ['I_SOLO'] = 2,
        ['B_MUTE'] = 1
    },
    [STATES.MUTE_SOLO_IGNORE_ROUTING] = {
        ['I_SOLO'] = 1,
        ['B_MUTE'] = 1
    },
    [' '] = {
        ['I_SOLO'] = 0,
        ['B_MUTE'] = 0
    }
}

 RENDERACTION_RENDERQUEUE_NOTHING = 0
 RENDERACTION_RENDERQUEUE_OPEN = 1
 RENDERACTION_RENDERQUEUE_RUN = 2
 RENDERACTION_RENDER = 3

 RENDERACTION_DESCRIPTIONS = {
    [RENDERACTION_RENDER] = 'Render Immediately',
    [RENDERACTION_RENDERQUEUE_NOTHING] = 'Add to render queue',
    [RENDERACTION_RENDERQUEUE_OPEN] = 'Add to render queue and open it',
    [RENDERACTION_RENDERQUEUE_RUN] = 'Add to render queue and run it'
}

 WAITTIME_MIN = 2
 WAITTIME_MAX = 30

 SYNCMODE_OFF = -1
 SYNCMODE_MIRROR = 0
 SYNCMODE_SOLO = 1

 SYNCMODE_DESCRIPTIONS = {
    [SYNCMODE_MIRROR] = "Soloing or muting in REAPER affects stem",
    [SYNCMODE_SOLO] = "Soloing or muting in REAPER does not affect stem"
}

 REFLECT_ON_ADD_TRUE = 0
 REFLECT_ON_ADD_FALSE = 1

 REFLECT_ON_ADD_DESCRIPTIONS = {
    [REFLECT_ON_ADD_TRUE] = 'with current solos/mutes',
    [REFLECT_ON_ADD_FALSE] = 'without solos/mutes'
}

 SETTINGS_SOURCE_MASK = 0x10EB

 RB_CUSTOM_TIME = 0
 RB_ENTIRE_PROJECT = 1
 RB_TIME_SELECTION = 2
 RB_ALL_REGIONS = 3
 RB_SELECTED_ITEMS = 4
 RB_SELECTED_REGIONS = 5
 RB_REZOR_EDIT_AREAS = 6
 RB_ALL_MARKERS = 7
 RB_SELECTED_MARKERS = 8

 RENDER_SETTING_GROUPS_SLOTS = 9 -- TODO: make that user defineable