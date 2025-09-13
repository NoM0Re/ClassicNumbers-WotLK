-- LIBS --
local AceAddon = LibStub("AceAddon-3.0");
local LibEasing = LibStub("LibEasing-1.0");
local SharedMedia = LibStub("LibSharedMedia-3.0");
local ACD = LibStub("AceConfigDialog-3.0")

ClassicNumbers = AceAddon:NewAddon("ClassicNumbers", "AceConsole-3.0", "AceEvent-3.0");
ClassicNumbers.frame = CreateFrame("Frame", nil, UIParent);

-- LOCALS --
local animating = {}

local playerGUID;
local unitToGuid = {};
local guidToUnit = {};

local soundChannels = {
  ["Dialog"] = "Dialog",
  ["Ambience"] = "Ambience",
  ["Music"] = "Music",
  ["SFX"] = "SFX",
};

-- DB --
local defaultFont = "Friz Quadrata TT";

local defaults = {
    global = {
        enabled = true,
		useLegacyOverlapHandler = false;
        font = defaultFont,
        truncate = false,
        commaSeperate = false,
		size = 28,
		critSize = 56,
		maxCritNumbersPerTarget = 4,
		normalHitsAlpha = 1,
		critsAlpha = 1,
		nonCritsOffsetX = 0,
		critsOffsetX = 0,
		nonCritsOffsetY = 0,
		critsOffsetY = 0,
		smallHitsFilter = 0,
		smallCritsFilter = 0,
        defaultColor = "ffffff",
        defaultAbilityColor = "FFEE00",
		nonCritAnimationDuration = 1.25,
		critAnimationDuration = 2,
		scrollSpeed = 1,
		scrollDistance = 50,
		useDamageSchoolColors = false,
		hideNonCritsIfBigCritChain = true,
		displayBiggestCritInCenterOfTheChain = false,
		biggestCritDisplaysLargerThanOtherOnes = false,
		critSoundEnabled = false,
		critSoundChannel = soundChannels["Dialog"],
		critSoundThreshold = 10000,
		hugeCritSoundEnabled = false,
		hugeCritSoundChannel = "Dialog",
		hugeCritSoundThreshold = 100000,
		monsterCritSoundEnabled = false,
		monsterCritSoundChannel = "Dialog",
		monsterCritSoundThreshold = 1000000,
    },
};

-- CONSTANTS --
local DAMAGE_TYPE_COLORS = {
    [1] = "FFEE00", --physical
    [2] = "FFE680", -- holy
    [4] = "FF8000", --fire
    [8] = "4DFF4D", --nature
    [16] = "80FFFF", --frost
    [32] = "8080FF", --shadow
    [64] = "FF80FF", --arcane
	[4 + 16 + 64 + 8 + 32] = "A330C9",
	[4 + 16 + 64 + 8 + 32 + 2] = "A330C9",
	[1 + 4 + 16 + 64 + 8 + 32 + 2] = "A330C9",
	["melee"] = "FFFFFF",
	["pet"] = "CC8400"
};

-- FONTSTRING --
local function getFontPath(fontName)
    local fontPath = SharedMedia:Fetch("font", fontName);

    if (fontPath == nil) then
        fontPath = "Fonts\\FRIZQT__.TTF";
    end

    return fontPath;
end


local fontStringCache = {};

local function getFontString()
    local fontString;

    if (next(fontStringCache)) then
        fontString = table.remove(fontStringCache);
    else
        fontString = ClassicNumbers.frame:CreateFontString();
    end

    fontString:SetParent(ClassicNumbers.frame);
    fontString:SetFont(getFontPath(ClassicNumbers.db.global.font), 15);
    fontString:SetShadowOffset(2,-2)
    fontString:SetAlpha(1);
    fontString:SetDrawLayer("BACKGROUND", -1);
    fontString:SetText("");
    fontString:Show();

	fontString.hasBeenPlaced = false;
	fontString.offsetX = 0;
	fontString.offsetY = 0;
	fontString.isCritNumber = {};
	fontString.fontHeight = 10;
	fontString.textWidth = 10;
	fontString.amount = 0;
	fontString.critsAlpha = 1;
	fontString.normalHitsAlpha = 1;
	fontString.maxCritNumbersPerTarget = 4;
	fontString.critsOffsetX = 0;
	fontString.critsOffsetY = 0;
	fontString.nonCritsOffsetX = 0;
	fontString.nonCritsOffsetY = 0;
	fontString.nonCritAnimationDuration = 1.25;
	fontString.critAnimationDuration = 2;
	fontString.scrollSpeed = 1
	fontString.scrollDistance = 40;
	fontString.hideNonCritsIfBigCritChain = true;
	fontString.displayBiggestCritInCenterOfTheChain = false;
	fontString.biggestCritDisplaysLargerThanOtherOnes = false;

    return fontString;
end

