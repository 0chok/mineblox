local ChunkRenderer = {}

-- 3333 max blocks, if face culling implemented
-- = 8 * 8 * 52 = 3328 blocks
--local buffer = buffer.create(12288)

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

local Player: Player = Players.LocalPlayer
local PlayerScripts = Player.PlayerScripts

local Modules = PlayerScripts:WaitForChild('Modules')

local ChunksData = require(Modules.Chunks.Data.ChunksData)
--local BlockMeshData = require(Modules.Chunks.Rendering.Data.BlockMeshData)
--local PlantMeshData = require(Modules.Chunks.Rendering.Data.PlantMeshData)
local AtlasTextureData = require(Modules.Chunks.Rendering.Data.AtlasTextureData)
local ChunkSettings = require(ReplicatedStorage.Shared.ChunkSettings)
local ChunksUtil = require(ReplicatedStorage.Shared.ChunksUtil)
local ItemsData = require(ReplicatedStorage.Shared.ItemsData)

local CHUNK_SIZE: number = ChunkSettings['CHUNK_SIZE']
local BLOCK_SIZE: number = ChunkSettings['BLOCK_SIZE']

local AIR_ID: number = ItemsData['Air']['ID']

local faceCfs = {
	CFrame.new(Vector3.zero, Vector3.new(0, 0,  1))*CFrame.new(0,0,-1.5),
	CFrame.new(Vector3.zero, Vector3.new(0, 0, -1))*CFrame.new(0,0,-1.5),
	CFrame.new(Vector3.zero, Vector3.new( 1, 0, 0))*CFrame.new(0,0,-1.5),
	CFrame.new(Vector3.zero, Vector3.new(-1, 0, 0))*CFrame.new(0,0,-1.5),
	CFrame.new(Vector3.zero, Vector3.new(0,  1, 0))*CFrame.new(0,0,-1.5),
	CFrame.new(Vector3.zero, Vector3.new(0, -1, 0))*CFrame.new(0,0,-1.5),
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

local function createFace(folder: Folder, blockId, faceId, x, z, y, chunkX, chunkZ, chunkY)
	local faceCf = faceCfs[faceId]
	local new = ReplicatedStorage.Face:Clone()
	
	new:PivotTo(CFrame.new((Vector3.new(x,y,z)+Vector3.new(chunkX, chunkY, chunkZ)*CHUNK_SIZE)*BLOCK_SIZE) * faceCf)
	
	new.Parent = folder
end


local function getShouldSidesRender(chunkX: number, chunkZ: number, chunkY: number, x: number, z: number, y: number): {}
	local shouldSidesRender = {false, false, false, false, false, false}
	local worldPosition = ChunksUtil.chunkToWorldPosition(chunkX, chunkZ, chunkY, x, z, y)
	
	for i, offsetVector in BLOCK_NEIGHBOUR_VECTORS do
		local neighborWorldPosition = Vector3.new(
			worldPosition.X + offsetVector.X,
			worldPosition.Y + offsetVector.Y,
			worldPosition.Z + offsetVector.Z
		)
		
		local neighborChunkPosition = ChunksUtil.worldToChunkPosition(neighborWorldPosition)
		local neighborChunkX = neighborChunkPosition[1]
		local neighborChunkZ = neighborChunkPosition[2]
		local neighborChunkY = neighborChunkPosition[3]
		local neighborX = neighborChunkPosition[4]
		local neighborZ = neighborChunkPosition[5]
		local neighborY = neighborChunkPosition[6]
		
		local bufferPosition = ChunksUtil.chunkToBufferPosition(neighborX, neighborZ, neighborY)

		shouldSidesRender[i] = buffer.readu8(ChunksData[neighborChunkX][neighborChunkZ][neighborChunkY]['buffer'], bufferPosition) == AIR_ID
	end
	return shouldSidesRender
end

-- PUBLIC

function ChunkRenderer.renderChunk(chunkX: number, chunkZ: number, chunkY: number): ()	
	local loadedChunkBlocks: buffer = ChunksData[chunkX][chunkZ][chunkY]['buffer']
	
	local folder = Instance.new("Folder")
	folder.Name = `{chunkX}x{chunkZ}x{chunkY}`
	folder.Parent = workspace.Chunks
	
	for x = 1, CHUNK_SIZE do
		local bufferPositionX = (x - 1) * CHUNK_SIZE

		for z = 1, CHUNK_SIZE do
			local bufferPositionZ = (z - 1) * CHUNK_SIZE * CHUNK_SIZE

			for y = 1, CHUNK_SIZE do
				local blockId = buffer.readu8(loadedChunkBlocks, bufferPositionX + bufferPositionZ + (y - 1))
				if 
					not blockId
					or blockId == AIR_ID
					or not AtlasTextureData[blockId]
				then 
					continue 
				end

				local shouldSidesRender: {} = getShouldSidesRender(chunkX, chunkZ, chunkY, x, z, y)
				for faceId, shouldRender in shouldSidesRender do
					if not shouldRender then
						continue
					end
					
					createFace(folder, blockId, faceId, x, z, y, chunkX, chunkZ, chunkY)
				end
			end
		end
	end

	if #folder:GetChildren() == 0 then 
		folder:Destroy()
	end
end


function ChunkRenderer.unrenderChunk(chunkX: number, chunkZ: number, chunkY: number): ()
	local chunk = workspace.Chunks:FindFirstChild(`{chunkX}x{chunkZ}x{chunkY}`)
	if chunk then
		chunk:Destroy()
	end
end


return ChunkRenderer