local Players = game:GetService('Players')
local StarterGui = game:GetService("StarterGui")
local Modules = Players.LocalPlayer.PlayerScripts:WaitForChild('Modules')

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

require(Modules.Chunks.ChunksManager)

task.delay(0, function()
	require(Modules.Break)
	require(Modules.CollisionsManager)
end)