local function recycleFontString(fontString)
    fontString:SetAlpha(0);
    fontString:Hide();

    animating[fontString] = nil;

	fontString.hasBeenPlaced = nil;
	fontString.offsetX = nil;
	fontString.offsetY = nil;
	fontString.offsetY2 = nil;
	fontString.isCritNumber = nil;
	fontString.fontHeight = nil;
	fontString.textWidth = nil;
	fontString.amount = nil;
	fontString.critsAlpha = nil;
	fontString.normalHitsAlpha = nil;
	fontString.maxCritNumbersPerTarget = nil;
	fontString.critsOffsetX = nil;
	fontString.critsOffsetY = nil;
	fontString.nonCritsOffsetX = nil;
	fontString.nonCritsOffsetY = nil;
	fontString.nonCritAnimationDuration = nil;
	fontString.critAnimationDuration = nil;
	fontString.scrollSpeed = nil;
	fontString.scrollDistance = nil;
	fontString.hideNonCritsIfBigCritChain = nil;
	fontString.displayBiggestCritInCenterOfTheChain = nil;
	fontString.biggestCritDisplaysLargerThanOtherOnes = nil;

    fontString.animatingStartTime = nil;
    fontString.anchorFrame = nil;

    fontString.unit = nil;

    fontString.pow = nil;
	fontString.isCritical = nil;
    fontString.startHeight = nil;
    fontString.fontSize = nil;
	fontString:ClearAllPoints();

    table.insert(fontStringCache, fontString);
end

-- CORE --
function ClassicNumbers:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("ClassicNumbersDB", defaults, true);

    self:RegisterChatCommand("classicnumbers", "OpenMenu");
    self:RegisterChatCommand("classicnumber", "OpenMenu");
    self:RegisterChatCommand("cn", "OpenMenu");

    self:RegisterMenu();

    if (self.db.global.enabled == false) then
        self:Disable();
    end
end


function ClassicNumbers:OnEnable()
    playerGUID = UnitGUID("player");

    self:RegisterEvent("NAME_PLATE_UNIT_ADDED");
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED");
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");

    self.db.global.enabled = true;
end

function ClassicNumbers:OnDisable()
    self:UnregisterAllEvents();

    for fontString, _ in pairs(animating) do
        recycleFontString(fontString);
    end

    self.db.global.enabled = false;
end

-- ANIMATION --
local function powSizing(elapsed, duration, start, middle, finish)
    local size = finish;
    if (elapsed < duration) then
        if (elapsed/duration < 0.1) then
            size = LibEasing.OutCirc(elapsed, start, middle - start, duration/2);
        else
            size = LibEasing.InCirc(elapsed - elapsed/2, middle, finish - middle, duration/2);
        end
    end
    return size;
end

local function AnimationOnUpdate()
	local animationDuration = 1;
    if (next(animating)) then

        for fontString, _ in pairs(animating) do
            local elapsed = GetTime() - fontString.animatingStartTime;
			if (fontString.pow) then
				animationDuration = fontString.critAnimationDuration;
			else
				animationDuration = fontString.nonCritAnimationDuration;
			end
            if (elapsed > animationDuration) then
                -- the animation is over
                recycleFontString(fontString);
            else
                local isTarget = false
                if fontString.unit then
                  isTarget = UnitIsUnit(fontString.unit, "target");
                else
                  fontString.unit = "player"
                end

                local alpha = 0;
				if (elapsed/animationDuration < 0.3) then
					if fontString.pow then
						alpha = LibEasing.OutQuint(elapsed, 0, fontString.critsAlpha, animationDuration*0.3);
					else
						alpha = LibEasing.OutQuint(elapsed, 0, fontString.normalHitsAlpha, animationDuration*0.3);
					end
				else
					if fontString.pow then
						alpha = LibEasing.InExpo(elapsed, fontString.critsAlpha, -fontString.critsAlpha, animationDuration);
					else
						alpha = LibEasing.InExpo(elapsed, fontString.normalHitsAlpha, -fontString.normalHitsAlpha, animationDuration);
					end
				end

				fontString:SetAlpha(alpha);

                -- crit size animation
                if (fontString.pow) then
                    if (elapsed < 0.2) then
                        local size = powSizing(elapsed, 0.2, fontString.startHeight/2, fontString.startHeight*2, fontString.startHeight);

						fontString:SetTextHeight(size);
						fontString.fontHeight = size;
                    else
						local size = powSizing(elapsed, 0.2, fontString.startHeight/2, fontString.startHeight*2, fontString.startHeight);

                        fontString:SetTextHeight(size);
                        fontString:SetText(fontString.text);
                    end
                end

				local newestCrit = GetNewestCrit(fontString.anchorFrame);
				if (newestCrit ~= nil and fontString.isCritNumber[fontString.anchorFrame] ~= nil) then
					-- handle crit position
					if (fontString.isCritNumber[fontString.anchorFrame] == 1) then
						fontString.offsetX = 0
						fontString.offsetY = -40
						if fontString.maxCritNumbersPerTarget < 1 then
							fontString:SetAlpha(0);
						end
					elseif (fontString.isCritNumber[fontString.anchorFrame] == 2) then
						fontString.offsetX = newestCrit.textWidth + newestCrit.fontHeight + 9
						fontString.offsetY = -40
						if fontString.maxCritNumbersPerTarget < 2 then
							fontString:SetAlpha(0);
						end
					elseif (fontString.isCritNumber[fontString.anchorFrame] == 3) then
						fontString.offsetX = -newestCrit.textWidth - newestCrit.fontHeight - 9
						fontString.offsetY = -40
						if fontString.maxCritNumbersPerTarget < 3 then
							fontString:SetAlpha(0);
						end
					elseif (fontString.isCritNumber[fontString.anchorFrame] == 4) then
						fontString.offsetX = 0
						fontString.offsetY = newestCrit.offsetY + newestCrit.fontHeight + 9;
						if fontString.maxCritNumbersPerTarget < 4 then
							fontString:SetAlpha(0);
						end
					elseif (fontString.isCritNumber[fontString.anchorFrame] == 5) then
						fontString.offsetX = 0
						fontString.offsetY = newestCrit.offsetY - newestCrit.fontHeight - 9;
						if fontString.maxCritNumbersPerTarget < 5 then
							fontString:SetAlpha(0);
						end
					elseif (fontString.isCritNumber[fontString.anchorFrame] > 5) then
						fontString:SetAlpha(0);
					end
				end

				-- handle non crit
				if (not fontString.pow) then
					if (not fontString.hasBeenPlaced) then
						fontString.offsetY = 20
					end

					-- disappear if lots of crits
					if (GetFourthCrit(fontString.anchorFrame) ~= nil and fontString.hideNonCritsIfBigCritChain) then
						fontString:SetAlpha(0)
					end


					-- non crit position
					local closestFontStringY = GetClosestDamageNumberYValueFrom(fontString);

					if closestFontStringY ~= nil and elapsed < 0.1 then
						local differenceFromClosest = math.abs(fontString.offsetY - closestFontStringY.offsetY)
						if (differenceFromClosest < 30) then
							if (fontString.offsetX == 0 and closestFontStringY.offsetX == 0) then
								fontString.offsetX = 80
							elseif (fontString.offsetX == 80 and closestFontStringY.offsetX == 80) then
								fontString.offsetX = -80
						end
							if (fontString.offsetY2 ~= 0 and fontString.offsetX == -80 and closestFontStringY.offsetX == -80) then
								closestFontStringY.offsetY2 = LibEasing.OutQuad(1.1, 20, fontString.scrollDistance, animationDuration)
								closestFontStringY.offsetX = math.random(-1, 1) * 80
							end
						end
					end
					if (fontString.offsetY2 ~= nil) then
						fontString.offsetY = LibEasing.OutQuad(elapsed, 20, fontString.scrollDistance, animationDuration) + fontString.offsetY2;
					else
						fontString.offsetY = LibEasing.OutQuad(elapsed, 20, fontString.scrollDistance, animationDuration)
					end
				end

                if (fontString.anchorFrame and fontString.anchorFrame:IsShown()) then
					if (fontString.pow) then
						fontString:SetPoint("CENTER", fontString.anchorFrame, "CENTER", fontString.offsetX + fontString.critsOffsetX, fontString.offsetY + fontString.critsOffsetY);
					else
						fontString:SetPoint("CENTER", fontString.anchorFrame, "CENTER", fontString.offsetX + fontString.nonCritsOffsetX, fontString.offsetY + fontString.nonCritsOffsetY);
					end
					fontString.hasBeenPlaced = true;
				else
                    recycleFontString(fontString);
                end
            end
        end
    else
        -- nothing in the animation list, so just kill the onupdate
        ClassicNumbers.frame:SetScript("OnUpdate", nil);
    end
