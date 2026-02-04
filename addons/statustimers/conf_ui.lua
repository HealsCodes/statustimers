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

local imgui = require('compat').require_imgui();
-- local modules
local helpers = require('helpers');
local resources = require('resources');
local filters_ui = require('conf_filters_ui');
local compat = require('compat');
-------------------------------------------------------------------------------
-- local state
-------------------------------------------------------------------------------
local ui = T {
    is_open = T{ false, },
    is_filters_open = T { false, },
    -- main config ui
    theme_index = T{ resources.get_theme_index('-default-') },
    ui_scale = 1.0
};
-------------------------------------------------------------------------------
-- exported functions
-------------------------------------------------------------------------------
local module = {};

-- render the configuration UI
---@param settings table the global settings table
---@param toggle boolean if true toggle the UI visibility
module.render_config_ui = function(settings, toggle)
    if (toggle) then
        ui.is_open[1] = not ui.is_open[1];
        ui.theme_index[1] = resources.get_theme_index(settings.icons.theme) or resources.get_theme_index('-default-');
        ui.ui_scale = settings.ui_scale;
    end

    if (not ui.is_open[1]) then
        return;
    end

    local c = { 0, 0, 0, 0 };
    local header_color = { 1.0, 0.75, 0.55, 1.0 };
    local scale_w = math.max(1.0, ui.ui_scale * 1.0);
    local scale_h = math.max(1.0, ui.ui_scale * 0.74);

    imgui.SetNextWindowContentSize({ 500 * scale_w, 760 * scale_h });

    if (imgui.Begin(('Statustimers v%s %s'):fmt(addon.version, compat.state()), ui.is_open, ImGuiWindowFlags_AlwaysAutoResize)) then
        imgui.PushFont(nil, imgui.GetFontSize()*ui.ui_scale);
        imgui.BeginGroup();
            -- icon sizes and theme
            imgui.TextColored(header_color, 'Icon Settings');
            imgui.BeginChild('conf_icons', { 0 * scale_w, 100 * scale_h }, ImGuiChildFlags_Borders);
                local main_size = T{ settings.icons.size.main };
                local target_size = T{ settings.icons.size.target };

                imgui.SliderInt('\xef\x86\xae Icons', main_size, 14, 256, '%dpx');
                imgui.ShowHelp('Size for the player\'s status icons.', true);
                imgui.SliderInt('\xef\x81\x9b Icons', target_size, 14, 256, '%dpx');
                imgui.ShowHelp('Size for target status icons.', true);

                local combo_flags = ImGuiComboFlags_None;
                local theme_paths = resources.get_theme_paths();

                if (imgui.BeginCombo('\xef\x97\x83 Theme', theme_paths[ui.theme_index[1]], combo_flags)) then
                    for i = 1,#theme_paths,1 do
                        local is_selected = i == ui.theme_index[1];

                        if (imgui.Selectable(theme_paths[i], is_selected)) then
                            ui.theme_index[1] = i;
                            settings.icons.theme = theme_paths[i];
                            resources.clear_cache();
                        end

                        if (is_selected) then
                            imgui.SetItemDefaultFocus();
                        end
                    end
                    imgui.EndCombo();
                end
                imgui.ShowHelp('Name of the theme directory inside statustimers\\themes\\\n' ..
                                    'or -default- for stock XI icons.', true);

                settings.icons.size.main = main_size[1];
                settings.icons.size.target = target_size[1];
            imgui.EndChild();

            -- font and background colours
            imgui.TextColored(header_color, 'Font Settings');
            imgui.BeginChild('conf_font', { 0 * scale_w, 100 * scale_h }, ImGuiChildFlags_Borders);
                c = helpers.color_u32_to_v4(settings.font.color);
                if (imgui.ColorEdit4('\xef\x94\xbf Colour', c)) then
                    settings.font.color = helpers.color_v4_to_u32(c);
                end
                imgui.ShowHelp('Timer foreground colour.', true);

                c = helpers.color_u32_to_v4(settings.font.background);
                if (imgui.ColorEdit4('\xef\x94\xbf Background', c)) then
                    settings.font.background = helpers.color_v4_to_u32(c);
                end
                imgui.ShowHelp('Timer background colour.', true);

                local ui_scale = T{ settings.ui_scale };
                imgui.SliderFloat('\xef\x86\xae UI Scale', ui_scale, 1.0, 4.0, '%.1fx');
                settings.ui_scale = ui_scale[1];
                if (not imgui.IsItemActive()) then
                    ui.ui_scale = settings.ui_scale;
                end
                imgui.ShowHelp('UI scaling factor (for use with HiDPI screens/4k/...).', true);
            imgui.EndChild();

            -- visual toggle and colour blocks
            imgui.TextColored(header_color, 'Visual Aid');
            imgui.ShowHelp('Visual Aid shows a coloured swatch below each status effect.\n' ..
                                'The colour is based the remaining duration in seconds and fully configurable.\n');

            imgui.BeginChild('conf_va', { 0 * scale_w, 345 * scale_h }, ImGuiChildFlags_Borders)
                if (imgui.Checkbox('Enabled?', { settings.visual_aid.enabled })) then
                    settings.visual_aid.enabled = not settings.visual_aid.enabled;
                end
                imgui.ShowHelp('Show visual aid swatches.');

                imgui.TextColored(header_color, 'Thresholds');
                imgui.BeginChild('conf_va_threshold', { 0 * settings.ui_scale, 100 * settings.ui_scale }, ImGuiChildFlags_Borders)
                    imgui.PushID('T#1');
                    imgui.InputInt(' ', settings.visual_aid.thresholds.t75);
                    imgui.PopID();
                    imgui.SameLine();
                    imgui.TextColored(helpers.color_u32_to_v4(settings.visual_aid.color75), '\xef\x80\x97 T1');
                    imgui.ShowHelp('Threshold in seconds remaining.', true);

                    imgui.PushID('T#2');
                    imgui.InputInt(' ', settings.visual_aid.thresholds.t50);
                    imgui.PopID();
                    imgui.SameLine();
                    imgui.TextColored(helpers.color_u32_to_v4(settings.visual_aid.color50), '\xef\x80\x97 T2');
                    imgui.ShowHelp('Threshold in seconds remaining.', true);

                    imgui.PushID('T#3');
                    imgui.InputInt(' ', settings.visual_aid.thresholds.t25);
                    imgui.PopID();
                    imgui.SameLine();
                    imgui.TextColored(helpers.color_u32_to_v4(settings.visual_aid.color25), '\xef\x80\x97 T3');
                    imgui.ShowHelp('Threshold in seconds remaining.', true);
                imgui.EndChild();

                imgui.TextColored(header_color, 'Colours');
                imgui.BeginChild('conf_va_colours', { 0 * scale_w, 125 * scale_h }, ImGuiChildFlags_Borders)
                    c = helpers.color_u32_to_v4(settings.visual_aid.color100);
                    if (imgui.ColorEdit4(('\xef\x80\x97 > T1 (%ds)'):format(settings.visual_aid.thresholds.t75[1]), c)) then
                        settings.visual_aid.color100 = helpers.color_v4_to_u32(c);
                    end
                    imgui.ShowHelp('Aid colour with more than T1 seconds remaining.', true);

                    c = helpers.color_u32_to_v4(settings.visual_aid.color75);
                    if (imgui.ColorEdit4(('\xef\x80\x97 > T2 (%ds)'):format(settings.visual_aid.thresholds.t50[1]), c)) then
                        settings.visual_aid.color75 = helpers.color_v4_to_u32(c);
                    end
                    imgui.ShowHelp('Aid colour with more than T2 seconds remaining.', true);

                    c = helpers.color_u32_to_v4(settings.visual_aid.color50);
                    if (imgui.ColorEdit4(('\xef\x80\x97 > T3 (%ds)'):format(settings.visual_aid.thresholds.t25[1]), c)) then
                        settings.visual_aid.color50 = helpers.color_v4_to_u32(c);
                    end
                    imgui.ShowHelp('Aid colour with more than T3 seconds remaining.', true);

                    c = helpers.color_u32_to_v4(settings.visual_aid.color25);
                    if (imgui.ColorEdit4(('\xef\x80\x97 < T3 (%ds)'):format(settings.visual_aid.thresholds.t25[1]), c)) then
                        settings.visual_aid.color25 = helpers.color_v4_to_u32(c);
                    end
                    imgui.ShowHelp('Aid colour with less than T3 seconds remaining.', true);
                imgui.EndChild();
                if (imgui.Button('Filter Settings')) then
                    ui.is_filters_open[1] = true;
                end
                imgui.ShowHelp('Setup black- or whitelist filters to define which effects receive visual aid.', true);

            imgui.EndChild();

            -- miscelanious settings
            imgui.TextColored(header_color, 'Misc.');
            imgui.BeginChild('conf_misc', { 0 * scale_w, 70 * scale_h }, ImGuiChildFlags_Borders)
                if (imgui.Checkbox('Movable target/subtarget bars?', { settings.split_bars.enabled })) then
                    settings.split_bars.enabled = not settings.split_bars.enabled;
                end
                imgui.ShowHelp('Detach target, subtarget and locked target from the main UI.');
            imgui.EndChild();

            imgui.TextDisabled(('\xef\x87\xb9 %s by %s'):fmt(os.date('%Y'), addon.author));
            imgui.TextDisabled(('-- %s'):fmt(addon.link));
        imgui.EndGroup();
        imgui.PopFont();
    end
    imgui.End();

    filters_ui.render_config_filter_ui(settings, ui.is_filters_open);
end

return module;
