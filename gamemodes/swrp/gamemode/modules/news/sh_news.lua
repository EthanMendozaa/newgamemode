--[[----------------------------------------------------------------------------
	News module (shared) — registry + config API.

	  SWRP.addNews( { title = "...", date = "12 JUN 2026", body = "..." } )
	  SWRP.addQuickLink( { label = "Discord", url = "https://...", color = Color(88,101,242) } )

	Posts render in declaration order — put the NEWEST post at the TOP of
	news.lua. Re-registration (config reload) is keyed by lowercased title/label,
	same pattern as ranks/lore. Validation: FPtje-grade, never crashes.
------------------------------------------------------------------------------]]

SWRP.News = SWRP.News or {}
local News   = SWRP.News
local Config = SWRP.Config
local log    = SWRP.Logger( "News" )

News.Posts      = News.Posts or {}        -- lower(title) -> post
News.QuickLinks = News.QuickLinks or {}   -- lower(label) -> link

local POST_SCHEMA = {
	title = { type = "string", required = true, max = 96 },
	date  = { type = "string", default = "",   max = 24 },
	body  = { type = "string", default = "",   max = 1200 },
}

local LINK_SCHEMA = {
	label = { type = "string", required = true, max = 32 },
	url   = { type = "string", required = true, max = 256,
		validate = function( v ) return string.match( v, "^https?://" ) ~= nil, "must start with http:// or https://" end },
	color = { type = "color",  default = nil },
}

local function register( registry, def, schema, what )
	-- Level 3: config file -> addNews/addQuickLink -> register -> Where.
	-- Blames the config file's line, not this module.
	local src = Config.Where( 3 )
	local res, errs = SWRP.Validate( def, schema, { label = what .. " field", source = src } )
	for _, e in ipairs( errs ) do log.Warn( e ) end

	local keyField = schema.title and "title" or "label"
	local key = res[ keyField ]
	if not isstring( key ) then
		log.Error( "%s: add%s needs a %s", src or "?",
			what == "news" and "News" or "QuickLink", keyField )
		return
	end

	-- A required field that failed validation resolved to nil — keep the
	-- registry free of half-valid entries (never-crash config philosophy).
	for field, fdef in pairs( schema ) do
		if fdef.required and res[ field ] == nil then
			log.Error( "%s: %s '%s' dropped — required field '%s' is missing or invalid",
				src or "?", what, tostring( key ), field )
			return
		end
	end

	key = string.lower( key )

	-- Stable declaration order across config reloads (re-register keeps seq).
	local existing = registry[ key ]
	News._seq = ( News._seq or 0 ) + ( existing and 0 or 1 )
	res.seq   = existing and existing.seq or News._seq
	registry[ key ] = res
end

function SWRP.addNews( def )      register( News.Posts,      def, POST_SCHEMA, "news" ) end
function SWRP.addQuickLink( def ) register( News.QuickLinks, def, LINK_SCHEMA, "quick link" ) end

local function ordered( registry )
	local out = {}
	for _, v in pairs( registry ) do out[ #out + 1 ] = v end
	table.sort( out, function( a, b ) return a.seq < b.seq end )
	return out
end

function News.OrderedPosts() return ordered( News.Posts ) end
function News.OrderedLinks() return ordered( News.QuickLinks ) end