end

function ClassicNumbers:Animate(fontString, anchorFrame, animation)
    fontString.animatingStartTime = GetTime();
    fontString.anchorFrame = anchorFrame == player and UIParent or anchorFrame;

	if ((fontString.pow and self.db.global.critSize > 0) or (not fontString.pow and self.db.global.size > 0)) then
		animating[fontString] = true;
	end

	if (fontString.pow) then
		fontString.isCritNumber[fontString.anchorFrame] = 0;
		OffsetCritIndexes(fontString.anchorFrame, 1, false);
	end

    -- start onupdate if it's not already running
    if (ClassicNumbers.frame:GetScript("OnUpdate") == nil) then
        ClassicNumbers.frame:SetScript("OnUpdate", AnimationOnUpdate);
    end
end


-- EVENTS --
function ClassicNumbers:NAME_PLATE_UNIT_ADDED(event, unitID)
    local guid = UnitGUID(unitID);

    unitToGuid[unitID] = guid;
    guidToUnit[guid] = unitID;
end

function ClassicNumbers:NAME_PLATE_UNIT_REMOVED(event, unitID)
    local guid = unitToGuid[unitID];

    unitToGuid[unitID] = nil;
    guidToUnit[guid] = nil;

	for fontString, _ in pairs(animating) do
		if fontString.unit == unitID then
			recycleFontString(fontString);
		end
    end
end

function ClassicNumbers:CombatFilter(clue, sourceGUID, sourceFlags, destGUID, destFlags, ...)
    if playerGUID == sourceGUID or (ClassicNumbers.db.global.personal and playerGUID == destGUID) then
        local destUnit = guidToUnit[destGUID]
        if destUnit or (destGUID == playerGUID and ClassicNumbers.db.global.personal) then
            if clue:find("_DAMAGE") then
                local spellID, spellName, spellSchool
                local amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing

                if clue:find("SWING") then
                    -- SWING_DAMAGE:
                    -- amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing
                    spellName, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = "ranged", ...;
                elseif clue:find("ENVIRONMENTAL") then
                    -- ENVIRONMENTAL_DAMAGE:
                    -- envType, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing
                    local envType
                    envType, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = ...;
                else
                    -- SPELL_DAMAGE / RANGE_DAMAGE / SPELL_PERIODIC_DAMAGE:
                    -- spellID, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing
                    spellID, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = ...;
                end

                self:DamageEvent(destGUID, spellID, amount, school, critical, spellName)
            end
        end

    -- Pet/Guardian
    elseif (bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_GUARDIAN) > 0
        or bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PET) > 0)
        and bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0 then

        if clue:find("_DAMAGE") then
            local isPet = true
            local spellID, spellName, spellSchool
            local amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing

            if clue:find("SWING") then
                spellName, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = "pet", ...;
            elseif clue:find("ENVIRONMENTAL") then
                local envType
                envType, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = ...;
            else
                spellID, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = ...;
            end

            self:DamageEvent(destGUID, spellID, amount, "pet", critical, spellName)
        end
    end
