-- 16895937395
--Hey developers out there, this was literally the easiest thing to make..
--I made this model because most of the models on the marketplace with disabling the camera's yaw rotation ended up
--going MAD on mobile, (which this model fixes) feel free to credit or delete these annotations, idc :3

--Credits to mystman12/Basically Games for baldi's basics anyway.. duh.
--Made by tedgoneandlol.

--Just don't reupload my model, it will be reported if published and credits in script is tampered with.
local cam = game.Workspace.CurrentCamera
local function check()
	cam.CFrame = CFrame.new(cam.CFrame.p, cam.CFrame.p + Vector3.new(cam.CFrame.lookVector.X, 0, cam.CFrame.lookVector.Z))
end
game:GetService("RunService").RenderStepped:Connect(check)