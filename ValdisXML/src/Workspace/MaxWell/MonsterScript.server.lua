--[[
	Basic Monster by ArceusInator

	Information:
		Configurations.MaximumDetectionDistance (default 200)
			The monster will not detect players past this point.  If you set it to a negative number then the monster will be able to chase from any distance.
			
		Configurations.CanGiveUp (default true)
			If true, the monster will give up if its target goes past the MaximumDetectionDistance.  This is a pretty good idea if you have people teleporting around.
			
		Configurations.CanRespawn (default true)
			If true, the monster will respawn after it dies
			
		Configurations.AutoDetectSpawnPoint (default true)
			If true, the spawn point will be auto detected based on where the monster is when it starts
		
		Configurations.SpawnPoint (default 0,0,0)
			If Settings.AutoDetectSpawnPoint is disabled, this will be set to the monster's initial position.  This value will be used when the monster auto respawns to tell it where to spawn next.
			
		Configurations.FriendlyTeam (default Really black)
			The monster will not attack players on this team
		
		
		
		Mind.CurrentTargetHumanoid (Humanoid objects only)
			You can force the monster to follow a certain humanoid by setting this to that humanoid
		
		
		
		Monster.Respawn (Function)
			Arguments are: Vector3 point
			Info: Respawns the monster at the given point, or at the SpawnPoint setting if none if provided
		
		Monster.Died (Event)
			Info: Fired when the monster dies
		
		Monster.Respawned (Event)
			Info: Fired when the monster respawns
--]]

local Self = script.Parent
local Settings = Self:FindFirstChild'Configurations' -- Points to the settings.
local Mind = Self:FindFirstChild'Mind' -- Points to the monster's mind.  You can edit parts of this from other scripts in-game to change the monster's behavior.  Advanced users only.

--
-- Verify that everything is where it should be
assert(Self:FindFirstChild'Humanoid' ~= nil, 'Monster does not have a humanoid')
assert(Settings ~= nil, 'Monster does not have a Configurations object')
	assert(Settings:FindFirstChild'MaximumDetectionDistance' ~= nil and Settings.MaximumDetectionDistance:IsA'NumberValue', 'Monster does not have a MaximumDetectionDistance (NumberValue) setting')
	assert(Settings:FindFirstChild'CanGiveUp' ~= nil and Settings.CanGiveUp:IsA'BoolValue', 'Monster does not have a CanGiveUp (BoolValue) setting')
	assert(Settings:FindFirstChild'CanRespawn' ~= nil and Settings.CanRespawn:IsA'BoolValue', 'Monster does not have a CanRespawn (BoolValue) setting')
	assert(Settings:FindFirstChild'SpawnPoint' ~= nil and Settings.SpawnPoint:IsA'Vector3Value', 'Monster does not have a SpawnPoint (Vector3Value) setting')
	assert(Settings:FindFirstChild'AutoDetectSpawnPoint' ~= nil and Settings.AutoDetectSpawnPoint:IsA'BoolValue', 'Monster does not have a AutoDetectSpawnPoint (BoolValue) setting')
	assert(Settings:FindFirstChild'FriendlyTeam' ~= nil and Settings.FriendlyTeam:IsA'BrickColorValue', 'Monster does not have a FriendlyTeam (BrickColorValue) setting')
	assert(Settings:FindFirstChild'AttackDamage' ~= nil and Settings.AttackDamage:IsA'NumberValue', 'Monster does not have a AttackDamage (NumberValue) setting')
	assert(Settings:FindFirstChild'AttackFrequency' ~= nil and Settings.AttackFrequency:IsA'NumberValue', 'Monster does not have a AttackFrequency (NumberValue) setting')
	assert(Settings:FindFirstChild'AttackRange' ~= nil and Settings.AttackRange:IsA'NumberValue', 'Monster does not have a AttackRange (NumberValue) setting')
assert(Mind ~= nil, 'Monster does not have a Mind object')
	assert(Mind:FindFirstChild'CurrentTargetHumanoid' ~= nil and Mind.CurrentTargetHumanoid:IsA'ObjectValue', 'Monster does not have a CurrentTargetHumanoid (ObjectValue) mind setting')
