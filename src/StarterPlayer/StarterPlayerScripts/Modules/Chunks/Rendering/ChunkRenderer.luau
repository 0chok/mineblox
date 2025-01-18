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

local CHUNK_SIZE: number = ChunkSettings.CHUNK_SIZE
local BLOCK_SIZE: number = ChunkSettings.BLOCK_SIZE

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

local function createBlock(blockId: number, position: Vector3, chunkPosition: Vector3): BasePart
	local new = BlocksRecycler.RequestBlock(BLOCK_SIZE)
	
	new.Transparency = 0
	new:PivotTo(CFrame.new((Vector3.new(position.X,position.Y,position.Z)+Vector3.new(chunkPosition.X, chunkPosition.Y, chunkPosition.Z)*CHUNK_SIZE)*BLOCK_SIZE))
	new.BrickColor = BrickColor.palette(blockId+5)

	return new
end

local function createCombinedBlock(blockId: number, position: Vector3, chunkPosition: Vector3, size: Vector3): BasePart
	local new = BlocksRecycler.RequestBlock(-1)

	new.Transparency = 0
	new.Size = Vector3.new(size.X,size.Y,size.Z)*BLOCK_SIZE
	new:PivotTo(CFrame.new((Vector3.new(position.X+(size.X-1)*.5,position.Y+(size.Y-1)*.5,position.Z+(size.Z-1)*.5)+Vector3.new(chunkPosition.X, chunkPosition.Y, chunkPosition.Z)*CHUNK_SIZE)*BLOCK_SIZE))
	new.BrickColor = BrickColor.palette(blockId+5)--Color3.fromHSV(math.random(), .3, .8)

	return new
end

local function GetAirExposed(chunkX: number, chunkZ: number, chunkY: number, x: number, z: number, y: number): boolean
	local worldPosition = ChunksUtil.chunkToWorldPosition(chunkX, chunkZ, chunkY, x, z, y)
	
	for i, offsetVector in BLOCK_NEIGHBOUR_VECTORS do
		local neighborWorldPosition = worldPosition + offsetVector
		
		local neighbourPosinfo = ChunksUtil.worldToChunkPosition(neighborWorldPosition)
		local chunkPosition = neighbourPosinfo.chunk
		local posInChunk = neighbourPosinfo.pos
		
		local bufferPosition = ChunksUtil.chunkToBufferPosition(posInChunk.X, posInChunk.Z, posInChunk.Y)

		if buffer.readu8(ChunksData[chunkPosition.X][chunkPosition.Z][chunkPosition.Y]['buffer'], bufferPosition) == AIR_ID then
			return true
		end
	end
	return false
end

-- PUBLIC

