--!nocheck

--[[
	// FileName: PlayerDropDown.lua
	// Written by: TheGamer101
	// Description: Code for the player drop down in the PlayerList and Chat
]]
local moduleApiTable = {}

local GuiService = game:GetService('GuiService')
local HttpService = game:GetService('HttpService')
local PlayersService = game:GetService('Players')
local CoreGui = PlayersService.LocalPlayer.PlayerGui
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxReplicatedStorage = ReplicatedStorage:WaitForChild('SocialEvents')

local LocalPlayer = PlayersService.LocalPlayer
while not LocalPlayer do
	PlayersService.PlayerAdded:wait()
	LocalPlayer = PlayersService.LocalPlayer
end

local recentApiRequests = -- stores requests for target players by userId
{
	Following = {};
}

local POPUP_ENTRY_SIZE_Y = 24
local ENTRY_PAD = 2
local BG_TRANSPARENCY = 0.5
local BG_COLOR = Color3.new(31/255, 31/255, 31/255)
local TEXT_STROKE_TRANSPARENCY = 0.75
local TEXT_COLOR = Color3.new(1, 1, 243/255)
local TEXT_STROKE_COLOR = Color3.new(34/255, 34/255, 34/255)
local MAX_FRIEND_COUNT = 200
local FRIEND_IMAGE = 'https://www.roblox.com/thumbs/avatar.ashx?userId='
local INSPECT_KEY = "InGame.InspectMenu.Action.View"

local GET_BLOCKED_USERIDS_TIMEOUT = 5

local BaseUrl = game:GetService("ContentProvider").BaseUrl:lower()
BaseUrl = string.gsub(BaseUrl, "http:", "https:")
local FriendCountUrl = string.gsub(BaseUrl, "www", "friends") .. "v1/users/{userId}/friends/count"

local RobloxGui = CoreGui:WaitForChild('RobloxGui')

local PolicyService = game:GetService("PolicyService")
local policyResult, policyInfo = pcall(function()
	return PolicyService:GetPolicyInfoForPlayerAsync(LocalPlayer)
end)

local inspectMenuEnabled = GuiService:GetInspectMenuEnabled()

local RemoteEvent_NewFollower = nil
local RemoteEvent_UpdatePlayerBlockList = nil

spawn(function()
	RemoteEvent_NewFollower = RobloxReplicatedStorage:WaitForChild('NewFollower', 86400) or RobloxReplicatedStorage:WaitForChild('NewFollower')
	RemoteEvent_UpdatePlayerBlockList = RobloxReplicatedStorage:WaitForChild('UpdatePlayerBlockList')
end)

local function iterPageItems(pages)
	return coroutine.wrap(function()
		local pagenum = 1
		while true do
			for _, item in ipairs(pages:GetCurrentPage()) do
				coroutine.yield(item, pagenum)
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
			pagenum = pagenum + 1
		end
	end)
end

local function createSignal()
	local sig = {}

	local mSignaler = Instance.new('BindableEvent')

	local mArgData = nil
	local mArgDataCount = nil

	function sig:fire(...)
		mArgData = {...}
		mArgDataCount = select('#', ...)
		mSignaler:Fire()
	end

	function sig:connect(f)
		if not f then error("connect(nil)", 2) end
		return mSignaler.Event:connect(function()
			f(unpack(mArgData, 1, mArgDataCount))
		end)
	end

	function sig:wait()
		mSignaler.Event:wait()
		assert(mArgData, "Missing arg data, likely due to :TweenSize/Position corrupting threadrefs.")
		return unpack(mArgData, 1, mArgDataCount)
	end

	return sig
end

local BlockStatusChanged = createSignal()
local MuteStatusChanged = createSignal()

local function sendNotification(title, text, image, duration, callback)
	pcall(function()
		StarterGui:SetCore('SendNotification',{
			Title = title,
			Text = text,
			Image = image,
			Duration = duration,
			Callback = callback
		})
	end)
end

