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
    pointer = T{ nil, nil, nil },
    opcodes = T{ 0x0000, 0x0000, 0x0000 },
};

-------------------------------------------------------------------------------
-- exported functions
-------------------------------------------------------------------------------
local module = {};

helpers.register_init('block_native_init', function()
    handler_data.pointer[1] = ashita.memory.find('FFXiMain.dll', 0, '75??8B4E0851B9', 0, 0);
    handler_data.pointer[2] = ashita.memory.find('FFXiMain.dll', 0, '7D??33C05EC20400C6', 0, 0);
    handler_data.pointer[3] = ashita.memory.find('FFXiMain.dll', 0, '85C00F??????????6A0232DBE8', 0, 0);

    if (handler_data.pointer[1] == 0 or handler_data.pointer[2] == 0 or handler_data.pointer[3] == 0) then
        return false;
    end

    -- Backup the original instructions..
    handler_data.opcodes[1] = ashita.memory.read_uint16(handler_data.pointer[1]);
    handler_data.opcodes[2] = ashita.memory.read_uint16(handler_data.pointer[2]);
    handler_data.opcodes[3] = ashita.memory.read_uint16(handler_data.pointer[3]);

    -- Check for previous modifications..
    if (handler_data.opcodes[1] == 0x9090 or handler_data.opcodes[2] == 0x9090 or handler_data.opcodes[3] == 0xC031) then
        return false;
    end

    -- Patch game functions..
    ashita.memory.write_uint16(handler_data.pointer[1], 0x9090);
    ashita.memory.write_uint16(handler_data.pointer[2], 0x9090);
    ashita.memory.write_uint16(handler_data.pointer[3], 0xC031);

    return true;
end);

helpers.register_cleanup('block_native_cleanup', function()
    if (handler_data.pointer[1] ~= 0 and handler_data.opcodes[1] ~= 0) then
        ashita.memory.write_uint16(handler_data.pointer[1], handler_data.opcodes[1]);
        handler_data.pointer[1] = 0;
        handler_data.opcodes[1] = 0;
    end

    if (handler_data.pointer[2] ~= 0 and handler_data.opcodes[2] ~= 0) then
        ashita.memory.write_uint16(handler_data.pointer[2], handler_data.opcodes[2]);
        handler_data.pointer[2] = 0;
        handler_data.opcodes[2] = 0;
    end

    if (handler_data.pointer[3] ~= 0 and handler_data.opcodes[3] ~= 0) then
        ashita.memory.write_uint16(handler_data.pointer[3], handler_data.opcodes[3]);
        handler_data.pointer[3] = 0;
        handler_data.opcodes[3] = 0;
    end

    return true;
end);

return module
