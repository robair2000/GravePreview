-- Offline test for the bundled graveyard dataset. Not loaded by WoW.

local function Vector(x, y)
	return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end

function CreateFromMixins(mixin)
	local result = {}
	for key, value in pairs(mixin or {}) do
		result[key] = value
	end
	return result
end

MapCanvasPinMixin = {
	SetScalingLimits = function() end,
	UseFrameLevelType = function() end,
}
MapCanvasDataProviderMixin = {
	OnAdded = function(self, map) self.owningMap = map end,
	GetMap = function(self) return self.owningMap end,
}

local namespace = {}
local dataChunk = assert(loadfile("C:\\Users\\robai\\Documents\\Standaardproject\\GravePreview\\GravePreviewData.lua"))
dataChunk("GravePreview", namespace)

assert(namespace.GraveyardData, "graveyard data did not load")
print("DATA ENTRIES:", #namespace.GraveyardData)

C_Map = {
	GetBestMapForUnit = function() return 1424 end,
	GetWorldPosFromMapPos = function(mapID, mapPosition)
		local x, y = mapPosition:GetXY()
		return 0, Vector(x, y)
	end,
	GetMapPosFromWorldPos = function(continentID, worldPosition, displayMapID)
		return displayMapID, Vector(0.5, 0.5)
	end,
}
C_DeathInfo = {
	GetGraveyardsForMap = function() return {} end,
}

local unitPositionResult = { 0.5255, 0.5183, 0, 0 }
function UnitPosition() return unpack(unitPositionResult) end
function UnitFactionGroup() return "Horde" end
function CreateVector2D(x, y) return Vector(x, y) end
function GetBuildInfo() return "1.60.1", "70888", nil, 16001 end
C_Timer = { NewTicker = function() return { Cancel = function() end } end }
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
GameTooltip = { SetOwner = function() end, SetText = function() end, AddLine = function() end, Show = function() end, Hide = function() end }

local eventFrame
function CreateFrame()
	eventFrame = {
		events = {},
		RegisterEvent = function(self, event) self.events[event] = true end,
		SetScript = function(self, name, func) self[name] = func end,
	}
	return eventFrame
end

local chunk = assert(loadfile("C:\\Users\\robai\\Documents\\Standaardproject\\GravePreview\\GravePreview.lua"))
chunk("GravePreview", namespace)
eventFrame.OnEvent(eventFrame, "ADDON_LOADED", "GravePreview")

-- Standing at Southshore as Horde: the Horde graveyard Tarren Mill wins over
-- the neutral Southshore entry in the same zone.
local data = GravePreview.GetLikelyGraveyard(1424)
assert(data, "no prediction at Southshore")
assert(data.name == "Tarren Mill", "expected Tarren Mill, got " .. tostring(data.name))
print("SOUTHSHORE HORDE:", data.name, string.format("%.2f yd", data.distance))

-- Standing at Tarren Mill: Horde gets Tarren Mill, Alliance cannot.
unitPositionResult = { 0.1969, 0.6446, 0, 0 }
data = GravePreview.GetLikelyGraveyard(1424)
assert(data and data.name == "Tarren Mill", "expected Tarren Mill for Horde, got " .. tostring(data and data.name))
print("TARREN HORDE:", data.name, string.format("%.2f yd", data.distance))

UnitFactionGroup = function() return "Alliance" end
data = GravePreview.GetLikelyGraveyard(1424)
assert(data and data.name ~= "Tarren Mill", "Alliance should not be sent to Tarren Mill")
print("TARREN ALLIANCE:", data.name, string.format("%.2f yd", data.distance))

print("STATIC DATA TESTS PASSED")
