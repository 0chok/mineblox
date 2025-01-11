--!strict

local ChunkRenderer = {}

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

local Player: Player = Players.LocalPlayer
local PlayerScripts = Player.PlayerScripts

local Modules = PlayerScripts:WaitForChild('Modules')

local ChunksData = require(Modules.Chunks.Data.ChunksData)
local ChunkSettings = require(ReplicatedStorage.Shared.ChunkSettings)
local ChunksUtil = require(ReplicatedStorage.Shared.ChunksUtil)
local ItemsData = require(ReplicatedStorage.Shared.ItemsData)
local BlocksRecycler = require(ReplicatedStorage.Shared.BlocksRecycler)

local CHUNK_SIZE: number = ChunkSettings['CHUNK_SIZE']
local BLOCK_SIZE: number = ChunkSettings['BLOCK_SIZE']

local AIR_ID: number = ItemsData['Air']['ID']

local ChunkParts = {} :: {[string]:{BasePart}}

local BLOCK_NEIGHBOUR_VECTORS = 
	{
		Vector3.new(0, 0, BLOCK_SIZE),
		Vector3.new(0, 0, -BLOCK_SIZE),
		Vector3.new(BLOCK_SIZE, 0, 0),
		Vector3.new(-BLOCK_SIZE, 0, 0),
		Vector3.new(0, BLOCK_SIZE, 0),
		Vector3.new(0, -BLOCK_SIZE, 0),
	}

-- PRIVATE

local function createBlock(blockId, x, z, y, chunkX, chunkZ, chunkY): BasePart
	local new = BlocksRecycler.RequestBlock()
	
	new.Transparency = 0
	new:PivotTo(CFrame.new((Vector3.new(x,y,z)+Vector3.new(chunkX, chunkY, chunkZ)*CHUNK_SIZE)*BLOCK_SIZE))
	new.BrickColor = BrickColor.palette(blockId)
	return new
end

local function GetAirExposed(chunkX: number, chunkZ: number, chunkY: number, x: number, z: number, y: number): boolean
	local worldPosition = ChunksUtil.chunkToWorldPosition(chunkX, chunkZ, chunkY, x, z, y)
	
	for i, offsetVector in BLOCK_NEIGHBOUR_VECTORS do
		local neighborWorldPosition = worldPosition + offsetVector
		
		local neighbour = ChunksUtil.worldToChunkPosition(neighborWorldPosition)
		
		local bufferPosition = ChunksUtil.chunkToBufferPosition(neighbour.x, neighbour.z, neighbour.y)

		if buffer.readu8(ChunksData[neighbour.chunkX][neighbour.chunkZ][neighbour.chunkY]['buffer'], bufferPosition) == AIR_ID then
			return true
		end
	end
	return false
end

-- PUBLIC

function ChunkRenderer.renderChunk(chunkX: number, chunkZ: number, chunkY: number): ()	
	local loadedChunkBlocks: buffer = ChunksData[chunkX][chunkZ][chunkY]['buffer']
	
	local PartList = {}
	
	for x = 1, CHUNK_SIZE do
		local bufferPositionX = (x - 1) * CHUNK_SIZE
		
		for z = 1, CHUNK_SIZE do
			local bufferPositionZ = (z - 1) * CHUNK_SIZE * CHUNK_SIZE

			for y = 1, CHUNK_SIZE do
				local blockId = buffer.readu8(loadedChunkBlocks, bufferPositionX + bufferPositionZ + (y - 1))
				if 
					not blockId
					or blockId == AIR_ID
				then 
					continue 
				end

				if GetAirExposed(chunkX, chunkZ, chunkY, x, z, y) then
					local newFace = createBlock(blockId, x, z, y, chunkX, chunkZ, chunkY)
					table.insert(PartList, newFace)
				end
			end
		end
	end

	if #PartList ~= 0 then 
		ChunkParts[`{chunkX}x{chunkZ}x{chunkY}`] = PartList
	end
end

function ChunkRenderer.unrenderChunk(chunkX: number, chunkZ: number, chunkY: number): ()
	local chunk = ChunkParts[`{chunkX}x{chunkZ}x{chunkY}`]
	if chunk then
		BlocksRecycler.ReturnBlocks(chunk)
		ChunkParts[`{chunkX}x{chunkZ}x{chunkY}`] = nil
	end
end

return ChunkRenderer