--[[
Copyright (c) 2025 Srlion (https://github.com/Srlion)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

if SERVER then
	AddCSLuaFile()
	return
end

local bit_band = bit.band
local surface_SetDrawColor = surface.SetDrawColor
local surface_SetMaterial = surface.SetMaterial
local surface_DrawTexturedRectUV = surface.DrawTexturedRectUV
local surface_DrawTexturedRect = surface.DrawTexturedRect
local render_CopyRenderTargetToTexture = render.CopyRenderTargetToTexture
local math_min = math.min
local math_max = math.max
local DisableClipping = DisableClipping
local type = type

local SHADERS_VERSION = "1779687766"
local SHADERS_GMA = [========[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]========]
do
	local DECODED_SHADERS_GMA = util.Base64Decode(SHADERS_GMA)
	if not DECODED_SHADERS_GMA or #DECODED_SHADERS_GMA == 0 then
		print("Failed to load shaders!") -- this shouldn't happen
		return
	end

	file.Write("rndx_shaders_" .. SHADERS_VERSION .. ".gma", DECODED_SHADERS_GMA)
	game.MountGMA("data/rndx_shaders_" .. SHADERS_VERSION .. ".gma")
end

local function GET_SHADER(name)
	return SHADERS_VERSION:gsub("%.", "_") .. "_" .. name
end

local BLUR_RT = GetRenderTargetEx("RNDX" .. SHADERS_VERSION .. SysTime(),
	1024, 1024,
	RT_SIZE_LITERAL,
	MATERIAL_RT_DEPTH_SEPARATE,
	bit.bor(2, 256, 4, 8 --[[4, 8 is clamp_s + clamp-t]]),
	0,
	IMAGE_FORMAT_BGRA8888
)

local NEW_FLAG; do
	local flags_n = -1
	function NEW_FLAG()
		flags_n = flags_n + 1
		return 2 ^ flags_n
	end
end

local NO_TL, NO_TR, NO_BL, NO_BR           = NEW_FLAG(), NEW_FLAG(), NEW_FLAG(), NEW_FLAG()

-- Svetov/Jaffies's great idea!
local SHAPE_CIRCLE, SHAPE_FIGMA, SHAPE_IOS = NEW_FLAG(), NEW_FLAG(), NEW_FLAG()

local BLUR                                 = NEW_FLAG()

local RNDX                                 = {}

local shader_mat                           = [==[
screenspace_general
{
	$pixshader ""
	$vertexshader ""

	$basetexture ""
	$texture1    ""
	$texture2    ""
	$texture3    ""

	// Mandatory, don't touch
	$ignorez            1
	$vertexcolor        1
	$vertextransform    1
	"<dx90"
	{
		$no_draw 1
	}

	$copyalpha                 0
	$alpha_blend_color_overlay 0
	$alpha_blend               1 // for AA
	$linearwrite               1 // to disable broken gamma correction for colors
	$linearread_basetexture    1 // to disable broken gamma correction for textures
	$linearread_texture1       1 // to disable broken gamma correction for textures
	$linearread_texture2       1 // to disable broken gamma correction for textures
	$linearread_texture3       1 // to disable broken gamma correction for textures
}
]==]

local MATRIXES                             = {}

local function create_shader_mat(name, opts)
	assert(name and isstring(name), "create_shader_mat: tex must be a string")

	local key_values = util.KeyValuesToTable(shader_mat, false, true)

	if opts then
		for k, v in pairs(opts) do
			key_values[k] = v
		end
	end

	local mat = CreateMaterial(
		"rndx_shaders1" .. name .. SysTime(),
		"screenspace_general",
		key_values
	)

	MATRIXES[mat] = Matrix()

	return mat
end

local ROUNDED_MAT = create_shader_mat("rounded", {
	["$pixshader"] = GET_SHADER("rndx_rounded_ps30"),
	["$vertexshader"] = GET_SHADER("rndx_vertex_vs30"),
})
local ROUNDED_TEXTURE_MAT = create_shader_mat("rounded_texture", {
	["$pixshader"] = GET_SHADER("rndx_rounded_ps30"),
	["$vertexshader"] = GET_SHADER("rndx_vertex_vs30"),
	["$basetexture"] = "loveyoumom", -- if there is no base texture, you can't change it later
})

local BLUR_VERTICAL = "$c0_x"
local ROUNDED_BLUR_MAT = create_shader_mat("blur_horizontal", {
	["$pixshader"] = GET_SHADER("rndx_rounded_blur_ps30"),
	["$vertexshader"] = GET_SHADER("rndx_vertex_vs30"),
	["$basetexture"] = BLUR_RT:GetName(),
	["$texture1"] = "_rt_FullFrameFB",
})

local SHADOWS_MAT = create_shader_mat("rounded_shadows", {
	["$pixshader"] = GET_SHADER("rndx_shadows_ps30"),
	["$vertexshader"] = GET_SHADER("rndx_vertex_vs30"),
})

local SHADOWS_BLUR_MAT = create_shader_mat("shadows_blur_horizontal", {
	["$pixshader"] = GET_SHADER("rndx_shadows_blur_ps30"),
	["$vertexshader"] = GET_SHADER("rndx_vertex_vs30"),
	["$basetexture"] = BLUR_RT:GetName(),
	["$texture1"] = "_rt_FullFrameFB",
})

local SHAPES = {
	[SHAPE_CIRCLE] = 2,
	[SHAPE_FIGMA] = 2.2,
	[SHAPE_IOS] = 4,
}
local DEFAULT_SHAPE = SHAPE_FIGMA
local DEFAULT_BLUR_INTENSITY = 1.0

local MATERIAL_SetTexture = ROUNDED_MAT.SetTexture
local MATERIAL_SetMatrix = ROUNDED_MAT.SetMatrix
local MATERIAL_SetFloat = ROUNDED_MAT.SetFloat
local MATRIX_SetUnpacked = Matrix().SetUnpacked

local MAT
local X, Y, W, H
local TL, TR, BL, BR
local TEXTURE
local USING_BLUR, BLUR_INTENSITY
local COL_R, COL_G, COL_B, COL_A
local SHAPE, OUTLINE_THICKNESS
local START_ANGLE, END_ANGLE, ROTATION
local CLIP_PANEL
local SHADOW_ENABLED, SHADOW_SPREAD, SHADOW_INTENSITY
local function RESET_PARAMS()
	MAT = nil
	X, Y, W, H = 0, 0, 0, 0
	TL, TR, BL, BR = 0, 0, 0, 0
	TEXTURE = nil
	USING_BLUR, BLUR_INTENSITY = false, DEFAULT_BLUR_INTENSITY
	COL_R, COL_G, COL_B, COL_A = 255, 255, 255, 255
	SHAPE, OUTLINE_THICKNESS = SHAPES[DEFAULT_SHAPE], -1
	START_ANGLE, END_ANGLE, ROTATION = 0, 360, 0
	CLIP_PANEL = nil
	SHADOW_ENABLED, SHADOW_SPREAD, SHADOW_INTENSITY = false, 0, 0
end

local normalize_corner_radii; do
	local HUGE = math.huge

	local function nzr(x)
		if x ~= x or x < 0 then return 0 end
		local lim = math_min(W, H)
		if x == HUGE then return lim end
		return x
	end

	local function clamp0(x) return x < 0 and 0 or x end

	function normalize_corner_radii()
		local TL, TR, BL, BR = nzr(TL), nzr(TR), nzr(BL), nzr(BR)

		local k = math_max(
			1,
			(TL + TR) / W,
			(BL + BR) / W,
			(TL + BL) / H,
			(TR + BR) / H
		)

		if k > 1 then
			local inv = 1 / k
			TL, TR, BL, BR = TL * inv, TR * inv, BL * inv, BR * inv
		end

		return clamp0(TL), clamp0(TR), clamp0(BL), clamp0(BR)
	end
end

local function SetupDraw()
	local TL, TR, BL, BR = normalize_corner_radii()

	local matrix = MATRIXES[MAT]
	MATRIX_SetUnpacked(
		matrix,

		BL, W, OUTLINE_THICKNESS or -1, END_ANGLE,
		BR, H, SHADOW_INTENSITY, ROTATION,
		TR, SHAPE, BLUR_INTENSITY or 1.0, 0,
		TL, TEXTURE and 1 or 0, START_ANGLE, 0
	)
	MATERIAL_SetMatrix(MAT, "$viewprojmat", matrix)

	if COL_R then
		surface_SetDrawColor(COL_R, COL_G, COL_B, COL_A)
	end

	surface_SetMaterial(MAT)
end

local MANUAL_COLOR = NEW_FLAG()
local DEFAULT_DRAW_FLAGS = DEFAULT_SHAPE

local function draw_rounded(x, y, w, h, col, flags, tl, tr, bl, br, texture, thickness)
	if col and col.a == 0 then
		return
	end

	RESET_PARAMS()

	if not flags then
		flags = DEFAULT_DRAW_FLAGS
	end

	local using_blur = bit_band(flags, BLUR) ~= 0
	if using_blur then
		return RNDX.DrawBlur(x, y, w, h, flags, tl, tr, bl, br, thickness)
	end

	MAT = ROUNDED_MAT; if texture then
		MAT = ROUNDED_TEXTURE_MAT
		MATERIAL_SetTexture(MAT, "$basetexture", texture)
		TEXTURE = texture
	end

	W, H = w, h
	TL, TR, BL, BR = bit_band(flags, NO_TL) == 0 and tl or 0,
		bit_band(flags, NO_TR) == 0 and tr or 0,
		bit_band(flags, NO_BL) == 0 and bl or 0,
		bit_band(flags, NO_BR) == 0 and br or 0
	SHAPE = SHAPES[bit_band(flags, SHAPE_CIRCLE + SHAPE_FIGMA + SHAPE_IOS)] or SHAPES[DEFAULT_SHAPE]
	OUTLINE_THICKNESS = thickness

	if bit_band(flags, MANUAL_COLOR) ~= 0 then
		COL_R = nil
	elseif col then
		COL_R, COL_G, COL_B, COL_A = col.r, col.g, col.b, col.a
	else
		COL_R, COL_G, COL_B, COL_A = 255, 255, 255, 255
	end

	SetupDraw()

	-- https://github.com/Jaffies/rboxes/blob/main/rboxes.lua
	-- fixes setting $basetexture to ""(none) not working correctly
	return surface_DrawTexturedRectUV(x, y, w, h, -0.015625, -0.015625, 1.015625, 1.015625)
end

function RNDX.Draw(r, x, y, w, h, col, flags)
	return draw_rounded(x, y, w, h, col, flags, r, r, r, r)
end

function RNDX.DrawOutlined(r, x, y, w, h, col, thickness, flags)
	return draw_rounded(x, y, w, h, col, flags, r, r, r, r, nil, thickness or 1)
end

function RNDX.DrawTexture(r, x, y, w, h, col, texture, flags)
	return draw_rounded(x, y, w, h, col, flags, r, r, r, r, texture)
end

function RNDX.DrawMaterial(r, x, y, w, h, col, mat, flags)
	local tex = mat:GetTexture("$basetexture")
	if tex then
		return RNDX.DrawTexture(r, x, y, w, h, col, tex, flags)
	end
end

function RNDX.DrawCircle(x, y, r, col, flags)
	return RNDX.Draw(r / 2, x - r / 2, y - r / 2, r, r, col, (flags or 0) + SHAPE_CIRCLE)
end

function RNDX.DrawCircleOutlined(x, y, r, col, thickness, flags)
	return RNDX.DrawOutlined(r / 2, x - r / 2, y - r / 2, r, r, col, thickness, (flags or 0) + SHAPE_CIRCLE)
end

function RNDX.DrawCircleTexture(x, y, r, col, texture, flags)
	return RNDX.DrawTexture(r / 2, x - r / 2, y - r / 2, r, r, col, texture, (flags or 0) + SHAPE_CIRCLE)
end

function RNDX.DrawCircleMaterial(x, y, r, col, mat, flags)
	return RNDX.DrawMaterial(r / 2, x - r / 2, y - r / 2, r, r, col, mat, (flags or 0) + SHAPE_CIRCLE)
end

local USE_SHADOWS_BLUR = false

local function draw_blur()
	if USE_SHADOWS_BLUR then
		MAT = SHADOWS_BLUR_MAT
	else
		MAT = ROUNDED_BLUR_MAT
	end

	COL_R, COL_G, COL_B, COL_A = 255, 255, 255, 255
	SetupDraw()

	render_CopyRenderTargetToTexture(BLUR_RT)
	MATERIAL_SetFloat(MAT, BLUR_VERTICAL, 0)
	surface_DrawTexturedRect(X, Y, W, H)

	render_CopyRenderTargetToTexture(BLUR_RT)
	MATERIAL_SetFloat(MAT, BLUR_VERTICAL, 1)
	surface_DrawTexturedRect(X, Y, W, H)
end

function RNDX.DrawBlur(x, y, w, h, flags, tl, tr, bl, br, thickness)
	RESET_PARAMS()

	if not flags then
		flags = DEFAULT_DRAW_FLAGS
	end

	X, Y = x, y
	W, H = w, h
	TL, TR, BL, BR = bit_band(flags, NO_TL) == 0 and tl or 0,
		bit_band(flags, NO_TR) == 0 and tr or 0,
		bit_band(flags, NO_BL) == 0 and bl or 0,
		bit_band(flags, NO_BR) == 0 and br or 0
	SHAPE = SHAPES[bit_band(flags, SHAPE_CIRCLE + SHAPE_FIGMA + SHAPE_IOS)] or SHAPES[DEFAULT_SHAPE]
	OUTLINE_THICKNESS = thickness

	draw_blur()
end

local function setup_shadows()
	X = X - SHADOW_SPREAD
	Y = Y - SHADOW_SPREAD
	W = W + (SHADOW_SPREAD * 2)
	H = H + (SHADOW_SPREAD * 2)

	TL = TL + (SHADOW_SPREAD * 2)
	TR = TR + (SHADOW_SPREAD * 2)
	BL = BL + (SHADOW_SPREAD * 2)
	BR = BR + (SHADOW_SPREAD * 2)
end

local function draw_shadows(r, g, b, a)
	if USING_BLUR then
		USE_SHADOWS_BLUR = true
		draw_blur()
		USE_SHADOWS_BLUR = false
	end

	MAT = SHADOWS_MAT

	if r == false then
		COL_R = nil
	else
		COL_R, COL_G, COL_B, COL_A = r, g, b, a
	end

	SetupDraw()
	-- https://github.com/Jaffies/rboxes/blob/main/rboxes.lua
	-- fixes having no $basetexture causing uv to be broken
	surface_DrawTexturedRectUV(X, Y, W, H, -0.015625, -0.015625, 1.015625, 1.015625)
end

function RNDX.DrawShadowsEx(x, y, w, h, col, flags, tl, tr, bl, br, spread, intensity, thickness)
	if col and col.a == 0 then
		return
	end

	local OLD_CLIPPING_STATE = DisableClipping(true)

	RESET_PARAMS()

	if not flags then
		flags = DEFAULT_DRAW_FLAGS
	end

	X, Y = x, y
	W, H = w, h
	SHADOW_SPREAD = spread or 30
	SHADOW_INTENSITY = intensity or SHADOW_SPREAD * 1.2

	TL, TR, BL, BR = bit_band(flags, NO_TL) == 0 and tl or 0,
		bit_band(flags, NO_TR) == 0 and tr or 0,
		bit_band(flags, NO_BL) == 0 and bl or 0,
		bit_band(flags, NO_BR) == 0 and br or 0

	SHAPE = SHAPES[bit_band(flags, SHAPE_CIRCLE + SHAPE_FIGMA + SHAPE_IOS)] or SHAPES[DEFAULT_SHAPE]

	OUTLINE_THICKNESS = thickness

	setup_shadows()

	USING_BLUR = bit_band(flags, BLUR) ~= 0

	if bit_band(flags, MANUAL_COLOR) ~= 0 then
		draw_shadows(false, nil, nil, nil)
	elseif col then
		draw_shadows(col.r, col.g, col.b, col.a)
	else
		draw_shadows(0, 0, 0, 255)
	end

	DisableClipping(OLD_CLIPPING_STATE)
end

function RNDX.DrawShadows(r, x, y, w, h, col, spread, intensity, flags)
	return RNDX.DrawShadowsEx(x, y, w, h, col, flags, r, r, r, r, spread, intensity)
end

function RNDX.DrawShadowsOutlined(r, x, y, w, h, col, thickness, spread, intensity, flags)
	return RNDX.DrawShadowsEx(x, y, w, h, col, flags, r, r, r, r, spread, intensity, thickness or 1)
end

local BASE_FUNCS; BASE_FUNCS = {
	Rad = function(self, rad)
		TL, TR, BL, BR = rad, rad, rad, rad
		return self
	end,
	Radii = function(self, tl, tr, bl, br)
		TL, TR, BL, BR = tl or 0, tr or 0, bl or 0, br or 0
		return self
	end,
	Texture = function(self, texture)
		TEXTURE = texture
		return self
	end,
	Material = function(self, mat)
		local tex = mat:GetTexture("$basetexture")
		if tex then
			TEXTURE = tex
		end
		return self
	end,
	Outline = function(self, thickness)
		OUTLINE_THICKNESS = thickness
		return self
	end,
	Shape = function(self, shape)
		SHAPE = SHAPES[shape] or 2.2
		return self
	end,
	Color = function(self, col_or_r, g, b, a)
		if type(col_or_r) == "number" then
			COL_R, COL_G, COL_B, COL_A = col_or_r, g or 255, b or 255, a or 255
		else
			COL_R, COL_G, COL_B, COL_A = col_or_r.r, col_or_r.g, col_or_r.b, col_or_r.a
		end
		return self
	end,
	Blur = function(self, intensity)
		if not intensity then
			intensity = DEFAULT_BLUR_INTENSITY
		end
		intensity = math_max(intensity, 0)
		USING_BLUR, BLUR_INTENSITY = true, intensity
		return self
	end,
	Rotation = function(self, angle)
		ROTATION = math.rad(angle or 0)
		return self
	end,
	StartAngle = function(self, angle)
		START_ANGLE = angle or 0
		return self
	end,
	EndAngle = function(self, angle)
		END_ANGLE = angle or 360
		return self
	end,
	Shadow = function(self, spread, intensity)
		SHADOW_ENABLED, SHADOW_SPREAD, SHADOW_INTENSITY = true, spread or 30, intensity or (spread or 30) * 1.2
		return self
	end,
	Clip = function(self, pnl)
		CLIP_PANEL = pnl
		return self
	end,
	Flags = function(self, flags)
		flags = flags or 0

		-- Corner flags
		if bit_band(flags, NO_TL) ~= 0 then
			TL = 0
		end
		if bit_band(flags, NO_TR) ~= 0 then
			TR = 0
		end
		if bit_band(flags, NO_BL) ~= 0 then
			BL = 0
		end
		if bit_band(flags, NO_BR) ~= 0 then
			BR = 0
		end

		-- Shape flags
		local shape_flag = bit_band(flags, SHAPE_CIRCLE + SHAPE_FIGMA + SHAPE_IOS)
		if shape_flag ~= 0 then
			SHAPE = SHAPES[shape_flag] or SHAPES[DEFAULT_SHAPE]
		end

		-- Blur flag
		if bit_band(flags, BLUR) ~= 0 then
			BASE_FUNCS.Blur(self)
		end

		-- Manual color flag
		if bit_band(flags, MANUAL_COLOR) ~= 0 then
			COL_R = nil
		end

		return self
	end,

}

local RECT = {
	Rad         = BASE_FUNCS.Rad,
	Radii       = BASE_FUNCS.Radii,
	Texture     = BASE_FUNCS.Texture,
	Material    = BASE_FUNCS.Material,
	Outline     = BASE_FUNCS.Outline,
	Shape       = BASE_FUNCS.Shape,
	Color       = BASE_FUNCS.Color,
	Blur        = BASE_FUNCS.Blur,
	Rotation    = BASE_FUNCS.Rotation,
	StartAngle  = BASE_FUNCS.StartAngle,
	EndAngle    = BASE_FUNCS.EndAngle,
	Clip        = BASE_FUNCS.Clip,
	Shadow      = BASE_FUNCS.Shadow,
	Flags       = BASE_FUNCS.Flags,

	Draw        = function(self)
		if START_ANGLE == END_ANGLE then
			return -- nothing to draw
		end

		local OLD_CLIPPING_STATE
		if SHADOW_ENABLED or CLIP_PANEL then
			-- if we are inside a panel, we need to draw outside of it
			OLD_CLIPPING_STATE = DisableClipping(true)
		end

		if CLIP_PANEL then
			local sx, sy = CLIP_PANEL:LocalToScreen(0, 0)
			local sw, sh = CLIP_PANEL:GetSize()
			render.SetScissorRect(sx, sy, sx + sw, sy + sh, true)
		end

		if SHADOW_ENABLED then
			setup_shadows()
			draw_shadows(COL_R, COL_G, COL_B, COL_A)
		elseif USING_BLUR then
			draw_blur()
		else
			if TEXTURE then
				MAT = ROUNDED_TEXTURE_MAT
				MATERIAL_SetTexture(MAT, "$basetexture", TEXTURE)
			end

			SetupDraw()
			surface_DrawTexturedRectUV(X, Y, W, H, -0.015625, -0.015625, 1.015625, 1.015625)
		end

		if CLIP_PANEL then
			render.SetScissorRect(0, 0, 0, 0, false)
		end

		if SHADOW_ENABLED or CLIP_PANEL then
			DisableClipping(OLD_CLIPPING_STATE)
		end
	end,

	GetMaterial = function(self)
		if SHADOW_ENABLED or USING_BLUR then
			error("You can't get the material of a shadowed or blurred rectangle!")
		end

		if TEXTURE then
			MAT = ROUNDED_TEXTURE_MAT
			MATERIAL_SetTexture(MAT, "$basetexture", TEXTURE)
		end
		SetupDraw()

		return MAT
	end,
}

local CIRCLE = {
	Texture = BASE_FUNCS.Texture,
	Material = BASE_FUNCS.Material,
	Outline = BASE_FUNCS.Outline,
	Color = BASE_FUNCS.Color,
	Blur = BASE_FUNCS.Blur,
	Rotation = BASE_FUNCS.Rotation,
	StartAngle = BASE_FUNCS.StartAngle,
	EndAngle = BASE_FUNCS.EndAngle,
	Clip = BASE_FUNCS.Clip,
	Shadow = BASE_FUNCS.Shadow,
	Flags = BASE_FUNCS.Flags,

	Draw = RECT.Draw,
	GetMaterial = RECT.GetMaterial,
}

local TYPES = {
	Rect = function(x, y, w, h)
		RESET_PARAMS()
		MAT = ROUNDED_MAT
		X, Y, W, H = x, y, w, h
		return RECT
	end,
	Circle = function(x, y, r)
		RESET_PARAMS()
		MAT = ROUNDED_MAT
		SHAPE = SHAPES[SHAPE_CIRCLE]
		X, Y, W, H = x - r / 2, y - r / 2, r, r
		r = r / 2
		TL, TR, BL, BR = r, r, r, r
		return CIRCLE
	end
}

setmetatable(RNDX, {
	__call = function()
		return TYPES
	end
})

-- Flags
RNDX.NO_TL = NO_TL
RNDX.NO_TR = NO_TR
RNDX.NO_BL = NO_BL
RNDX.NO_BR = NO_BR

RNDX.SHAPE_CIRCLE = SHAPE_CIRCLE
RNDX.SHAPE_FIGMA = SHAPE_FIGMA
RNDX.SHAPE_IOS = SHAPE_IOS

RNDX.BLUR = BLUR
RNDX.MANUAL_COLOR = MANUAL_COLOR

function RNDX.SetFlag(flags, flag, bool)
	flag = RNDX[flag] or flag
	if tobool(bool) then
		return bit.bor(flags, flag)
	else
		return bit.band(flags, bit.bnot(flag))
	end
end

function RNDX.SetDefaultShape(shape)
	DEFAULT_SHAPE = shape or SHAPE_FIGMA
	DEFAULT_DRAW_FLAGS = DEFAULT_SHAPE
end

function RNDX.SetDefaultBlurIntensity(val)
    DEFAULT_BLUR_INTENSITY = math_max(0, tonumber(val) or 1.0)
end

function RNDX.GetDefaultBlurIntensity()
    return DEFAULT_BLUR_INTENSITY
end


--------------------------------------------------------------------------------
-- SWRP vendoring adapter (modification to upstream, MIT terms above):
-- expose through the gamemode namespace instead of a require() return.
-- Upstream: https://github.com/Srlion/RNDX (release build, shaders embedded)
--------------------------------------------------------------------------------
SWRP.RNDX = RNDX
