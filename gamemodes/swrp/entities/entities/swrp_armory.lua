--[[----------------------------------------------------------------------------
	Armory crate — press E to re-equip your class loadout (weapons + ammo).

	Deliberately NOT a heal: health/armor are spawn-time values, so the armory
	can't be camped as a free medstation. Staff place it with
	`ent_create swrp_armory` (map persistence comes with event tools, Phase 5).
------------------------------------------------------------------------------]]

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_gmodentity"
ENT.PrintName = "Armory Crate"
ENT.Category  = "SWRP"
ENT.Spawnable = true
ENT.AdminOnly = true

local COOLDOWN = 5

function ENT:Initialize()
	if CLIENT then return end

	self:SetModel( "models/items/ammocrate_smg1.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetUseType( SIMPLE_USE )

	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:Wake() end
end

function ENT:Use( activator )
	if CLIENT then return end
	if not ( IsValid( activator ) and activator:IsPlayer() and activator:Alive() ) then return end

	activator._swrpArmoryNext = activator._swrpArmoryNext or 0
	if CurTime() < activator._swrpArmoryNext then return end
	activator._swrpArmoryNext = CurTime() + COOLDOWN

	if SWRP.Class and SWRP.Class.Equip and SWRP.Class.Equip( activator ) then
		self:EmitSound( "items/ammo_pickup.wav" )
		SWRP.UI.Notify( activator, true, "Loadout resupplied" )
	else
		SWRP.UI.Notify( activator, false, "No class loadout to resupply" )
	end
end
