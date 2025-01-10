--!native
local ChunkLoading = {}

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild('HumanoidRootPart') :: Part
local PlayerScripts = Player.PlayerScripts

local Modules = PlayerScripts:WaitForChild('Modules')
local Events = PlayerScripts:WaitForChild('Events')

local ChunkRenderer = require(Modules.Chunks.Rendering.ChunkRenderer)
local ChunksData = require(Modules.Chunks.Data.ChunksData)
local ChunkGenerationStages = require(Modules.Chunks.Data.ChunkGenerationStages)
local ChunkSettings = require(ReplicatedStorage.Shared.ChunkSettings)
local ChunksUtil = require(ReplicatedStorage.Shared.ChunksUtil)
local ItemsData = require(ReplicatedStorage.Shared.ItemsData)
local BlockFaceRecycler = require(ReplicatedStorage.Shared.BlockFaceRecycler)

local ParallelScripts = PlayerScripts:WaitForChild('ParallelScripts')

local BiomeLoaderParallel: LocalScript = ParallelScripts.BiomeLoaderParallel
local TerrainLoaderParallel: LocalScript = ParallelScripts.TerrainLoaderParallel

local ClientSettings = PlayerScripts:WaitForChild('ClientSettings')

-- render settings
local BLOCK_SIZE: number = ChunkSettings['BLOCK_SIZE']
local CHUNK_SIZE: number = ChunkSettings['CHUNK_SIZE']
local RENDER_DISTANCE: number = ChunkSettings['RENDER_DISTANCE']
local MAX_CHUNK_LOADING_ACTORS: number = ChunkSettings['MAX_CHUNK_LOADING_ACTORS']

-- load count
local LOAD_OFFSET: number = 2

local CHUNKS_TO_RENDER_PER_UPDATE: number = 1 --TODO fix big bug if more than 1
local CHUNKS_TO_LOAD_TERRAIN_PER_UPDATE: number = 9

-- block ids
local AIR_ID: number = ItemsData['Air']['ID']

-- world gen
local SEED: number = 500

-- chunk finding
local FocuesdChunk: Vector3 = nil

local ChunkOffsetsToLoad: {{number}} = {}
local CheckedChunkOffsetsToLoad = 0

local ChunkOffsetsToRender: {{number}} = {}
local CheckedChunkOffsetsToRender = 0

local ChunkOffsetsToNotUnload: {[string]:boolean?} = {}
local LoadedChunks = {} :: {{x: number, y: number, z: number}}

local ChunkOffsetsToNotUnrender: {[string]:boolean?} = {}
local RenderedChunks = {} :: {{x: number, y: number, z: number}}

-- actors
local chunkLoadingActors: number = ClientSettings:GetAttribute('ChunkLoadingActors')
local chunkLoadingActorsHalf: number = chunkLoadingActors // 2 -- Amount of biome and terrain actors seperately

local terrainActors = table.create(chunkLoadingActorsHalf)
local biomeActors = table.create(chunkLoadingActorsHalf)

local ActorsFolder = Instance.new('Folder')
ActorsFolder.Name = 'Actors'
ActorsFolder.Parent = ParallelScripts

-- Create actors for loadChunk()
for i = 1, MAX_CHUNK_LOADING_ACTORS // 2 do
	local terrainActor = Instance.new('Actor')
	terrainActor.Name = 'TerrainActor' .. i
	local terrainScript = TerrainLoaderParallel:Clone()
	terrainScript.Parent = terrainActor
	terrainActor.Parent = ActorsFolder

	local biomeActor = Instance.new('Actor')
	biomeActor.Name = 'BiomeActor' .. i
	local biomeScript = BiomeLoaderParallel:Clone()
	biomeScript.Parent = biomeActor
	biomeActor.Parent = ActorsFolder

	table.insert(terrainActors, terrainActor)
	table.insert(biomeActors, biomeActor)
end

-- PRIVATE

local function OnChunkLoadingActorsChanged(): ()
	local newValue = ClientSettings:GetAttribute('ChunkLoadingActors')
	ClientSettings:SetAttribute('ChunkLoadingActors', math.clamp(math.floor(newValue), 2, MAX_CHUNK_LOADING_ACTORS))
	newValue = ClientSettings:GetAttribute('ChunkLoadingActors')

	chunkLoadingActors = newValue
	chunkLoadingActorsHalf = newValue // 2
