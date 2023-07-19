-- Register the behaviour
behaviour("MovementPlus")

function MovementPlus:Awake()
	self.gameObject.name = "MovementPlus"
	--self:CacheWeaponMeshSizes()
end

function MovementPlus:Start()
	-- Run when behaviour is created
	self.baseMovementSpeed = 1
	self.weightMultiplier = 1
	self.currentMovementSpeed = self.baseMovementSpeed
	self.movementSpeedModifiers = {}

	self.weightSystemEnabled = self.script.mutator.GetConfigurationBool("weightSystemEnabled")

	self.defaultData = {}
	self.defaultData[WeaponSlot.Primary] = self:GenerateDefaultData(self.script.mutator.GetConfigurationFloat("defaultPrimaryWeight"), self.script.mutator.GetConfigurationRange("defaultPrimaryAdsMultiplier"))
	self.defaultData[WeaponSlot.Secondary] = self:GenerateDefaultData(self.script.mutator.GetConfigurationFloat("defaultSecondaryWeight"), self.script.mutator.GetConfigurationRange("defaultSecondaryAdsMultiplier"))
	self.defaultData[WeaponSlot.Gear] = self:GenerateDefaultData(self.script.mutator.GetConfigurationFloat("defaultSmallGearWeight"), self.script.mutator.GetConfigurationRange("defaultSmallGearAdsMultiplier"))
	self.defaultData[WeaponSlot.LargeGear] = self:GenerateDefaultData(self.script.mutator.GetConfigurationFloat("defaultLargeGearWeight"), self.script.mutator.GetConfigurationRange("defaultLargeGearAdsMultiplier"))

	self.weaponData = {}
	self:ParseOverrideString(self.script.mutator.GetConfigurationString("line1"))
	self:ParseOverrideString(self.script.mutator.GetConfigurationString("line2"))
	self:ParseOverrideString(self.script.mutator.GetConfigurationString("line3"))
	self:ParseOverrideString(self.script.mutator.GetConfigurationString("line4"))
	self:ParseOverrideString(self.script.mutator.GetConfigurationString("line5"))
	self:ParseOverrideString(self.script.mutator.GetConfigurationString("line6"))
	self:ParseOverrideString(self.script.mutator.GetConfigurationString("line7"))
	self:ParseOverrideString(self.script.mutator.GetConfigurationString("line8"))
	self:ParseOverrideString(self.script.mutator.GetConfigurationString("line9"))
	self:ParseOverrideString(self.script.mutator.GetConfigurationString("line10"))

	self.tagData = {}
	self:ParseTagString(self.script.mutator.GetConfigurationString("categoryLine1"))
	self:ParseTagString(self.script.mutator.GetConfigurationString("categoryLine2"))
	self:ParseTagString(self.script.mutator.GetConfigurationString("categoryLine3"))
	self:ParseTagString(self.script.mutator.GetConfigurationString("categoryLine4"))
	self:ParseTagString(self.script.mutator.GetConfigurationString("categoryLine5"))

	self.mediumThreshold = 6
	self.mediumWeightMultiplier = 0.90
	self.heavyThreshold = 8
	self.heavyWeightMultiplier = 0.75

	self.weightMultiplier = 1

	self.isAiming = false
	self.script.AddValueMonitor("monitorIsAiming", "onIsAimingStateChanged")

	GameEvents.onActorSpawn.AddListener(self,"onActorSpawn")
end

--Parse string lines for weapon data
function MovementPlus:ParseOverrideString(str)
	for word in string.gmatch(str, '([^,]+)') do
		local iterations = 0
		local name = ""
		local adsMultiplier = 1.0
		local weaponWeight = 1.0
		for wrd in string.gmatch(word,'([^|]+)') do
			if wrd ~= "-" then
				if iterations == 0 then name = wrd end
				if iterations == 1 then adsMultiplier = tonumber(wrd) end
				if iterations == 2 then weaponWeight = tonumber(wrd) end
			end
			iterations = iterations + 1
			if(iterations >= 3) then break end
		end
		self:CreateData(name, adsMultiplier,weaponWeight)
		
	end
end

function MovementPlus:ParseTagString(str)
	for word in string.gmatch(str, '([^,]+)') do
		local iterations = 0
		local name = ""
		local categoryWeightModifier = 1
		for wrd in string.gmatch(word,'([^|]+)') do
			if wrd ~= "-" then
				if iterations == 0 then name = string.lower(wrd) end
				if iterations == 1 then categoryWeightModifier = tonumber(wrd) end
			end
			iterations = iterations + 1
			if(iterations >= 2) then break end
		end
		self.tagData[name] = categoryWeightModifier
	end
