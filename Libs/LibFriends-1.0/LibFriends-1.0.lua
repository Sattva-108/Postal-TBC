local MAJOR_VERSION = "LibFriends-1.0"
local MINOR_VERSION = tonumber(("$Revision: 75755 $"):match("%d+")) or 0

local lib, oldMinor = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

local BC, BZ
local _G = _G
local ShowFriends = ShowFriends
local select = select
local next = next

local new, del
do
	local cache = {}
	function new(...)
		local t = next(cache)
		if t then
			cache[t] = nil
			for i = 1, select('#', ...) do
				t[i] = select(i, ...)
			end
			return t
		else
			return { ... }
		end
	end
	
	function del(t)
		for k in pairs(t) do
			t[k] = nil
		end
		cache[t] = true
		return nil
	end
end

local frame
if lib.frame then
	frame = lib.frame
	frame:UnregisterAllEvents()
	frame:SetScript("OnEvent", nil)
	frame:SetScript("OnUpdate", nil)
else
	frame = CreateFrame("Frame", MAJOR_VERSION .. "_Frame")
	lib.frame = frame
end

frame:SetScript("OnEvent", function(this, event, ...)
	this[event](lib, ...)
end)

local timeSoFar = 0
frame:SetScript("OnUpdate", function(this, timeSinceLast)
	timeSoFar = timeSoFar + timeSinceLast
	if timeSoFar > 15 then
		timeSoFar = 0
		ShowFriends()
	end
end)

local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0")
if lib.callbacks then
	lib:UnregisterAll(lib)
else
	lib.callbacks = LibStub("CallbackHandler-1.0"):New(lib, nil, nil, "UnregisterAll")
end

frame:RegisterEvent("FRIENDLIST_UPDATE")

local players = {}
local playersOnline = {}
local playerLevels = {}
local playerClasses = {}
local playerZones = {}
local playerStatuses = {}
local numPlayersOnline = 0
local numPlayersTotal = 0
local firstScanDone = false

local playersOnlineOld, playersOld, playerLevelsOld = {}, {}, {}
function frame:FRIENDLIST_UPDATE()
	playersOnline, playersOnlineOld = playersOnlineOld, playersOnline -- for signon/off events
	players, playersOld = playersOld, players -- for add/remove events
	playerLevels, playerLevelsOld = playerLevelsOld, playerLevels -- for ding events
	numPlayersOnline = 0
	numPlayersTotal = GetNumFriends()
	
	for i = 1, numPlayersTotal do
		local name, level, class, zone, online, status = GetFriendInfo(i)
		local add, connect, ding
		if name then
			if status == "" then
				status = nil
			end
			players[name] = true
			playerLevels[name] = level or 0 -- note: 0 if offline
			playerClasses[name] = class or UNKNOWN
			playerZones[name] = zone or UNKNOWN
			playerStatuses[name] = status
			if playersOld[name] then
				playersOld[name] = nil
				if online and playerLevelsOld[name] and playerLevelsOld[name] > 0 and playerLevelsOld[name] < level then
					ding = true
				end
				playerLevelsOld[name] = nil
			else
				add = true
			end
		end
		if online then
			numPlayersOnline = numPlayersOnline + 1
			if name then
				playersOnline[name] = true
				if playersOnlineOld[name] then
					playersOnlineOld[name] = nil
				elseif playersOld[name] then
					connect = true
				end
			end
		end
		if firstScanDone then
			if add then
				lib.callbacks:Fire("Added", name)
			end
			if connect then
				lib.callbacks:Fire("Connected", name)
			end
			if ding then
				lib.callbacks:Fire("LevelUp", name, level)
			end
		end
	end
	for k in pairs(playersOld) do
		playersOld[k] = nil
		lib.callbacks:Fire("Removed", k)
	end
	for k in pairs(playersOnlineOld) do
		playersOnlineOld[k] = nil
		lib.callbacks:Fire("Disconnected", k)
	end
	for k in pairs(playerLevelsOld) do
		playerLevelsOld[k] = nil
	end
	
	lib.callbacks:Fire("Update")
	firstScanDone = true
end

function lib:GetNumOnline()
	return numPlayersOnline
end

function lib:GetNumTotal()
	return numPlayersTotal
end

function lib:HasFriend(name)
	return players[name] and true or false
end

function lib:IsFriendOnline(name)
	return playersOnline[name] or false
end

function lib:GetLevel(name)
	return playerLevels[name]
end

function lib:GetClass(name)
	return playerClasses[name]
end

function lib:GetEnglishClass(name)
	if not BC then BC = LibStub("LibBabble-Class-3.0"):GetReverseLookupTable() end
	local class = playerClasses[name]
	if class then
		return BC[class]
	else
		return nil
	end
end

function lib:GetClassColor(name)
	local class = self:GetEnglishClass(name)
	if class then
		local c = RAID_CLASS_COLORS[class:upper()]
		return c.r, c.g, c.b
	else
		return 0.8, 0.8, 0.8
	end
end

function lib:GetClassHexColor(name)
	local class = self:GetEnglishClass(name)
	if class then
		local c = RAID_CLASS_COLORS[class:upper()]
		return ("%02X%02X%02X"):format(c.r*255, c.g*255, c.b*255)
	else
		return "cccccc"
	end
end

function lib:GetZone(name)
	return playerZones[name]
end

function lib:GetEnglishZone(name)
	if not BZ then BZ = LibStub("LibBabble-Zone-3.0"):GetReverseLookupTable() end
	local zone = playerZones[name]
	if zone ~= UNKNOWN then
		return BZ[zone]
	else
		return "Unknown"
	end
end

function lib:GetStatus(name)
	return playerStatuses[name]
end

local sorts; sorts = {
	NAME = function(a,b)
		return a < b
	end,
	LEVEL = function(a,b)
		if playerLevels[a] == playerLevels[b] then
			return sorts.NAME(a,b)
		else
			return playerLevels[a] < playerLevels[b]
		end
	end,
	CLASS = function(a,b)
		if playerClasses[a] == playerClasses[b] then
			return sorts.LEVEL(a,b)
		else
			return playerClasses[a] < playerClasses[b]
		end
	end,
	ZONE = function(a,b)
		if playerZones[a] == playerZones[b] then
			return sorts.CLASS(a,b)
		else
			return playerZones[a] < playerZones[b]
		end
	end,
	ONLINE = function(a,b)
		if playersOnline[a] == playersOnline[b] then
			return sorts.CLASS(a,b)
		else
			return connected[a] --1 or nil, you see.
		end
	end,
}

local iter = function(t)
	local n = t.n + 1
	t.n = n
	return t[n] or del(t)
end
function lib:GetIterator(sort, includeOffline)
	local sortFunc = sorts[sort or "NAME"]
	if not sortFunc then
		error('Argument #2 must be "NAME", "LEVEL", "CLASS", "ZONE", "ONLINE", or nil.')
	end
	
	local tmp = new()
	for k in pairs(includeOffline and players or playersOnline) do
		tmp[#tmp+1] = k
	end
	
	table.sort(tmp, sortFunc)
	tmp.n = 0
	
	return iter, tmp, nil
end