end

function ClassicNumbers:COMBAT_LOG_EVENT_UNFILTERED(event, ...)
    local _, clue, sourceGUID, _, sourceFlags, destGUID, _, destFlags = ...
    return self:CombatFilter(clue, sourceGUID, sourceFlags, destGUID, destFlags, select(9, ...))
end

-- DISPLAY --
local function commaSeperate(number)
    local _, _, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)');
    int = int:reverse():gsub("(%d%d%d)", "%1,");
    return minus..int:reverse():gsub("^,", "")..fraction;
end

function ClassicNumbers:DamageEvent(guid, spellID, amount, school, crit, spellName)
    local text, animation, pow, size, icon;
	local autoattack = not spellID or spellID == 75;

	pow = crit

    local unit = guidToUnit[guid];
    local isTarget = unit and UnitIsUnit(unit, "target");

	size = ClassicNumbers.db.global.size;
    if (crit) and playerGUID ~= guid then
        size = self.db.global.critSize;
    end

	if (pow and amount < self.db.global.smallCritsFilter) then
		pow = false;
		size = self.db.global.size * 1.5;
	end
	if (not pow and amount < self.db.global.smallHitsFilter or size == 0) then
		return;
	end

	-- truncate
	if (self.db.global.truncate and amount >= 1000000) then
		text = string.format("%.1fM", amount / 1000000);
	elseif (self.db.global.truncate and amount >= 10000) then
		text = string.format("%.0f", amount / 1000);
		text = text.."k";
	elseif (self.db.global.truncate and amount >= 1000) then
		text = string.format("%.1f", amount / 1000);
			text = text.."k";
	else
		if (self.db.global.commaSeperate) then
			text = commaSeperate(amount);
		else
			text = tostring(amount);
		end
	end

	-- color text
	if guid ~= playerGUID then
		if autoattack then
			text = "|Cff"..self.db.global.defaultColor..text.."|r";
		elseif school and DAMAGE_TYPE_COLORS[school] then
			if self.db.global.useDamageSchoolColors then
				text = "|Cff"..DAMAGE_TYPE_COLORS[school]..text.."|r";
			else
				text = "|Cff"..self.db.global.defaultAbilityColor..text.."|r";
			end
		elseif spellName == "melee" and DAMAGE_TYPE_COLORS[spellName] then
			text = "|Cff"..DAMAGE_TYPE_COLORS[spellName]..text.."|r";
		else
			text = "|Cff"..self.db.global.defaultAbilityColor..text.."|r";
		end
	else
		if self.db.global.damageColorPersonal and school and DAMAGE_TYPE_COLORS[school] then
			text = "|Cff"..DAMAGE_TYPE_COLORS[school]..text.."|r";
		elseif self.db.global.damageColorPersonal and spellName == "melee" and DAMAGE_TYPE_COLORS[spellName] then
			text = "|Cff"..DAMAGE_TYPE_COLORS[spellName]..text.."|r";
		else
			text = "|Cff"..self.db.global.defaultAbilityColor..text.."|r";
		end
	end

	self:DisplayText(guid, text, size, animation, pow, amount);
end