assert(Self:FindFirstChild'Respawn' and Self.Respawn:IsA'BindableFunction', 'Monster does not have a Respawn BindableFunction')
assert(Self:FindFirstChild'Died' and Self.Died:IsA'BindableEvent', 'Monster does not have a Died BindableEvent')
assert(Self:FindFirstChild'Respawned' and Self.Died:IsA'BindableEvent', 'Monster does not have a Respawned BindableEvent')
assert(Self:FindFirstChild'Attacked' and Self.Died:IsA'BindableEvent', 'Monster does not have a Attacked BindableEvent')
assert(script:FindFirstChild'Attack' and script.Attack:IsA'Animation', 'Monster does not have a MonsterScript.Attack Animation')


--
--
local Info = {
	-- These are constant values.  Don't change them unless you know what you're doing.

	-- Services
	Players = Game:GetService 'Players',
	PathfindingService = Game:GetService 'PathfindingService',

	-- Advanced settings
	RecomputePathFrequency = 1, -- The monster will recompute its path this many times per second
	RespawnWaitTime = 5, -- How long to wait before the monster respawns
	JumpCheckFrequency = 1, -- How many times per second it will do a jump check
}
local Data = {
	-- These are variable values used internally by the script.  Advanced users only.

	LastRecomputePath = 0,
	Recomputing = false, -- Reocmputing occurs async, meaning this script will still run while it's happening.  This variable will prevent the script from running two recomputes at once.
	PathCoords = {},
	IsDead = false,
	TimeOfDeath = 0,
	CurrentNode = nil,
	CurrentNodeIndex = 1,
	AutoRecompute = true,
	LastJumpCheck = 0,
	LastAttack = 0,
	
	BaseMonster = Self:Clone(),
	AttackTrack = nil,
}

--
--
local Monster = {} -- Create the monster class


function Monster:GetCFrame()
	-- Returns the CFrame of the monster's humanoidrootpart

	local humanoidRootPart = Self:FindFirstChild('HumanoidRootPart')

	if humanoidRootPart ~= nil and humanoidRootPart:IsA('BasePart') then
		return humanoidRootPart.CFrame
	else
		return CFrame.new()
	end
end

function Monster:GetMaximumDetectionDistance()
	-- Returns the maximum detection distance
	
	local setting = Settings.MaximumDetectionDistance.Value

	if setting < 0 then
		return math.huge
	else
		return setting
	end
end

function Monster:SearchForTarget()
	-- Finds the closest player and sets the target

	local players = Info.Players:GetPlayers()
	local closestCharacter, closestCharacterDistance

	for i=1, #players do
		local player = players[i]
		
		if player.Neutral or player.TeamColor ~= Settings.FriendlyTeam.Value then
			local character = player.Character
	
			if character ~= nil and character:FindFirstChild('Humanoid') ~= nil and character.Humanoid:IsA('Humanoid') then
				local distance = player:DistanceFromCharacter(Monster:GetCFrame().p)
	
				if distance < Monster:GetMaximumDetectionDistance() then
					if closestCharacter == nil then
						closestCharacter, closestCharacterDistance = character, distance
					else
						if closestCharacterDistance > distance then
							closestCharacter, closestCharacterDistance = character, distance
						end
					end
				end
			end
		end
	end


	if closestCharacter ~= nil then
		Mind.CurrentTargetHumanoid.Value = closestCharacter.Humanoid
	end
end

function Monster:TryRecomputePath()
	if Data.AutoRecompute or tick() - Data.LastRecomputePath > 1/Info.RecomputePathFrequency then
		Monster:RecomputePath()
	end
end

function Monster:GetTargetCFrame()
	local targetHumanoid = Mind.CurrentTargetHumanoid.Value
	
	if Monster:TargetIsValid() then
		return targetHumanoid.Torso.CFrame
	else
		return CFrame.new()
	end
end

function Monster:IsAlive()
	return Self.Humanoid.Health > 0 and Self.Humanoid.Torso ~= nil
end