end

local function RenderChunks(toRender: {}): ()
	for _, chunk in toRender do
		local chunkX = chunk[1]
		local chunkZ = chunk[2]
		local chunkY = chunk[3]
		
		ChunksData[chunkX][chunkZ][chunkY]['isRendered'] = true
		ChunkRenderer.renderChunk(chunkX, chunkZ, chunkY)
		table.insert(RenderedChunks, {x = chunkX, y = chunkY, z = chunkZ})
	end
end


local function UnrenderChunks(chunks: {{x: number, y: number, z: number}}): ()
	for i, chunk in chunks do
		local index = table.find(RenderedChunks, chunk) -- probably bad idea to do this
		if index then
			table.remove(RenderedChunks, index)
		end

		ChunkRenderer.unrenderChunk(chunk.x, chunk.z, chunk.y)
		ChunksData[chunk.x][chunk.z][chunk.y]['isRendered'] = false
	end
end


-- Calls loadChunk() on every chunk to load
local function LoadChunks(toLoad: {}): ()
	
	local chunksToLoadTerrain = {}
	local chunksToLoadBiome = {}
	
	for _, chunk in toLoad do
		local chunkX: number = chunk[1]
		local chunkZ: number = chunk[2]
		local chunkY: number = chunk[3]

		if ChunksData[chunkX][chunkZ][chunkY]['stage'] == ChunkGenerationStages['none'] then
			ChunksData[chunkX][chunkZ][chunkY]['isLoading'] = true
			
			table.insert(chunksToLoadTerrain, chunk)
			
		elseif ChunksData[chunkX][chunkZ][chunkY]['stage'] == ChunkGenerationStages['terrain'] then
			print("what")
			if -- Neighbours' terrain must be loaded
				not ChunksData[chunkX][chunkZ][chunkY - 1]
				or ChunksData[chunkX][chunkZ][chunkY - 1]['stage'] == ChunkGenerationStages['none']
			then
				continue
			end
			ChunksData[chunkX][chunkZ][chunkY]['isLoading'] = true
			
			table.insert(chunksToLoadBiome, chunk)
		end
	end
	
	task.defer(function()
		local i = 0
		for _, chunk in chunksToLoadTerrain do
			local chunkX: number = chunk[1]
			local chunkZ: number = chunk[2]
			local chunkY: number = chunk[3]
			
			terrainActors[i+1]:SendMessage('beginLoading', chunkX, chunkZ, chunkY, SEED)
			i = (i+1)%chunkLoadingActorsHalf
		end
		
		for _, chunk in chunksToLoadBiome do
			local chunkX: number = chunk[1]
			local chunkZ: number = chunk[2]
			local chunkY: number = chunk[3]
			
			local chunkBlocks: buffer = ChunksData[chunkX][chunkZ][chunkY]['buffer']
			local neighbouringChunks = {
				[chunkX .. 'x' .. chunkZ .. 'x' .. chunkY - 1] = ChunksData[chunkX][chunkZ][chunkY - 1]['buffer']
			}
			
			biomeActors[i+1]:SendMessage('beginLoading', chunkX, chunkZ, chunkY, chunkBlocks, neighbouringChunks, SEED)
			i = (i+1)%chunkLoadingActorsHalf
		end
	end)
end

local function UnloadChunks(chunks: {{x: number,y: number,z: number}})
	for _, chunk in chunks do
		local index = table.find(LoadedChunks, chunk) -- probably bad idea to do this
		if index then
			table.remove(LoadedChunks, index)
		end

		if ChunksData[chunk.x][chunk.z][chunk.y]["isRendered"] then 
			ChunkRenderer.unrenderChunk(chunk.x, chunk.z, chunk.y)
		end
		ChunksData[chunk.x][chunk.z][chunk.y] = nil
	end
end

