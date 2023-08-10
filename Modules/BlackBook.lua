--[[ Postal_BlackBook: Adds a popup contact list when you mouseover the To: field. ]]--

assert( Postal, "Postal not found!")

------------------------------
--      Are you local?      --
------------------------------

local dewdrop = AceLibrary("Dewdrop-2.0")
local L = AceLibrary("AceLocale-2.2"):new("Postal")
local friends = LibStub("LibFriends-1.0")

local Postal_BlackBookButton
local sorttable = {}
local ignoresortlocale = {
	["koKR"] = true,
	["zhCN"] = true,
	["zhTW"] = true,
}

local enableAltsMenu = true
----------------------------------
--      Module Declaration      --
----------------------------------

Postal_BlackBook = Postal:NewModule("BlackBook")
Postal_BlackBook.defaults = {
	contacts = {}
}

Postal_BlackBook.revision = tonumber(string.sub("$Revision: 79759 $", 12, -3))

function Postal_BlackBook:OnEnable()
	if not Postal_BlackBookButton then
		-- Create the Menu Button
		Postal_BlackBookButton = CreateFrame("Button", "Postal_BlackBookButton", SendMailFrame);
		Postal_BlackBookButton:SetWidth(25);
		Postal_BlackBookButton:SetHeight(25);
		Postal_BlackBookButton:SetPoint("LEFT", SendMailNameEditBox, "RIGHT", -2, 0);
		Postal_BlackBookButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up");
		Postal_BlackBookButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Round");
		Postal_BlackBookButton:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled");
		Postal_BlackBookButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down");
		dewdrop:Register(Postal_BlackBookButton,
			"children", function(level, value) Postal_BlackBook:Populate(level, value) end,
			"point", function(parent) return "TOPRIGHT", "BOTTOMRIGHT" end,
			"dontHook", true
		)
		Postal_BlackBookButton:SetScript("OnClick", function(self)
			if dewdrop:IsOpen(self) then
				dewdrop:Close()
			else
				dewdrop:Open(self)
			end
		end)
		Postal_BlackBookButton:SetScript("OnHide", function()
			if dewdrop:IsOpen(self) then
				dewdrop:Close()
			end
		end)
	end
	self:RegisterEvent("MAIL_SHOW")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "AddAlt")
	-- For enabling after a disable
	Postal_BlackBookButton:Show()
end

function Postal_BlackBook:OnDisable()
	--self:Reset()	-- Disabling modules unregisters all events/hook automatically
	Postal_BlackBookButton:Hide()
end

function Postal_BlackBook:MAIL_SHOW()
	self:RegisterEvent("MAIL_CLOSED", "Reset")
	self:RegisterEvent("PLAYER_LEAVING_WORLD", "Reset")
end

function Postal_BlackBook:Reset()
	dewdrop:Close()
	self:UnregisterEvent("MAIL_CLOSED")
	self:UnregisterEvent("PLAYER_LEAVING_WORLD")
end

function Postal_BlackBook:AddAlt()
	--local realm = GetRealmName()
	local faction = UnitFactionGroup("player")
	local player = UnitName("player")
	local level = UnitLevel("player")
	local lclass, class = UnitClass("player")
	--if not realm or not faction or not player or not level or not class then return end
	if not faction or not player or not level or not class then return end
	local namestring = ("%s|%s|%s|%s|%s"):format(player, faction, level, class, lclass)
	local db = Postal.db.profile.BlackBook.alts
	enableAltsMenu = false
	for i = #db, 1, -1 do
		local p, f, l, c, lc = strsplit("|", db[i])
		lc = lc or UNKNOWN
		if p == player and f == faction then
			tremove(db, i)
		end
		if p ~= player and f == faction then
			enableAltsMenu = true
		end
	end
	tinsert(db, namestring)
	table.sort(db)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self.AddAlt = nil -- Kill ourselves so we only run it once
end

function Postal_BlackBook.DeleteAlt(dropdownbutton, arg1, arg2, checked)
	--local realm = GetRealmName()
	local faction = UnitFactionGroup("player")
	local player = UnitName("player")
	local db = Postal.db.profile.BlackBook.alts
	enableAltsMenu = false
	for i = #db, 1, -1 do
		if arg1 == db[i] then
			tremove(db, i)
		else
			local p, f = strsplit("|", db[i])
			if f == faction and p ~= player then
				enableAltsMenu = true
			end
		end
	end
	CloseDropDownMenus()
end

local function SetSendMailName(name)
	SendMailNameEditBox:SetText(name)
	dewdrop:Close()
end

function Postal_BlackBook:AddContact()
	local name = strtrim(SendMailNameEditBox:GetText())
	if name == "" then return end
	local db = self.db.char.contacts
	for k = 1, #db do
		if name == db[k] then return end
	end
	tinsert(db, name)
	table.sort(db)
end

function Postal_BlackBook:RemoveContact()
	local name = strtrim(SendMailNameEditBox:GetText())
	if name == "" then return end
	local db = self.db.char.contacts
	for k = 1, #db do
		if name == db[k] then tremove(db, k) return end
	end
end

