--!nocheck

--[[
	// FileName: Topbar.lua
	// Written by: SolarCrane
	// Description: Code for lua side Top Menu items in ROBLOX.
]]
local accountTypeText
local laccountTypeTextShort

--[[ FFLAG VALUES ]]
local FFlagCoreScriptNoPosthumousHurtOverlay = true

local FFlagUseRoactPlayerList = false
local FFlagEmotesMenuEnabled2 = false

local FFlagTenFootInterface = false

--[[ END OF FFLAG VALUES ]]

--[[ SERVICES ]]

local PlayersService = game:GetService('Players')
local GuiService = game:GetService('GuiService')
local InputService = game:GetService('UserInputService')
local MarketplaceService game:GetService("MarketplaceService")
local StarterGui = game:GetService('StarterGui')
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService('RunService')
local TextService = game:GetService('TextService')
local ChatService = game:GetService('Chat')
local VRService = game:GetService('VRService')
local CorePackages = game:GetService('CorePackages')

--[[ END OF SERVICES ]]

local FFlagDisableAutoTranslateForKeyTranslatedContent = false

local topbarEnabled = true
local topbarEnabledChangedEvent = Instance.new('BindableEvent')

StarterGui:SetCore("TopbarEnabled", true)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)

local function isTopbarEnabled()
	return topbarEnabled and not VRService.VREnabled
end

-- Registers a placeholder setcore function that keeps track of players enabling/disabling the topbar before it's ready.
function _G.SetTopbarEnabled(enabled)
	if type(enabled) == "boolean" then
		topbarEnabled = enabled
	end
end

--[[ MODULES ]]--
local GuiRoot = script.Parent
local TopbarConstants = require(GuiRoot.Modules.TopbarConstants)
local Utility = require(GuiRoot.Modules.Utility)
local PolicyService = game:GetService("PolicyService")
local EmotesModule

local FFlagEmotesMenuShowUiOnlyWhenAvailable
if FFlagEmotesMenuEnabled2 then
	EmotesModule = require(GuiRoot.Modules.EmotesMenu.EmotesMenuMaster)
	FFlagEmotesMenuShowUiOnlyWhenAvailable = game:GetFastFlag("EmotesMenuShowUiOnlyWhenAvailable", false)
end

--[[ END OF MODULES ]]

local settingsActive = false

local GameSettings = UserSettings().GameSettings
local Player = PlayersService.LocalPlayer
while not Player do
	PlayersService.ChildAdded:wait()
	Player = PlayersService.LocalPlayer
end

local canChat = ChatService:CanUserChatAsync(Player.UserId)

local acccccountttage = game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(game.Players.LocalPlayer)
if acccccountttage.AreAdsAllowed == true then

accountTypeText = "Account: 13+"
accountTypeTextShort = "13+"
else
	accountTypeText = "Account: <13"
	accountTypeTextShort = "<13"
end

local TenFootInterface = nil
local isTenFootInterface = GuiService:IsTenFootInterface()

local Util = {}
do
	-- Check if we are running on a touch device
	function Util.IsTouchDevice()
		return InputService.TouchEnabled
	end

	function Util.IsSmallTouchScreen()
		local screenResolution = workspace.CurrentCamera.ViewportSize
		return InputService.TouchEnabled and (screenResolution.Y < 500 or screenResolution.X < 700)
	end

	function Util.Create(instanceType)
		return function(data)
			local obj = Instance.new(instanceType)
			for k, v in pairs(data) do
				if type(k) == 'number' then
					v.Parent = obj
				else
					obj[k] = v
				end
			end
			return obj
		end
	end

	function Util.Clamp(low, high, input)
		return math.max(low, math.min(high, input))
	end

	function Util.DisconnectEvent(conn)
		if conn then
			conn:disconnect()
		end
		return nil
	end

	function Util.SetGUIInsetBounds(x1, y1, x2, y2)
		-- GuiService:SetGlobalGuiInset(x1, y1, x2, y2)
		if GuiRoot:FindFirstChild("GuiInsetChanged") then
			GuiRoot.GuiInsetChanged:Fire(x1, y1, x2, y2)
		end
	end

	function Util.IsSubjectToChinaPolicies()
		local result, policyInfo = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(Player)
		end)
		if not result then
			warn("PolicyService error: " .. policyInfo)
			return false
		elseif policyInfo.IsSubjectToChinaPolicies then
			return true
		end
		return false
	end

	local humanoidCache = {}
	function Util.FindPlayerHumanoid(player)
		local character = player and player.Character
		if character then
			local resultHumanoid = humanoidCache[player]
			if resultHumanoid and resultHumanoid.Parent == character then
				return resultHumanoid
			else
				humanoidCache[player] = nil -- Bust Old Cache
				for _, child in pairs(character:GetChildren()) do
					if child:IsA('Humanoid') then
						humanoidCache[player] = child
						return child
					end
				end
			end
		end
	end
	
	function Util.onResized(viewportSize, portrait)
		local textSize = 0
		if portrait then
			textSize = 16
		else
			textSize = isTenFootInterface() and 36 or 24
		end
	end
end

local function CreateTopBar()
	local this = {}

	local playerGuiChangedConn = nil

	local topbarContainer = Util.Create'Frame'{
		Name = "TopBarContainer";
		Size = UDim2.new(1, 0, 0, TopbarConstants.TOPBAR_THICKNESS);
		Position = UDim2.new(0, 0, 0, -TopbarConstants.TOPBAR_THICKNESS);
		BackgroundTransparency = TopbarConstants.TOPBAR_OPAQUE_TRANSPARENCY;
		BackgroundColor3 = TopbarConstants.TOPBAR_BACKGROUND_COLOR;
		BorderSizePixel = 0;
		Active = true;
		Parent = GuiRoot;
		AutoLocalize = not FFlagDisableAutoTranslateForKeyTranslatedContent;
	};

	local topbarShadow = Util.Create'ImageLabel'{
		Name = "TopBarShadow";
		Size = UDim2.new(1, 0, 0, 3);
		Position = UDim2.new(0, 0, 1, 0);
		Image = "rbxasset://textures/ui/TopBar/dropshadow.png";
		BackgroundTransparency = 1;
		Active = false;
		Visible = false;
		Parent = topbarContainer;
	};

	local function ComputeTransparency()
		if not isTopbarEnabled() then
			return 1
		end

		local playerGui = Player:FindFirstChild('PlayerGui')
		if playerGui then
			return playerGui:GetTopbarTransparency()
		end

		return TopbarConstants.TOPBAR_TRANSLUCENT_TRANSPARENCY
	end

	function this:UpdateBackgroundTransparency()
		if settingsActive and not VRService.VREnabled then
			topbarContainer.BackgroundTransparency = TopbarConstants.TOPBAR_OPAQUE_TRANSPARENCY
			topbarShadow.Visible = false
		else
			topbarContainer.BackgroundTransparency = ComputeTransparency()
			topbarContainer.Active = (topbarContainer.BackgroundTransparency ~= 1)
			topbarShadow.Visible = (topbarContainer.BackgroundTransparency == 0)
		end
	end

	function this:GetInstance()
		return topbarContainer
	end

	spawn(function()
		local playerGui = Player:WaitForChild('PlayerGui', 86400) or Player:WaitForChild('PlayerGui')
		playerGuiChangedConn = Util.DisconnectEvent(playerGuiChangedConn)
		pcall(function()
			playerGuiChangedConn = playerGui.TopbarTransparencyChangedSignal:connect(this.UpdateBackgroundTransparency)
		end)
		this:UpdateBackgroundTransparency()
	end)

	return this