function Monster:TargetIsValid()
	local targetHumanoid = Mind.CurrentTargetHumanoid.Value
	
	if targetHumanoid ~= nil and targetHumanoid:IsA 'Humanoid' and targetHumanoid.Torso ~= nil and targetHumanoid.Torso:IsA 'BasePart' then
		return true
	else
		return false
	end
end

function Monster:HasClearLineOfSight()
	-- Going to cast a ray to see if I can just see my target
	local myPos, targetPos = Monster:GetCFrame().p, Monster:GetTargetCFrame().p
	
	local hit, pos = Workspace:FindPartOnRayWithIgnoreList(
		Ray.new(
			myPos,
			targetPos - myPos
		),
		{
			Self,
			Mind.CurrentTargetHumanoid.Value.Parent
		}
	)
	
	
	if hit == nil then
		return true
	else
		return false
	end
end

function Monster:RecomputePath()
	if not Data.Recomputing then
		if Monster:IsAlive() and Monster:TargetIsValid() then
			if Monster:HasClearLineOfSight() then
				Data.AutoRecompute = true
				Data.PathCoords = {
					Monster:GetCFrame().p,
					Monster:GetTargetCFrame().p
				}
				
				Data.LastRecomputePath = tick()
				Data.CurrentNode = nil
				Data.CurrentNodeIndex = 2 -- Starts chasing the target without evaluating its current position
			else
				-- Do pathfinding since you can't walk straight
				Data.Recomputing = true -- Basically a debounce.
				Data.AutoRecompute = false
				
				
				local path = Info.PathfindingService:ComputeSmoothPathAsync(
					Monster:GetCFrame().p,
					Monster:GetTargetCFrame().p,
					500
				)
				Data.PathCoords = path:GetPointCoordinates()
				
				
				Data.Recomputing = false
				Data.LastRecomputePath = tick()
				Data.CurrentNode = nil
				Data.CurrentNodeIndex = 1
			end
		end
	end
end

function Monster:Update()
	Monster:ReevaluateTarget()
	Monster:SearchForTarget()
	Monster:TryRecomputePath()
	Monster:TravelPath()
end

function Monster:TravelPath()
	local closest, closestDistance, closestIndex
	local myPosition = Monster:GetCFrame().p
	local skipCurrentNode = Data.CurrentNode ~= nil and (Data.CurrentNode - myPosition).magnitude < 3
	
	for i=Data.CurrentNodeIndex, #Data.PathCoords do
		local coord = Data.PathCoords[i]
		if not (skipCurrentNode and coord == Data.CurrentNode) then
			local distance = (coord - myPosition).magnitude
			
			if closest == nil then
				closest, closestDistance, closestIndex = coord, distance, i
			else
				if distance < closestDistance then
					closest, closestDistance, closestIndex = coord, distance, i
				else
					break
				end
			end
		end
	end
	
	
	--
	if closest ~= nil then
		Data.CurrentNode = closest
		Data.CurrentNodeIndex = closestIndex
		
		local humanoid = Self:FindFirstChild 'Humanoid'
		
		if humanoid ~= nil and humanoid:IsA'Humanoid' then
			humanoid:MoveTo(closest)
		end
		
		if Monster:IsAlive() and Monster:TargetIsValid() then
			Monster:TryJumpCheck()
			Monster:TryAttack()
		end
		
		if closestIndex == #Data.PathCoords then
			-- Reached the end of the path, force a new check
			Data.AutoRecompute = true
		end
	end
end

function Monster:TryJumpCheck()
	if tick() - Data.LastJumpCheck > 1/Info.JumpCheckFrequency then
		Monster:JumpCheck()
	end
end

function Monster:TryAttack()
	if tick() - Data.LastAttack > 1/Settings.AttackFrequency.Value then
		Monster:Attack()
	end
end

function Monster:Attack()
	local myPos, targetPos = Monster:GetCFrame().p, Monster:GetTargetCFrame().p
	
	if (myPos - targetPos).magnitude <= Settings.AttackRange.Value then
		Mind.CurrentTargetHumanoid.Value:TakeDamage(Settings.AttackDamage.Value)
		Data.LastAttack = tick()
		Data.AttackTrack:Play()
	end
