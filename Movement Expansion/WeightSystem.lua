-- Register the behaviour
behaviour("MovementExpansion")

function WeightSystem:Awake()
	self.gameObject.name = "MovementExpansion"
end

function WeightSystem:Start()
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

	self.isAiming = false
	self.script.AddValueMonitor("monitorIsAiming", "onIsAimingStateChanged")

	GameEvents.onActorSpawn.AddListener(self,"onActorSpawn")
end

--Parse string lines for weapon data
function WeightSystem:ParseOverrideString(str)
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

function WeightSystem:ParseTagString(str)
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

function WeightSystem:monitorIsAiming()
	if Player.actor.activeWeapon == nil then return false end
	return Player.actor.activeWeapon.isAiming
end

function WeightSystem:onIsAimingStateChanged()
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
		if _movementCoreInstance then
			_movementCoreInstance:AddModifier(Player.actor, "ADSPenalty", adsMultiplier)
		end
	else
		if _movementCoreInstance then
			_movementCoreInstance:RemoveModifier(Player.actor, "ADSPenalty")
		end
	end
end

function WeightSystem:onActorSpawn(actor)
	self:EvaluateWeapons(actor)
end

function WeightSystem:EvaluateWeapons(actor)
	local totalWeight = 0
	for i = 1, #actor.weaponSlots, 1 do
		local weapon = actor.weaponSlots[i]
		local weaponEntry = weapon.weaponEntry
		local cleanName = string.gsub(weaponEntry.name,"<.->","")
		local data = self.weaponData[cleanName]
		if data == nil then data = self:GetStatsFromDataContainer(cleanName,weapon) end
		if data == nil then data = self:AutoGenerateWeaponStats(cleanName, weaponEntry) end

		local weaponWeight = 0
		weaponWeight = data.weaponWeight

		totalWeight = totalWeight + weaponWeight
	end

	--print(actor.name .. " total weight: " .. totalWeight)
	local weightMultiplier = 1
	if totalWeight >= self.heavyThreshold then
		weightMultiplier = self.heavyWeightMultiplier
	elseif totalWeight >= self.mediumThreshold then
		weightMultiplier = self.mediumWeightMultiplier
	end
	
	if _movementCoreInstance then
		_movementCoreInstance:AddModifier(actor, "Weight", weightMultiplier)
	end
end

function WeightSystem:GenerateDefaultData(weaponWeight, adsMultiplier)
	local newData = {}
	newData.adsMultiplier = adsMultiplier
	newData.weaponWeight = weaponWeight
	return newData
end

function WeightSystem:GetWeightModifiersFromTags(weaponEntry)
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

function WeightSystem:CreateData(name ,adsMultiplier, weaponWeight)
	local data = {}
	data.adsMultiplier = adsMultiplier
	data.weaponWeight = weaponWeight
	self.weaponData[name] = data

	--print("[Movement Plus] Registered " .. name)
	--print("[Movement Plus] --ADS Multiplier " .. adsMultiplier)
	--print("[Movement Plus] --Weight " .. weaponWeight)
	return data
end

function WeightSystem:AutoGenerateWeaponStats(cleanName, weaponEntry)
	local weaponWeight = self:GenerateWeight(weaponEntry)
	local adsMultiplier = self:GenerateADSMultiplier(weaponEntry, weaponWeight)
	
	return self:CreateData(cleanName, adsMultiplier, weaponWeight)
end

function WeightSystem:GenerateWeight(weaponEntry)
	local slotWeight = self.defaultData[weaponEntry.slot].weaponWeight
	local tagWeight = self:GetWeightModifiersFromTags(weaponEntry)

	return slotWeight + tagWeight
end

function WeightSystem:GenerateADSMultiplier(weaponEntry, weaponWeight)
	--The greater the weaponWeight is compared to slotWeight, the slower ADS movement will be
	local slotWeight = self.defaultData[weaponEntry.slot].weaponWeight

	local dif = weaponWeight/slotWeight - 1
	local adsMultiplier = (1-dif) * self.defaultData[weaponEntry.slot].adsMultiplier
	if adsMultiplier > 1 then adsMultiplier = 1 end

	return adsMultiplier
end

function WeightSystem:GetStatsFromDataContainer(cleanName, weapon)
	local dataContainer = weapon.gameObject.GetComponent(DataContainer)
	if dataContainer == nil then return nil end

	local weaponWeight = 1
	if dataContainer.HasFloat("WeaponWeight") then
		weaponWeight = dataContainer.GetFloat("WeaponWeight")
	else
		weaponWeight = self:GenerateWeight(weapon.weaponEntry)
	end

	local adsMultiplier = 1
	if dataContainer.HasFloat("ADSMultiplier") then
		adsMultiplier = dataContainer.GetFloat("ADSMultiplier")
	else
		adsMultiplier = self:GenerateADSMultiplier(weapon.weaponEntry, weaponWeight)
	end
	return self:CreateData(cleanName, adsMultiplier, weaponWeight)
end