function ClassicNumbers:DisplayText(guid, text, size, animation, pow, amount)
    local fontString;
    local unit = guidToUnit[guid];
    local nameplate;

    if (unit) then
        nameplate = C_NamePlate.GetNamePlateForUnit(unit);
    end

    -- if there isn't an anchor frame, make sure that there is a guidNameplatePosition cache entry
    if playerGUID == guid and not unit then
          nameplate = player
    elseif (not nameplate) then
        return;
    end

    fontString = getFontString();

    fontString.text = text;
    fontString:SetText(fontString.text);

    fontString.fontSize = size;
    fontString:SetFont(getFontPath(ClassicNumbers.db.global.font), fontString.fontSize, ClassicNumbers.db.global.fontFlag);
	fontString:SetShadowOffset(2,-2)
    fontString.startHeight = fontString:GetStringHeight();
    fontString.pow = pow;
	fontString.fontHeight = size;
	fontString.amount = amount
	fontString.textWidth = size/2 * math.log10(amount);
	fontString.maxCritNumbersPerTarget = ClassicNumbers.db.global.maxCritNumbersPerTarget;
	fontString.critsAlpha = ClassicNumbers.db.global.critsAlpha;
	fontString.normalHitsAlpha = ClassicNumbers.db.global.normalHitsAlpha;
	fontString.nonCritsOffsetX = ClassicNumbers.db.global.nonCritsOffsetX;
	fontString.nonCritsOffsetY = ClassicNumbers.db.global.nonCritsOffsetY;
	fontString.critsOffsetX = ClassicNumbers.db.global.critsOffsetX;
	fontString.critsOffsetY = ClassicNumbers.db.global.critsOffsetY;
	fontString.nonCritAnimationDuration = ClassicNumbers.db.global.nonCritAnimationDuration;
	fontString.critAnimationDuration = ClassicNumbers.db.global.critAnimationDuration;
	fontString.scrollSpeed = ClassicNumbers.db.global.scrollSpeed
	fontString.scrollDistance = ClassicNumbers.db.global.scrollDistance;
	fontString.hideNonCritsIfBigCritChain = ClassicNumbers.db.global.hideNonCritsIfBigCritChain;
	fontString.displayBiggestCritInCenterOfTheChain = ClassicNumbers.db.global.displayBiggestCritInCenterOfTheChain;
	fontString.biggestCritDisplaysLargerThanOtherOnes = ClassicNumbers.db.global.biggestCritDisplaysLargerThanOtherOnes;

	--Sound effects
	 if (ClassicNumbers.db.global.critSoundEnabled and pow and amount > ClassicNumbers.db.global.critSoundThreshold and (not ClassicNumbers.db.global.hugeCritSoundEnabled or amount < ClassicNumbers.db.global.hugeCritSoundThreshold))
	 then
		PlaySoundFile("Interface\\AddOns\\ClassicNumbers\\Media\\Sounds\\Critical.ogg", ClassicNumbers.db.global.critSoundChannel)
	 end

	 if (ClassicNumbers.db.global.hugeCritSoundEnabled and pow and amount > ClassicNumbers.db.global.hugeCritSoundThreshold and (not ClassicNumbers.db.global.monsterCritSoundEnabled or amount < ClassicNumbers.db.global.monsterCritSoundThreshold))
	 then
		 PlaySoundFile("Interface\\AddOns\\ClassicNumbers\\Media\\Sounds\\HugeCritical.ogg", ClassicNumbers.db.global.hugeCritSoundChannel)
	end

	if (ClassicNumbers.db.global.monsterCritSoundEnabled and pow and amount > ClassicNumbers.db.global.monsterCritSoundThreshold)
	 then
		PlaySoundFile("Interface\\AddOns\\ClassicNumbers\\Media\\Sounds\\MonsterCritical.ogg", ClassicNumbers.db.global.monsterCritSoundChannel)
	end


	if (self.db.global.useLegacyOverlapHandler) then
		fontString.offsetY2 = 0
	end

    if (fontString.startHeight <= 0) then
        fontString.startHeight = 5;
    end

    fontString.unit = unit;
    self:Animate(fontString, nameplate, animation);
end

