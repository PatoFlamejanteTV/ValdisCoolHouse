local function Touch(part)
local parent = part.Parent
local Door = script.Parent.Elevator
if game.Players:GetPlayerFromCharacter(parent)then
	script.Disabled = true
	Door.Open:Play()
	Door.Texture1.Texture = "http://www.roblox.com/asset/?id=3657098163"
	Door.Texture2.Texture = "http://www.roblox.com/asset/?id=3657098163"
	wait(.1)
	Door.Texture1.Texture = "http://www.roblox.com/asset/?id=3657098553"
	Door.Texture2.Texture = "http://www.roblox.com/asset/?id=3657098553"
	wait(.1)
	Door.Texture1.Texture = "http://www.roblox.com/asset/?id=3657098940"
	Door.Texture2.Texture = "http://www.roblox.com/asset/?id=3657098940"
	wait(4)
	Door.Close:Play()
	Door.Texture1.Texture = "http://www.roblox.com/asset/?id=3657098940"
	Door.Texture2.Texture = "http://www.roblox.com/asset/?id=3657098940"
	wait(.1)
	Door.Texture1.Texture = "http://www.roblox.com/asset/?id=3657098553"
	Door.Texture2.Texture = "http://www.roblox.com/asset/?id=3657098553"
	wait(.1)
	Door.Texture1.Texture = "http://www.roblox.com/asset/?id=3657098163"
	Door.Texture2.Texture = "http://www.roblox.com/asset/?id=3657098163"
	wait(.1)
	Door.Texture1.Texture = "http://www.roblox.com/asset/?id=3657097652"
	Door.Texture2.Texture = "http://www.roblox.com/asset/?id=3657097652"
	script.Disabled = false
end
end
script.Parent.Sensor.Touched:connect(Touch)