end


local BarAlignmentEnum =
{
	Right = 0;
	Left = 1;
	Middle = 2;
}

local function CreateMenuBar(barAlignment)
	local this = {}
	local thickness = TopbarConstants.TOPBAR_THICKNESS
	local alignment = barAlignment or BarAlignmentEnum.Right
	local items = {}
	local propertyChangedConnections = {}
	local dock = nil

	function this:ArrangeItems()
		local totalWidth = 0

		local spacing = TopbarConstants.ITEM_SPACING
		if InputService.VREnabled then
			spacing = TopbarConstants.VR_ITEM_SPACING
		end

		for i, item in ipairs(items) do
			local width = item:GetWidth()

			if alignment == BarAlignmentEnum.Left then
				item.Position = UDim2.new(0, totalWidth, 0, 0)
			elseif alignment == BarAlignmentEnum.Right then
				item.Position = UDim2.new(1, -totalWidth - width, 0, 0)
			end

			if i ~= #items then
				width = width + spacing
			end

			totalWidth = totalWidth + width
		end

		if alignment == BarAlignmentEnum.Middle then
			local currentX = -totalWidth / 2
			for _, item in ipairs(items) do
				item.Position = UDim2.new(0, currentX, 0, 0)

				currentX = currentX + item:GetWidth() + spacing
			end
		end

		return totalWidth
	end

	function this:GetThickness()
		return thickness
	end

	function this:GetNumberOfItems()
		return #items
	end

	function this:SetDock(newDock)
		dock = newDock
		for _, item in pairs(items) do
			item.Parent = dock
		end
	end

	function this:IndexOfItem(searchItem)
		for index, item in pairs(items) do
			if item == searchItem then
				return index
			end
		end
		return nil
	end

	function this:ItemAtIndex(index)
		return items[index]
	end

	function this:GetItems()
		return items
	end

	function this:AddItem(item, index)
		local numItems = self:GetNumberOfItems()
		index = Util.Clamp(1, numItems + 1, (index or numItems + 1))

		local alreadyFoundIndex = self:IndexOfItem(item)
		if alreadyFoundIndex then
			return item, index
		end

		table.insert(items, index, item)
		Util.DisconnectEvent(propertyChangedConnections[item])
		propertyChangedConnections[item] = item.Changed:connect(function(property)
			if property == 'AbsoluteSize' then
				self:ArrangeItems()
			end
		end)
		self:ArrangeItems()

		if dock then
			item.Parent = dock
		end

		return item, index
	end

	function this:RemoveItem(item)
		local index = self:IndexOfItem(item)
		if index then
			local removedItem = table.remove(items, index)

			removedItem.Parent = nil
			Util.DisconnectEvent(propertyChangedConnections[removedItem])

			self:ArrangeItems()
			return removedItem, index
		end
	end


	return this
end

local function CreateMenuChangedNotifier()
	local this = {}
	local notifier3D = require(GuiRoot.Modules.VR.NotifierHint3D)

	function this:PromptNotification()
		-- Don't show the notification if we are looking down at the menubar already
		notifier3D:BeginNotification(notifier3D.DEFAULT_DURATION)
	end

	Player.FriendStatusChanged:connect(function(fromPlayer, friendStatus)
		if friendStatus == Enum.FriendStatus.FriendRequestReceived then
			this:PromptNotification()
		end
	end)

	local function findScreenGuiAncestor(object)
		if not object then
			return nil
		end
		local parent = object.Parent
		if parent and parent:IsA('ScreenGui') then
			return parent
		end
		return findScreenGuiAncestor(parent)
	end

	InputService.TextBoxFocused:connect(function(textbox)
		local myScreenGui = findScreenGuiAncestor(textbox)
		local myScreenGuiParent = myScreenGui and myScreenGui.Parent
		if myScreenGuiParent and myScreenGuiParent:IsA('PlayerGui') then
			this:PromptNotification()
		end
	end)

	return this
end


local function CreateMenuItem(origInstance)
	local this = {}
	local instance = origInstance

	function this:SetInstance(newInstance)
		if not instance then
			instance = newInstance
		else
			print("Trying to set an Instance of a Menu Item that already has an instance; doing nothing.")
		end
	end

	function this:GetWidth()
		return self.Size.X.Offset
	end

	-- We are extending a regular instance.
	do
		local mt =
		{
			__index = function (t, k)
				return instance[k]
			end;

			__newindex = function (t, k, v)
				--if instance[k] ~= nil then
					instance[k] = v
				--else
				--	rawset(t, k, v)
				--end
			end;
		}
		setmetatable(this, mt)
	end

	return this
end