-------------
-- OPTIONS --
-------------
local menu = {
    name = "Classic Numbers",
    handler = ClassicNumbers,
    type = 'group',
    args = {
        enable = {
            type = 'toggle',
            name = "Enable",
            desc = "If the addon is enabled.",
            get = "IsEnabled",
            set = function(_, newValue) if (not newValue) then ClassicNumbers:Disable(); else ClassicNumbers:Enable(); end end,
            order = 1,
            width = "full",
        },

		disableBlizzardNumbers = {
            type = 'toggle',
            name = "Disable Blizzard numbers",
            desc = "Hide Blizzard's default combat text",
            get = function(_, newValue) return GetCVar("CombatDamage") == "0" end,
            set = function(_, newValue)
                if (newValue) then
					SetCVar("CombatDamage", 0)
					SetCVar("CombatLogPeriodicSpells", 0)
					SetCVar("PetMeleeDamage", 0)
					SetCVar("CombatHealing", 0)
					SetCVar("enableCombatText", 0)
					_G["SHOW_COMBAT_TEXT"] = "0"
					SetCVar("fctCombatState", 0)
					_G["COMBAT_TEXT_SHOW_COMBAT_STATE"] = "0"
					SetCVar("fctDodgeParryMiss", 0)
					_G["COMBAT_TEXT_SHOW_DODGE_PARRY_MISS"] = "0"
					SetCVar("fctDamageReduction", 0)
					_G["COMBAT_TEXT_SHOW_RESISTANCES"] = "0"
					SetCVar("fctFriendlyHealers", 0)
					_G["COMBAT_TEXT_SHOW_FRIENDLY_NAMES"] = "0"
                else
					SetCVar("CombatDamage", 1)
					SetCVar("CombatLogPeriodicSpells", 1)
					SetCVar("PetMeleeDamage", 1)
					SetCVar("CombatHealing", 1)
					SetCVar("enableCombatText", 1)
					_G["SHOW_COMBAT_TEXT"] = "1"
					SetCVar("fctCombatState", 1)
					_G["COMBAT_TEXT_SHOW_COMBAT_STATE"] = "1"
					SetCVar("fctDodgeParryMiss", 1)
					_G["COMBAT_TEXT_SHOW_DODGE_PARRY_MISS"] = "1"
					SetCVar("fctDamageReduction", 1)
					_G["COMBAT_TEXT_SHOW_RESISTANCES"] = "1"
					SetCVar("fctFriendlyHealers", 1)
					_G["COMBAT_TEXT_SHOW_FRIENDLY_NAMES"] = "1"
                end
            end,
            order = 2,
            width = "full",
        },

		textStyle = {
            type = 'group',
            name = "Text Style",
            order = 3,
            inline = true,
            disabled = function() return not ClassicNumbers.db.global.enabled; end;
            args = {
				truncateBigNumbers = {
					type = 'toggle',
					name = "Truncate big numbers",
					desc = "Example : a 1200 hit will be displayed as 1.2k",
					get = function() return ClassicNumbers.db.global.truncate; end,
					set = function(_, newValue) ClassicNumbers.db.global.truncate = newValue end,
					order = 1,
					width = "full",
				},
				commaSeperate = {
					type = 'toggle',
					name = "Comma separate numbers",
					desc = "Example : a 1200 hit will be displayed as 1,200. Classic wow don't use commas",
					get = function() return ClassicNumbers.db.global.commaSeperate; end,
					set = function(_, newValue) ClassicNumbers.db.global.commaSeperate = newValue end,
					order = 2,
					width = "full",
				},
				useDamageSchoolColors = {
					type = 'toggle',
					name = "Use damage school colors",
					desc = "Fire damage will be orange, frost damage will be blue, etc... if disabled, all abilities damage will be yellow",
					get = function() return ClassicNumbers.db.global.useDamageSchoolColors; end,
					set = function(_, newValue) ClassicNumbers.db.global.useDamageSchoolColors = newValue; end,
					order = 3,
					width = "full",
				},
				useLegacyOverlapHandler = {
					type = 'toggle',
					name = "Use legacy overlap handler",
					desc = "If enabled -> non crits will behave exactly as they did when the addon was first released, if disabled -> non crits will be less likely to overlap",
					get = function() return ClassicNumbers.db.global.useLegacyOverlapHandler; end,
					set = function(_, newValue) ClassicNumbers.db.global.useLegacyOverlapHandler = newValue; end,
					order = 4,
					width = "full",
				},
			    font = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    name = "Font style",
                    order = 5,
                    values = AceGUIWidgetLSMlists.font,
                    set = function(_, newValue) ClassicNumbers.db.global.font = newValue; end,
                    get = function() return ClassicNumbers.db.global.font; end,
                },
			}
		},

		nonCritTextOptions = {
            type = 'group',
            name = "Non critical text options",
            order = 4,
            inline = true,
            disabled = function() return not ClassicNumbers.db.global.enabled; end;
            args = {
				size = {
					type = 'range',
					name = "Size",
					desc = "Non-crit's Size",
					min = 0,
					max = 72,
					step = 4,
					get = function() return ClassicNumbers.db.global.size; end,
					set = function(_, newValue) ClassicNumbers.db.global.size = newValue; end,
					order = 1,
				},
				nonCritsOffsetX = {
					type = 'range',
					name = "Position Offset X",
					desc = "",
					min = -150,
					max = 150,
					step = 10,
					get = function() return ClassicNumbers.db.global.nonCritsOffsetX; end,
					set = function(_, newValue) ClassicNumbers.db.global.nonCritsOffsetX = newValue; end,
					order = 2,
				},
				nonCritsOffsetY = {
					type = 'range',
					name = "Position Offset Y",
					desc = "",
					min = -150,
					max = 150,
					step = 10,
					get = function() return ClassicNumbers.db.global.nonCritsOffsetY; end,
					set = function(_, newValue) ClassicNumbers.db.global.nonCritsOffsetY = newValue; end,
					order = 3,
				},
				scrollDistance = {
					type = 'range',
					name = "Scroll Distance",
					desc = "",
					min = -100,
					max = 100,
					step = 10,
					get = function() return ClassicNumbers.db.global.scrollDistance; end,
					set = function(_, newValue) ClassicNumbers.db.global.scrollDistance = newValue; end,
					order = 4,
				},
				normalHitsAlpha = {
					type = 'range',
					name = "Transparent <-> Opaque",
					desc = "0 : fully transparent, 1 : fully opaque",
					min = 0,
					max = 1,
					step = 0.1,
					get = function() return ClassicNumbers.db.global.normalHitsAlpha; end,
					set = function(_, newValue) ClassicNumbers.db.global.normalHitsAlpha = newValue; end,
					order = 5,
				},
				nonCritAnimationDuration = {
					type = 'range',
					name = "Display duration (seconds)",
					min = 0,
					max = 5,
					step = 0.25,
					get = function() return ClassicNumbers.db.global.nonCritAnimationDuration; end,
					set = function(_, newValue) ClassicNumbers.db.global.nonCritAnimationDuration = newValue; end,
					order = 6,
				},
				smallHitsFilter = {
					type = 'range',
					name = "Small hits filter",
					desc = "Hide numbers below this value",
					min = 0,
					max = 99999,
					step = 50,
					get = function() return ClassicNumbers.db.global.smallHitsFilter; end,
					set = function(_, newValue) ClassicNumbers.db.global.smallHitsFilter = newValue; end,
					order = 7,
				},
			}
		},

		CritTextOptions = {
            type = 'group',
            name = "Critical text options",
            order = 5,
            inline = true,
            disabled = function() return not ClassicNumbers.db.global.enabled; end;
            args = {
				hideNonCritsIfBigCritChain = {
					type = 'toggle',
					name = "Hide non crits on big crit chain",
					desc = "Temporarly hide normal hits if having rapid flow of critical strikes",
					get = function() return ClassicNumbers.db.global.hideNonCritsIfBigCritChain; end,
					set = function(_, newValue) ClassicNumbers.db.global.hideNonCritsIfBigCritChain = newValue; end,
					order = 0,
					width = "full",
				},
				critSize = {
					type = 'range',
					name = "Size",
					desc = "",
					min = 0,
					max = 72,
					step = 3,
					get = function() return ClassicNumbers.db.global.critSize; end,
					set = function(_, newValue) ClassicNumbers.db.global.critSize = newValue; end,
					order = 1,
				},

				critsOffsetX = {
					type = 'range',
					name = "Position Offset X",
					desc = "",
					min = -150,
					max = 150,
					step = 10,
					get = function() return ClassicNumbers.db.global.critsOffsetX; end,
					set = function(_, newValue) ClassicNumbers.db.global.critsOffsetX = newValue; end,
					order = 2,
				},
				critsOffsetY = {
					type = 'range',
					name = "Position Offset Y",
					desc = "",
					min = -150,
					max = 150,
					step = 10,
					get = function() return ClassicNumbers.db.global.critsOffsetY; end,
					set = function(_, newValue) ClassicNumbers.db.global.critsOffsetY = newValue; end,
					order = 3,
				},

				critsAlpha = {
					type = 'range',
					name = "Transparent <-> Opaque",
					desc = "0 : fully transparent, 1 : fully opaque",
					min = 0,
					max = 1,
					step = 0.1,
					get = function() return ClassicNumbers.db.global.critsAlpha; end,
					set = function(_, newValue) ClassicNumbers.db.global.critsAlpha = newValue; end,
					order = 5,
				},

				critAnimationDuration = {
					type = 'range',
					name = "Display duration (seconds)",
					min = 0,
					max = 5,
					step = 0.25,
					get = function() return ClassicNumbers.db.global.critAnimationDuration; end,
					set = function(_, newValue) ClassicNumbers.db.global.critAnimationDuration = newValue; end,
					order = 6,
				},

				smallCritsFilter = {
					type = 'range',
					name = "Small crits filter",
					desc = "Crits below this value will be displayed as if it was a non crit",
					min = 0,
					softMax = 99999,
					step = 50,
					get = function() return ClassicNumbers.db.global.smallCritsFilter; end,
					set = function(_, newValue) ClassicNumbers.db.global.smallCritsFilter = newValue; end,
					order = 7,
				},
				maxCritNumbersPerTarget = {
					type = 'range',
					name = "Max crits displayed per target",
					desc = "Max number of crits displayed on a target",
					min = 1,
					max = 5,
					step = 1,
					get = function() return ClassicNumbers.db.global.maxCritNumbersPerTarget; end,
					set = function(_, newValue) ClassicNumbers.db.global.maxCritNumbersPerTarget = newValue; end,
					order = 4,
				},
			}
		},

		CritSound = {
            type = 'group',
            name = "Crit sound effect",
            order = 6,
            inline = true,
            disabled = function() return not ClassicNumbers.db.global.enabled; end;
            args = {
				critSoundEnabled = {
					type = 'toggle',
					name = "Enabled",
					desc = "Enable playing a sound effect when doing a critical strike above the threshold",
					get = function() return ClassicNumbers.db.global.critSoundEnabled; end,
					set = function(_, newValue) ClassicNumbers.db.global.critSoundEnabled = newValue; end,
					order = 0,
					width = "full",
				},
				critSoundThreshold = {
					type = 'range',
					name = "Damage Threshold to play sound",
					desc = "The critical strike's damage should be higher than X to play the sound",
					disabled = function() return not ClassicNumbers.db.global.enabled or not ClassicNumbers.db.global.critSoundEnabled; end;
					min = 0,
					softMax = 10000000,
					step = 50,
					get = function() return ClassicNumbers.db.global.critSoundThreshold; end,
					set = function(_, newValue) ClassicNumbers.db.global.critSoundThreshold = newValue; end,
					width = "full",
					order = 1,
				},
				critSoundChannel = {
                    type = 'select',
                    name = "Channel",
					disabled = function() return not ClassicNumbers.db.global.enabled or not ClassicNumbers.db.global.critSoundEnabled; end;
                    get = function() return ClassicNumbers.db.global.critSoundChannel; end,
                    set = function(_, newValue) ClassicNumbers.db.global.critSoundChannel = newValue; end,
                    values = soundChannels,
					width = "full",
                    order = 2,
                },
			}
		},

		HugeCritSound = {
            type = 'group',
            name = "HUGE Crit sound effect",
            order = 7,
            inline = true,
            disabled = function() return not ClassicNumbers.db.global.enabled; end;
            args = {
				hugeCritSoundEnabled = {
					type = 'toggle',
					name = "Enabled",
					desc = "Enable playing a bigger sound effect when doing a critical strike above the threshold",
					get = function() return ClassicNumbers.db.global.hugeCritSoundEnabled; end,
					set = function(_, newValue) ClassicNumbers.db.global.hugeCritSoundEnabled = newValue; end,
					order = 0,
					width = "full",
				},
				hugeCritSoundThreshold = {
					type = 'range',
					name = "Damage Threshold to play sound",
					desc = "The critical strike's damage should be higher than X to play the sound",
					disabled = function() return not ClassicNumbers.db.global.enabled or not ClassicNumbers.db.global.hugeCritSoundEnabled; end;
					min = 0,
					softMax = 10000000,
					step = 50,
					get = function() return ClassicNumbers.db.global.hugeCritSoundThreshold; end,
					set = function(_, newValue) ClassicNumbers.db.global.hugeCritSoundThreshold = newValue; end,
					width = "full",
					order = 1,
				},
				hugeCritSoundChannel = {
                    type = 'select',
                    name = "Channel",
					disabled = function() return not ClassicNumbers.db.global.enabled or not ClassicNumbers.db.global.hugeCritSoundEnabled; end;
                    get = function() return ClassicNumbers.db.global.hugeCritSoundChannel; end,
                    set = function(_, newValue) ClassicNumbers.db.global.hugeCritSoundChannel = newValue; end,
                    values = soundChannels,
					width = "full",
                    order = 2,
                },
			}
		},

		 MonsterCritSound = {
          type = 'group',
           name = "MONSTER Crit sound effect",
          order = 7,
           inline = true,
           disabled = function() return not ClassicNumbers.db.global.enabled; end;
           args = {
				monsterCritSoundEnabled = {
					type = 'toggle',
					name = "Enabled",
					desc = "Enable playing a bigger sound effect when doing a critical strike above the threshold",
					get = function() return ClassicNumbers.db.global.monsterCritSoundEnabled; end,
					set = function(_, newValue) ClassicNumbers.db.global.monsterCritSoundEnabled = newValue; end,
					order = 0,
					width = "full",
				},
				monsterCritSoundThreshold = {
					type = 'range',
					name = "Damage Threshold to play sound",
					desc = "The critical strike's damage should be higher than X to play the sound",
					disabled = function() return not ClassicNumbers.db.global.enabled or not ClassicNumbers.db.global.monsterCritSoundEnabled; end;
					min = 0,
					softMax = 10000000,
					step = 50,
					get = function() return ClassicNumbers.db.global.monsterCritSoundThreshold; end,
					set = function(_, newValue) ClassicNumbers.db.global.monsterCritSoundThreshold = newValue; end,
					width = "full",
					order = 1,
				},
				monsterCritSoundChannel = {
                    type = 'select',
                    name = "Channel",
					disabled = function() return not ClassicNumbers.db.global.enabled or not ClassicNumbers.db.global.monsterCritSoundEnabled; end;
                    get = function() return ClassicNumbers.db.global.monsterCritSoundChannel; end,
                    set = function(_, newValue) ClassicNumbers.db.global.monsterCritSoundChannel = newValue; end,
                    values = soundChannels,
					width = "full",
                    order = 2,
                },
			}
		}
	}
}