-- Returns chunks to render
local function FindChunksToRender(): {}
	local toLoad = {}

	while #toLoad < CHUNKS_TO_RENDER_PER_UPDATE and CheckedChunkOffsetsToRender < #ChunkOffsetsToRender do
		CheckedChunkOffsetsToRender += 1
		
		local chunkX = ChunkOffsetsToRender[CheckedChunkOffsetsToRender][1] + FocuesdChunk.X
		local chunkZ = ChunkOffsetsToRender[CheckedChunkOffsetsToRender][2] + FocuesdChunk.Z
		local chunkY = ChunkOffsetsToRender[CheckedChunkOffsetsToRender][3] + FocuesdChunk.Y

		if
			not ChunksData[chunkX] 
			or not ChunksData[chunkX][chunkZ] 
			or not ChunksData[chunkX][chunkZ][chunkY]
		then
		ChunksUtil.fillChunksTable(ChunksData, chunkX, chunkZ, chunkY)
		ChunksData[chunkX][chunkZ][chunkY]['stage'] = ChunkGenerationStages['none']
		end

		if --check that adjacent chunks are loaded
			ChunksData[chunkX][chunkZ][chunkY]['isRendered'] == true
		then continue end

		if
			   not ChunksData[chunkX][chunkZ + 1]
			or not ChunksData[chunkX][chunkZ - 1]
			or not ChunksData[chunkX + 1]
			or not ChunksData[chunkX + 1][chunkZ]
			or not ChunksData[chunkX - 1]
			or not ChunksData[chunkX - 1][chunkZ]
		then return {} end

		if
			   not ChunksData[chunkX + 1][chunkZ][chunkY]
			or     ChunksData[chunkX + 1][chunkZ][chunkY]['stage'] ~= ChunkGenerationStages['done']
			
			or not ChunksData[chunkX - 1][chunkZ][chunkY]
			or     ChunksData[chunkX - 1][chunkZ][chunkY]['stage'] ~= ChunkGenerationStages['done']
			
			or not ChunksData[chunkX][chunkZ + 1][chunkY]
			or     ChunksData[chunkX][chunkZ + 1][chunkY]['stage'] ~= ChunkGenerationStages['done']
			
			or not ChunksData[chunkX][chunkZ - 1][chunkY]
			or     ChunksData[chunkX][chunkZ - 1][chunkY]['stage'] ~= ChunkGenerationStages['done']
			
			or not ChunksData[chunkX][chunkZ][chunkY + 1]
			or     ChunksData[chunkX][chunkZ][chunkY + 1]['stage'] ~= ChunkGenerationStages['done']
			
			or not ChunksData[chunkX][chunkZ][chunkY - 1]
			or     ChunksData[chunkX][chunkZ][chunkY - 1]['stage'] ~= ChunkGenerationStages['done']
		then return {} end

		local isAllAir: boolean = true
		local chunkBlocks: buffer = ChunksData[chunkX][chunkZ][chunkY]['buffer']
		for i = 0, CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE do
			if buffer.readu8(chunkBlocks, i) ~= AIR_ID then
				isAllAir = false
				break
			end
		end
		if isAllAir then
			continue
		end

		table.insert(toLoad, {chunkX, chunkZ, chunkY})
	end

	return toLoad
end

-- Returns chunks to unrender
local function FindChunksToUnrender()
	local t = {}
	for _, chunk in LoadedChunks do
		if ChunkOffsetsToNotUnrender[`{chunk.x - FocuesdChunk.X}x{chunk.y - FocuesdChunk.Y}x{chunk.z - FocuesdChunk.Z}`] then continue end
		table.insert(t, chunk)
	end
	return t
end

-- Returns the closest chunks to the character which arent loaded
local function FindChunksToLoad()
	local toLoad = {}

	while #toLoad < CHUNKS_TO_LOAD_TERRAIN_PER_UPDATE and CheckedChunkOffsetsToLoad < #ChunkOffsetsToLoad do
		CheckedChunkOffsetsToLoad += 1
		
		local chunkX = ChunkOffsetsToLoad[CheckedChunkOffsetsToLoad][1] + FocuesdChunk.X
		local chunkZ = ChunkOffsetsToLoad[CheckedChunkOffsetsToLoad][2] + FocuesdChunk.Z
		local chunkY = ChunkOffsetsToLoad[CheckedChunkOffsetsToLoad][3] + FocuesdChunk.Y

		if
			not ChunksData[chunkX] 
			or not ChunksData[chunkX][chunkZ] 
			or not ChunksData[chunkX][chunkZ][chunkY]
		then
		ChunksUtil.fillChunksTable(ChunksData, chunkX, chunkZ, chunkY)
		ChunksData[chunkX][chunkZ][chunkY]['stage'] = ChunkGenerationStages['none']
		end

		local chunkData = ChunksData[chunkX][chunkZ][chunkY]
		if chunkData['stage'] == ChunkGenerationStages['done'] then continue end -- we dont want to load loaded chunks!
			
		table.insert(toLoad, {chunkX, chunkZ, chunkY})
	end
	return toLoad