function ChunkRenderer.renderChunk(chunkPosition: Vector3): ()	
	local loadedChunkBlocks: buffer = ChunksData[chunkPosition.X][chunkPosition.Z][chunkPosition.Y]['buffer']

	local partList = {}
	partList[BLOCK_SIZE] = {}
	partList[-1] = {}
	
	local data = {} :: {{{boolean | number}}}
	for x = 1, CHUNK_SIZE do
		local bufferPositionX = (x - 1) * CHUNK_SIZE * CHUNK_SIZE
		data[x] = {}
		for y = 1, CHUNK_SIZE do
			local bufferPositionZ = (y - 1) * CHUNK_SIZE 
			data[x][y] = {}
			for z = 1, CHUNK_SIZE do
				local bufferPositionY: number = (z - 1)
				local blockId = buffer.readu8(loadedChunkBlocks, bufferPositionX + bufferPositionZ + bufferPositionY)
				if 
					not blockId
					or blockId == AIR_ID
				then 
					data[x][y][z] = true
					continue 
				end

				if GetAirExposed(chunkPosition.X, chunkPosition.Z, chunkPosition.Y, x, z, y) then
					data[x][y][z] = blockId
				else
					data[x][y][z] = false
				end
			end
		end
	end

	for x = 1, CHUNK_SIZE do
		for y = 1, CHUNK_SIZE do
			for z = 1, CHUNK_SIZE do -- for each block
				if typeof(data[x][y][z]) == "boolean" then continue end -- dont render air or hidden blocks
				local blockId = data[x][y][z] :: number
				
				-- X SECTION
				local confirmedExpandX = 0 -- the minimum we will to expand x
				local potentialExpandX = 0-- the max we can expand x
				
				while x + potentialExpandX < CHUNK_SIZE do -- expand in x direction
					potentialExpandX += 1
					if data[x + potentialExpandX][y][z] == false then -- hidden blocks are fine
						potentialExpandX = potentialExpandX
						continue
					end 

					if data[x + potentialExpandX][y][z] ~= blockId then 
						potentialExpandX -= 1
						break -- dont expand through other block types including air
					end

					if data[x + potentialExpandX][y][z] == blockId then 
						data[x + potentialExpandX][y][z] = true
						confirmedExpandX = potentialExpandX
					end
				end
				
				-- Y SECTION
				local potentialExpandY = 0 -- the max we can expand y
				local confirmedExpandY = 0 -- the minimum we will to expand y

				for length = confirmedExpandX, potentialExpandX do -- try all lengths to expand into
					potentialExpandY = 0
					local Stop = false
					while y + potentialExpandY < CHUNK_SIZE do -- for each block we try to expand 
						potentialExpandY += 1

						local FoundBlock = false

						for i = 0, length do -- check every block along x axis at that length
							if data[x + i][y + potentialExpandY][z] == false then -- hidden blocks are fine
								continue 
							end 
							if data[x + i][y + potentialExpandY][z] ~= blockId then  -- dont expand through other block types including air
								Stop = true
								break
							end
							if data[x + i][y + potentialExpandY][z] == blockId then  -- do expand through correct block
								FoundBlock = true
							end
						end
						
						if Stop == true then
							potentialExpandY -= 1
							break
						end
						
						if not FoundBlock then continue end
						confirmedExpandY = potentialExpandY
						-- overwrite blocks weve confirmed
						for i = 0, length do
							if data[x + i][y + potentialExpandY][z] == blockId then
								data[x + i][y + potentialExpandY][z] = true
							end
						end
					end

					if Stop == true then
						break
					end
				end
				
				local positionInChunk = Vector3.new(x, y, z)
				local size = Vector3.new(confirmedExpandX + 1, confirmedExpandY + 1, 1)
				if confirmedExpandX ~= 0 or confirmedExpandY ~= 0 then
					local newBlock = createCombinedBlock(blockId, positionInChunk, chunkPosition, size) --TODO other axes
					newBlock:SetAttribute("confirmedExpandX", confirmedExpandX)
					newBlock:SetAttribute("potentialExpandX", potentialExpandX)
					table.insert(partList[-1], newBlock)
				else
					local newBlock = createBlock(blockId, positionInChunk, chunkPosition)
					table.insert(partList[BLOCK_SIZE], newBlock)
				end
				
			end
		end
	end

	if #partList[BLOCK_SIZE] ~= 0 or #partList[-1] ~= 0 then
		ChunkParts[`{chunkPosition.X}x{chunkPosition.Z}x{chunkPosition.Y}`] = partList
		local newBlock = createBlock(ItemsData.Bedrock['ID'], Vector3.one, chunkPosition)
		table.insert(partList[BLOCK_SIZE], newBlock)
	end
end

function ChunkRenderer.unrenderChunk(chunkPosition: Vector3): ()
	local chunk = ChunkParts[`{chunkPosition.X}x{chunkPosition.Z}x{chunkPosition.Y}`]
	if chunk then
		for i, list in chunk do
			BlocksRecycler.ReturnBlocks(list, i)
		end
		ChunkParts[`{chunkPosition.X}x{chunkPosition.Z}x{chunkPosition.Y}`] = nil
	end
end

return ChunkRenderer