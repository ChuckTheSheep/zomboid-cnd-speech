require "ConditionalSpeech_Util"

ConditionalSpeech = {}
ConditionalSpeech.Phrases = {}

VolumeMAX = 30

------------------------------------------ FILTERS ----------------------------------------------
--Handler for filters
function ConditionalSpeech.PassMoodleFilters(text,mothermoodle)
	if text then
		local filterspassed = {} --[key]=value

		--[debug]] print("PassMoodleFilter: ",text," (mothermoodle:",mothermoodle,")")
		for MoodID,_ in pairs(ConditionalSpeech.MoodleTable) do --for each mood grab type/key
			local MoodleEntry = ConditionalSpeech.MoodleTable[MoodID]--direct reference to grab vars in value
			--[debug]] print("-- PassMoodleFilter: passing:",MoodID)
			-- panic filter doesn't play well with others: "shit! shit! shit! I need a snack!"

			--if mothermoodle~="Panic" and MoodID=="Panic" then
			--	--[[debug]] print("--- PassMoodleFilter: ignoring:",MoodID)
			--	MoodleEntry = nil
			--end

			if MoodleEntry and MoodleEntry.level > 0 and MoodleEntry.filters ~= nil then
				--[debug]] print("-- PassMoodleFilter: juggling: key:",MoodID)
				--if we should bother with processing the mood
				for _,Filter in pairs(MoodleEntry.filters) do --for each filter in filters
					local needinsert = true --insertcheck, turns false if found
					for filterstored,levelof in pairs(filterspassed) do --for each filter already added for passing
						if filterstored==Filter then --if keys in filterspassed matches values in MoodleEntry.filters
							needinsert = false --found
							if MoodleEntry.level > levelof then
								filterspassed[filterstored] = MoodleEntry.level
							end
							--if currently handled mood level exceeds stored level
						end
					end
					if needinsert == true then --if needinsert still true add filter and moodlevel to passinglist
						--table.insert(filterspassed, Filter)
						filterspassed[Filter] = MoodleEntry.level
					end
				end
			else --[debug]] print("-- PassMoodleFilter: can't pass: key:",MoodID)
			end
		end

		local filtered_vv = 0
		--pass each collected filter with correspondin instensity/level
		for FilterType,Intensity in pairs(filterspassed) do
			--[debug]] print("--==-== Run Filter: key:",FilterType,"  value:",Intensity)
			local filterresults = FilterType(text, Intensity)
			text = filterresults["return_text"]
			if filterresults["return_vol"]>filtered_vv then filtered_vv=filterresults["return_vol"] end
		end

		return {["dia_logue"]=text,["voc_vol"]=filtered_vv}
	end
end

--[[
-- Filter Template
function ConditionalSpeech.TEMPLATE(text, intensity)
	if text then
		local vol = 0 --VolumeMAX
		--- Stuff Here
		return {["return_text"]=text,["return_vol"]=vol}
	end
end
]]--

-- Blurt Out
function ConditionalSpeech.Blurt(text, intensity)
	if text then
		local vol = 0
		if prob(intensity*20) == true then
			vol = VolumeMAX/5
		end
		return {["return_text"]=text,["return_vol"]=vol}
	end
end

-- SCREAM FILTER!
function ConditionalSpeech.SCREAM_Filter(text, intensity)
	if text then
		local vol = VolumeMAX/2
		--[debug]] print("FILTER CALLED:  (SCREAM_Filter)",text," intensity:",intensity)
		text = replaceText(text, "%.", "%!")
		if prob(intensity*20) == true then
			text = text:upper()
			vol = VolumeMAX
		end
		return {["return_text"]=text,["return_vol"]=vol}
	end
end

-- S-s-stammer Filt-t-t-ter
function ConditionalSpeech.Stammer_Filter(text, intensity)
	if intensity <= 0 then intensity = 1 end
	if text then
		local vol = 0
		--[debug]] print("FILTER CALLED:  (Stammer_Filter)",text," intensity:",intensity)
		local characters = splitTextbyChar(text)
		local post_characters = {}
		local max_stammer = intensity
		for _,value in pairs(characters) do
			local c = value
			local chance = intensity*8
			if max_stammer > 0 and valueIn(ConditionalSpeech.Phrases.Plosives,value) == true then
				max_stammer = max_stammer-1
				while chance > 0 do
					if prob(chance)==true then c = c .. "-" .. c end
					chance = chance-(30+ZombRand(15))
				end
			end
			table.insert(post_characters, c)
		end
		return {["return_text"]=joinText(post_characters,0),["return_vol"]=vol}
	end
