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
local BlockFaceRecycler = require(ReplicatedStorage.Shared.BlockFaceRecycler)

local CHUNK_SIZE: number = ChunkSettings['CHUNK_SIZE']
local BLOCK_SIZE: number = ChunkSettings['BLOCK_SIZE']

local AIR_ID: number = ItemsData['Air']['ID']

local ChunkParts = {} :: {[string]:{BasePart}}

local faceCfs = {
	CFrame.new(Vector3.zero, Vector3.new(0, 0,  1))*CFrame.new(0,0,-BLOCK_SIZE*.5),
	CFrame.new(Vector3.zero, Vector3.new(0, 0, -1))*CFrame.new(0,0,-BLOCK_SIZE*.5),
	CFrame.new(Vector3.zero, Vector3.new( 1, 0, 0))*CFrame.new(0,0,-BLOCK_SIZE*.5),
	CFrame.new(Vector3.zero, Vector3.new(-1, 0, 0))*CFrame.new(0,0,-BLOCK_SIZE*.5),
	CFrame.new(Vector3.zero, Vector3.new(0,  1, 0))*CFrame.new(0,0,-BLOCK_SIZE*.5),
	CFrame.new(Vector3.zero, Vector3.new(0, -1, 0))*CFrame.new(0,0,-BLOCK_SIZE*.5),
}

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

local function createFace(blockId, faceId, x, z, y, chunkX, chunkZ, chunkY): BasePart
	local faceCf = faceCfs[faceId]
	local new = BlockFaceRecycler.RequestFace()
	
	new.Transparency = 0
	new.Size = Vector3.new(BLOCK_SIZE, 0.001, BLOCK_SIZE)
	new:PivotTo(CFrame.new((Vector3.new(x,y,z)+Vector3.new(chunkX, chunkY, chunkZ)*CHUNK_SIZE)*BLOCK_SIZE) * faceCf)
	new.BrickColor = BrickColor.palette(blockId)
	return new
end


local function getShouldSidesRender(chunkX: number, chunkZ: number, chunkY: number, x: number, z: number, y: number): {[number]: boolean}
	local shouldSidesRender = {false, false, false, false, false, false}
	local worldPosition = ChunksUtil.chunkToWorldPosition(chunkX, chunkZ, chunkY, x, z, y)
	
	for i, offsetVector in BLOCK_NEIGHBOUR_VECTORS do
		local neighborWorldPosition = worldPosition + offsetVector
		local neighbour = ChunksUtil.worldToChunkPosition(neighborWorldPosition)
		
		local bufferPosition = ChunksUtil.chunkToBufferPosition(neighbour.x, neighbour.z, neighbour.y)

		shouldSidesRender[i] = buffer.readu8(ChunksData[neighbour.chunkX][neighbour.chunkZ][neighbour.chunkY]['buffer'], bufferPosition) == AIR_ID
	end
	return shouldSidesRender
end

local function GetAirExposed(chunkX: number, chunkZ: number, chunkY: number, x: number, z: number, y: number): boolean
	local worldPosition = ChunksUtil.chunkToWorldPosition(chunkX, chunkZ, chunkY, x, z, y)
	
	for i, offsetVector in BLOCK_NEIGHBOUR_VECTORS do
		local neighborWorldPosition = worldPosition + offsetVector
		
		local neighborChunkPosition = ChunksUtil.worldToChunkPosition(neighborWorldPosition)
		local neighborChunkX = neighborChunkPosition[1]
		local neighborChunkZ = neighborChunkPosition[2]
		local neighborChunkY = neighborChunkPosition[3]
		local neighborX = neighborChunkPosition[4]
		local neighborZ = neighborChunkPosition[5]
		local neighborY = neighborChunkPosition[6]
		
		local bufferPosition = ChunksUtil.chunkToBufferPosition(neighborX, neighborZ, neighborY)

		if buffer.readu8(ChunksData[neighborChunkX][neighborChunkZ][neighborChunkY]['buffer'], bufferPosition) == AIR_ID then
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

				local shouldSidesRender = getShouldSidesRender(chunkX, chunkZ, chunkY, x, z, y)
				for faceId, shouldRender in shouldSidesRender do
					if not shouldRender then
						continue
					end
					
					local newFace = createFace(blockId, faceId, x, z, y, chunkX, chunkZ, chunkY)
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
		BlockFaceRecycler.ReturnFaces(chunk)
		ChunkParts[`{chunkX}x{chunkZ}x{chunkY}`] = nil
	end
end

return ChunkRenderer