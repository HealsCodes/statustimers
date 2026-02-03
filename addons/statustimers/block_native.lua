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

-------------------------------------------------------------------------------
-- local state
-------------------------------------------------------------------------------
local handler_data = T {
    pointer = T{ nil, nil },
    opcodes = T{ 0x0000, 0x0000 },
};

-------------------------------------------------------------------------------
-- exported functions
-------------------------------------------------------------------------------
local module = {};

helpers.register_init('block_native_init', function()
    handler_data.pointer[1] = ashita.memory.find('FFXiMain.dll', 0, '75??55518B0D????????E8????????85C07F??8BDE', 0, 0);
    handler_data.pointer[2] = ashita.memory.find('FFXiMain.dll', 0, '75??55518B0D????????E8????????85C07F??8BDE', 0, 1);

    if (handler_data.pointer[1] == nil or handler_data.pointer[1] == 0 or handler_data.pointer[2] == nil or handler_data.pointer[2] == 0) then
        return false;
    end

    if (handler_data.pointer[1] == handler_data.pointer[2]) then
        return false;
    end

    -- backup the original instructions
    handler_data.opcodes[1] = ashita.memory.read_uint16(handler_data.pointer[1]);
    handler_data.opcodes[2] = ashita.memory.read_uint16(handler_data.pointer[2]);

    -- check if first location has been modified
    if (handler_data.opcodes[1] ~= 0x9090) then
        -- Patch only the FIRST location - hides display but keeps F key menu working
        ashita.memory.write_uint16(handler_data.pointer[1], 0x9090);
        return true;
    end
    return false;
end);

helpers.register_cleanup('block_native_cleanup', function()
    -- revert the NOP to the original instruction
    if (handler_data.pointer[1] ~= nil and handler_data.pointer[1] ~= 0) then
        if (handler_data.opcodes[1] ~= 0x0000) then
            ashita.memory.write_uint16(handler_data.pointer[1], handler_data.opcodes[1]);
        end
    end
    return true;
end);

return module
