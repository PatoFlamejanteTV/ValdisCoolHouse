--DO NOT DESTROY. THIS IS CRUTIAL FOR THE CLASSIC TOPBAR.

a = game.Players.LocalPlayer.PlayerGui
b = a:WaitForChild("RobloxGui")
c = b:WaitForChild("TopBarContainer")
d = c:WaitForChild("Chat")
e = c:WaitForChild("Settings")

d:Destroy()
e:Destroy()
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu,false)
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false)