end

local function FindChunksToUnload() : {{x: number, y: number, z: number}}
	local t = {}
	for _, chunk in LoadedChunks do
		if ChunkOffsetsToNotUnload[`{chunk.x - FocuesdChunk.X}x{chunk.y - FocuesdChunk.Y}x{chunk.z - FocuesdChunk.Z}`] then continue end
		table.insert(t, chunk)
	end
	return t
end

local function GenerateOrderedChunkOffsets(radius)
	local radiusFloor = math.floor(radius)

	local chunkOffsetsInRange = {}

	for chunkX = -radiusFloor, radiusFloor do
		local chunkXDistance = chunkX ^ 2
		for chunkZ = -radiusFloor, radiusFloor do
			local chunkZDistance = chunkZ ^ 2
			for chunkY = -radiusFloor, radiusFloor do
				local distanceSquared = chunkXDistance + chunkZDistance + chunkY ^ 2
				if distanceSquared > radius^2 then continue end
				
				table.insert(chunkOffsetsInRange, {distanceSquared,{chunkX, chunkZ, chunkY}})
			end
		end
	end

	table.sort(chunkOffsetsInRange, function(a0: {number}, a1: {number}): boolean 
		return a0[1] < a1[1]
	end)

	local t = {}
	for i, v in chunkOffsetsInRange do
		t[i] = v[2]
	end
	return t
end

local function GenerateChunkOffsetsInRange(radius): {}
	local radiusFloor = math.floor(radius)

	local chunkOffsetsInRange = {}

	for chunkX = -radiusFloor, radiusFloor do
		local chunkXDistance = chunkX ^ 2
		for chunkZ = -radiusFloor, radiusFloor do
			local chunkZDistance = chunkZ ^ 2
			for chunkY = -radiusFloor, radiusFloor do
				local distanceSquared = chunkXDistance + chunkZDistance + chunkY ^ 2
				if distanceSquared > radius^2 then continue end
				chunkOffsetsInRange[`{chunkX}x{chunkY}x{chunkZ}`] = true
			end
		end
	end

	return chunkOffsetsInRange
end

local function OnHeartBeat(): ()
	if BlockFaceRecycler.GetStoredFacesCount() < 250 then -- could be done on separate thread in the future ?
		debug.profilebegin("CreateStoredFaces")
		BlockFaceRecycler.CreateStoredFaces(50)
		debug.profileend()
		return
	end

	if workspace:GetAttribute("a") == true then return end
	if not HumanoidRootPart or not HumanoidRootPart.Parent then
		if not Player.Character then return end
		Character = Player.Character
		HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") :: Part
		if not HumanoidRootPart then return end
	end
	
	local characterPosition: Vector3 = HumanoidRootPart.Position
	local newCharacterChunk = Vector3.new(
		characterPosition.X // (CHUNK_SIZE * BLOCK_SIZE),
		characterPosition.Y // (CHUNK_SIZE * BLOCK_SIZE),
		characterPosition.Z // (CHUNK_SIZE * BLOCK_SIZE)
	)
	
	local changedChunk = false
	if FocuesdChunk ~= newCharacterChunk then
		FocuesdChunk = newCharacterChunk
		CheckedChunkOffsetsToLoad = 0
		CheckedChunkOffsetsToRender = 0
		changedChunk = true


		-- unload
		debug.profilebegin("unloadChunks")
		local chunksToUnload = FindChunksToUnload()
		UnloadChunks(chunksToUnload)
		debug.profileend()

		-- unrendering
		debug.profilebegin("chunkUNrendering")

		debug.profilebegin("findChunksToUnrender")
		local ChunksToUnrender = FindChunksToUnrender()
		debug.profileend()

		debug.profilebegin("unerenderChunks")
		UnrenderChunks(ChunksToUnrender)
		debug.profileend()

		debug.profileend()
	end

	--rendering
	debug.profilebegin("chunkrendering")

	debug.profilebegin("findChunksToRender")
	local chunksToRender = FindChunksToRender()
	debug.profileend()

	debug.profilebegin("renderChunks")
	RenderChunks(chunksToRender)
	debug.profileend()

	debug.profileend()

	-- dont do the first "Finds" for a new chunk on the same frame to conserve frame budget
	-- rendering is done first just to make it one more frame responsive
	if changedChunk == true then return end 

	-- loading
	debug.profilebegin("loadUnloadChunks")

	debug.profilebegin("findChunksToLoad")
	local chunksToLoad = FindChunksToLoad()
	debug.profileend()

	debug.profilebegin("loadChunks")
	LoadChunks(chunksToLoad)
	debug.profileend()

	debug.profilebegin("loadExtra")
	if CheckedChunkOffsetsToLoad < 50 then
		LoadChunks(FindChunksToLoad())
	end
	debug.profileend()

	debug.profileend()
