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

-------------------------------------------------------------------------------
-- imports
-------------------------------------------------------------------------------
local helpers = require('helpers');
-------------------------------------------------------------------------------
-- local constants
-------------------------------------------------------------------------------
local STATUSHANDLER1_ID = 'statustimers:statushandler_1';
local STATUSHANDLER2_ID = 'statustimers:statushandler_2';
-------------------------------------------------------------------------------
-- local state
-------------------------------------------------------------------------------
local handler_data = T { 0x0000, 0x0000 };
-------------------------------------------------------------------------------
-- exported functions
-------------------------------------------------------------------------------
local module = {};

helpers.register_init('block_native_init', function()
    local pm = AshitaCore:GetPointerManager();

    if (pm:Get(STATUSHANDLER1_ID) == 0) then
        pm:Add(STATUSHANDLER1_ID, 'FFXiMain.dll', '75??55518B0D????????E8????????85C07F??8BDE', 0, 0);
        if (pm:Get(STATUSHANDLER1_ID) == 0) then
            return false;
        end
    end

    if (pm:Get(STATUSHANDLER2_ID) == 0) then
        pm:Add(STATUSHANDLER2_ID, 'FFXiMain.dll', '75??55518B0D????????E8????????85C07F??8BDE', 0, 1);
        if (pm:Get(STATUSHANDLER2_ID) == 0) then
            return false;
        end
    end

    -- this should be two different signatures, if not -> abort
    if (pm:Get(STATUSHANDLER1_ID) == pm:Get(STATUSHANDLER2_ID)) then
        pm:Delete(STATUSHANDLER1_ID);
        pm:Delete(STATUSHANDLER2_ID);
        return false;
    end

    -- backup the original instructions
    handler_data[1] = ashita.memory.read_uint16(pm:Get(STATUSHANDLER1_ID));
    handler_data[2] = ashita.memory.read_uint16(pm:Get(STATUSHANDLER2_ID));

    -- check if they have been modified
    if (handler_data[1] ~= 0x9090 and handler_data[2] ~= 0x9090) then
        -- NOP out the branch that draws the native status icons
        ashita.memory.write_uint16(pm:Get(STATUSHANDLER1_ID), 0x9090);
        ashita.memory.write_uint16(pm:Get(STATUSHANDLER2_ID), 0x9090);
        return true;
    end
    return false;
end);

helpers.register_cleanup('block_native_cleanup', function()
    local pm = AshitaCore:GetPointerManager();

    -- revert the NOPs to the original instructions
    if (pm:Get(STATUSHANDLER1_ID) ~= 0) then
        if (handler_data[1] ~= 0x0000) then
            ashita.memory.write_uint16(pm:Get(STATUSHANDLER1_ID), handler_data[1]);
        end
        pm:Delete(STATUSHANDLER1_ID);
    end

    if (pm:Get(STATUSHANDLER2_ID) ~= 0) then
        if (handler_data[2] ~= 0x0000) then
            ashita.memory.write_uint16(pm:Get(STATUSHANDLER2_ID), handler_data[2]);
        end
        pm:Delete(STATUSHANDLER2_ID);
    end
    return true;
end);

return module