function Postal_BlackBook:Populate(level, value)
	if level == 1 then
		local db = self.db.char.contacts
		dewdrop:AddLine("text", L["Contacts"], "isTitle", true)
		for k = 1, #db do
			dewdrop:AddLine(
				"text", db[k],
				"func", SetSendMailName,
				"arg1", db[k]
			)
		end
		dewdrop:AddLine()
		dewdrop:AddLine(
			"text", L["Add Contact"],
			"func", self.AddContact,
			"arg1", self
		)
		dewdrop:AddLine(
			"text", L["Remove Contact"],
			"func", self.RemoveContact,
			"arg1", self
		)
		dewdrop:AddLine()
		dewdrop:AddLine("text",  L["Alts"], "hasArrow", true, "value", "alts" )
		dewdrop:AddLine("text", L["Friends"], "hasArrow", true, "value", "friend" )
		dewdrop:AddLine("text",  L["Guild"], "hasArrow", true, "value", "guild" )
	elseif level == 2 then
		if value == "friend" then
			local numFriends = GetNumFriends()
			for i = 1, numFriends do
				local name, level, lclass = GetFriendInfo(i);

				local class;
				if friends:GetEnglishClass(name) then
					class = (friends:GetEnglishClass(name)):upper() or UNKNOWN
				else
					if lclass then class = lclass else class = UNKNOWN end
				end

				local namestring = ("%s|%s|%s|%s"):format(name, level, class, lclass)
				--sorttable[i] = GetFriendInfo(i)
				sorttable[i] = namestring
			end
			for i = #sorttable, numFriends+1, -1 do
				sorttable[i] = nil
			end
			if not ignoresortlocale[GetLocale()] then table.sort(sorttable) end
			if numFriends > 0 and numFriends <= 25 then
				for i = 1, numFriends do
					local p, l, c, cl = strsplit("|", sorttable[i])
					local clr = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[c] or RAID_CLASS_COLORS[c] or {r=1,g=1,b=1}
					local ptext = format("%s |cff%.2x%.2x%.2x(%d %s)|r", p, clr.r*255, clr.g*255, clr.b*255, l, cl)
					--local name = sorttable[i]
					dewdrop:AddLine(
						"text", ptext,
						"func", SetSendMailName,
						"arg1", p
					)
				end
			elseif numFriends > 25 then
				-- More than 25 people, split the list into multiple sublists of 25
				local num = 0
				for i = 1, numFriends, 25 do
					num = num + 1
					dewdrop:AddLine("text", L["Part %d"]:format(num), "hasArrow", true, "value", "fpart"..num )
				end
			end
		elseif value == "guild" then
			local numFriends = GetNumGuildMembers(true)
			for i = 1, numFriends do
				-- updated by fuba
				--local name, rank = GetGuildRosterInfo(i)
				--sorttable[i] = name.." |cffffd200("..rank..")|r"
				local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName, achievementPoints, achievementRank, isMobile, canSoR = GetGuildRosterInfo(i)
				local c = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFileName] or RAID_CLASS_COLORS[classFileName] or {r=1,g=1,b=1}
				sorttable[i] = format("%s |cffffd200(%s)|r |cff%.2x%.2x%.2x(%d %s)|r", name, rank, c.r*255, c.g*255, c.b*255, level, class)
			end
			for i = #sorttable, numFriends+1, -1 do
				sorttable[i] = nil
			end
			if not ignoresortlocale[GetLocale()] then table.sort(sorttable) end
			if numFriends > 0 and numFriends <= 25 then
				for i = 1, numFriends do
					dewdrop:AddLine(
						"text", sorttable[i],
						"func", SetSendMailName,
						"arg1", strmatch(sorttable[i], "(.*) |cffffd200")
					)
				end
			elseif numFriends > 25 then
				-- More than 25 people, split the list into multiple sublists of 25
				local num = 0
				for i = 1, numFriends, 25 do
					num = num + 1
					dewdrop:AddLine("text", L["Part %d"]:format(num), "hasArrow", true, "value", "gpart"..num )
				end
			end
		elseif value == "alts" then
			-- Add Alts here (added by fuba for 2.4.3)
			if not enableAltsMenu then return end
			local db = Postal.db.profile.BlackBook.alts
			local realm = GetRealmName()
			local faction = UnitFactionGroup("player")
			local player = UnitName("player")

			for i = 1, #db do
				local p, f, l, c, lc = strsplit("|", db[i])
				lc = lc or UNKNOWN
				if f == faction and p ~= player then
					if l and c then
						local clr = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[c] or RAID_CLASS_COLORS[c] or {r=1,g=1,b=1}
						local ptext = format("%s |cff%.2x%.2x%.2x(%d %s)|r", p, clr.r*255, clr.g*255, clr.b*255, l, lc)
						dewdrop:AddLine(
							"text", ptext,
							"func", SetSendMailName,
							"arg1", p
						)
					else
						dewdrop:AddLine(
							"text", p,
							"func", SetSendMailName,
							"arg1", p
						)
					end
				end
			end

		end
	elseif level == 3 then
		if type(value) == "string" then
			if strfind(value, "fpart") then
				local startIndex = tonumber(strmatch(value, "fpart(%d+)")) * 25 - 24
				local endIndex = min(startIndex+24, GetNumFriends())
				for i = startIndex, endIndex do
					local name = sorttable[i]
					dewdrop:AddLine(
						"text", name,
						"func", SetSendMailName,
						"arg1", name
					)
				end
			elseif strfind(value, "gpart") then
				local startIndex = tonumber(strmatch(value, "gpart(%d+)")) * 25 - 24
				local endIndex = min(startIndex+24, GetNumGuildMembers(true))
				for i = startIndex, endIndex do
					dewdrop:AddLine(
						"text", sorttable[i],
						"func", SetSendMailName,
						"arg1", strmatch(sorttable[i], "(.*) |cffffd200")
					)
				end
			end
		end
	end
end