end


-- Logic for repeated swearing
function ConditionalSpeech.panicSwear_Filter(text, intensity)
	if not intensity then intensity = ZombRand(4)+1 end
	if text then
		--[debug]] print("FILTER CALLED:  (panicSwear_Filter)",text," intensity:",intensity)
		local vol = 0
		local randswear = WeightedRandPick(ConditionalSpeech.Phrases.SWEAR,intensity,4)

		if randswear then
			randswear = randswear .. "."

			local chance = intensity*15
			while chance > 0 do
				if prob(chance)==true then randswear = randswear .. " " .. randswear end
				chance = chance-(30+ZombRand(10))
			end

			if prob(50)==true then text = randswear .. " " .. text
			else text = text .. " " .. randswear --50% before or after text
			end
		end
		return {["return_text"]=text,["return_vol"]=vol}
	end
end

-- Logic for interlaced swears
function ConditionalSpeech.interlacedSwear_Filter(text, intensity)
	if not intensity then intensity = 1 end
	if text then
		--[debug]] print("FILTER CALLED:  (interlacedSwear_Filter)",text," intensity:",intensity)
		local vol = 0
		local skip_words = {"is","it","of","at","no","as"}
		local words = splitTextbyWord(text)
		if not words or #words <= 1 then return text end

		for key,value in pairs(words) do
			if key ~= #words and prob(5*intensity) == true then
				if valueIn(skip_words,words[key+1]) ~= true then
					local swear = WeightedRandPick(ConditionalSpeech.Phrases.SWEAR,intensity,4)
					if swear then
						words[key] = value .. " " .. swear
					end
				end
			end
		end
		return {["return_text"]=joinText(words, 1),["return_vol"]=vol}
	end
end

