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

local ChunkParts = {} :: {[string]:{{BasePart}}}

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
	local new = BlocksRecycler.RequestBlock(BLOCK_SIZE)
	
	new.Transparency = 0
	new:PivotTo(CFrame.new((Vector3.new(x,y,z)+Vector3.new(chunkX, chunkY, chunkZ)*CHUNK_SIZE)*BLOCK_SIZE))
	new.BrickColor = BrickColor.palette(blockId)

	return new
end

local function createCombinedBlock(blockId: number, x: number, z: number, y: number, chunkX: number, chunkZ: number, chunkY: number, sizeX: number, sizeZ: number, sizeY: number): BasePart
	local new = BlocksRecycler.RequestBlock(-1)

	new.Transparency = 0
	new.Size = Vector3.new(sizeX,sizeY,sizeZ)*BLOCK_SIZE
	new:PivotTo(CFrame.new((Vector3.new(x+(sizeX-1)*.5,y+(sizeY-1)*.5,z+(sizeZ-1)*.5)+Vector3.new(chunkX, chunkY, chunkZ)*CHUNK_SIZE)*BLOCK_SIZE))
	new.Color = Color3.fromHSV(math.random(), .3, .8)

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
	
	local partList = {}
	partList[BLOCK_SIZE] = {}
	partList[-1] = {}
	
	local data = {} :: {{{boolean | number}}}
	for x = 1, CHUNK_SIZE do
		local bufferPositionX = (x - 1) * CHUNK_SIZE
		data[x] = {}
		for z = 1, CHUNK_SIZE do
			local bufferPositionZ = (z - 1) * CHUNK_SIZE * CHUNK_SIZE
			data[x][z] = {}
			for y = 1, CHUNK_SIZE do
				local blockId = buffer.readu8(loadedChunkBlocks, bufferPositionX + bufferPositionZ + (y - 1))
				if 
					not blockId
					or blockId == AIR_ID
				then 
					data[x][z][y] = true
					continue 
				end

				if GetAirExposed(chunkX, chunkZ, chunkY, x, z, y) then
					data[x][z][y] = blockId
				else
					data[x][z][y] = false
				end
			end
		end
	end

	for x = 1, CHUNK_SIZE do
		for z = 1, CHUNK_SIZE do
			for y = 1, CHUNK_SIZE do -- for each block
				if typeof(data[x][z][y]) == "boolean" then continue end -- dont render air or hidden blocks
				local blockId = data[x][z][y] :: number

				local confirmedExpandX = 0 -- the minimum we will to expand x
				local potentialExpandX = 0-- the max we can expand x
				
				while x + potentialExpandX < CHUNK_SIZE do -- expand in x direction
					potentialExpandX += 1
					if data[x + potentialExpandX][z][y] == false then -- hidden blocks are fine
						potentialExpandX = potentialExpandX
						continue
					end 

					if data[x + potentialExpandX][z][y] ~= blockId then 
						potentialExpandX -= 1
						break -- dont expand through other block types including air
					end

					if data[x + potentialExpandX][z][y] == blockId then 
						data[x + potentialExpandX][z][y] = true
						confirmedExpandX = potentialExpandX
					end
				end
				
				local potentialExpandY = 0 -- the max we can expand y
				local confirmedExpandY = 0 -- the minimum we will to expand y

				for length = confirmedExpandX, potentialExpandX do -- try all lengths to expand into
					local expandY = 0
					while y + expandY < CHUNK_SIZE do -- for each block we try to expand 
						expandY += 1

						local Stop = false
						local FoundBlock = false

						for i = 0, length do -- check every block along x axis at that length
							if data[x + i][z][y + expandY] == false then -- hidden blocks are fine
								continue 
							end 
							if data[x + i][z][y + expandY] ~= blockId then  -- dont expand through other block types including air
								Stop = true
								break
							end
							if data[x + i][z][y + expandY] == blockId then  -- do expand through correct block
								FoundBlock = true
							end
						end				
						potentialExpandY = expandY-1
						if Stop == true then
							break
						end
						
						if not FoundBlock then continue end
						confirmedExpandY = expandY
						-- overwrite blocks weve confirmed
						for i = 0, length do
							if data[x + i][z][y + expandY] == blockId then
								data[x + i][z][y + expandY] = true
							end
						end
					end
				end

				if confirmedExpandX ~= 0 or confirmedExpandY ~= 0 then
					local newBlock = createCombinedBlock(blockId, x, z, y, chunkX, chunkZ, chunkY, confirmedExpandX + 1, 1, confirmedExpandY + 1) --TODO other axes
					newBlock:SetAttribute("confirmedExpandX", confirmedExpandX)
					newBlock:SetAttribute("potentialExpandX", potentialExpandX)
					table.insert(partList[-1], newBlock)
				else
					local newBlock = createBlock(blockId, x, z, y, chunkX, chunkZ, chunkY)
					table.insert(partList[BLOCK_SIZE], newBlock)
				end
				
				
			end
		end
	end

	if #partList[BLOCK_SIZE] ~= 0 or #partList[-1] ~= 0 then
		ChunkParts[`{chunkX}x{chunkZ}x{chunkY}`] = partList
		local newBlock = createBlock(ItemsData.Bedrock['ID'], 1, 1, 1, chunkX, chunkZ, chunkY)
		table.insert(partList[BLOCK_SIZE], newBlock)
	end
end

function ChunkRenderer.unrenderChunk(chunkX: number, chunkZ: number, chunkY: number): ()
	local chunk = ChunkParts[`{chunkX}x{chunkZ}x{chunkY}`]
	if chunk then
		for i, list in chunk do
			BlocksRecycler.ReturnBlocks(list, i)
		end
		ChunkParts[`{chunkX}x{chunkZ}x{chunkY}`] = nil
	end
end

return ChunkRenderer