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
    pointer = nil,
    opcodes = nil,
};
-------------------------------------------------------------------------------
-- exported functions
-------------------------------------------------------------------------------
local module = {};

helpers.register_init('block_native_init', function()
    -- Locate the client function used to render status icons..
    handler_data.pointer = ashita.memory.find('FFXiMain.dll', 0, '8BF885FF0F84????????5368', 4, 0);
    if (handler_data.pointer == 0) then
        return false;
    end

    -- Backup the original jump opcode..
    handler_data.opcodes = ashita.memory.read_array(handler_data.pointer, 6);

    -- Patch the jump if it is not already patched..
    if (handler_data.opcodes[1] == 0x0F) then
        -- Rebuild the jump instruction..
        local jmp = T{ 0xE9, handler_data.opcodes[3], handler_data.opcodes[4], handler_data.opcodes[5], handler_data.opcodes[6], 0x90, };
        jmp[2] = jmp[2] + 1;

        -- Patch the client function..
        ashita.memory.write_array(handler_data.pointer, jmp);
        return true;
    end

    return false;
end);

helpers.register_cleanup('block_native_cleanup', function()
    -- Restore the original client function..
    if (handler_data.pointer ~= nil and handler_data.opcodes ~= nil) then
        ashita.memory.write_array(handler_data.pointer, handler_data.opcodes);

        handler_data.pointer = nil;
        handler_data.opcodes = nil;
    end

    return true;
end);

return module