local function createNormalHealthBar()
	local container = Util.Create'ImageButton'
	{
		Name = "NameHealthContainer";
		Size = UDim2.new(0, TopbarConstants.USERNAME_CONTAINER_WIDTH, 1, 0);
		AutoButtonColor = false;
		Image = "";
		BackgroundTransparency = 1;
	}

	local username = Util.Create'TextLabel'{
		Name = "Username";
		Text = Player.Name;
		Size = UDim2.new(1, -14, 0, 18);
		Position = UDim2.new(0, 7, 0, 0);
		Font = Enum.Font.SourceSansBold;
		FontSize = Enum.FontSize.Size14;
		BackgroundTransparency = 1;
		TextColor3 = TopbarConstants.FONT_COLOR;
		TextYAlignment = Enum.TextYAlignment.Bottom;
		TextXAlignment = Enum.TextXAlignment.Left;
		Parent = container;
	};


	local accountType = Util.Create'TextLabel'{
		Name = "AccountType";
		Text = accountTypeText;
		Size = UDim2.new(1, -14, 0, 9);
		Position = UDim2.new(0, 7, 0, 20);
		Font = Enum.Font.SourceSans;
		TextSize = 11;
		BackgroundTransparency = 1;
		TextColor3 = TopbarConstants.FONT_COLOR;
		TextYAlignment = Enum.TextYAlignment.Bottom;
		TextXAlignment = Enum.TextXAlignment.Left;
		Parent = container;
	};

	spawn(function()
		wait()
		accountType.Text = accountTypeText
	end)

	local healthContainer = Util.Create'Frame'{
		Name = "HealthContainer";
		Size = UDim2.new(1, -14, 0, 3);
		Position = UDim2.new(0, 7, 1, -7);
		BorderSizePixel = 0;
		BackgroundColor3 = TopbarConstants.HEALTH_BACKGROUND_COLOR;
		Parent = container;
	};

	local healthFill = Util.Create'Frame'{
		Name = "HealthFill";
		Size = UDim2.new(1, 0, 1, 0);
		BorderSizePixel = 0;
		BackgroundColor3 = TopbarConstants.HEALTH_GREEN_COLOR;
		Parent = healthContainer;
	};

	local function onResized(viewportSize, isPortrait)
		if isPortrait then
			username.TextXAlignment = Enum.TextXAlignment.Right
			accountType.TextXAlignment = Enum.TextXAlignment.Right
			container.Size = UDim2.new(0.3, 0, 1, 0)
			container.AnchorPoint = Vector2.new(1, 0)
		else
			username.TextXAlignment = Enum.TextXAlignment.Left
			accountType.TextXAlignment = Enum.TextXAlignment.Left
			container.Size = UDim2.new(0, TopbarConstants.USERNAME_CONTAINER_WIDTH, 1, 0)
			container.AnchorPoint = Vector2.new(0, 0)
		end
	end
	Utility:OnResized(container, onResized)

	return container, username, healthContainer, healthFill, accountType
end

----- HEALTH -----
local function CreateUsernameHealthMenuItem()

	local container, username, healthContainer, healthFill = nil

	if isTenFootInterface and FFlagTenFootInterface then
		container, username, healthContainer, healthFill, accountType = TenFootInterface:CreateHealthBar()
	else
		container, username, healthContainer, healthFill, accountType = createNormalHealthBar()
	end

	local hurtOverlayImage = TopbarConstants.HURT_OVERLAY_IMAGE
	if Util.IsSubjectToChinaPolicies() then
		hurtOverlayImage = TopbarConstants.HURT_OVERLAY_IMAGE_WHITE
	end
	local hurtOverlay = Util.Create'ImageLabel'
	{
		Name = "HurtOverlay";
		BackgroundTransparency = 1;
		Image = hurtOverlayImage;
		Position = UDim2.new(-10,0,-10,0);
		Size = UDim2.new(20,0,20,0);
		Visible = false;
		Parent = GuiRoot;
	};

	local this = CreateMenuItem(container)

	--- EVENTS ---
	local humanoidHealthChangedConn
	local humanoidDiedConn
	local childAddedConn
	local childRemovedConn
	--------------

	local HealthBarEnabled = true
	local NameEnabled = true
	local CurrentHumanoid = nil

	local function AnimateHurtOverlay()
		if hurtOverlay and not VRService.VREnabled and StarterGui:GetCoreGuiEnabled("Health") then
			local newSize = UDim2.new(20, 0, 20, 0)
			local newPos = UDim2.new(-10, 0, -10, 0)

			if hurtOverlay:IsDescendantOf(game) then
				-- stop any tweens on overlay
				hurtOverlay:TweenSizeAndPosition(newSize, newPos, Enum.EasingDirection.Out, Enum.EasingStyle.Linear, 0, true, function()
					-- show the gui
					hurtOverlay.Size = UDim2.new(1,0,1,0)
					hurtOverlay.Position = UDim2.new(0,0,0,0)
					hurtOverlay.Visible = true
					-- now tween the hide
					if hurtOverlay:IsDescendantOf(game) then
						hurtOverlay:TweenSizeAndPosition(newSize, newPos, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 10, false, function()
							hurtOverlay.Visible = false
						end)
					else
						hurtOverlay.Size = newSize
						hurtOverlay.Position = newPos
					end
				end)
			end
		end
	end

	local healthColorToPosition = {
		[Vector3.new(TopbarConstants.HEALTH_RED_COLOR.r,
      TopbarConstants.HEALTH_RED_COLOR.g,
      TopbarConstants.HEALTH_RED_COLOR.b)] = 0.1;
		[Vector3.new(TopbarConstants.HEALTH_YELLOW_COLOR.r,
      TopbarConstants.HEALTH_YELLOW_COLOR.g,
      TopbarConstants.HEALTH_YELLOW_COLOR.b)] = 0.5;
		[Vector3.new(TopbarConstants.HEALTH_GREEN_COLOR.r,
      TopbarConstants.HEALTH_GREEN_COLOR.g,
      TopbarConstants.HEALTH_GREEN_COLOR.b)] = 0.8;
	}
	local min = 0.1
	local minColor = TopbarConstants.HEALTH_RED_COLOR
	local max = 0.8
	local maxColor = TopbarConstants.HEALTH_GREEN_COLOR

	local function HealthbarColorTransferFunction(healthPercent)
		if healthPercent < min then
			return minColor
		elseif healthPercent > max then
			return maxColor
		end

		-- Shepard's Interpolation
		local numeratorSum = Vector3.new(0,0,0)
		local denominatorSum = 0
		for colorSampleValue, samplePoint in pairs(healthColorToPosition) do
			local distance = healthPercent - samplePoint
			if distance == 0 then
				-- If we are exactly on an existing sample value then we don't need to interpolate
				return Color3.new(colorSampleValue.x, colorSampleValue.y, colorSampleValue.z)
			else
				local wi = 1 / (distance*distance)
				numeratorSum = numeratorSum + wi * colorSampleValue
				denominatorSum = denominatorSum + wi
			end
		end
		local result = numeratorSum / denominatorSum
		return Color3.new(result.x, result.y, result.z)
	end

	local function UpdateHealthVisible()
		local isEnabled = HealthBarEnabled and CurrentHumanoid and CurrentHumanoid.Health ~= CurrentHumanoid.MaxHealth
		healthContainer.Visible = isEnabled
	end

	local function OnHumanoidAdded(humanoid)
		CurrentHumanoid = humanoid
		local lastHealth = humanoid.Health
		local isDead = false

		local function OnHumanoidHealthChanged(health)
			UpdateHealthVisible()
			if humanoid then
				local healthDelta = lastHealth - health
				local maxHealth = humanoid.MaxHealth
				local healthPercent = health / maxHealth
				if maxHealth <= 0 then
					healthPercent = 0
				end
				healthPercent = math.clamp(healthPercent, 0, 1)
				local healthColor = HealthbarColorTransferFunction(healthPercent)
				local thresholdForHurtOverlay = maxHealth * TopbarConstants.HEALTH_PERCANTAGE_FOR_OVERLAY

				if FFlagCoreScriptNoPosthumousHurtOverlay then
					if healthDelta >= thresholdForHurtOverlay and health ~= maxHealth and not isDead then
						AnimateHurtOverlay()
					end
				else
					if healthDelta >= thresholdForHurtOverlay and health ~= humanoid.MaxHealth then
						AnimateHurtOverlay()
					end
				end

				healthFill.Size = UDim2.new(healthPercent, 0, 1, 0)
				healthFill.BackgroundColor3 = healthColor

				lastHealth = health
			end
		end

		local function OnHumanoidDied()
			Util.DisconnectEvent(humanoidDiedConn)
			humanoidDiedConn = nil
			isDead = true
		end

		Util.DisconnectEvent(humanoidHealthChangedConn)
		humanoidHealthChangedConn = humanoid.HealthChanged:Connect(OnHumanoidHealthChanged)

		if FFlagCoreScriptNoPosthumousHurtOverlay then
			Util.DisconnectEvent(humanoidDiedConn)
			humanoidDiedConn = humanoid.Died:Connect(OnHumanoidDied)
		end

		OnHumanoidHealthChanged(lastHealth)
	end

	local function OnCharacterAdded(character)
		local humanoid = Util.FindPlayerHumanoid(Player)
		if humanoid then
			OnHumanoidAdded(humanoid)
		end

		local function onChildAddedOrRemoved()
			local tempHumanoid = Util.FindPlayerHumanoid(Player)
			if tempHumanoid and tempHumanoid ~= humanoid then
				humanoid = tempHumanoid
				OnHumanoidAdded(humanoid)
			end
		end
		Util.DisconnectEvent(childAddedConn)
		Util.DisconnectEvent(childRemovedConn)
		childAddedConn = character.ChildAdded:connect(onChildAddedOrRemoved)
		childRemovedConn = character.ChildRemoved:connect(onChildAddedOrRemoved)
	end

	local function UpdateContainerEnabled()
		if HealthBarEnabled or NameEnabled then
			container.Visible = true
			container.Active = true
		else
			container.Visible = false
			container.Active = false
		end
	end

	rawset(this, "SetHealthbarEnabled",
		function(self, enabled)
			HealthBarEnabled = enabled
			UpdateHealthVisible()
			UpdateContainerEnabled()
		end)

	rawset(this, "SetNameVisible",
		function(self, visible)
			NameEnabled = visible
			username.Visible = visible
			accountType.Visible = visible
			UpdateContainerEnabled()
		end)

	-- Don't need to disconnect this one because we never reconnect it.
	Player.CharacterAdded:connect(OnCharacterAdded)
	if Player.Character then
		OnCharacterAdded(Player.Character)
	end

	if FFlagUseRoactPlayerList then
		local PlayerListMaster = require(GuiRoot.Modules.PlayerList.PlayerListManager)
		container.MouseButton1Click:connect(function()
			if isTopbarEnabled() then
				PlayerListMaster:SetVisibility(not PlayerListMaster:GetVisibility())
			end
		end)
	else
		local PlayerlistModule = require(GuiRoot.Modules.PlayerlistModule)
		container.MouseButton1Click:connect(function()
			if isTopbarEnabled() then
				PlayerlistModule.ToggleVisibility()
			end
		end)
	end

	return this
