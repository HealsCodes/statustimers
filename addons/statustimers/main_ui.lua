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

local bit   = require('bit');
local imgui = require('imgui');
local chat = require('chat');
-- local modules
local helpers   = require('helpers');
local resources = require('resources');
local party     = require('party');
-------------------------------------------------------------------------------
-- local constants
-------------------------------------------------------------------------------
local ITEM_SPACING = 3;
-------------------------------------------------------------------------------
-- local state
-------------------------------------------------------------------------------
local settings = T {};
local ui = T {
    is_open = T{ true, },
    im_window = false,
    color = T {
        label = T{},
        label_bg = T{},
        locked_border = { 1.0, 0.75, 0.55, 1.0 },
        va = T{
            _100 = T{},
            _75  = T{},
            _50  = T{},
            _25  = T{},
        },
        menu_target_outline = T{},
    },
    id_states = T{},
    locked_target = 0,
    window_flags = T{
        current  = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize),
        inactive = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_AlwaysAutoResize),
        active   = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_AlwaysAutoResize),
    },
    split_bars = T{
        active = { true, },
        flags_ltarget = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize),
        flags_mtarget = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize),
        flags_starget = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize),
    },
};

-------------------------------------------------------------------------------
-- local functions
-------------------------------------------------------------------------------
-- return the ITEM_SPACING constant with applied UI scale factor
---@return number the value for ITEM_SPACING taking the UI scale into account
local function item_spacing()
    return ITEM_SPACING * settings.ui_scale;
end

-- return a imgui.CalcTextSize(text) applying UI scaling if needed
---@return table { text_dim.x, text_dim.y } 
local function calc_text_size(text)
    local text_dim = { imgui.CalcTextSize(text) };
    if(ui.im_window == false) then
        text_dim = { text_dim[1] * settings.ui_scale, text_dim[2] * settings.ui_scale };
    end
    return text_dim;
end

-- return the icon size for the main ui
---@return number The configured main icon size with UI scaling applied
local function icon_size_main()
    return settings.icons.size.main * settings.ui_scale;
end

-- return the icon size for the target ui
---@return number The configured target icon size with UI scaling applied
local function icon_size_target()
    return settings.icons.size.target * settings.ui_scale;
end

-- return the fixed item width as well as the max label dimensions
---@return table sizes { item_width_main, item_width_target, { text_dim.x, text_dim.y } }
local function get_base_sizes()
    local text_dim = calc_text_size('WWW');
    return T{ 
        math.max(text_dim[1], icon_size_main()),
        math.max(text_dim[1], icon_size_target()),
        text_dim
    };
end

-- check the passed name is the name of the locked target
---@param name string a player name
---@return boolean is_lock_target if the names match
local function is_lock_target(name)
    return name ~= nil and name == party.get_member_name(ui.locked_target);
end

