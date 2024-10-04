function onTouched(hit)
	if not hit or not hit.Parent then return end
	local human = hit.Parent:findFirstChild("Humanoid")
	if human and human:IsA("Humanoid") then
		game:GetService("ReplicatedStorage").OST.passport_mid_HIGH_QUALITY:Stop()
		--game:GetService("ReplicatedStorage").OST.passport_mid_HIGH_QUALITY:Destroy()

	end
end

script.Parent.Touched:connect(onTouched)