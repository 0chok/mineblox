--!strict
local BlocksRecycler = {}

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local BaseFace = ReplicatedStorage.Block

local CreatedBlocks = 0

local StoredBlocks = setmetatable({}, {__index = function(t,i)

    local newtable = {} :: {BasePart}

    t[i] = newtable

    return newtable
end,})

-- PRIVATE
function CreateNewBlock(size, doWarn: boolean?): BasePart
    if doWarn then warn(`No blocks stored of size {size}`) end
    CreatedBlocks += 1

    local new = BaseFace:Clone()
    new.Parent = workspace.Blocks
    if size ~= -1 then -- all blocks that do not have a certain size are stored at -1
        new.Size = Vector3.new(size,size,size)
    end
    return new
end

-- PUBLIC
function BlocksRecycler.RequestBlock(size: number): BasePart
    assert(size)
    local t = StoredBlocks[size]
    return table.remove(t,#t) or CreateNewBlock(size, true)
end

function BlocksRecycler.ReturnBlocks(faces: {BasePart}, size: number)
    assert(size)
    local t = StoredBlocks[size]
    local startIndex = #t
    for i, face in faces do
        face.Transparency = 1
        t[startIndex + i] = faces[i]
    end

end

function BlocksRecycler.CreateStoredBlocks(count: number, size: number)
    assert(size)
    local t = StoredBlocks[size]
    local startIndex = #t
    for i = 1, count do
        t[startIndex + i] = CreateNewBlock(size)
    end
end

function BlocksRecycler.GetStoredBlocksCount(size: number)
    return #StoredBlocks[size]
end

-- init
task.spawn(function()
    while true do
        task.wait(3)
        print(CreatedBlocks, #StoredBlocks[4], #StoredBlocks[-1])
    end
end)

-- RETURN
return BlocksRecycler