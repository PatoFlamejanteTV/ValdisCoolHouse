--- This will cause a brick to go in motion unanchored or not! ---

while true do
wait()
for i= 1, 7 do
script.Parent.CFrame = script.Parent.CFrame * CFrame.new(0.0,0.0,-0.1)
wait()
end
for i= 1, 7 do
script.Parent.CFrame = script.Parent.CFrame * CFrame.new(0.0,0.0,0.1)
wait()
end
end