end
----- END OF HEALTH -----

----- LEADERSTATS -----

local function CreateLeaderstatsMenuItem()
	local leaderstatsContainer = Util.Create'ImageButton'
	{
		Name = "LeaderstatsContainer";
		Size = UDim2.new(0, 0, 1, 0);
		AutoButtonColor = false;
		Image = "";
		BackgroundTransparency = 1;
	};

	local this = CreateMenuItem(leaderstatsContainer)
	--Remove with FFlagUseRoactPlayerList
	local columns = {}

	rawset(this, "SetColumns",
		function(self, columnsList)
			-- Should we handle is the screen dimensions change and it is no longer a small touch device after we set columns?
			local isSmallTouchDevice = Util.IsSmallTouchScreen()
			local numColumns = #columnsList

			-- Destroy old columns
			for _, oldColumn in pairs(columns) do
				oldColumn:Destroy()
			end
			columns = {}
			-- End destroy old columns
			local count = 0
			for index, columnData in pairs(columnsList) do  -- i = 1, numColumns do
				if not isSmallTouchDevice or index <= 1 then
					local columnName = columnData.Name
					local columnValue = columnData.Text

					local columnNameLabel = Util.Create'TextLabel'
					{
						Name = "ColumnName";
						Size = UDim2.new(1, 0, 0, 10);
						Position = UDim2.new(0, 0, 0, 4);
						Text = columnName;
						Font = Enum.Font.SourceSans;
						FontSize = Enum.FontSize.Size14;
						BorderSizePixel = 0;
						BackgroundTransparency = 1;
						TextColor3 = TopbarConstants.FONT_COLOR;
						TextYAlignment = Enum.TextYAlignment.Center;
						TextXAlignment = Enum.TextXAlignment.Center;
					}


					local columnframe = Util.Create'Frame'
					{
						Name = "Column" .. tostring(index);
						Size = UDim2.new(0, TopbarConstants.COLUMN_WIDTH + (index == numColumns and 0 or TopbarConstants.NAME_LEADERBOARD_SEP_WIDTH), 1, 0);
						Position = UDim2.new(0, TopbarConstants.NAME_LEADERBOARD_SEP_WIDTH + (TopbarConstants.COLUMN_WIDTH + TopbarConstants.NAME_LEADERBOARD_SEP_WIDTH) * (index-1),  0, 0);
						BackgroundTransparency = 1;
						Parent = leaderstatsContainer;

						columnNameLabel;

						Util.Create'TextLabel'
						{
							Name = "ColumnValue";
							Text = columnValue;
							Size = UDim2.new(1, 0, 0, 10);
							Position = UDim2.new(0, 0, 0, 19);
							Font = Enum.Font.SourceSansBold;
							FontSize = Enum.FontSize.Size14;
							BorderSizePixel = 0;
							BackgroundTransparency = 1;
							TextColor3 = TopbarConstants.FONT_COLOR;
							TextYAlignment = Enum.TextYAlignment.Center;
							TextXAlignment = Enum.TextXAlignment.Center;
						};
					};
					columns[columnName] = columnframe
					count = count + 1
				end
			end
			leaderstatsContainer.Size = UDim2.new(0,
        TopbarConstants.COLUMN_WIDTH * count + TopbarConstants.NAME_LEADERBOARD_SEP_WIDTH * count,
        1, 0)
		end)

	rawset(this, "UpdateColumnValue",
		function(self, columnName, value)
			local column = columns[columnName]
			local columnValue = column and column:FindFirstChild('ColumnValue')
			if columnValue then
				columnValue.Text = tostring(value)
			end
		end)


	if FFlagUseRoactPlayerList then
		local PlayerListMaster = require(GuiRoot.Modules.PlayerList.PlayerListManager)
		topbarEnabledChangedEvent.Event:connect(function(enabled)
			PlayerListMaster:SetTopBarEnabled(enabled)
		end)

		leaderstatsContainer.MouseButton1Click:connect(function()
			if isTopbarEnabled() then
				PlayerListMaster:SetVisibility(not PlayerListMaster:GetVisibility())
			end
		end)
	else
		local PlayerlistModule = require(GuiRoot.Modules.PlayerlistModule)
		topbarEnabledChangedEvent.Event:connect(function(enabled)
			PlayerlistModule.TopbarEnabledChanged(enabled and not VRService.VREnabled) --We don't show the playerlist at all in VR
		end)

		this:SetColumns(PlayerlistModule.GetStats())
		PlayerlistModule.OnLeaderstatsChanged.Event:connect(function(newStatColumns)
			if not Utility:IsPortrait() then
				this:SetColumns(newStatColumns)
			end
		end)

		PlayerlistModule.OnStatChanged.Event:connect(function(statName, statValueAsString)
			this:UpdateColumnValue(statName, statValueAsString)
		end)

		leaderstatsContainer.MouseButton1Click:connect(function()
			if isTopbarEnabled() then
				PlayerlistModule.ToggleVisibility()
			end
		end)
	end

	return this
