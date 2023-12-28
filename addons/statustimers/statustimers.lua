--[[
* statustimers - Copyright (c) 2022 Heals
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

addon.name    = 'statustimers';
addon.author  = 'heals';
addon.version = '4.1.501';
addon.desc    = 'Replacement for the default status timer display';
addon.link    = 'https://github.com/HealsCodes/statustimers';

-------------------------------------------------------------------------------
-- imports
-------------------------------------------------------------------------------
require('common');
local settings = require('settings');
local chat = require('chat');
-- local modules
require('block_native');
local helpers = require('helpers');
local main_ui = require('main_ui');
local conf_ui = require('conf_ui');
-------------------------------------------------------------------------------
-- local state
-------------------------------------------------------------------------------
local default_settings = T{
    icons = T{
        size = T{
            main = 24,
            target = 16,
        },
        theme = '-default-',
    },

    font = T{
        color = 0xFFFFFFFF,
        background = 0x72000000,
    },

    visual_aid = T{
        enabled  = false,
        color100 = 0xFF00FF00,
        color75  = 0xFFFFFF33,
        color50  = 0xFFFFA64D,
        color25  = 0xFFFF0000,

        thresholds = {
            t75 = T{ 30 },
            t50 = T{ 20 },
            t25 = T{ 10 },
        },

        filters = T{
            mode = 'blacklist',
            ids = T{ },
        },
    },

    split_bars = T{
        enabled = false,
    },

    ui_scale = 1.0,
};

local st = T {
    settings = settings.load(default_settings),
    toggle_settings = false,
};
-------------------------------------------------------------------------------
-- local functions
-------------------------------------------------------------------------------
local function try_cancel(status_id)
    -- this is unconditional but the main ui only calls it for cancellable ids
    local status_hi = bit.rshift(status_id, 8);
    local status_lo = bit.band(status_id, 0xff);

    AshitaCore:GetPacketManager():AddOutgoingPacket(0xf1, { 0x00, 0x00, 0x00, 0x00, status_lo, status_hi, 0x00, 0x00 });
end

local function toggle_settings()
    st.toggle_settings = true;
end
-------------------------------------------------------------------------------
-- addon callbacks
-------------------------------------------------------------------------------
settings.register('settings', 'settings_update', function (s)
    if (s ~= nil) then
        st.settings = s;
    end

    -- Save the current settings..
    settings.save();
end);

local ffi = require('ffi');
ashita.events.register('load', 'statustimers_load', function ()
    helpers.run_init();
end)

ashita.events.register('unload', 'statustimers_unload', function ()
    settings.save();
    helpers.run_cleanup();
end)

ashita.events.register('d3d_present', 'statustimers_present', function()
    main_ui.render_main_ui(st.settings, try_cancel, toggle_settings);
    conf_ui.render_config_ui(st.settings, st.toggle_settings);

    st.toggle_settings = false;
end)

ashita.events.register('command', 'statustimers_command', function (e)
    local args = e.command:args();
    if (#args == 0 or (args[1] ~= '/statustimers' and args[1] ~= '/stt'
                   and args[1] ~= '/lockstatus' and args[1] ~= '/unlockstatus'
                   and args[1] ~= '/dumpstatus')) then
        return;
    end

    e.blocked = true;

    if (args[1] == '/statustimers' or args[1] == '/stt') then
        toggle_settings();
    elseif (args[1] == '/lockstatus') then
        if (#args == 1) then
            print(chat.header(addon.name):append(chat.error(('/lockstatus requires a party member name'))));
        else
            main_ui.lock_target(args[2]);
        end
    elseif (args[1] == '/unlockstatus') then
        main_ui.unlock_target();
    elseif (args[1] == '/dumpstatus') then
        main_ui.dump_status();
    end
end)