end

function MovementPlus:monitorIsAiming()
	if Player.actor.activeWeapon == nil then return false end
	return Player.actor.activeWeapon.isAiming
end

function MovementPlus:onIsAimingStateChanged()
	if Player.actor.activeWeapon == nil then return end

	local isAiming = Player.actor.activeWeapon.isAiming
	if isAiming then
		local weaponEntry = Player.actor.activeWeapon.weaponEntry
		local cleanName = string.gsub(weaponEntry.name,"<.->","")
		local weaponData = self.weaponData[cleanName]
		local adsMultiplier = 1
		if weaponData then
			adsMultiplier = weaponData.adsMultiplier
		end
		self:AddModifier("ADSPenalty", adsMultiplier)
	else
		self:RemoveModifier("ADSPenalty")
	end
end

function MovementPlus:AddModifier(modifierName, modifierValue)
	self.movementSpeedModifiers[modifierName] = modifierValue
	self:CalculateMovementSpeed(Player.actor)
end

function MovementPlus:RemoveModifier(modifierName)
	self.movementSpeedModifiers[modifierName] = nil
	self:CalculateMovementSpeed(Player.actor)
end

function MovementPlus:CalculateMovementSpeed(actor)
	local multiplier = 1
	for modifier, value in pairs(self.movementSpeedModifiers) do
		multiplier = multiplier * value
	end
	self.currentMovementSpeed = self.baseMovementSpeed * multiplier * self.weightMultiplier
	actor.speedMultiplier = self.currentMovementSpeed
end

function MovementPlus:onActorSpawn(actor)
	if actor.isPlayer then
		self:EvaluateWeapons(actor)
		self:CalculateMovementSpeed(actor)
	end
end

function MovementPlus:EvaluateWeapons(actor)
	local totalWeight = 0
	for i = 1, #actor.weaponSlots, 1 do
		local weapon = actor.weaponSlots[i]
		local weaponEntry = weapon.weaponEntry
		local cleanName = string.gsub(weaponEntry.name,"<.->","")
		local data = self.weaponData[cleanName]
		if data == nil then data = self:AutoGenerateWeaponStats(cleanName, weaponEntry) end

		local weaponWeight = 0
		weaponWeight = data.weaponWeight

		print(weaponEntry.name .. ": " .. weaponWeight)
		totalWeight = totalWeight + weaponWeight
	end

	print("Total weight: " .. totalWeight)
	if totalWeight >= self.heavyThreshold then
		self.weightMultiplier = self.heavyWeightMultiplier
	elseif totalWeight >= self.mediumThreshold then
		self.weightMultiplier = self.mediumWeightMultiplier
	else
		self.weightMultiplier = 1
	end
end

function MovementPlus:GenerateDefaultData(weaponWeight, adsMultiplier)
	local newData = {}
	newData.adsMultiplier = adsMultiplier
	newData.weaponWeight = weaponWeight
	return newData
end

function MovementPlus:GetWeightModifiersFromTags(weaponEntry)
	local totalWeightMod = 0
	for i = 1, #weaponEntry.tags, 1 do
		local tag = string.lower(weaponEntry.tags[i])
		local weightMod = self.tagData[tag]
		if weightMod then
			totalWeightMod = totalWeightMod + weightMod
		end
	end
	return totalWeightMod
end

function MovementPlus:CreateData(name ,adsMultiplier, weaponWeight)
	local data = {}
	data.adsMultiplier = adsMultiplier
	data.weaponWeight = weaponWeight
	self.weaponData[name] = data

	print("[Movement Plus] Registered " .. name)
	print(" ----ADS Multiplier " .. adsMultiplier)
	print(" ----Weight " .. weaponWeight)
	return data
end

function MovementPlus:AutoGenerateWeaponStats(cleanName, weaponEntry)
	local slotWeight = self.defaultData[weaponEntry.slot].weaponWeight
	local tagWeight = self:GetWeightModifiersFromTags(weaponEntry)
	local weaponWeight = slotWeight + tagWeight

	--The greater the weaponWeight is compared to slotWeight, the slower ADS movement will be
	local dif = weaponWeight/slotWeight - 1
	local adsMultiplier = (1-dif) * self.defaultData[weaponEntry.slot].adsMultiplier
	if adsMultiplier > 1 then adsMultiplier = 1 end
	
	return self:CreateData(cleanName, adsMultiplier, weaponWeight)
end