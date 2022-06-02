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
    mode_index = T{ nil },
    mode_names = T{ 'blacklist', 'whitelist' },

    status_id_list = T{ },

    search_filter = T { '' },

    table_flags = bit.bor(ImGuiTableFlags_ScrollY,
                          ImGuiTableFlags_Borders,
                          ImGuiTableFlags_RowBg,
                          ImGuiTableFlags_Sortable),

    row_height = imgui.GetTextLineHeightWithSpacing(),
};
-------------------------------------------------------------------------------
-- local functions
-------------------------------------------------------------------------------
-- render a table for all active filter IDs
---@param settings table the global settings table
local function render_active_id_table(settings)
    imgui.BeginTable('conf_filter_ids', 3, ui.table_flags, { 0, ui.row_height * 10 });

        imgui.TableSetupScrollFreeze(0, 1); -- always show the top row
        imgui.TableSetupColumn(' ',             ImGuiTableColumnFlags_WidthFixed + ImGuiTableColumnFlags_NoSort, 20);
        imgui.TableSetupColumn('#id',           bit.bor(ImGuiTableColumnFlags_WidthFixed, ImGuiTableColumnFlags_DefaultSort), 40);
        imgui.TableSetupColumn('Status Effect', ImGuiTableColumnFlags_WidthStretch);
        imgui.TableHeadersRow();

        -- check the table sorting
        local sort_specs = imgui.TableGetSortSpecs();
        if (sort_specs ~= nil and sort_specs.SpecsDirty) then
            if (sort_specs.Specs.ColumnIndex == 1) then
                -- sort by ID
                settings.visual_aid.filters.ids:sort(function(a, b)
                    if (sort_specs.Specs.SortDirection == ImGuiSortDirection_Ascending) then
                        return a < b;
                    end
                    return a > b;
                end);
            elseif (sort_specs.Specs.ColumnIndex == 2) then
                -- sort by Name
                settings.visual_aid.filters.ids:sort(function(a, b)
                    local na = resources.get_status_name(a);
                    local nb = resources.get_status_name(b);

                    if (sort_specs.Specs.SortDirection == ImGuiSortDirection_Ascending) then
                        return na < nb;
                    end
                    return na > nb;
                end);
            end
            sort_specs.SpecsDirty = false;
        end

        local index_to_delete = nil;
        for i = 1,#settings.visual_aid.filters.ids,1 do
            imgui.TableNextColumn();

            -- all of the buttons are called '-' so they need a unique ID set this way..
            imgui.PushID(('-#%d'):fmt(i)); 
                if (imgui.SmallButton('-')) then
                    index_to_delete = i;
                end
            imgui.PopID();

            local id = settings.visual_aid.filters.ids[i];
            local icon = resources.get_icon_from_theme(settings.icons.theme, id);
            local label = resources.get_status_name(id) or '???';

            imgui.TableNextColumn();
            imgui.Text(('#%d'):fmt(id));

            imgui.TableNextColumn();
            if (icon ~= nil) then
                imgui.Image(icon, { 14, 14 });
                imgui.SameLine();
            end
            imgui.Text(label);
        end

        if (index_to_delete ~= nil) then
            -- safely remove the index now that the table is rendered
            settings.visual_aid.filters.ids:remove(index_to_delete);
        end
    imgui.EndTable();
end