end
----- END OF LEADERSTATS -----

--- SETTINGS ---
local function CreateSettingsIcon(topBarInstance)
	
	local settingsIconButton = Util.Create'ImageButton'
	{
		Name = "Settings";
		Size = UDim2.new(0, 50, 0, TopbarConstants.TOPBAR_THICKNESS);
		Image = "";
		AutoButtonColor = false;
		BackgroundTransparency = 1;
	}

	local settingsIconImage = Util.Create'ImageLabel'
	{
		Name = "SettingsIcon";
		Size = UDim2.new(0, 32, 0, 25);
		Position = UDim2.new(0.5, -16, 0.5, -12);
		BackgroundTransparency = 1;
		Image = "rbxasset://textures/ui/Menu/Hamburger.png";
		Parent = settingsIconButton;
	};

	local function UpdateHamburgerIcon()
		if settingsActive then
			settingsIconImage.Image = "rbxasset://textures/ui/Menu/HamburgerDown.png";
		else
			settingsIconImage.Image = "rbxasset://textures/ui/Menu/Hamburger.png";
		end
	end

	local function toggleSettings()
		if settingsActive == false then
			settingsActive = true
		else
			settingsActive = false
		end

		-- MenuModule:ToggleVisibility()
		UpdateHamburgerIcon()

		return settingsActive
	end

	settingsIconButton.MouseButton1Click:connect(function() toggleSettings() end)

	GuiService.MenuOpened:connect(function()
		settingsActive = true
		topBarInstance:UpdateBackgroundTransparency()
		UpdateHamburgerIcon()
	end)

	GuiService.MenuClosed:connect(function()
		settingsActive = false
		topBarInstance:UpdateBackgroundTransparency()
		UpdateHamburgerIcon()
	end)

	local menuItem = CreateMenuItem(settingsIconButton)

	rawset(menuItem, "SetTransparency", function(self, transparency)
		settingsIconImage.ImageTransparency = transparency
	end)
	rawset(menuItem, "SetImage", function(self, image)
		settingsIconImage.Image = image
	end)
	rawset(menuItem, "SetSettingsActive", function(self, active)
		settingsActive = active
		-- MenuModule:ToggleVisibility(settingsActive)
		UpdateHamburgerIcon()

		return settingsActive
	end)

	return menuItem
end


------------

--- CHAT ---
local function CreateUnreadMessagesNotifier(ChatModule)
	local chatActive = false
	local lastMessageCount = 0

	local chatCounter = Util.Create'ImageLabel'
	{
		Name = "ChatCounter";
		Size = UDim2.new(0, 18, 0, 18);
		Position = UDim2.new(1, -12, 0, -4);
		BackgroundTransparency = 1;
		Image = "rbxasset://textures/ui/Chat/MessageCounter.png";
		Visible = false;
	};

	local chatCountText = Util.Create'TextLabel'
	{
		Name = "ChatCounterText";
		Text = '';
		Size = UDim2.new(0, 13, 0, 9);
		Position = UDim2.new(0.5, -7, 0.5, -7);
		Font = Enum.Font.SourceSansBold;
		FontSize = Enum.FontSize.Size14;
		BorderSizePixel = 0;
		BackgroundTransparency = 1;
		TextColor3 = TopbarConstants.FONT_COLOR;
		TextYAlignment = Enum.TextYAlignment.Center;
		TextXAlignment = Enum.TextXAlignment.Center;
		Parent = chatCounter;
	};

	local function OnUnreadMessagesChanged(count)
		if chatActive then
			lastMessageCount = count
		end
		local unreadCount = count - lastMessageCount

		if unreadCount <= 0 then
			chatCountText.Text = ""
			chatCounter.Visible = false
		else
			if unreadCount < 100 then
				chatCountText.Text = tostring(unreadCount)
			else
				chatCountText.Text = "!"
			end
			chatCounter.Visible = true
		end
	end

	local function onChatStateChanged(visible)
		chatActive = visible
		if ChatModule then
			OnUnreadMessagesChanged(ChatModule:GetMessageCount())
		end
	end


	if ChatModule then
		if ChatModule.VisibilityStateChanged then
			ChatModule.VisibilityStateChanged:connect(onChatStateChanged)
		end
		if ChatModule.MessagesChanged then
			ChatModule.MessagesChanged:connect(OnUnreadMessagesChanged)
		end

		onChatStateChanged(ChatModule:GetVisibility())
		OnUnreadMessagesChanged(ChatModule:GetMessageCount())
	end

	return chatCounter
end

local function GetChatIcon(chatIconName)
    if pcall(function() MarketplaceService:PlayerOwnsAsset(Player, 102611803) end) then
        return "rbxasset://textures/ui/Chat/" .. chatIconName .. "Flip.png"
    else
        return "rbxasset://textures/ui/Chat/" .. chatIconName .. ".png"
    end
end

