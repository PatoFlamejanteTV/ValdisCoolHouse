--[[
	// FileName: ChatSelector.lua
	// Written by: Xsitsu
	// Description: Code for determining which chat version to use in game.
]]

local FORCE_IS_CONSOLE = false
local FORCE_IS_VR = false

local CoreGuiService = script.Parent.Parent.Parent
local RobloxGui = CoreGuiService:WaitForChild("RobloxGui")
local Modules = RobloxGui:WaitForChild("Modules")

local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Players = game:GetService("Players")

local Util = require(RobloxGui.Modules.ChatUtil)

local ClassicChatEnabled = Players.ClassicChat
local BubbleChatEnabled = Players.BubbleChat

local useModule = nil

local state = {Visible = true}
local interface = {}
do
	function interface:ToggleVisibility()
		if (useModule) then
			useModule:ToggleVisibility()
		else
			state.Visible = not state.Visible
		end
	end

	function interface:SetVisible(visible)
		if (useModule) then
			useModule:SetVisible(visible)
		else
			state.Visible = visible
		end
	end

	function interface:FocusChatBar()
		if (useModule) then
			useModule:FocusChatBar()
		end
	end

	function interface:EnterWhisperState(player)
		if useModule then
			return useModule:EnterWhisperState(player)
		end
	end

	function interface:GetVisibility()
		if (useModule) then
			return useModule:GetVisibility()
		else
			return state.Visible
		end
	end

	function interface:GetMessageCount()
		if (useModule) then
			return useModule:GetMessageCount()
		else
			return 0
		end
	end

	function interface:TopbarEnabledChanged(...)
		if (useModule) then
			return useModule:TopbarEnabledChanged(...)
		end
	end

	function interface:IsFocused(useWasFocused)
		if (useModule) then
			return useModule:IsFocused(useWasFocused)
		else
			return false
		end
	end

	function interface:ClassicChatEnabled()
		if useModule then
			return useModule:ClassicChatEnabled()
		else
			return ClassicChatEnabled
		end
	end

	function interface:IsBubbleChatOnly()
		if useModule then
			return useModule:IsBubbleChatOnly()
		end
		return BubbleChatEnabled and not ClassicChatEnabled
	end

	function interface:IsDisabled()
		if useModule then
			return useModule:IsDisabled()
		end
		return not (BubbleChatEnabled or ClassicChatEnabled)
	end

	interface.ChatBarFocusChanged = Util.Signal()
	interface.VisibilityStateChanged = Util.Signal()
	interface.MessagesChanged = Util.Signal()

	-- Signals that are called when we get information on if Bubble Chat and Classic chat are enabled from the chat.
	interface.BubbleChatOnlySet = Util.Signal()
	interface.ChatDisabled = Util.Signal()
end

return interface