end

function Monster:JumpCheck()
	-- Do a raycast to check if we need to jump
	local myCFrame = Monster:GetCFrame()
	local checkVector = (Monster:GetTargetCFrame().p - myCFrame.p).unit*2
	
	local hit, pos = Workspace:FindPartOnRay(
		Ray.new(
			myCFrame.p + Vector3.new(0, -2.4, 0),
			checkVector
		),
		Self
	)
	
	if hit ~= nil and not hit:IsDescendantOf(Mind.CurrentTargetHumanoid.Value.Parent) then
		-- Do a slope check to make sure we're not walking up a ramp
		
		local hit2, pos2 = Workspace:FindPartOnRay(
			Ray.new(
				myCFrame.p + Vector3.new(0, -2.3, 0),
				checkVector
			),
			Self
		)
		
		if hit2 == hit then
			if ((pos2 - pos)*Vector3.new(1,0,1)).magnitude < 0.05 then -- Will pass for any ramp with <2 slope
				Self.Humanoid.Jump = true
			end
		end
	end
	
	Data.LastJumpCheck = tick()
end

function Monster:Connect()
	Mind.CurrentTargetHumanoid.Changed:connect(function(humanoid)
		if humanoid ~= nil then
			assert(humanoid:IsA'Humanoid', 'Monster target must be a humanoid')
			
			Monster:RecomputePath()
		end
	end)
	
	Self.Respawn.OnInvoke = function(point)
		Monster:Respawn(point)
	end
end

function Monster:Initialize()
	Monster:Connect()
	
	if Settings.AutoDetectSpawnPoint.Value then
		Settings.SpawnPoint.Value = Monster:GetCFrame().p
	end
end

function Monster:Respawn(point)
	local point = point or Settings.SpawnPoint.Value
	
	for index, obj in next, Data.BaseMonster:Clone():GetChildren() do
		if obj.Name == 'Configurations' or obj.Name == 'Mind' or obj.Name == 'Respawned' or obj.Name == 'Died' or obj.Name == 'MonsterScript' or obj.Name == 'Respawn' then
			obj:Destroy()
		else
			Self[obj.Name]:Destroy()
			obj.Parent = Self
		end
	end
	
	Monster:InitializeUnique()
	
	Self.Parent = Workspace
	
	Self.HumanoidRootPart.CFrame = CFrame.new(point)
	Settings.SpawnPoint.Value = point
	Self.Respawned:Fire()
end

function Monster:InitializeUnique()
	Data.AttackTrack = Self.Humanoid:LoadAnimation(script.Attack)
end

function Monster:ReevaluateTarget()
	local currentTarget = Mind.CurrentTargetHumanoid.Value
	
	if currentTarget ~= nil and currentTarget:IsA'Humanoid' then
		local character = currentTarget.Parent
		
		if character ~= nil then
			local player = Info.Players:GetPlayerFromCharacter(character)
			
			if player ~= nil then
				if not player.Neutral and player.TeamColor == Settings.FriendlyTeam.Value then
					Mind.CurrentTargetHumanoid.Value = nil
				end
			end
		end
		
		
		if currentTarget == Mind.CurrentTargetHumanoid.Value then
			local torso = currentTarget.Torso
			
			if torso ~= nil and torso:IsA 'BasePart' then
				if Settings.CanGiveUp.Value and (torso.Position - Monster:GetCFrame().p).magnitude > Monster:GetMaximumDetectionDistance() then
					Mind.CurrentTargetHumanoid.Value = nil
				end
			end
		end
	end
end

--
--
Monster:Initialize()
Monster:InitializeUnique()

while true do
	if not Monster:IsAlive() then
		if Data.IsDead == false then
			Data.IsDead = true
			Data.TimeOfDeath = tick()
			Self.Died:Fire()
		end
		if Data.IsDead == true then
			if tick()-Data.TimeOfDeath > Info.RespawnWaitTime then
				Monster:Respawn()
			end
		end
	end
	
	if Monster:IsAlive() then
		Monster:Update()
	end
	
	wait()
end