-------- Moodle Handler (Stores levels over time and has a filterlist to refer back to -------------
-- This has to be under where the filters themselves are defined
ConditionalSpeech.MoodleTable = {
["Endurance"] = {level = 0, filters = {ConditionalSpeech.Blurt} },
["Tired"] = {level = 0, filters = {ConditionalSpeech.Blurt} },
["Hungry"] = {level = 0, filters = nil },
["Panic"] = {level = 0, filters = {ConditionalSpeech.panicSwear_Filter,ConditionalSpeech.Stammer_Filter,ConditionalSpeech.Blurt,ConditionalSpeech.SCREAM_Filter} },
["Sick"] = {level = 0, filters = nil },
["Bored"] = {level = 0, filters = {ConditionalSpeech.Blurt} },
["Unhappy"] = {level = 0, filters = nil },
["Bleeding"] = {level = 0, filters = {ConditionalSpeech.Blurt} },
["Wet"] = {level = 0, filters = nil },
["HasACold"] = {level = 0, filters = nil },
["Angry"] = {level = 0, filters = {ConditionalSpeech.interlacedSwear_Filter,ConditionalSpeech.SCREAM_Filter} },
["Stress"] = {level = 0, filters = nil },
["Thirst"] = {level = 0, filters = nil },
["Injured"] = {level = 0, filters = nil },
["Pain"] = {level = 0, filters = {ConditionalSpeech.Blurt,ConditionalSpeech.interlacedSwear_Filter} },
["HeavyLoad"] = {level = 0, filters = nil },
["Drunk"] = {level = 0, filters = {ConditionalSpeech.Blurt} },
--[Dead] = {level = 0, filters = nil },
--[Zombie] = {level = 0, filters = nil },
["Hyperthermia"] = {level = 0, filters = nil },
["Hypothermia"] = {level = 0, filters = {ConditionalSpeech.Stammer_Filter} },
["Windchill"] = {level = 0, filters = nil },
["FoodEaten"] = {level = 0, filters = nil }
}

-- Start Up --
function ConditionalSpeech.Start() -- start up
	getPlayer():getMoodles():Update() -- makes sure that the Moodles system is properly loaded
	ConditionalSpeech.retrieveMoodles() -- matches moodles' levels to stored value
	Events.OnPlayerUpdate.Add(ConditionalSpeech.doMoodleCheck) -- preps conditions checker
end

-- Retrieve Level Values --
function ConditionalSpeech.retrieveMoodles() --uses the associative key as a reference
	for key,_ in pairs(ConditionalSpeech.MoodleTable) do ConditionalSpeech.MoodleTable[key].level = getPlayer():getMoodles():getMoodleLevel(MoodleType[key]) end
end


--Generates speech from a given table/list of phrases - also cleans up the sentence and applies filters
function ConditionalSpeech.generateSpeech(ID,intensity,MAXintensity)

	if (getPlayer():getMoodles():getMoodleLevel(MoodleType.Panic) >= 1) and (MoodleID ~= "Panic") then return end --can't think in panic

	if not intensity or intensity <=0 then intensity = 1 end
	if not MAXintensity or MAXintensity <=0 then MAXintensity = 1 end

	local PhraseTable = ConditionalSpeech.Phrases[ID]--this doesn't work for some reason, leaving it in for now anyway
	if not PhraseTable then return end
	local dialogue = WeightedRandPick(PhraseTable,intensity,MAXintensity)

	--[[debug]]local dialogue_backup = dialogue -- debug
	--[[debug]]if not dialogue then print("--ERR: Dialogue == false") return end --debug
	
	--replace KEYWORDS found with randomly picked words
	for KEYWORD,REPLACEWORDS in pairs(ConditionalSpeech.Phrases) do dialogue = replaceText(dialogue, "<"..KEYWORD..">", pickFrom(REPLACEWORDS)) end

	local fc = string.sub(dialogue, 1,1) --fc=first character
	local lc = string.sub(dialogue, -1) --lc=last character

	local vocal_volume = 0

	if fc=="*" and lc=="*" then --avoid filtering/messing with *emotive* text
	else
		if lc~="." and lc~="!" and lc~="?" then dialogue = dialogue .. "." end --just in case of no punctuation add some.
		local conditional_speech = ConditionalSpeech.PassMoodleFilters(dialogue,ID)--have other moods impact dialogue
		dialogue = conditional_speech["dia_logue"]
		vocal_volume = conditional_speech["voc_vol"]
		dialogue = dialogue:gsub("[!?.]%s", "%0\0"):gsub("%f[%Z]%s*%l", dialogue.upper):gsub("%z", "")--Proper sentence capitalization. Like so.
	end

	--[[debug]]print("    dialogue:",dialogue_backup)
	--[[debug]]print("    processed:",dialogue)
	--[[debug]]print("  --------------------------------------------------------")

	dialogue = tostring(dialogue)
	-- Speaking
	local player = getPlayer()
	ConditionalSpeech.VolumetricColor_Say(player,dialogue,vocal_volume)
	addSound(player, player:getX(), player:getY(), player:getZ(), vocal_volume, vocal_volume)
end


function ConditionalSpeech.VolumetricColor_Say(player,text,vol)
	local vc_shift = 0.3+(0.7*(vol/VolumeMAX))--have a 0.3 base --difference of 0.7 is then multipled against volume/maxvolume
	local MpText_Color = getCore():getMpTextColor()--grab player's MP text from main menu
	local text_color = {r = MpText_Color:getR()*vc_shift, g = MpText_Color:getG()*vc_shift, b = MpText_Color:getB()*vc_shift, a = vc_shift}--alpha shift based on vc_shift
	local graybase = {r=0.45, g=0.45, b=0.45, a=1}--gray base text_color will be overlayed onto
	local return_color = {r=0, g=0, b=0, a=0}--set up return color
	return_color.a = 1 - (1 - text_color.a) * (1 - graybase.a)--alpha
	return_color.r = text_color.r * text_color.r / return_color.a + graybase.r * graybase.a * (1 - text_color.a) / return_color.a--red
	return_color.g = text_color.g * text_color.g / return_color.a + graybase.g * graybase.a * (1 - text_color.a) / return_color.a--green
	return_color.b = text_color.b * text_color.b / return_color.a + graybase.b * graybase.a * (1 - text_color.a) / return_color.a--blue

	--[debug]]print("--- textcolor:  vol:",vol," - ",return_color.r*255,",",return_color.g*255,",",return_color.b*255)
	player:Say(text, return_color.r, return_color.g, return_color.b, UIFont.Small, vol, "radio") --radio makes it colored, I don't know why exactly
end



