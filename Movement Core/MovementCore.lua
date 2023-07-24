-- Register the behaviour
behaviour("MovementCore")

_movementCoreInstance = nil

function MovementCore:Awake()
	self.gameObject.name = "MovementCore"
	_movementCoreInstance = self

	self.baseActorSpeed = self.script.mutator.GetConfigurationFloat("BaseActorSpeed")
	self.doDebug = self.script.mutator.GetConfigurationBool("Debug")

	for i = 1, #ActorManager.actors, 1 do
		local actor = ActorManager.actors[i]
		actor.speedMultiplier = self.baseActorSpeed
	end

	self.actorData = {}

	GameEvents.onActorDiedInfo.AddListener(self,"OnActorDiedInfo")
end

function MovementCore:AddModifier(actor,modifierName, modifierValue)
	if self.actorData[actor.actorIndex] == nil then
		self.actorData[actor.actorIndex] = {}
	end

	self.actorData[actor.actorIndex][modifierName] = modifierValue
	self:CalculateMovementSpeed(actor)
end

function MovementCore:RemoveModifier(actor, modifierName)
	if self.actorData[actor.actorIndex] == nil then return end

	self.actorData[actor.actorIndex][modifierName] = nil
	self:CalculateMovementSpeed(actor)
end

function MovementCore:CalculateMovementSpeed(actor)
	local multiplier = 1
	local modifiers = self.actorData[actor.actorIndex]
	for modifier, value in pairs(modifiers) do
		multiplier = multiplier * value
	end
	
	actor.speedMultiplier = self.baseActorSpeed * multiplier
	if self.doDebug then
		print(actor.name .. " speed is " .. actor.speedMultiplier)
	end
end

function MovementCore:RemoveAllModifiers(actor)
	if self.actorData[actor.actorIndex] == nil then return end

	self.actorData[actor.actorIndex] = {}
	self:CalculateMovementSpeed(actor)
end

function MovementCore:OnActorDiedInfo(actor, info, isSilentKill)
	self:RemoveAllModifiers(actor)
end