local function CreateChatIcon()
	local chatEnabled = canChat
	if not chatEnabled then return end

	local ChatModule = require(GuiRoot.Modules.ChatSelector)


	local chatIconButton = Util.Create'ImageButton'
	{
		Name = "Chat";
		Size = UDim2.new(0, 50, 0, TopbarConstants.TOPBAR_THICKNESS);
		Image = "";
		AutoButtonColor = false;
		BackgroundTransparency = 1;
	};

	local chatIconImage = Util.Create'ImageLabel'
	{
		Name = "ChatIcon";
		Size = UDim2.new(0, 28, 0, 27);
		Position = UDim2.new(0.5, -14, 0.5, -13);
		BackgroundTransparency = 1;
        Image = GetChatIcon("Chat");
		Parent = chatIconButton;
	};
	local chatCounter = CreateUnreadMessagesNotifier(ChatModule)
    chatCounter.Parent = chatIconImage

	local function updateIcon(down)
		if down then
			chatIconImage.Image = GetChatIcon("ChatDown")
		else
			chatIconImage.Image = GetChatIcon("Chat")
		end
	end

	local function onChatStateChanged(visible)
		updateIcon(visible)
        ChatVisible = visible
	end

	topbarEnabledChangedEvent.Event:connect(function(enabled)
		ChatModule:TopbarEnabledChanged(enabled)
	end)

	chatIconButton.MouseButton1Click:connect(function()
		ChatModule:ToggleVisibility()
	end)

	if ChatModule.ChatBarFocusChanged then
		ChatModule.ChatBarFocusChanged:connect(function(isFocused)
			updateIcon(isFocused)
		end)
	end

	updateIcon(false)

	if ChatModule.BubbleChatOnlySet then
		ChatModule.BubbleChatOnlySet:connect(function()
			if ChatModule:IsBubbleChatOnly() then
				updateIcon(false)
			else
				updateIcon(true)
			end
		end)
	end

	if ChatModule.VisibilityStateChanged then
		ChatModule.VisibilityStateChanged:connect(onChatStateChanged)
	end

	if not VRService.VREnabled then
		-- check to see if the chat was disabled
		local willEnableChat = true
        willEnableChat = ChatVisible
		if Util.IsSmallTouchScreen() then
			willEnableChat = false
		end
		ChatModule:SetVisible(willEnableChat)
	end

	local menuItem = CreateMenuItem(chatIconButton)

	rawset(menuItem, "ToggleChat", function(self)
		ChatModule:ToggleVisibility()
	end)
	rawset(menuItem, "SetTransparency", function(self, transparency)
		chatIconImage.ImageTransparency = transparency
	end)
	rawset(menuItem, "SetImage", function(self, newImage)
		chatIconImage.Image = newImage
	end)

	return menuItem
end

local function CreateMobileHideChatIcon()
	local ChatModule = require(GuiRoot.Modules.ChatSelector)

	local chatHideIconButton = Util.Create'ImageButton'
	{
		Name = "ChatVisible";
		Size = UDim2.new(0, 50, 0, TopbarConstants.TOPBAR_THICKNESS);
		Image = "";
		AutoButtonColor = false;
		BackgroundTransparency = 1;
	};

	local chatIconImage = Util.Create'ImageLabel'
	{
		Name = "ChatVisibleIcon";
		Size = UDim2.new(0, 28, 0, 27);
		Position = UDim2.new(0.5, -14, 0.5, -13);
		BackgroundTransparency = 1;
        Image = GetChatIcon("ToggleChat");
		Parent = chatHideIconButton;
	};

	local unreadMessageNotifier = CreateUnreadMessagesNotifier(ChatModule)
	unreadMessageNotifier.Parent = chatIconImage

	local function updateIcon(down)
		if down then
			chatIconImage.Image = GetChatIcon("ToggleChatDown")
		else
			chatIconImage.Image = GetChatIcon("ToggleChat")
		end
	end


	local function onChatStateChanged(visible)
		updateIcon(visible)
	end

	chatHideIconButton.MouseButton1Click:connect(function()
		ChatModule:ToggleVisibility()
        ChatVisible = ChatModule:GetVisibility()
	end)

	if ChatModule.VisibilityStateChanged then
		ChatModule.VisibilityStateChanged:connect(onChatStateChanged)
	end
	onChatStateChanged(ChatModule:GetVisibility())

	return CreateMenuItem(chatHideIconButton)
end




-----------

--- Backpack ---
local function CreateBackpackIcon()
	local BackpackModule = require(GuiRoot.Modules.BackpackScript)

	local backpackIconButton = Util.Create'ImageButton'
	{
		Name = "Backpack";
		Size = UDim2.new(0, 50, 0, TopbarConstants.TOPBAR_THICKNESS);
		Image = "";
		AutoButtonColor = false;
		BackgroundTransparency = 1;
	};

	local backpackIconImage = Util.Create'ImageLabel'
	{
		Name = "BackpackIcon";
		Size = UDim2.new(0, 22, 0, 28);
		Position = UDim2.new(0.5, -11, 0.5, -14);
		BackgroundTransparency = 1;
		Image = "rbxasset://textures/ui/Backpack/Backpack.png";
		Parent = backpackIconButton;
	};

	local function onBackpackStateChanged(open)
		if open then
			backpackIconImage.Image = "rbxasset://textures/ui/Backpack/Backpack_Down.png";
		else
			backpackIconImage.Image = "rbxasset://textures/ui/Backpack/Backpack.png";
		end
	end

	BackpackModule.StateChanged.Event:connect(onBackpackStateChanged)

	local function toggleBackpack()
		BackpackModule:OpenClose()
	end

	topbarEnabledChangedEvent.Event:connect(function(enabled)
		BackpackModule:TopbarEnabledChanged(enabled)
	end)

	backpackIconButton.MouseButton1Click:connect(function()
		BackpackModule:OpenClose()
	end)

	return CreateMenuItem(backpackIconButton)
end
--------------