-- render a table for all available filter IDs
---@param settings table the global settings table
local function render_available_id_table(settings)

    imgui.BeginTable('conf_filter_available', 3, ui.table_flags, { 0, ui.row_height * 10 });

        imgui.TableSetupScrollFreeze(0, 1); -- always show the top row
        imgui.TableSetupColumn(' ',             bit.bor(ImGuiTableColumnFlags_WidthFixed, ImGuiTableColumnFlags_NoSort), 20);
        imgui.TableSetupColumn('#id',           bit.bor(ImGuiTableColumnFlags_WidthFixed, ImGuiTableColumnFlags_DefaultSort), 40);
        imgui.TableSetupColumn('Status Effect', ImGuiTableColumnFlags_WidthStretch);
        imgui.TableHeadersRow();

        -- check the table sorting
        local sort_specs = imgui.TableGetSortSpecs();
        if (sort_specs ~= nil and sort_specs.SpecsDirty) then
            if (sort_specs.Specs.ColumnIndex == 1) then
                -- sort by ID
                ui.status_id_list:sort(function(a, b)
                    if (sort_specs.Specs.SortDirection == ImGuiSortDirection_Ascending) then
                        return a.id < b.id;
                    end
                    return a.id > b.id;
                end);
            elseif (sort_specs.Specs.ColumnIndex == 2) then
                -- sort by Name
                ui.status_id_list:sort(function(a, b)
                    if (sort_specs.Specs.SortDirection == ImGuiSortDirection_Ascending) then
                        return a.name < b.name;
                    end
                    return a.name > b.name;
                end);
            end
            sort_specs.SpecsDirty = false;
        end

        for i = 1,#ui.status_id_list,1 do
            local status = ui.status_id_list[i];

            if (ui.search_filter[1] ~= '') then
                local name_match = status.name:contains(ui.search_filter[1]);
                local id_match = ('#%d'):format(status.id):contains(ui.search_filter[1]);

                if (not name_match and not id_match) then
                    -- text doesn't match the current filter
                    goto skip_to_next;
                end
            end

            if (not settings.visual_aid.filters.ids:hasvalue(status.id)) then
                imgui.TableNextColumn();

                -- all of the buttons are called '+' so they need a unique ID set this way..
                imgui.PushID(('+#%d'):fmt(i));
                    if (imgui.SmallButton('+')) then
                        settings.visual_aid.filters.ids[#settings.visual_aid.filters.ids+1] = status.id;
                    end
                imgui.PopID();

                imgui.TableNextColumn();
                imgui.Text(('#%d'):fmt(status.id));

                imgui.TableNextColumn();
                local icon = resources.get_icon_from_theme(settings.icons.theme, status.id);

                if (icon ~= nil) then
                    imgui.Image(icon, { 14, 14 });
                    imgui.SameLine();
                end

                imgui.Text(status.name);
            end
            ::skip_to_next::
        end
    imgui.EndTable();
end

-------------------------------------------------------------------------------
-- exported functions
-------------------------------------------------------------------------------
local module = {};

-- render the filter settings UI
---@param settings table the global settings table
---@param is_open table a wrapped boolean indicating if the UI is visible or not
module.render_config_filter_ui = function(settings, is_open)
    if (not is_open[1]) then
        return;
    end

    if (not next(ui.status_id_list)) then
        -- first time init
        for i = 0,1023,1 do
            local status_name = resources.get_status_name(i);
            if (status_name ~= nil and status_name[1] ~= '(') then
                ui.status_id_list[#ui.status_id_list+1] = T{ id = i, name = ('%s (#%d)'):fmt(status_name, i) };
            end
        end
    end

    if (ui.mode_index[1] == nil) then
        -- first time init
        for i = 1,#ui.mode_names,1 do
            if (ui.mode_names[i] == settings.visual_aid.filters.mode) then
                ui.mode_index[1] = i;
                break;
            end
        end

        if (ui.mode_index[1] == nil) then
            ui.mode_index[1] = 1; -- default to blacklist
        end
    end

    imgui.SetNextWindowContentSize({ 400, 415 });

    if (imgui.Begin('Visual Aid Filter Settings', is_open, ImGuiWindowFlags_AlwaysAutoResize)) then
        if (imgui.BeginCombo('Filter Mode', ui.mode_names[ui.mode_index[1]], ImGuiComboFlags_None)) then
            for i = 1,#ui.mode_names,1 do
                local is_selected = i == ui.mode_index[1];

                if (imgui.Selectable(ui.mode_names[i], is_selected)) then
                    ui.mode_index[1] = i;
                    settings.visual_aid.filters.mode = ui.mode_names[i];
                end

                if (is_selected) then
                    imgui.SetItemDefaultFocus();
                end
            end
            imgui.EndCombo();
        end
        imgui.ShowHelp('Chose between including or excluding certain status effects for visual aid.', true);

        if (settings.visual_aid.filters.mode == 'whitelist') then
            imgui.Text('Show visual aid');
            imgui.SameLine();
            imgui.TextColored({ 1.0, 0.8, 0.2, 1.0 }, 'ONLY');
            imgui.SameLine();
            imgui.Text('for these status effects:');
        else
            imgui.TextColored({ 1.0, 0.8, 0.2, 1.0 }, 'DO NOT');
            imgui.SameLine();
            imgui.Text('show visual aid for these status effects:');
        end

        -- show the currently selected ids first
        render_active_id_table(settings);

        imgui.Spacing();

        imgui.InputTextWithHint('', 'Search effects below by name or #id', ui.search_filter, 256);
        imgui.ShowHelp('Enter an effect name to filter the list below.', true);

        render_available_id_table(settings);
    end
    imgui.End();
end

return module;