-- Utils functions --

function GetBiggestCrit(anchorFrame)
	local biggestCrit
	for fontString, _ in pairs(animating) do

		if fontString.isCritNumber[anchorFrame] ~= nil and fontString.isCritNumber[anchorFrame] > 0 then
			if biggestCrit == nil then
				biggestCrit = fontString
			elseif fontString.amount >= biggestCrit.amount then
				biggestCrit = fontString
			end
		end
	end

	return biggestCrit
end

function OffsetCritIndexes(anchorFrame, offset, resetIndexesBefore)
	local crits = {}
	for fontString, _ in pairs(animating) do
		if (fontString.pow and fontString.anchorFrame == anchorFrame) then
			if resetIndexesBefore then
				crits[fontString] = true;
				fontString.isCritNumber[fontString.anchorFrame] = 0
			else
				fontString.isCritNumber[fontString.anchorFrame] = fontString.isCritNumber[fontString.anchorFrame] + offset
			end
		end
	end

	if resetIndexesBefore then
	local count = 0
		for crit, _ in pairs(crits) do
			count = count + 1
			crit.isCritNumber[crit.anchorFrame] = 1 + count
		end
	end
end

function GetNewestCrit(anchorFrame)
	local newestCrit = nil

	for fontString,  _ in pairs(animating) do
		if (fontString.anchorFrame == anchorFrame and fontString.isCritNumber[fontString.anchorFrame] == 1) then
			newestCrit = fontString
		end
	end
	return newestCrit
