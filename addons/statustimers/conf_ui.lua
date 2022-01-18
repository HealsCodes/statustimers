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

local imgui = require('imgui');
-- local modules
local helpers = require('helpers');
local resources = require('resources')
-------------------------------------------------------------------------------
-- local state
-------------------------------------------------------------------------------
local ui = T {
    is_open = T{ false, },
    theme_valid = true,
    theme_index = { resources.get_theme_index('-default-') },
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
    end

    if (not ui.is_open[1]) then
        return;
    end

    local c = { 0, 0, 0, 0 };
    local header_color = { 1.0, 0.75, 0.55, 1.0 };

    imgui.SetNextWindowContentSize({400, 380});

    if (imgui.Begin(('Statustimers v%s'):fmt(addon.version), ui.is_open, ImGuiWindowFlags_AlwaysAutoResize)) then
        imgui.BeginGroup();
            -- icon sizes and theme
            imgui.TextColored(header_color, 'Icon Settings');
            imgui.BeginChild('conf_icons', { 0, 90 }, true);
                local main_size = T{ settings.icons.size.main };
                local target_size = T{ settings.icons.size.target };

                imgui.SliderInt('\xef\x86\xae Icons', main_size, 14, 256, '%dpx');
                imgui.ShowHelp('Size for the player\'s status icons.', true);
                imgui.SliderInt('\xef\x81\x9b Icons', target_size, 14, 256, '%dpx');
                imgui.ShowHelp('Size for target status icons.', true);

                local combo_flags = bit.bor(ImGuiComboFlags_None);
                local theme_paths = resources.get_theme_paths();

                if (imgui.BeginCombo('\xef\x97\x83 Theme', theme_paths[ui.theme_index[1] ], combo_flags)) then
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
            imgui.BeginChild('conf_font', { 0, 60 }, true);
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
            imgui.EndChild();

            -- visual toggle and colour blocks
            imgui.TextColored(header_color, 'Visual Aid');
            imgui.ShowHelp('Visual Aid shows a coloured swatch below each status effect.\n' ..
                                'The remaining % is based on when statustimers first tracked\n' ..
                                'a status effect and thus may not be accurate for pre-existing effects (Signed, etc.).');

            imgui.BeginChild('conf_va', { 0, 135 }, true)
                if (imgui.Checkbox('Enabled?', { settings.visual_aid.enabled })) then
                    settings.visual_aid.enabled = not settings.visual_aid.enabled;
                end
                imgui.ShowHelp('Show visual aid swatches.');

                c = helpers.color_u32_to_v4(settings.visual_aid.color100);
                if (imgui.ColorEdit4('\xef\x80\x97 > 75%', c)) then
                    settings.visual_aid.color100 = helpers.color_v4_to_u32(c);
                end
                imgui.ShowHelp('Aid colour with more than 75% remaining duration.', true);

                c = helpers.color_u32_to_v4(settings.visual_aid.color75);
                if (imgui.ColorEdit4('\xef\x80\x97 > 50%', c)) then
                    settings.visual_aid.color75 = helpers.color_v4_to_u32(c);
                end
                imgui.ShowHelp('Aid colour with more than 50% remaining duration.', true);

                c = helpers.color_u32_to_v4(settings.visual_aid.color50);
                if (imgui.ColorEdit4('\xef\x80\x97 > 25%', c)) then
                    settings.visual_aid.color50 = helpers.color_v4_to_u32(c);
                end
                imgui.ShowHelp('Aid colour with more than 25% remaining duration.', true);

                c = helpers.color_u32_to_v4(settings.visual_aid.color25);
                if (imgui.ColorEdit4('\xef\x80\x97 < 25%', c)) then
                    settings.visual_aid.color25 = helpers.color_v4_to_u32(c);
                end
                imgui.ShowHelp('Aid colour below 25% remaining duration.', true);
            imgui.EndChild();
            imgui.Text('');
            imgui.TextDisabled(('\xef\x87\xb9 2022 by %s - %s'):fmt(addon.author, addon.link));
        imgui.EndGroup();
    end
    imgui.End();
end

return module;
