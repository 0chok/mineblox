local Players = game:GetService('Players')
local Modules = Players.LocalPlayer.PlayerScripts:WaitForChild('Modules')

require(Modules.Chunks.ChunksManager)

task.delay(.1, function()
	require(Modules.Break)
	require(Modules.CollisionsManager)
end)