--- Emotes ---
local function CreateEmotesIcon()
	if not FFlagEmotesMenuEnabled2 then
		return
	end

	local emotesIconButton = Util.Create'ImageButton'
	{
		Name = "Emotes";
		Size = UDim2.new(0, 50, 0, TopbarConstants.TOPBAR_THICKNESS);
		Image = "";
		AutoButtonColor = false;
		BackgroundTransparency = 1;
	};

	local emotesIconImage = Util.Create'ImageLabel'
	{
		Name = "EmotesIcon";
		AnchorPoint = Vector2.new(0.5, 0.5);
		Size = UDim2.new(0, 22, 0, 28);
		Position = UDim2.new(0.5, 0, 0.5, 0);
		BackgroundTransparency = 1;
		Image = "rbxasset://textures/ui/Emotes/EmotesIcon.png";
		Parent = emotesIconButton;
	};

	local function onEmotesMenuToggled(open)
		if open then
			emotesIconImage.ImageColor3 = Color3.fromRGB(003, 162, 245)
		else
			emotesIconImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	EmotesModule.EmotesMenuToggled.Event:connect(onEmotesMenuToggled)

	local function toggleEmotesMenu()
		if EmotesModule:isOpen() then
			EmotesModule:close()
		else
			EmotesModule:open()
		end
	end

	topbarEnabledChangedEvent.Event:connect(function(enabled)
		EmotesModule:setTopBarEnabled(enabled)
	end)

	emotesIconButton.Activated:connect(function()
		toggleEmotesMenu()
	end)

	return CreateMenuItem(emotesIconButton)
end
--------------

----- Stop Recording --
local function CreateStopRecordIcon()
	local stopRecordIconButton = Util.Create'ImageButton'
	{
		Name = "StopRecording";
		Size = UDim2.new(0, 50, 0, TopbarConstants.TOPBAR_THICKNESS);
		Image = "";
		Visible = true;
		BackgroundTransparency = 1;
	};
	stopRecordIconButton.Activated:Connect(function()
		-- CoreGuiService:ToggleRecording()
	end)

	local stopRecordIconLabel = Util.Create'ImageLabel'
	{
		Name = "StopRecordingIcon";
		Size = UDim2.new(0, 28, 0, 28);
		Position = UDim2.new(0.5, -14, 0.5, -14);
		BackgroundTransparency = 1;
		Image = "rbxasset://textures/ui/RecordDown.png";
		Parent = stopRecordIconButton;
	};

	return CreateMenuItem(stopRecordIconButton)
end
-----------------------




local function CreateNoTopBarAccountType()
	local container = Util.Create'ImageButton'
	{
		Name = "AccountTypeContainer";
		Size = UDim2.new(0, 0, 0, 0);
		AutoButtonColor = false;
		Image = "";
		BackgroundTransparency = 1;
	}

	local accountTypeTextLabel = Util.Create'TextLabel'{
		Name = "AccountTypeText";
		Text = accountTypeTextShort;
		Size = UDim2.new(1, -12, 1, -12);
		Position = UDim2.new(0, 0, 0, 6);
		Font = Enum.Font.SourceSansBold;
		FontSize = Enum.FontSize.Size14;
		BackgroundTransparency = 1;
		TextColor3 = TopbarConstants.FONT_COLOR;
		TextYAlignment = Enum.TextYAlignment.Center;
		TextXAlignment = Enum.TextXAlignment.Left;
		Parent = container;
	};

	spawn(function()
		wait()
		accountTypeTextLabel.Text = accountTypeTextShort
		if container.Visible then
			local textBounds = accountTypeTextLabel.TextBounds.X
			local containerSize = textBounds
			container.Size = UDim2.new(0, containerSize, 1, 0)
		end
	end)

	local function UpdateNoTopBarAccountType()
		if isTopbarEnabled() or VRService.VREnabled then
			container.Visible = false
			container.Size = UDim2.new(0, 0, 0, 0)
		else
			container.Visible = true
			local textBounds = accountTypeTextLabel.TextBounds.X
			local containerSize = textBounds
			container.Size = UDim2.new(0, containerSize, 1, 0)
		end
	end

	topbarEnabledChangedEvent.Event:connect(UpdateNoTopBarAccountType)
	VRService:GetPropertyChangedSignal("VREnabled"):Connect(UpdateNoTopBarAccountType)
	UpdateNoTopBarAccountType()

	local menuItem = CreateMenuItem(container)

	return menuItem
end

------------------------

local TopBar = CreateTopBar()
local LeftMenubar = CreateMenuBar(BarAlignmentEnum.Left)
local RightMenubar = CreateMenuBar(BarAlignmentEnum.Right)

local settingsIcon = CreateSettingsIcon(TopBar)

local noTopBarAccountType = nil

if isTenFootInterface and FFlagTenFootInterface then
	spawn(function()
		wait()
		calculateAccountText()
		TenFootInterface:CreateAccountType(accountTypeTextShort)
	end)
elseif not isTenFootInterface then
	noTopBarAccountType = CreateNoTopBarAccountType()
end

local chatIcon = CreateChatIcon()
local backpackIcon = CreateBackpackIcon()
local emotesIcon = CreateEmotesIcon()
local stopRecordingIcon = CreateStopRecordIcon()

local leaderstatsMenuItem = CreateLeaderstatsMenuItem()
local nameAndHealthMenuItem = CreateUsernameHealthMenuItem()

local menuChangedNotifier3D = nil

local LEFT_ITEM_ORDER = {}
local RIGHT_ITEM_ORDER = {}


-- Set Item Orders
if settingsIcon then
	LEFT_ITEM_ORDER[settingsIcon] = 1
end
if noTopBarAccountType then
	LEFT_ITEM_ORDER[noTopBarAccountType] = 2
end
if chatIcon then
	LEFT_ITEM_ORDER[chatIcon] = 4
end
if backpackIcon then
	LEFT_ITEM_ORDER[backpackIcon] = 5
end
if emotesIcon then
	LEFT_ITEM_ORDER[emotesIcon] = 6
end
if stopRecordingIcon then
	LEFT_ITEM_ORDER[stopRecordingIcon] = 7
end

if leaderstatsMenuItem then
	RIGHT_ITEM_ORDER[leaderstatsMenuItem] = 1
end
if nameAndHealthMenuItem and not isTenFootInterface and not FFlagTenFootInterface then
	RIGHT_ITEM_ORDER[nameAndHealthMenuItem] = 2
end

-------------------------


local function AddItemInOrder(Bar, Item, ItemOrder)
	local index = 1
	while ItemOrder[Bar:ItemAtIndex(index)] and ItemOrder[Bar:ItemAtIndex(index)] < ItemOrder[Item] do
		index = index + 1
	end
	Bar:AddItem(Item, index)
end

local ChatModule = require(GuiRoot.Modules.ChatSelector)