end

function GetFourthCrit(anchorFrame)
	local newestCrit = nil

	for fontString,  _ in pairs(animating) do
		if (fontString.anchorFrame == anchorFrame and fontString.isCritNumber[fontString.anchorFrame] == 4) then
			newestCrit = fontString
		end
	end
	return newestCrit
end

function GetClosestDamageNumberYValueFrom(fs)
	local closestValue = 999
	local closestFontString = nil

	for fontString, _ in pairs(animating) do
		if fontString.offsetY2 == 0 then
			if fontString ~= fs and not fontString.pow and not fs.pow and fontString.anchorFrame == fs.anchorFrame then
				local difference = math.abs(fontString.offsetY - fs.offsetY)
				if difference < closestValue and fontString.offsetX == fs.offsetX then
					closestValue = difference;
					closestFontString = fontString;
				end
			end
		else
			if fontString ~= fs and not fontString.pow and not fs.pow and fontString.anchorFrame == fs.anchorFrame and fontString.offsetY2 == nil and fs.offsetY2 == nil then
				local difference = math.abs(fontString.offsetY - fs.offsetY)
				if difference < closestValue and fontString.offsetX == fs.offsetX then
					closestValue = difference;
					closestFontString = fontString;
				end
			end
		end

	end
	return closestFontString;
end

function ClassicNumbers:OpenMenu(...)
	ACD:SetDefaultSize("ClassicNumbers", 635, 500)
	ACD:Open("ClassicNumbers")
end

function ClassicNumbers:RegisterMenu()
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("ClassicNumbers", menu);
    self.menu = ACD:AddToBlizOptions("ClassicNumbers", "ClassicNumbers");
end
