--!strict
local BlocksRecycler = {}

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local BaseFace = ReplicatedStorage.Face2

local CreatedBlocks = 0

local StoredFaces = {} :: {BasePart}

-- PRIVATE
function CreateNewBlock(size, doWarn: boolean?): BasePart
    if doWarn then warn(`No blocks stored of size {size}`) end
    CreatedBlocks += 1

    local new = BaseFace:Clone()
    new.Parent = workspace.Faces
    new.Size = Vector3.new(size,size,size)
    return new
end

-- PUBLIC
function BlocksRecycler.RequestBlock()
    return table.remove(StoredFaces,#StoredFaces) or CreateNewBlock(4, true)
end

function BlocksRecycler.ReturnBlocks(faces: {BasePart})
    local startIndex = #StoredFaces
    for i, face in faces do
        face.Transparency = 1
        StoredFaces[startIndex + i] = faces[i]
    end

end

function BlocksRecycler.CreateStoredBlocks(count: number)
    local startIndex = #StoredFaces
    for i = 1, count do
        StoredFaces[startIndex + i] = CreateNewBlock(4)
    end
end

function BlocksRecycler.GetStoredBlocksCount()
    return #StoredFaces
end

-- init
task.spawn(function()
    while true do
        task.wait(3)
        print(CreatedBlocks, #StoredFaces)
    end
end)

-- RETURN
return BlocksRecycler