local function OnCoreGuiChanged(coreGuiType, coreGuiEnabled)
	local enabled = coreGuiEnabled and topbarEnabled
	if coreGuiType == Enum.CoreGuiType.PlayerList or coreGuiType == Enum.CoreGuiType.All then
		if leaderstatsMenuItem then
			if enabled then
				AddItemInOrder(RightMenubar, leaderstatsMenuItem, RIGHT_ITEM_ORDER)
			else
				RightMenubar:RemoveItem(leaderstatsMenuItem)
			end
		end
	end
	if coreGuiType == Enum.CoreGuiType.Health or coreGuiType == Enum.CoreGuiType.All then
		if nameAndHealthMenuItem then
			nameAndHealthMenuItem:SetHealthbarEnabled(enabled)
		end
	end
	if coreGuiType == Enum.CoreGuiType.Backpack or coreGuiType == Enum.CoreGuiType.All then
		if backpackIcon then
			if enabled then
				AddItemInOrder(LeftMenubar, backpackIcon, LEFT_ITEM_ORDER)
			else
				LeftMenubar:RemoveItem(backpackIcon)
			end
		end
	end

	if FFlagEmotesMenuEnabled2 and not EmotesModule.MenuVisibilityChanged then
		if coreGuiType == Enum.CoreGuiType.EmotesMenu or coreGuiType == Enum.CoreGuiType.All then
			if enabled then
				AddItemInOrder(LeftMenubar, emotesIcon, LEFT_ITEM_ORDER)
			else
				LeftMenubar:RemoveItem(emotesIcon)
			end
		end
	end

	if coreGuiType == Enum.CoreGuiType.Chat or coreGuiType == Enum.CoreGuiType.All then
		enabled = enabled and (not ChatModule:IsDisabled())
		local ChatSelector = require(GuiRoot.Modules.ChatSelector)
		local showTopbarChatIcon = enabled

		if showTopbarChatIcon then
			if Util.IsTouchDevice() or ChatModule:IsBubbleChatOnly() then
				if chatIcon and canChat then
					AddItemInOrder(LeftMenubar, chatIcon, LEFT_ITEM_ORDER)
				end
			else
				if chatIcon then
					AddItemInOrder(LeftMenubar, chatIcon, LEFT_ITEM_ORDER)
				end
			end
		else
			if chatIcon then
				LeftMenubar:RemoveItem(chatIcon)
		end
		end
	end

	if nameAndHealthMenuItem then
		local playerListOn = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
		local healthbarOn = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Health)
		-- Left-align the player's name if either playerlist or healthbar is shown
		nameAndHealthMenuItem:SetNameVisible(topbarEnabled)
	end
end

local function onEmotesMenuVisibilityChangedSignal(isVisible)
	if isVisible then
		AddItemInOrder(LeftMenubar, emotesIcon, LEFT_ITEM_ORDER)
	else
		LeftMenubar:RemoveItem(emotesIcon)
	end
end

if EmotesModule and FFlagEmotesMenuShowUiOnlyWhenAvailable then
	EmotesModule.MenuVisibilityChanged.Event:Connect(onEmotesMenuVisibilityChangedSignal)
	onEmotesMenuVisibilityChangedSignal(EmotesModule.MenuIsVisible)
end

local function OnChatModuleDisabled()
	if chatIcon then
		LeftMenubar:RemoveItem(chatIcon)
	end
end

if ChatModule.ChatDisabled then
	ChatModule.ChatDisabled:connect(function()
		OnChatModuleDisabled()
	end)
end

TopBar:UpdateBackgroundTransparency()

LeftMenubar:SetDock(TopBar:GetInstance())
RightMenubar:SetDock(TopBar:GetInstance())

if not isTenFootInterface and not FFlagTenFootInterface then
	Util.SetGUIInsetBounds(0, TopbarConstants.TOPBAR_THICKNESS, 0, 0)
end

if settingsIcon then
	AddItemInOrder(LeftMenubar, settingsIcon, LEFT_ITEM_ORDER)
end
if noTopBarAccountType and not isTenFootInterface and not FFlagTenFootInterface then
	AddItemInOrder(LeftMenubar, noTopBarAccountType, LEFT_ITEM_ORDER)
end
if nameAndHealthMenuItem and isTopbarEnabled() and not isTenFootInterface and not FFlagTenFootInterface then
	AddItemInOrder(RightMenubar, nameAndHealthMenuItem, RIGHT_ITEM_ORDER)
end
--[[
local gameOptions = settings():FindFirstChild("Game Options")
if gameOptions and not isTenFootInterface and not FFlagTenFootInterface then
	local success, result = pcall(function()
		gameOptions.VideoRecordingChangeRequest:connect(function(recording)
			if recording and isTopbarEnabled() then
				AddItemInOrder(LeftMenubar, stopRecordingIcon, LEFT_ITEM_ORDER)
			else
				LeftMenubar:RemoveItem(stopRecordingIcon)
			end
		end)
	end)
end
]]
local function topbarEnabledChanged()
	if VRService.VREnabled then
		Util.SetGUIInsetBounds(0, 0, 0, 0)
	else
		if not isTenFootInterface and not FFlagTenFootInterface then
			Util.SetGUIInsetBounds(0, TopbarConstants.TOPBAR_THICKNESS, 0, 0)
		end
	end


	topbarEnabledChangedEvent:Fire(topbarEnabled)
	TopBar:UpdateBackgroundTransparency()
	for _, enumItem in pairs(Enum.CoreGuiType:GetEnumItems()) do
		-- The All enum will be false if any of the coreguis are false
		-- therefore by force updating it we are clobbering the previous sets
		if enumItem ~= Enum.CoreGuiType.All then
			OnCoreGuiChanged(enumItem, StarterGui:GetCoreGuiEnabled(enumItem))
		end
	end
end

if FFlagUseRoactPlayerList then
	local function onResized(viewportSize, isPortrait)
		RightMenubar:ArrangeItems()
	end
	Utility:OnResized(leaderstatsMenuItem, onResized)
else
	--Temporarily disable the leaderstats while in portrait mode.
	--Will come back to this when a new design is ready.
	local PlayerlistModule = require(GuiRoot.Modules.PlayerlistModule)
	local function onResized(viewportSize, isPortrait)
		if isPortrait then
			leaderstatsMenuItem:SetColumns({})
		else
			leaderstatsMenuItem:SetColumns(PlayerlistModule.GetStats())
		end
		RightMenubar:ArrangeItems()
	end
	Utility:OnResized(leaderstatsMenuItem, onResized)
end

topbarEnabledChanged() -- if it was set before this point, enable/disable it now

spawn(function()
	local success, localUserCanChat = pcall(function()
		return ChatService:CanUserChatAsync(Player.UserId)
	end)
	canChat = RunService:IsStudio() or (success and localUserCanChat)
	if canChat == false then
		if Util.IsTouchDevice() or ChatModule:IsBubbleChatOnly() then
			if chatIcon then
				LeftMenubar:RemoveItem(chatIcon)
			end
		end
		ChatModule:SetVisible(false)
	end
end)

-- Hook-up coregui changing
OnCoreGuiChanged(Enum.CoreGuiType.All, true)
print("Loaded erazias's Old TopBar")