local function getFriendStatus(selectedPlayer)
	if selectedPlayer == LocalPlayer then
		return Enum.FriendStatus.NotFriend
	else
		local success = LocalPlayer:IsFriendsWith(selectedPlayer.UserId)
		if success then
			return Enum.FriendStatus.Friend
		else
			return Enum.FriendStatus.NotFriend
		end
	end
end

-- if userId = nil, then it will get count for local player
local function getFriendCountAsync(userId)
	local friendCount = nil
	
	local friendPages = PlayersService:GetFriendsAsync(userId)

	friendCount = {}
	for item, pageNo in iterPageItems(friendPages) do
		table.insert(friendCount, item.Username)
	end

	return #friendCount
end

-- checks if we can send a friend request. Right now the only way we
-- can't is if one of the players is at the max friend limit
local function canSendFriendRequestAsync(otherPlayer)
	local theirFriendCount = getFriendCountAsync(otherPlayer.UserId)
	local myFriendCount = getFriendCountAsync()

	-- assume max friends if web call fails
	if not myFriendCount or not theirFriendCount then
		return false
	end
	if myFriendCount < MAX_FRIEND_COUNT and theirFriendCount < MAX_FRIEND_COUNT then
		return true
	elseif myFriendCount >= MAX_FRIEND_COUNT then
		sendNotification("Cannot send friend request", "You are at the max friends limit.", "", 5, function() end)
		return false
	elseif theirFriendCount >= MAX_FRIEND_COUNT then
		sendNotification("Cannot send friend request", otherPlayer.Name.." is at the max friends limit.", "", 5, function() end)
		return false
	end
end

local BlockedList = {}
local MutedList = {}

local function GetBlockedPlayersAsync()
	local userId = LocalPlayer.UserId
	local apiPath = "userblock/getblockedusers" .. "?" .. "userId=" .. tostring(userId) .. "&" .. "page=" .. "1"
	pcall(function()
		if userId > 0 then
			local blockedUserIds = StarterGui:GetCore("GetBlockedUserIds")
			if blockedUserIds then
				local returnList = {}
				for _, blockedUserId in ipairs(blockedUserIds) do
					returnList[blockedUserId] = true
				end
				return returnList
			end
		end
	end)
	return {}
end

local function getBlockedUserIdsFromBlockedList()
	local userIdList = {}
	for userId, _ in pairs(BlockedList) do
		table.insert(userIdList, userId)
	end
	return userIdList
end

local function getBlockedUserIds()
	if LocalPlayer.UserId > 0 then
		local timeWaited = 0
		while true do
			if GetBlockedPlayersCompleted then
				return getBlockedUserIdsFromBlockedList()
			end
			timeWaited = timeWaited + wait()
			if timeWaited > GET_BLOCKED_USERIDS_TIMEOUT then
				return {}
			end
		end
	end
	return {}
end

local function initializeBlockList()
	spawn(function()
		BlockedList = GetBlockedPlayersAsync()
		GetBlockedPlayersCompleted = true

		local RemoteEvent_SetPlayerBlockList = RobloxReplicatedStorage:WaitForChild('SetPlayerBlockList')
		local blockedUserIds = getBlockedUserIds()
		RemoteEvent_SetPlayerBlockList:FireServer(blockedUserIds)
	end)
end

local function isBlocked(userId)
	if (BlockedList[userId]) then
		return true
	end
	return false
end

local function isMuted(userId)
	if (MutedList[userId] ~= nil and MutedList[userId] == true) then
		return true
	end
	return false
end

local function BlockPlayerAsync(playerToBlock)
	if playerToBlock and LocalPlayer ~= playerToBlock then
		local blockUserId = playerToBlock.UserId
		if blockUserId > 0 then
			if not isBlocked(blockUserId) then
				BlockedList[blockUserId] = true
				BlockStatusChanged:fire(blockUserId, true)

				if RemoteEvent_UpdatePlayerBlockList then
					RemoteEvent_UpdatePlayerBlockList:FireServer(blockUserId, true)
				end

				local success, wasBlocked = pcall(function()
					StarterGui:SetCore('PromptBlockPlayer', playerToBlock)
				end)
				return success and wasBlocked
			else
				return true
			end
		end
	end
	return false
