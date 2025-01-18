local Break = {}

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local UserInputService = game:GetService('UserInputService')

local Player: Player = Players.LocalPlayer
local PlayerScripts = Player.PlayerScripts

local Modules = PlayerScripts:WaitForChild('Modules')

local ChunksData = require(Modules.Chunks.Data.ChunksData)
local ChunkRenderer = require(Modules.Chunks.Rendering.ChunkRenderer)
local ChunkSettings = require(ReplicatedStorage.Shared.ChunkSettings)
local ChunksUtil = require(ReplicatedStorage.Shared.ChunksUtil)
local ItemsData = require(ReplicatedStorage.Shared.ItemsData)

local mouse: Mouse = Player:GetMouse()
local camera: Camera = workspace.CurrentCamera

local BLOCK_SIZE: number = ChunkSettings.BLOCK_SIZE
local CHUNK_SIZE: number = ChunkSettings.CHUNK_SIZE

local AIR_ID: number = ItemsData['Air']['ID']

-- PRIVATE

local function roundToNearest(value: number, snap: number): number
	return math.round(value / snap) * snap
end


local function handleInputBegan(input: InputObject, typing: boolean): ()
	if 
		typing 
		or input.UserInputType ~= Enum.UserInputType.MouseButton1
		or not Player.Character
	then
		return
	end
	
	local rayOrigin = camera.CFrame.Position
	local rayDirection = mouse.UnitRay.Direction 
	
	local lastRoundedPosition = nil

	-- Keep raycasting with increments
	for i = 1, 150 do
		local location = rayOrigin + rayDirection * (i / 10)
		local roundedPosition = Vector3.new(
			roundToNearest(location.X, BLOCK_SIZE),
			roundToNearest(location.Y, BLOCK_SIZE),
			roundToNearest(location.Z, BLOCK_SIZE)
		)
		
		if roundedPosition == lastRoundedPosition then
			continue
		end
		
		local Posinfo = ChunksUtil.worldToChunkPosition(roundedPosition)
		local chunkPosition = Posinfo.chunk
		local posInChunk = Posinfo.pos
		local x = posInChunk.x
		local z = posInChunk.z
		local y = math.clamp(posInChunk.y, 0, CHUNK_SIZE)
		
		if not ChunksData[chunkPosition.X][chunkPosition.Z][chunkPosition.Y] then continue end

		local bufferPosition = ChunksUtil.chunkToBufferPosition(x, z, y)
		
		local blockId = buffer.readu8(ChunksData[chunkPosition.X][chunkPosition.Z][chunkPosition.Y]['buffer'], bufferPosition)
		
		if blockId ~= AIR_ID then
			buffer.writeu8(ChunksData[chunkPosition.X][chunkPosition.Z][chunkPosition.Y]['buffer'], bufferPosition, AIR_ID)
			local toRerender = {chunkPosition}
			
			if x == 1 then
				table.insert(toRerender, chunkPosition + Vector3.new(0 - 1, 0, 0))
			elseif x == CHUNK_SIZE then
				table.insert(toRerender, chunkPosition + Vector3.new(0 + 1, 0, 0))
			end
			if y == 1 then
				table.insert(toRerender, chunkPosition + Vector3.new(0, 0 - 1, 0))
			elseif y == CHUNK_SIZE then
				table.insert(toRerender, chunkPosition + Vector3.new(0, 0 + 1, 0))
			end
			if z == 1 then
				table.insert(toRerender, chunkPosition + Vector3.new(0, 0, 0 - 1))
			elseif z == CHUNK_SIZE then
				table.insert(toRerender, chunkPosition + Vector3.new(0, 0, 0 + 1))
			end
			
			for _, chunk in toRerender do
				ChunkRenderer.unrenderChunk(chunk)
				ChunkRenderer.renderChunk(chunk)
			end
			return
		end
		
		lastRoundedPosition = roundedPosition
	end
end

-- EVENTS

UserInputService.InputBegan:Connect(handleInputBegan)

return Break