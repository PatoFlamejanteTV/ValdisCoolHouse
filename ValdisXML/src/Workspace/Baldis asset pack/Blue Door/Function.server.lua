local function Touch(part)
local parent = part.Parent
local Door = script.Parent.DoorMain
if game.Players:GetPlayerFromCharacter(parent)then
	script.open.Playing = true -- open SFX
	script.Disabled = true
	Door.Open:Play()
	Door.ClosedFront.Transparency = 1
	Door.ClosedBack.Transparency = 1
	Door.OpenFront.Transparency = 0
	Door.OpenBack.Transparency = 0
	wait(game:GetService("Lighting").Config.DoorDelayAnim.Value)
	Door.Close:Play()
	Door.ClosedFront.Transparency = 0
	Door.ClosedBack.Transparency = 0
	Door.OpenFront.Transparency = 1
	Door.OpenBack.Transparency = 1
	script.Disabled = false
end
end
script.Parent.DoorMain.Touched:connect(Touch)