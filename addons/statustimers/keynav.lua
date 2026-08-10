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
local party = require('party');
local resources = require('resources');
-------------------------------------------------------------------------------
-- local state
-------------------------------------------------------------------------------
local COMMAND = '/statustimers nav ';

-- bind used for navigation, select is the only persistent one
local BINDS = T{
    T{ key = 'select',  label = 'Select buffs', default = '^F',     bindstr = '', persistent = true },
    T{ key = 'left',    label = 'Move left',    default = 'LEFT',   bindstr = '' },
    T{ key = 'right',   label = 'Move right',   default = 'RIGHT',  bindstr = '' },
    T{ key = 'confirm', label = 'Cancel buff',  default = 'RETURN', bindstr = '' },
    T{ key = 'exit',    label = 'Exit',         default = 'ESCAPE', bindstr = '' },
};

local state = T{ active = false, index = 1 };

local cfg         = T{};
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

local function run(command)
    AshitaCore:GetChatManager():ExecuteScriptString(command, '', false);
end

-- use native ashita /bind for our binds
local function set_bind(bind, active)
    local bindstr = '';

    if (active) then
        bindstr = cfg[bind.key] or '';
    end

    if (bindstr == bind.bindstr) then
        return;
    end

    if (bind.bindstr ~= '') then
        run('/unbind ' .. bind.bindstr);
    end

    bind.bindstr = bindstr;

    if (bindstr ~= '') then
        run(('/bind %s %s%s'):fmt(bindstr, COMMAND, bind.key));
    end
end

-- confirm the bind is not taken via ashita already
local function is_taken(kb, bind)
    local bindstr = cfg[bind.key] or '';

    if (bindstr == '' or bindstr == bind.bindstr) then
        return false;
    end

    local key  = bindstr:match('[!^@#+]*(.+)$');
    local mods = T{};

    for name, prefix in pairs(T{ alt = '!', apps = '#', ctrl = '^', shift = '+', win = '@' }) do
        mods[name] = bindstr:find(prefix, 1, true) ~= nil;
    end

    -- default binds use key down
    local bound = kb:IsBound(kb:S2D(key), true, mods.alt, mods.apps, mods.ctrl, mods.shift, mods.win, false, false);
    if (bound) then
        print(chat.header('statustimers'):append(chat.error(
            ('%s is already bound, pick another key for %s.'):fmt(bindstr, bind.key))));
        return true;
    end

    return false;
end


-- set binds to silent so we dont slam the chat window
-- cache the old value to reset after
local function apply()
    local kb = AshitaCore:GetInputManager():GetKeyboard();
    if (kb == nil) then
        return;
    end

    local current_silent = kb:GetSilentBinds();
    kb:SetSilentBinds(true);

    for _, b in ipairs(BINDS) do
        if (is_taken(kb, b)) then
            break;
        end

        set_bind(b, b.persistent or state.active);
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
    apply();
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
        t[b.key] = b.default;
    end
    return t;
end

module.rebind = apply;

module.bind = function(settings, cancel)
    cfg         = settings.key_nav;
    cancel_func = cancel;

    apply();
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
    cfg          = T{};
    apply();
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

return module;