end

local function UnblockPlayerAsync(playerToUnblock)
	if playerToUnblock then
		local unblockUserId = playerToUnblock.UserId

		if isBlocked(unblockUserId) then
			BlockedList[unblockUserId] = nil
			BlockStatusChanged:fire(unblockUserId, false)

			if RemoteEvent_UpdatePlayerBlockList then
				RemoteEvent_UpdatePlayerBlockList:FireServer(unblockUserId, false)
			end

			local success, result = pcall(function()
				StarterGui:SetCore('PromptUnblockPlayer', playerToUnblock)
			end)
			return success and result
		else
			return true
		end
	end
	return false
end

local function MutePlayer(playerToMute)
	if playerToMute and LocalPlayer ~= playerToMute then
		local muteUserId = playerToMute.UserId
		if muteUserId > 0 then
			if not isMuted(muteUserId) then
				MutedList[muteUserId] = true
				MuteStatusChanged:fire(muteUserId, true)
			end
		end
	end
end

local function UnmutePlayer(playerToUnmute)
	if playerToUnmute then
		local unmuteUserId = playerToUnmute.UserId
		MutedList[unmuteUserId] = nil
		MuteStatusChanged:fire(unmuteUserId, false)
	end
end

function createPlayerDropDown()
	local playerDropDown = {}
	playerDropDown.Player = nil
	playerDropDown.PopupFrame = nil
	playerDropDown.HidePopupImmediately = false
	playerDropDown.PopupFrameOffScreenPosition = nil -- if this is set the popup frame tweens to a different offscreen position than the default

	playerDropDown.HiddenSignal = createSignal()

	--[[ Functions for when options in the dropdown are pressed ]]--
	local function onFriendButtonPressed()
		if playerDropDown.Player then
			local status = getFriendStatus(playerDropDown.Player)
			if status == Enum.FriendStatus.Friend then
				pcall(function()
					StarterGui:SetCore('PromptUnfriend', playerDropDown.Player)
				end)
			elseif status == Enum.FriendStatus.Unknown or status == Enum.FriendStatus.NotFriend then
				-- cache and spawn
				local cachedLastSelectedPlayer = playerDropDown.Player
				spawn(function()
					-- check for max friends before letting them send the request
					if canSendFriendRequestAsync(cachedLastSelectedPlayer) then 	-- Yields
						if cachedLastSelectedPlayer and cachedLastSelectedPlayer.Parent == PlayersService then
							pcall(function()
								StarterGui:SetCore('PromptSendFriendRequest', playerDropDown.Player)
							end)
						end
					end
				end)
			end

			playerDropDown:Hide()
		end
	end

	local function onDeclineFriendButonPressed()
		if playerDropDown.Player then
			pcall(function()
				StarterGui:SetCore('PromptUnfriend', playerDropDown.Player)
			end)
			playerDropDown:Hide()
		end
	end

	local function onBlockButtonPressed()
		if playerDropDown.Player then
			local cachedPlayer = playerDropDown.Player
			spawn(function()
				BlockPlayerAsync(cachedPlayer)
			end)
			playerDropDown:Hide()
		end
	end

	local function onUnblockButtonPressed()
		if playerDropDown.Player then
			local cachedPlayer = playerDropDown.Player
			spawn(function()
				UnblockPlayerAsync(cachedPlayer)
			end)
			playerDropDown:Hide()
		end
	end

	local function createPopupFrame(buttons)
		local frame = Instance.new('Frame')
		frame.Name = "PopupFrame"
		frame.Size = UDim2.new(1, 0, 0, (POPUP_ENTRY_SIZE_Y * #buttons) + (#buttons - ENTRY_PAD))
		frame.Position = UDim2.new(1, 1, 0, 0)
		frame.BackgroundTransparency = 1

		for i,button in ipairs(buttons) do
			local btn = Instance.new('TextButton')
			btn.Name = button.Name
			btn.Size = UDim2.new(1, 0, 0, POPUP_ENTRY_SIZE_Y)
			btn.Position = UDim2.new(0, 0, 0, POPUP_ENTRY_SIZE_Y * (i - 1) + ((i - 1) * ENTRY_PAD))
			btn.BackgroundTransparency = BG_TRANSPARENCY
			btn.BackgroundColor3 = BG_COLOR
			btn.BorderSizePixel = 0
			btn.Text = button.Text
			btn.Font = Enum.Font.SourceSans
			btn.FontSize = Enum.FontSize.Size14
			btn.TextColor3 = TEXT_COLOR
			btn.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
			btn.TextStrokeColor3 = TEXT_STROKE_COLOR
			btn.AutoButtonColor = true
			btn.Parent = frame

			btn.MouseButton1Click:connect(button.OnPress)
		end

		return frame
	end

	local TWEEN_TIME = 0.25

	local function onInspectButtonPressed()
		if not playerDropDown.Player or not inspectMenuEnabled then
			return
		end

		GuiService:InspectPlayerFromUserId(playerDropDown.Player.UserId)
		playerDropDown:Hide()
	end

	-- Checks if a player has at least one option for the player drop down list.
	function playerDropDown:HasOptions(selectedPlayer)
		local hasOptions =
			(selectedPlayer ~= LocalPlayer and selectedPlayer.UserId > 0 and LocalPlayer.UserId > 0) or
			(selectedPlayer == LocalPlayer and inspectMenuEnabled)
		return hasOptions
	end

	function playerDropDown:Hide()
		if playerDropDown.PopupFrame then
			local offscreenPosition = (playerDropDown.PopupFrameOffScreenPosition ~= nil and playerDropDown.PopupFrameOffScreenPosition or UDim2.new(1, 1, 0, playerDropDown.PopupFrame.Position.Y.Offset))
			if not playerDropDown.HidePopupImmediately then
				playerDropDown.PopupFrame:TweenPosition(offscreenPosition, Enum.EasingDirection.InOut,
					Enum.EasingStyle.Quad, TWEEN_TIME, true, function()
						if playerDropDown.PopupFrame then
							playerDropDown.PopupFrame:Destroy()
							playerDropDown.PopupFrame = nil
						end
					end)
			else
				playerDropDown.PopupFrame:Destroy()
				playerDropDown.PopupFrame = nil
			end
		end
		if playerDropDown.Player then
			playerDropDown.Player = nil
		end
		playerDropDown.HiddenSignal:fire()
	end

	function playerDropDown:CreatePopup(Player)
		playerDropDown.Player = Player

		local buttons = {}

		if Player == LocalPlayer and inspectMenuEnabled then
			table.insert(buttons, {
				Name = "InspectButton",
				Text = "View",
				OnPress = onInspectButtonPressed,
			})
		elseif Player ~= LocalPlayer then
			local status = getFriendStatus(playerDropDown.Player)
			local friendText = ""
			local canDeclineFriend = false
			if status == Enum.FriendStatus.Friend then
				friendText = "Unfriend Player"
			elseif status == Enum.FriendStatus.Unknown or status == Enum.FriendStatus.NotFriend then
				friendText = "Send Friend Request"
			elseif status == Enum.FriendStatus.FriendRequestSent then
				friendText = "Revoke Friend Request"
			elseif status == Enum.FriendStatus.FriendRequestReceived then
				friendText = "Accept Friend Request"
				canDeclineFriend = true
			end

			local blocked = isBlocked(playerDropDown.Player.UserId)

			if not blocked then
				table.insert(buttons, {
					Name = "FriendButton",
					Text = friendText,
					OnPress = onFriendButtonPressed,
					})
			end

			if canDeclineFriend and not blocked then
				table.insert(buttons, {
					Name = "DeclineFriend",
					Text = "Decline Friend Request",
					OnPress = onDeclineFriendButonPressed,
					})
			end

			local showPlayerBlocking = not policyInfo.IsSubjectToChinaPolicies

			if showPlayerBlocking then
				local blockedText = blocked and "Unblock Player" or "Block Player"
				table.insert(buttons, {
					Name = "BlockButton",
					Text = blockedText,
					OnPress = blocked and onUnblockButtonPressed or onBlockButtonPressed,
					})
			end

			if inspectMenuEnabled then
				table.insert(buttons, {
					Name = "InspectButton",
					Text = "View",
					OnPress = onInspectButtonPressed,
				})
			end
		end
		if playerDropDown.PopupFrame then
			playerDropDown.PopupFrame:Destroy()
		end
		playerDropDown.PopupFrame = createPopupFrame(buttons)
		return playerDropDown.PopupFrame
	end

	PlayersService.PlayerRemoving:connect(function(leavingPlayer)
		if playerDropDown.Player == leavingPlayer then
			playerDropDown:Hide()
		end
	end)

	return playerDropDown
end

--- GetCore Blocked/Muted/Friended events.

local PlayerBlockedEvent = Instance.new("BindableEvent")
local PlayerUnblockedEvent = Instance.new("BindableEvent")
local PlayerMutedEvent = Instance.new("BindableEvent")
local PlayerUnMutedEvent = Instance.new("BindableEvent")
local PlayerFriendedEvent = Instance.new("BindableEvent")
local PlayerUnFriendedEvent = Instance.new("BindableEvent")

BlockStatusChanged:connect(function(userId, isBlocked)
	local player = PlayersService:GetPlayerByUserId(userId)
	if player then
		if isBlocked then
			PlayerBlockedEvent:Fire(player)
		else
			PlayerUnblockedEvent:Fire(player)
		end
	end
end)

MuteStatusChanged:connect(function(userId, isMuted)
	local player = PlayersService:GetPlayerByUserId(userId)
	if player then
		if isMuted then
			PlayerMutedEvent:Fire(player)
		else
			PlayerUnMutedEvent:Fire(player)
		end
	end
end)

do
	moduleApiTable.FollowerStatusChanged = createSignal()

	function moduleApiTable:CreatePlayerDropDown()
		return createPlayerDropDown()
	end

	function moduleApiTable:GetFriendCountAsync(player)
		return getFriendCountAsync(player.UserId)
	end

	--Remove with FFlagUseRoactPlayerList
	function moduleApiTable:InitBlockListAsync()
		initializeBlockList()
	end

	function moduleApiTable:MaxFriendCount()
		return MAX_FRIEND_COUNT
	end

	function moduleApiTable:GetFriendStatus()
		return getFriendStatus()
	end

	--Remove with FFlagUseRoactPlayerList
	function moduleApiTable:CreateBlockingUtility()
		local blockingUtility = {}

		function blockingUtility:BlockPlayerAsync(player)
			return BlockPlayerAsync(player)
		end

		function blockingUtility:UnblockPlayerAsync(player)
			return UnblockPlayerAsync(player)
		end

		function blockingUtility:MutePlayer(player)
			return MutePlayer(player)
		end

		function blockingUtility:UnmutePlayer(player)
			return UnmutePlayer(player)
		end

		function blockingUtility:IsPlayerBlockedByUserId(userId)
			return isBlocked(userId)
		end

		function blockingUtility:GetBlockedStatusChangedEvent()
			return BlockStatusChanged
		end

		function blockingUtility:GetMutedStatusChangedEvent()
			return MuteStatusChanged
		end

		function blockingUtility:IsPlayerMutedByUserId(userId)
			return isMuted(userId)
		end

		function blockingUtility:GetBlockedUserIdsAsync()
			return getBlockedUserIds()
		end

		return blockingUtility
	end
end

return moduleApiTable
