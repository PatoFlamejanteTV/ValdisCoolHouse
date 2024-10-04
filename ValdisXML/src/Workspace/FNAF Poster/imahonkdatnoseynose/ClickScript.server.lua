clicks = 0
script.Parent.ClickDetector.MouseClick:connect(function()
script.Parent.Sound:Play()
clicks += 1
if clicks > 49 then -- 50 is bigger than 49, so...
	-- give badge
	local player = game.Players:FindFirstChild(script.Parent.ClickDetector.Parent.Parent.Name)
		game:GetService("BadgeService"):AwardBadge(player.UserId, 912611511314842)
	script.Parent.Victory:Play() -- "tada" ahh sound effect :cry emoji:
	script.Parent.Parent["FNaF 1 Celebrate Poster"].Poster.Anchored = false	
end
end)