--Tracks moodle levels overtime, runs generate speech
function ConditionalSpeech.doMoodleCheck()
	for MoodleID,_ in pairs(ConditionalSpeech.MoodleTable) do
		local MoodleEntry = ConditionalSpeech.MoodleTable[MoodleID]
		local currentMoodleLevel = getPlayer():getMoodles():getMoodleLevel(MoodleType[MoodleID])
		--[debug]] print("-----X ConditionalSpeech:doMoodleCheck Start",MoodleID," currentMoodleLevel:",currentMoodleLevel)
		if currentMoodleLevel ~= MoodleEntry.level then --currentMoodleLevel(current mood level) is not equal to stored mood level then
			--[debug]] print("-----X ConditionalSpeech:doMoodleCheck Need Update",MoodleID," ",currentMoodleLevel,"~",MoodleEntry.level)
			if currentMoodleLevel > MoodleEntry.level then --if moodlevel has increased
				--[debug]] print("-----XX ConditionalSpeech:doMoodleCheck ",MoodleID,"  stored lvl:",MoodleEntry.level," getlvl:",currentMoodleLevel)--,"/",getPlayer():getMoodles():getGoodBadNeutral(key))
				ConditionalSpeech.generateSpeech(MoodleID,MoodleEntry.level,4)
			end
			MoodleEntry.level = currentMoodleLevel --match stored mood level to current- this is where the recorded level is lowered
		end

	end
end


--[[
-- Campfire code is broken but I think it is trying to find players near by and create a group singing event which is a pretty cool idea.
ConditionalSpeech.TimeOfRegister = false
function ConditionalSpeech.isGetCampfire() -- I yonked most of this function from camping.lua.
	local players = IsoPlayer.getPlayers()
	for _,vCamp in pairs(camping.campfires) do
		local gridSquare = vCamp:getSquare()
		if vCamp.isLit and gridSquare then
			for i=0,players:size()-1 do
				local vPlayer = players:get(i)
				if vPlayer and not vPlayer:isDead() and vPlayer:getCurrentSquare() and vPlayer:getCurrentSquare():DistTo(gridSquare) <= 3 and ConditionalSpeech.TimeOfRegister ~= os.date("%M") then
					ConditionalSpeech.CampFireRegister = true
					ConditionalSpeech.TimeOfRegister = os.date("%M")
					return true
				end
			end
		end
	end
end
]]


-- Out of Ammo
function ConditionalSpeech.check_OutOfAmmo()
	local primary_weapon = getPlayer():getPrimaryHandItem()
	if primary_weapon and primary_weapon:getCategory() == "Weapon" and primary_weapon:isRanged() and not getPlayer():isShoving() then
		if primary_weapon:isJammed() then ConditionalSpeech.generateSpeech(ConditionalSpeech.GunJammed)
		else
			if (primary_weapon:haveChamber() and not primary_weapon:isRoundChambered()) or (not primary_weapon:haveChamber() and primary_weapon:getCurrentAmmoCount() <= 0) then
				ConditionalSpeech.generateSpeech("OutOfAmmo")
			end
		end
	end
end

function ConditionalSpeech.check_Time()
	local TIME = math.floor(getGameTime():getTimeOfDay())
	--[debug]]print("-=-=- check_Dawn: getTimeOfDay:",TIME, "   outside?",getPlayer():isOutside())
	if getPlayer():isOutside() and prob(75)==true then
		if TIME==6 then ConditionalSpeech.generateSpeech("OnDawn")
		else if TIME==22 then ConditionalSpeech.generateSpeech("OnDusk") end
		end
	end
end

--Events.EveryDays.Add()
Events.EveryHours.Add(ConditionalSpeech.check_Time)
Events.OnLoad.Add(ConditionalSpeech.Start)
Events.OnWeaponSwing.Add(ConditionalSpeech.check_OutOfAmmo)

--Events.OnWeaponHitCharacter
--Events.OnWeaponHitTree
--Events.OnWeaponSwingHitPoint
--Events.onWeaponHitXp = function(owner, weapon, hitObject, damage)
--Events.EveryTenMinutes
--Events.EveryDays
--Events.EveryHours
--Events.OnEnterVehicle.Add()
--Events.OnExitVehicle.Add()
--Events.OnVehicleDamageTexture.Add()
--Events.LevelPerk.Add(xpUpdate.levelPerk)
--Events.OnZombieDead

--	player:getDescriptor():isFemale()
--	player:getDescriptor():getForename()
--	player:getDescriptor():getSurname()
--	player:getDescriptor():getProfession()

--	for i=0,player:getTraits():size() -1 do
--	local trait = player:getTraits():get(i)

--LuaEventManager.AddEvent("function")