end

local function handleChunkLoadedTerrain(chunkX: number, chunkZ: number, chunkY: number, chunkBlocks: buffer)
	ChunksData[chunkX][chunkZ][chunkY]['buffer'] = chunkBlocks
	ChunksData[chunkX][chunkZ][chunkY]['stage'] = ChunkGenerationStages['done']--['terrain'] temp disabled biome step
	ChunksData[chunkX][chunkZ][chunkY]['isLoading'] = false
	table.insert(LoadedChunks, {x = chunkX, y = chunkY, z = chunkZ})
end

local function handleChunkLoadedBiome(chunkX: number, chunkZ: number, chunkY: number, chunkBlocks: buffer, neighbouringChunks: {})
	print("bla")
	ChunksData[chunkX][chunkZ][chunkY]['buffer'] = chunkBlocks
	ChunksData[chunkX][chunkZ][chunkY]['stage'] = ChunkGenerationStages['done']
	ChunksData[chunkX][chunkZ][chunkY]['isLoading'] = false
	
	--[[
	
	for neighbouringChunkString, neighbouringChunkNewBuffer  in neighbouringChunks do
		local neighbouringChunkPosition = string.split(neighbouringChunkString, 'x')
		local neighbouringChunkX = tonumber(neighbouringChunkPosition[1])
		local neighbouringChunkZ = tonumber(neighbouringChunkPosition[2])
		local neighbouringChunkY = tonumber(neighbouringChunkPosition[3])
		
		local neighbouringChunkOldBuffer = ChunksData[neighbouringChunkX][neighbouringChunkZ][neighbouringChunkY]['buffer']
		
		for x = 1, CHUNK_SIZE do
			local bufferPositionX: number = (x - 1) * CHUNK_SIZE
			for z = 1, CHUNK_SIZE do
				local bufferPositionZ: number = (z - 1) * CHUNK_SIZE * CHUNK_SIZE
				for y = 1, CHUNK_SIZE do
					local oldBlockId: number = buffer.readu8(neighbouringChunkOldBuffer, bufferPositionX + bufferPositionZ + (y - 1))
					local newBlockId: number = buffer.readu8(neighbouringChunkNewBuffer, bufferPositionX + bufferPositionZ + (y - 1))

					buffer.writeu8(neighbouringChunkOldBuffer, bufferPositionX + bufferPositionZ + (y - 1), newBlockId)
				end
			end
		end
	end--]]
end

-- EVENTS
RunService.Heartbeat:Connect(OnHeartBeat)

Events.ChunkLoadedTerrain.Event:Connect(handleChunkLoadedTerrain)
Events.ChunkLoadedBiome.Event:Connect(handleChunkLoadedBiome)

ClientSettings:GetAttributeChangedSignal('ChunkLoadingActors'):Connect(OnChunkLoadingActorsChanged)

-- INIT
ChunkOffsetsToLoad = GenerateOrderedChunkOffsets(RENDER_DISTANCE + LOAD_OFFSET + .5)
ChunkOffsetsToRender = GenerateOrderedChunkOffsets(RENDER_DISTANCE + .5)
ChunkOffsetsToNotUnload = GenerateChunkOffsetsInRange(RENDER_DISTANCE + LOAD_OFFSET + 1.5)
ChunkOffsetsToNotUnrender = GenerateChunkOffsetsInRange(RENDER_DISTANCE + 1.5)

task.spawn(function()
	task.wait(5)
	print(ChunksData)
end)

return ChunkLoading
