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
local d3d8 = require('d3d8');
local ffi = require('ffi');
-------------------------------------------------------------------------------
-- local state
-------------------------------------------------------------------------------
local compat_flags = T{
    buff_table = false,
    icon_sizes = false,
    d3dx_decls = false,
    imgui_stub = false
};
local compat_checks_done = false;

-------------------------------------------------------------------------------
-- check for a number of changes between early alpha/beta and current v4
-------------------------------------------------------------------------------

if (compat_checks_done == false) then
    -- check for known changes in resource tables
    if (AshitaCore:GetResourceManager():GetString('buffs.names', 0) == nil) then
        -- older versions used 'buffs' instead of 'buffs.names'
        compat_flags.buff_table = true;
    end

    -- check for missing D3D8X exports
    local d3dx_call_successful, _ = pcall(function()
        -- this call is expected to fail but not throw on exception on current v4
        return ffi.C.D3DXCreateTextureFromFileInMemoryEx(nil, nil, 0, 0, 0, 0, 0, ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0, nil, nil, nil); 
    end);

    if (not d3dx_call_successful) then
        compat_flags.d3dx_decls = true;

        -- older versions of v4 did not define these d3dx8 exports
        ffi.cdef[[
            enum {
                D3DX_DEFAULT = 0xffffffff,
            };

            typedef enum _D3DXIMAGE_FILEFORMAT {
                D3DXIFF_BMP         = 0,
                D3DXIFF_JPG         = 1,
                D3DXIFF_TGA         = 2,
                D3DXIFF_PNG         = 3,
                D3DXIFF_DDS         = 4,
                D3DXIFF_PPM         = 5,
                D3DXIFF_DIB         = 6,
                D3DXIFF_FORCE_DWORD = 0x7fffffff
            } D3DXIMAGE_FILEFORMAT;

            typedef struct _D3DXIMAGE_INFO {
                UINT                    Width;
                UINT                    Height;
                UINT                    Depth;
                UINT                    MipLevels;
                D3DFORMAT               Format;
                D3DRESOURCETYPE         ResourceType;
                D3DXIMAGE_FILEFORMAT    ImageFileFormat;
            } D3DXIMAGE_INFO;

            HRESULT __stdcall D3DXCreateTextureFromFileA(IDirect3DDevice8* pDevice, const char* pSrcFile, IDirect3DTexture8** ppTexture);
            HRESULT __stdcall D3DXCreateTextureFromFileExA(IDirect3DDevice8* pDevice, const char* pSrcFile, UINT Width, UINT Height, UINT MipLevels, DWORD Usage, D3DFORMAT Format, D3DPOOL Pool, DWORD Filter, DWORD MipFilter, D3DCOLOR ColorKey, D3DXIMAGE_INFO* pSrcInfo, PALETTEENTRY* pPalette, IDirect3DTexture8** ppTexture);
            HRESULT __stdcall D3DXCreateTextureFromFileInMemoryEx(IDirect3DDevice8* pDevice, LPCVOID pSrcData, UINT SrcDataSize, UINT Width, UINT Height, UINT MipLevels, DWORD Usage, D3DFORMAT Format, D3DPOOL Pool, DWORD Filter, DWORD MipFilter, D3DCOLOR ColorKey, D3DXIMAGE_INFO* pSrcInfo, PALETTEENTRY* pPalette, IDirect3DTexture8** ppTexture);
        ]];
    end

    -- check for unadjusted icon sizes
    local icon = AshitaCore:GetResourceManager():GetStatusIconByIndex(0);
    if (icon.ImageSize == 4153) then
        -- stock icon size is 4167 bytes
        compat_flags.icon_sizes = true
    end

    local imgui = require('imgui');
    if (imgui.ShowHelp == nil) then
        compat_flags.imgui_stub = true;
    end
    compat_checks_done = true;
end

-------------------------------------------------------------------------------
-- exported functions
-------------------------------------------------------------------------------
local module = {};

-- return the correct ImageSize for an icon resource
---@param icon_data table the status icon resource data as returned by GetStatusIconById()
---@return number image_size the correct image size for this icon
module.icon_size = function(icon_data)
    if (compat_flags.icon_sizes == true) then
        -- older v4 versions did not add this offset internally
        return icon_data.ImageSize + 0x0E;
    end
    return icon_data.ImageSize;
end

-- return the name of the 'buffs.names' resource table
---@return string buffs_table_name the correct table name for this v4 version
module.buffs_table = function()
    if (compat_flags.buff_table == true) then
        return 'buffs';
    end
    return 'buffs.names';
end

-- add dummy stubs for missing imgui functions
module.require_imgui = function()
    local imgui = require('imgui');
    if (compat_flags.imgui_stub == true) then
        imgui.ShowHelp = function(_, __) end;
        imgui._CompatMode = true;
    else
        imgui._CompatMode = false;
    end
    return imgui;
end

-- dump the currently active compat flags to chat
module.dump_flags = function()
    print(('compat.flags: { buff_table: %d, icon_sizes: %d, d3dx8_decls: %d, imgui_stub: %d }'):fmt(
        compat_flags.buff_table and 1 or 0,
        compat_flags.icon_sizes and 1 or 0,
        compat_flags.d3dx_decls and 1 or 0,
        compat_flags.imgui_stub and 1 or 0
    ));
end

-- return a compat info string
---@return string compat info
module.state = function()
    if (compat_flags.buff_table or compat_flags.icon_sizes or compat_flags.d3dx_decls or compat_flags.imgui_stub) then
        return ('[compat{%d%d%d%d}]'):fmt(
            compat_flags.buff_table and 1 or 0,
            compat_flags.icon_sizes and 1 or 0,
            compat_flags.d3dx_decls and 1 or 0,
            compat_flags.imgui_stub and 1 or 0
        );
    end
    return '';
end

return module;