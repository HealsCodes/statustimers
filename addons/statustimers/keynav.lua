--[[
* statustimers - Copyright (c) 2022-2026 Heals
*
* This file is part of statustimers for Ashita.
*
* statustimers is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* statustimers is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with statustimers.  If not, see <https://www.gnu.org/licenses/>.
--]]

-------------------------------------------------------------------------------
-- imports
-------------------------------------------------------------------------------
require('common');
local chat = require('chat');
local ffi = require('ffi');
local party = require('party');
local resources = require('resources');
-------------------------------------------------------------------------------
-- local state
-------------------------------------------------------------------------------
local COMMAND = '/statustimers nav ';

-- modifier prefixes for ashita binds
local MODIFIERS = T{ alt = '!', apps = '#', ctrl = '^', shift = '+', win = '@' };

-- bind used for navigation, select is the only persistent one
local BINDS = T{
    T{ action = 'select',  label = 'Select buffs', default = '^F', persistent = true },
    T{ action = 'left',    label = 'Move left',    default = 'LEFT' },
    T{ action = 'right',   label = 'Move right',   default = 'RIGHT' },
    T{ action = 'confirm', label = 'Cancel buff',  default = 'RETURN' },
    T{ action = 'exit',    label = 'Exit',         default = 'ESCAPE' },
};

local state = T{
    active        = false,
    index         = 1,
    cfg           = T{},
    current_binds = T{},
};

local cancel_func = nil;
-------------------------------------------------------------------------------
-- local functions
-------------------------------------------------------------------------------
local function status_count()
    local list = party.get_player_status();
    if (list == nil) then
        return nil, 0;
    end
    return list, #list;
end

-- parse ashita keybind format into scancodes
local function parse_keybind(kb, keybind)
    local mod_prefix, key_name = keybind:match('^([!#%^%+@]*)(.+)$');
    local mods = T{};

    for mod, char in pairs(MODIFIERS) do
        mods[mod] = mod_prefix ~= nil and mod_prefix:find(char, 1, true) ~= nil;
    end

    return kb:S2D((key_name or ''):upper()), mods;
end

local function each_key(keybind)
    return keybind:gmatch('[^|%s]+');
end

local function unbind(kb, action)
    local current_keybind = state.current_binds[action];
    if (current_keybind == nil) then
        return;
    end

    for keybind in each_key(current_keybind) do
        local scancode, mods = parse_keybind(kb, keybind);

        kb:Unbind(scancode, true, mods.alt, mods.apps, mods.ctrl, mods.shift, mods.win, false, false);
    end

    state.current_binds[action] = nil;
end

local function bind(kb, action, pending_keybind)
    local bound = T{};

    for keybind in each_key(pending_keybind) do
        local scancode, mods = parse_keybind(kb, keybind);
        local taken = kb:IsBound(scancode, true, mods.alt, mods.apps, mods.ctrl, mods.shift, mods.win, false, false);

        if (scancode == 0) then
            print(chat.header('statustimers'):append(chat.error(
                ('%s is not a valid key for %s.'):fmt(keybind, action))));
        elseif (taken) then
            print(chat.header('statustimers'):append(chat.error(
                ('%s is already bound, pick another key for %s.'):fmt(keybind, action))));
        else
            kb:Bind(scancode, true, mods.alt, mods.apps, mods.ctrl, mods.shift, mods.win, false, false, COMMAND .. action);
            bound[#bound + 1] = keybind;
        end
    end

    state.current_binds[action] = table.concat(bound, '|');
end

local function pending_bind(b)
    if (state.active or b.persistent) then
        return state.cfg[b.action] or '';
    end

    return '';
end

local function current_bind(b)
    return state.current_binds[b.action] or '';
end

-- set binds to silent so we dont slam the chat window
-- cache the old value to reset after
local function update_binds()
    local kb = AshitaCore:GetInputManager():GetKeyboard();
    if (kb == nil) then
        return;
    end

    local current_silent = kb:GetSilentBinds();
    kb:SetSilentBinds(true);

    for _, b in ipairs(BINDS) do
        local pending = pending_bind(b);

        -- only update the keys that are changing
        if (pending ~= current_bind(b)) then
            unbind(kb, b.action);

            if (pending ~= '') then
                bind(kb, b.action, pending);
            end
        end
    end

    kb:SetSilentBinds(current_silent);
end

local function set_active(flag)
    if (state.active == flag) then
        return;
    end

    local _, count = status_count();
    if (flag and count < 1) then
        print(chat.header('statustimers'):append(chat.error('no status effects to select.')));
        return;
    end

    state.active = flag;
    state.index  = 1;
    update_binds();
end

local function move(delta)
    local _, count = status_count();
    if (count < 1) then
        return;
    end

    state.index = state.index + delta;
    if (state.index > count) then
        state.index = 1;
    elseif (state.index < 1) then
        state.index = count;
    end
end

local function confirm()
    local list, count = status_count();
    local entry = list and list[math.min(state.index, count)];
    if (entry == nil) then
        return;
    end

    if (not resources.status_can_be_cancelled(entry.id)) then
        print(chat.header('statustimers'):append(chat.warning(
            ('%s cannot be cancelled.'):fmt(resources.get_status_name(entry.id)))));
        return;
    end

    cancel_func(entry.id);
end
-------------------------------------------------------------------------------
-- exported functions
-------------------------------------------------------------------------------
local module = {};

module.BINDS = BINDS;

module.stop = function()
    set_active(false);
end

local ACTIONS = T{
    select  = function() set_active(not state.active); end,
    left    = function() move(-1); end,
    right   = function() move(1); end,
    confirm = confirm,
    exit    = module.stop,
};

module.defaults = function()
    local t = T{};
    for _, b in ipairs(BINDS) do
        t[b.action] = b.default;
    end
    return t;
end

module.rebind = update_binds;

module.bind = function(settings, cancel)
    state.cfg   = settings.key_nav;
    cancel_func = cancel;

    update_binds();
end

-- execute the action, select is always valid, else check if active
module.action = function(name)
    local fn = ACTIONS[name];

    if (fn ~= nil and (name == 'select' or state.active)) then
        fn();
    end
end

-- reset everything
module.cleanup = function()
    state.active = false;
    state.cfg    = T{};
    update_binds();
end

-- index of the outlined icon
---@param count number effects rendered this frame
---@return number|nil
module.focus_index = function(count)
    if (not state.active) then
        return nil;
    end
    if (count < 1) then
        set_active(false);
        return nil;
    end
    state.index = math.min(state.index, count);
    return state.index;
end

-- ashita skips the unload event for addons that error out, so lean on the gc
-- finalizer as a last chance to hand these keys back to the game
module.gc = ffi.gc(ffi.cast('uint8_t*', 0), function()
    local kb = AshitaCore:GetInputManager():GetKeyboard();
    if (kb == nil) then
        return;
    end

    for action in pairs(state.current_binds) do
        unbind(kb, action);
    end
end);

return module;
