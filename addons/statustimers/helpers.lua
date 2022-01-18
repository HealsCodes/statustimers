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
require('common');
-------------------------------------------------------------------------------
-- local state
-------------------------------------------------------------------------------
local cleanup_callbacks = T{};
local init_callbacks = T{};
-------------------------------------------------------------------------------
-- exported functions
-------------------------------------------------------------------------------
local module = {};

-- register a callback to be executed by 'run_init'
---@param callback function a callback to be executed on cleanup
module.register_init = function(name, callback)
    init_callbacks[#init_callbacks+1] = {
        name = name,
        cb = callback
    };
end

-- run all callbacks queued by register_init in order
--- if a callback returns a value and that value is false then abort.
---@return boolean status true if all callbacks succeeded.
module.run_init = function()
    if (not next(init_callbacks)) then
        return true;
    end

    for i = 1,#init_callbacks,1 do
        local res = init_callbacks[i]['cb']();
        if (res ~= nil and res == false) then
            print('init failed for ' .. init_callbacks[i]['name']);
            return false;
        end
    end
    return true;
end

-- register a callback to be executed by 'run_cleanup'
---@param callback function a callback to be executed on cleanup
module.register_cleanup = function(name, callback)
    cleanup_callbacks[#cleanup_callbacks+1] = {
        name = name,
        cb = callback
    };
end

-- run all callbacks queued by register_cleanup in order.
--- if a callback returns a value and that value is false then abort.
---@return boolean status true if all callbacks succeeded.
module.run_cleanup = function()
    if (not next(cleanup_callbacks)) then
        return true;
    end

    for i = 1,#cleanup_callbacks,1 do
        local res = cleanup_callbacks[i]['cb']();
        if (res ~= nil and res == false) then
            print('cleanup failed for ' .. cleanup_callbacks[i]['name']);
            return false;
        end
    end
    return true;
end

-- return a pre-formated duration string
---@param duration number the numerical duration (in seconds) or -1 for inf
---@return string duration_str the formatted duration string
module.formatted_duration = function(duration)
    if (duration == nil or duration == -1) then
        return '--';
    elseif (duration > 3600) then
        return ('%dh'):fmt(duration / 3600);
    elseif (duration >= 60) then
        return ('%dm'):fmt(duration / 60);
    elseif (duration <= 5) then
        return (' ');
    end
    return ('%d'):fmt(duration);
end

-- convert a u32 AARRGGBB color into an ImVec4
---@param color number the colour as 32 bit argb value
---@return table color_vec ImVec4 representation of color
module.color_u32_to_v4 = function(color)
    return {
        bit.band(bit.rshift(color, 16), 0xff) / 255.0, -- red
        bit.band(bit.rshift(color,  8), 0xff) / 255.0, -- green
        bit.band(color, 0xff) / 255.0, -- blue
        bit.rshift(color, 24) / 255.0, -- alpha
    };
end

-- convert an ImVec3 to a u32 AARRGGBB color
---@param color_vec table the colour as ImVec4 argument
---@return number color 32bit rgba representation of color_vec
module.color_v4_to_u32 = function(color_vec)
    local r = color_vec[1] * 255;
    local g = color_vec[2] * 255;
    local b = color_vec[3] * 255;
    local a = color_vec[4] * 255;

    return bit.bor(
        bit.lshift(bit.band(a, 0xff), 24),  -- alpha
        bit.lshift(bit.band(r, 0xff), 16), -- red
        bit.lshift(bit.band(g, 0xff), 8), -- green
        bit.band(b, 0xff) -- blue
    );
end

return module;
