local Players = game:GetService('Players')

local Player: Player = Players.LocalPlayer
local PlayerScripts = Player.PlayerScripts

local Modules = PlayerScripts:WaitForChild('Modules')

local ForestGenerator = require(Modules.Chunks.Loading.Terrain.Biomes.Forest.ForestGenerator)

return {
	{
		temperature = {
			min = -1,
			max = 1
		},
		humidity = {
			min = -2,
			max = 0
		},
		biomeGenerator = ForestGenerator
	}
}