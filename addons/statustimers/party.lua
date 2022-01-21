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

local bit = require('bit');
-- local modules
local helpers = require('helpers');
-------------------------------------------------------------------------------
-- local constants
-------------------------------------------------------------------------------
local INFINITE_DURATION = 0x7FFFFFFF;
local REALUTCSTAMP_ID = 'statustimers:realutcstamp';
-------------------------------------------------------------------------------
-- local functions
-------------------------------------------------------------------------------
-- return the utc timestamp the game is using.
---@return number timestamp the game's UTC timestamp
local function get_utcstamp()
    local ptr = AshitaCore:GetPointerManager():Get(REALUTCSTAMP_ID);
    -- double dereference the pointer to get the correct address
    ptr = ashita.memory.read_uint32(ptr);
    ptr = ashita.memory.read_uint32(ptr);
    -- the utcstamp is at offset 0x0C
    return ashita.memory.read_uint32(ptr + 0x0C);
end
-------------------------------------------------------------------------------
-- exported functions
-------------------------------------------------------------------------------
local module = {};

-- return the name of a party member based on server id.
---@param server_id number the party memer or target server id to check
---@return string name the member name or nil of server id is not a party memeber
module.get_member_name = function(server_id)
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party == nil) then
        return nil;
    end

    -- try and find a party member with a matching server id
    for i = 1,4,1 do
        if (party:GetMemberServerId(i) == server_id) then
            return party:GetMemberName(i);
        end
    end
    return nil;
end

-- return a table of status ids for a party member based on server id.
---@param server_id number the party memer or target server id to check
---@return table status_ids a list of the targets status ids or nil
module.get_member_status = function(server_id)
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party == nil) then
        return nil;
    end

    -- try and find a party member with a matching server id
    for i = 0,4,1 do
        if (party:GetStatusIconsServerId(i) == server_id) then
            local icons_lo = party:GetStatusIcons(i);
            local icons_hi = party:GetStatusIconsBitMask(i);
            local status_ids = T{};

            for j = 0,31,1 do
                if (icons_lo[j+1] ~= 255) then
                    -- icons_hi holds bit 9 & 10 in a 32 entry 2bit array
                    status_ids[#status_ids + 1] = icons_lo[j + 1] + bit.lshift(bit.band(bit.rshift(icons_hi, 2 * j), 3), 8);
                end
            end

            if (next(status_ids)) then
                return status_ids;
            end
            break;
        end
    end
    return nil;
end

-- check if the player "exists"
---@return boolean player_exists true if the player object is valid
module.is_player_valid = function()
    if (AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0) ~= 0) then
        return AshitaCore:GetMemoryManager():GetPlayer():GetIsZoning() == 0;
    end
    return false;
end

-- return name of the current target if it is a party member
---@return string name the targets name or nil
module.get_target_name = function()
    local target = AshitaCore:GetMemoryManager():GetTarget();
    if (target ~= nil) then
        if (target:GetIsSubTargetActive()) then
            return module.get_member_name(target:GetServerId(1));
        else
            return module.get_member_name(target:GetServerId(0));
        end
    end
    return nil;
end

-- return name of the current subtarget if it is a party member
---@return string name the subtargets name or nil
module.get_subtarget_name = function()
    local target = AshitaCore:GetMemoryManager():GetTarget();
    if (target ~= nil and target:GetIsSubTargetActive()) then
        return module.get_member_name(target:GetServerId(0));
    end
    return nil;
end

-- return the status effects of the current target if it is a party member
---@return table status_ids the targets status ids or nil
module.get_target_status = function()
    local target = AshitaCore:GetMemoryManager():GetTarget();
    if (target ~= nil) then
        if (target:GetIsSubTargetActive()) then
            return module.get_member_status(target:GetServerId(1));
        else
            return module.get_member_status(target:GetServerId(0));
        end
    end
    return nil;
end

-- return the status effects of the current sub target if it is a party member
---@return table status_ids the targets status ids or nil
module.get_subtarget_status = function()
    local target = AshitaCore:GetMemoryManager():GetTarget();
    if (target ~= nil and target:GetIsSubTargetActive()) then
        return module.get_member_status(target:GetServerId(0));
    end
    return nil;
end

-- return a table of { id, duration } pairs for the player's status effects
---@return table status_ids the player's status effects or nil if no player exists
module.get_player_status = function()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil or module.is_player_valid() == false) then
        return nil;
    end

    --@param raw_duration number
    local buff_duration = function(raw_duration)
        local vana_base_stamp = 0x3C307D70;
        local base_offset = 572662306;
        local timestamp = get_utcstamp();

        if (raw_duration == INFINITE_DURATION) then
            return -1;
        end

        raw_duration = (raw_duration / 60) + base_offset + vana_base_stamp;
        if (raw_duration > timestamp and ((raw_duration - timestamp) / 3600) <= 99) then
            return raw_duration  - timestamp;
        end
        return 0;
    end

    local icons = player:GetStatusIcons();
    local timers = player:GetStatusTimers();
    local status_ids = T{};

    for j = 0,31,1 do
        if (icons[j + 1] ~= 255 and icons[j + 1] > 0) then
            status_ids[#status_ids+1] = T{
                id = icons[j + 1],
                duration = buff_duration(timers[j + 1])
            };
        end
    end
    if (next(status_ids)) then
        return status_ids;
    end
    return nil;
end

helpers.register_init('party_init', function()
    local pm = AshitaCore:GetPointerManager();
    if (pm:Get(REALUTCSTAMP_ID) == 0) then
        pm:Add(REALUTCSTAMP_ID, 'FFXiMain.dll', '8B0D????????8B410C8B49108D04808D04808D04808D04C1C3', 2, 0);
        if (pm:Get(REALUTCSTAMP_ID) == 0) then
            return false;
        end
    end
    return true;
end);

helpers.register_cleanup('party_cleanup', function()
    local pm = AshitaCore:GetPointerManager();
    if (pm:Get(REALUTCSTAMP_ID) ~= 0) then
        pm:Delete(REALUTCSTAMP_ID);
    end
    return true;
end);

return module;