-- return the dimensions of the player status list
---@return table size { w, h } for the player status list
local function player_status_size()
    local status = party.get_player_status();
    local item_width, _, text_dim = get_base_sizes():unpack();
    local va_multiplier = settings.visual_aid.enabled and 2 or 1;

    if (status ~= nil) then
        return { #status * (item_width + item_spacing()), item_width + item_spacing() + text_dim[2] * va_multiplier };
    end
    return { 0, 0 };
end

-- return the dimensions of an arbitrary status list
---@param label string the targets name label or nil
---@param status_list table the targets status list or nil
---@param check_lock_target boolean if true and the target is equal to the locked target return { 0, 0 }
---@return table size { w, h } for the targets status list
local function target_status_size(label, status_list, check_lock_target)
    if (check_lock_target == true and is_lock_target(label or '')) then
        return { 0, 0 };
    end

    local text_dim = calc_text_size(label or '');
    local lock_dim = { 0, 0 };
    if (imgui.IsWindowHovered() or is_lock_target(label or '')) then
        -- extra padding for the lock icon
        lock_dim = calc_text_size('\xef\x8f\x81');
        lock_dim[1] = lock_dim[1] + item_spacing();
    end

    if (status_list ~= nil) then
        return {
            #status_list * (icon_size_target() + item_spacing()) + text_dim[1] + 2 * item_spacing() + lock_dim[1],
            math.max(icon_size_target(), text_dim[2]) + 2 * item_spacing()
        };
    elseif (label ~= nil) then
        return { text_dim[1] + 2 * item_spacing() + lock_dim[1], text_dim[2] + 2 * item_spacing() };
    end
    return { 0, 0 };
end

-- return the required width and height of the main window
---@return table size ImVec2 containing the required window size
local function get_window_size()
    local player_size  = player_status_size();
    local mtarget_size = target_status_size(party.get_target_name(), party.get_target_status(), true);
    local starget_size = target_status_size(party.get_subtarget_name(), party.get_subtarget_status(), true);
    local ltarget_size = target_status_size(party.get_member_name(ui.locked_target), party.get_member_status(ui.locked_target));
    local spacing = 0;

    if (settings.split_bars.enabled == true) then
        -- split bars cuts the size of the main bar down considerably
        return {
            player_size[1],
            player_size[2] + item_spacing();
        };
    end

    if (mtarget_size[1] ~= 0) then spacing = spacing + item_spacing(); end
    if (starget_size[1] ~= 0) then spacing = spacing + item_spacing(); end
    if (ltarget_size[1] ~= 0) then spacing = spacing + item_spacing(); end

    return {
        -- whichever list is widest determines the width of the window
        math.max(player_size[1], mtarget_size[1], starget_size[1], ltarget_size[1]),
        -- the height of the window is always the sum of all lists
        player_size[2] + mtarget_size[2] + starget_size[2] + ltarget_size[2] + item_spacing() + spacing;
    };
end

-- wrap all calls required to add a rectangle to imgui's draw list
---@param top_left table ImVec2, x/y coordinates relative to cursor
---@param bot_right table ImVec2, bottom/right coordinatens relative to cursor
---@param color table ImVec4, rgba colour values in range 0.0 to 1.0
---@param radius number optional corner radius
---@param fill boolean wether to fill the rect or draw a simple outline
---@param flags number ImGuiRoundingCornerFlags, defaults to 'all'
local function draw_rect(top_left, bot_right, color, radius, fill, flags)
    local cursor = { imgui.GetCursorScreenPos() };
    local color_u32 = imgui.GetColorU32(color);
    local abs_rect = {
        { cursor[1] + top_left[1], cursor[2] + top_left[2] },
        { cursor[1] + bot_right[1], cursor[2] + bot_right[2] }
    };

    if (fill == nil or fill) then
        imgui.GetWindowDrawList():AddRectFilled(abs_rect[1], abs_rect[2], color_u32, radius or 0.0, flags or ImDrawCornerFlags_All);
    else
        imgui.GetWindowDrawList():AddRect(abs_rect[1], abs_rect[2], color_u32, radius or 0.0, flags or ImDrawCornerFlags_All);
    end
end

-- keep track of a status id's initial and remaining duration
--- and also animate it's alpha value based on the remainder.
---@param status number the status id to track
---@param duration number the number in seconds left until expiry
local function track_id_state(status, duration)
    if (not ui.id_states:haskey(status) or ui.id_states[status] == nil) then
        ui.id_states[status] = T{ alpha = 1.0, alpha_step = -0.05, duration = duration };
    else
        if (duration > -1 and duration <= 15) then
            -- qualified for animation
            ui.id_states[status].alpha = ui.id_states[status].alpha + ui.id_states[status].alpha_step;
            if (ui.id_states[status].alpha < 0.01 or ui.id_states[status].alpha > 1.0) then
                ui.id_states[status].alpha_step = -ui.id_states[status].alpha_step;
            end
        else
            -- otherwise pin the alpha to opaque to account for refreshes etc.
            ui.id_states[status].alpha = 1.0;
            ui.id_states[status].alpha_step = -0.05;
        end
    end
end

-- clean out stale status id information from the id_states map
local function prune_id_states()
    local player_status = party.get_player_status();
    if (player_status == nil) then
       return;
    end

    local status_ids = player_status:imap(function (v) return v.id; end);
    local id_state_keys = ui.id_states:keys();
    for i = 1,#id_state_keys,1 do
        if (not status_ids:hasvalue(id_state_keys[i])) then
            ui.id_states[id_state_keys[i]] = nil;
        end
    end
end

-- render the tooltip for a specific status id
---@param status number the status id
---@param is_target boolean if true, don't show '(right click to cancel)' hint
local function render_tooltip(status, is_target)
    if (status == nil or status < 1 or status > 0x3FF or status == 255) then
        return;
    end

    local info = AshitaCore:GetResourceManager():GetStatusIconByIndex(status);
    local name = resources.get_status_name(status);
    if (name ~= nil and info ~= nil) then
        imgui.BeginTooltip();
            imgui.Text(('%s (#%d)'):fmt(name, status));
            imgui.Text(info.Description[1] or '???');
            if (not is_target and resources.status_can_be_cancelled(status)) then
                imgui.TextDisabled('(right click to cancel)');
            end
        imgui.EndTooltip();
    end
end

-- render the name and status icons box for a (sub)target
---@param name string the target name tag or nil
---@param status_list table a list of status ids for the target or nil
---@param is_locked boolean if true, render the target bar in the "lock on" style
local function render_target_status(name, status_list, is_locked)
    if (name == nil and status_list == nil) then
        return;
    end

    imgui.Dummy({ 0, 0 });

    local bg = { { 0, 0 }, target_status_size(name, status_list) };
    local corner_flags = bit.bor(ImDrawCornerFlags_BotLeft, ImDrawCornerFlags_TopRight);

    draw_rect(bg[1], bg[2], ui.color.label_bg, 7.0, true, corner_flags);
    if (is_locked) then
        draw_rect(bg[1], bg[2], ui.color.locked_border, 7.0, false, corner_flags);
    end

    -- target name goes left of the icons
    if (imgui.IsWindowHovered() or is_lock_target(name or '')) then
        -- draw the extra icons for target lock and unlock
        imgui.SetCursorPos({ imgui.GetCursorPosX() + 2 * item_spacing(), imgui.GetCursorPosY() + item_spacing() });

        if (is_locked or is_lock_target(name or '')) then
            imgui.TextColored(ui.color.locked_border, '\xef\x80\xa3'); -- lock closed
            if (imgui.IsItemClicked()) then
                ui.locked_target = 0;
            end
        else
            imgui.Text('\xef\x8f\x81'); -- lock open
            if (imgui.IsItemClicked()) then
                ui.locked_target = party.get_member_id_by_name(name or '');
            end
        end
        imgui.SameLine(0);
    else
        imgui.SetCursorPos({ imgui.GetCursorPosX() + item_spacing(), imgui.GetCursorPosY() + item_spacing() });
    end

    imgui.TextColored(ui.color.label, name or '');
    if (status_list ~= nil and next(status_list)) then
        imgui.SameLine(0);

        for i = 1,#status_list,1 do

            local icon = resources.get_icon_from_theme(settings.icons.theme, status_list[i]);
            imgui.Image(icon, { icon_size_target(), icon_size_target() }, { 0, 0 }, { 1, 1 }, { 1, 1, 1, 1 }, { 0, 0, 0, 0 });

            if (imgui.IsItemHovered()) then
                -- show a tooltip even for the targets status effects
                render_tooltip(status_list[i], true);
            end

            if (i < #status_list) then
                imgui.SameLine(0);
            end
        end
    end
end

-- render the coloured visual aid swatch for a status
---@param status number the id of the status effect
---@param duration number the remaining status duration in seconds
---@param size table ImVec2 with and height of the swatch
---@return boolean did_render true if the swatch was rendered
local function render_visual_aid_swatch(status, duration, size)
    if (not resources.status_has_visual_aid(status, settings)) then
        return false;
    end

    -- pick the current aid colour
    local progress = duration * 100.0 / ui.id_states[status].duration;
    local color = {0.0, 0.0, 0.0, 0.0};

    if (duration == -1) then
        color = { 1.0, 1.0, 1.0, 0.25 };
    else
        if (duration > settings.visual_aid.thresholds.t75[1]) then
            color = ui.color.va._100;
        elseif (duration > settings.visual_aid.thresholds.t50[1]) then
            color = ui.color.va._75;
        elseif (progress > settings.visual_aid.thresholds.t25[1]) then
            color = ui.color.va._50;
        else
            color = ui.color.va._25;
        end
        color[4] = ui.id_states[status].alpha;
    end

    local rect = { { 0, 0 }, size };
    draw_rect(rect[1], rect[2], color, 7.0, true);
    imgui.Dummy( size );

    return true;
end

-- renders a detached target status bar in a separate window
---@param split_bar_id string an identifier for this bar, also used as key into ui.split_bars
---@param name string the target name tag or nil
---@param status_list table a list of status ids for the target or nil
---@param is_locked boolean if true, render the target bar in the "lock on" style
local function render_split_bar(split_bar_id, name, status_list, is_locked)
    if (name == nil) then
        return;
    end

    ui.im_window = false;
    local window_size = target_status_size(name, status_list);
    if (not is_locked) then
        -- windows form target and subtarget are slightly wider to accomodate
        -- for the hover-lock icon
        lock_dim = calc_text_size('\xef\x8f\x81');
        window_size = { window_size[1] + lock_dim[1] + item_spacing(), window_size[2] }
    end

    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, {item_spacing(), item_spacing()});
    imgui.SetNextWindowBgAlpha(0.45);
    imgui.SetNextWindowContentSize(window_size);

    if (imgui.Begin('st_' + split_bar_id, ui.is_open, ui.split_bars[split_bar_id])) then
        ui.im_window = true;
        imgui.SetWindowFontScale(settings.ui_scale);
        render_target_status(name, status_list, is_locked);
        -- update the window state for the next draw
        ui.split_bars[split_bar_id] = imgui.IsWindowHovered() and ui.window_flags.active or ui.window_flags.inactive;
    end
    imgui.SetWindowFontScale(1.0);
    imgui.End();
    imgui.PopStyleVar(1);
    ui.im_window = false;
end

-------------------------------------------------------------------------------
-- exported functions
-------------------------------------------------------------------------------
local module = {};

-- render the main statustimers UI
---@param s table the global settings table
---@param status_clicked function fn(id) callback to cancel the selected status
---@param settings_clicked function callback when the user clicks the settings icon
module.render_main_ui = function(s, status_clicked, settings_clicked)
    settings = s;

    -- clean up since the last frame
    prune_id_states();

    -- pre parse the argb colours into ImVec4
    ui.color.label    = helpers.color_u32_to_v4(settings.font.color);
    ui.color.label_bg = helpers.color_u32_to_v4(settings.font.background);
    ui.color.va._100  = helpers.color_u32_to_v4(settings.visual_aid.color100);
    ui.color.va._75   = helpers.color_u32_to_v4(settings.visual_aid.color75);
    ui.color.va._50   = helpers.color_u32_to_v4(settings.visual_aid.color50);
    ui.color.va._25   = helpers.color_u32_to_v4(settings.visual_aid.color25);
    ui.color.menu_target_outline   = helpers.color_u32_to_v4(settings.menu_target.outline_color);

    ui.im_window = false;
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, {item_spacing(), item_spacing()});

    imgui.SetNextWindowBgAlpha(0.45);
    imgui.SetNextWindowContentSize(get_window_size());

    if (imgui.Begin('st_ui', ui.is_open, ui.window_flags.current)) then
        imgui.SetWindowFontScale(settings.ui_scale);

        ui.im_window = true;
        local item_width, _, text_dim = get_base_sizes():unpack();
        local player_status = party.get_player_status();
        local is_targeting_buff_menu = resources.get_menu_is_buff_menu();
        local menu_target_index = resources.get_menu_target_index();

        -- render the player status
        if (player_status ~= nil) then
            local add_dummy_swatch_spacer = settings.visual_aid.enabled;
            local swatch_size = { item_width, text_dim[2] - item_spacing() };

            for i = 1,#player_status,1 do
                -- run the bookkeeping for duration and fade states
                track_id_state(player_status[i].id, player_status[i].duration);

                local icon = resources.get_icon_from_theme(settings.icons.theme, player_status[i].id);
                local label = helpers.formatted_duration(player_status[i].duration);

                -- respect hidden timers
                if (resources.status_timer_hidden(player_status[i].id)) then
                    label = '--';
                end

                text_dim = calc_text_size(label);

                --imgui.PushItemWidth(16);
                imgui.BeginGroup();
                    local icon_tint = { 1.0, 1.0, 1.0, ui.id_states[player_status[i].id].alpha }

                    imgui.SetCursorPosX(imgui.GetCursorPosX() + ((item_width - icon_size_main()) * 0.5));
                    if (is_targeting_buff_menu and i == menu_target_index) then
                        -- draw a border around the icon if it is targetted in the game menu
                        draw_rect({ -item_spacing() * 1.0, -item_spacing() * 1.0 }, { icon_size_main() + (item_spacing() * 1.0), icon_size_main() + (item_spacing() * 1.0) }, ui.color.menu_target_outline, 7.0, false);
                    end
                    imgui.Image(icon, { icon_size_main(), icon_size_main() }, { 0, 0 }, { 1, 1 }, icon_tint, { 0, 0, 0, 0});

                    if (imgui.IsItemHovered()) then
                        render_tooltip(player_status[i].id, false);
                    end

                    -- this dummy is essential for correct resizing as it always has the actual item_width
                    imgui.Dummy({ item_width + item_spacing(), 1 });

                    if (i == 1) then
                        -- first item also draws the background for the whole row
                        local bg = { { -item_spacing(), -item_spacing() * 0.5 }, { player_status_size()[1], text_dim[2] } };

                        if (settings.visual_aid.enabled) then
                            -- visual aid adds another row below the timers
                            bg[2][2] = bg[2][2] + text_dim[2] + item_spacing();
                        end
                        draw_rect(bg[1], bg[2], ui.color.label_bg, 7.0);
                    end

                    imgui.SetCursorPosX(imgui.GetCursorPosX() + ((item_width - text_dim[1]) * 0.5));
                    imgui.TextColored(ui.color.label, label);

                    if (settings.visual_aid.enabled) then
                        if (render_visual_aid_swatch(player_status[i].id, player_status[i].duration, swatch_size)) then
                            add_dummy_swatch_spacer = false;
                        end
                    end
                imgui.EndGroup();
                if (imgui.IsItemClicked(ImGuiMouseButton_Right)) then
                    if (status_clicked ~= nil and resources.status_can_be_cancelled(player_status[i].id)) then
                        status_clicked(player_status[i].id);
                    end
                end

                if i < #player_status then
                    imgui.SameLine(0, 0);
                end
            end
            if (add_dummy_swatch_spacer) then
                -- required if visual aid is active but no whitelisted status is visible
                imgui.Dummy(swatch_size);
            end
        end

        if (settings.split_bars.enabled == false) then
            -- render the locked target (if any)
            if (ui.locked_target ~= 0) then
                render_target_status(party.get_member_name(ui.locked_target), party.get_member_status(ui.locked_target), true);
            end
            -- render the player's target
            if (not is_lock_target(party.get_target_name())) then
                render_target_status(party.get_target_name(), party.get_target_status());
            end
            -- render the player's subtarget
            if (not is_lock_target(party.get_subtarget_name())) then
                render_target_status(party.get_subtarget_name(), party.get_subtarget_status());
            end
        end

        -- add the settings button if the window is being hovered
        if (imgui.IsWindowHovered() and settings_clicked ~= nil) then
            if get_window_size()[1] ~= 0 then
                imgui.SetCursorPos({ imgui.GetWindowWidth() - 25 * settings.ui_scale, 
                                     imgui.GetWindowHeight() - 25 * settings.ui_scale });
            end
            imgui.Button('\xef\x82\xad', { 20 * settings.ui_scale, 20 * settings.ui_scale });
            if (imgui.IsItemClicked()) then
                settings_clicked();
            end
        end

        -- update the window state for the next draw
        ui.window_flags.current = imgui.IsWindowHovered() and ui.window_flags.active or ui.window_flags.inactive;
    end
    imgui.SetWindowFontScale(1.0);
    imgui.End();
    imgui.PopStyleVar(1);
    ui.im_window = false;

    -- if split bars are active render them after the main window
    if (settings.split_bars.enabled == true) then
        -- render the locked target (if any)
        if (ui.locked_target ~= 0) then
            render_split_bar('flags_ltarget', party.get_member_name(ui.locked_target), party.get_member_status(ui.locked_target), true);
        end
        -- render the player's target
        if (not is_lock_target(party.get_target_name())) then
            render_split_bar('flags_mtarget', party.get_target_name(), party.get_target_status());
        end
        -- render the player's subtarget
        if (not is_lock_target(party.get_subtarget_name())) then
            render_split_bar('flags_starget', party.get_subtarget_name(), party.get_subtarget_status());
        end
    end
end

-- set the lock-on target to a named party member
---@param name string name of the party member to lock on
module.lock_target = function(name)
    ui.locked_target = party.get_member_id_by_name(name);
    if (ui.locked_target == 0) then
        print(chat.header(addon.name):append(chat.error(('"%s" is not a party member.'):fmt(name or ''))));
    end
end

-- clear the lock-on target
module.unlock_target = function()
    ui.locked_target = 0;
end

-- dump the current status effects for the player and party to chat
module.dump_status = function()
    local player_status = party.get_player_status();

    -- render the player status
    if (player_status ~= nil) then
        print(chat.header(addon.name):append(('player: %d active effects:'):fmt(#player_status)));

        for i = 1,#player_status,1 do
            print(chat.header(addon.name):append('-- id: %d, duration: %d'):fmt(player_status[i].id, player_status[i].duration));
        end
    else
        print(chat.header(addon.name):append('player: no active effects'));
    end
end

return module;
