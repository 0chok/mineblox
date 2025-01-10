--!strict
local BlockFaceRecycler = {}

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local BaseFace = ReplicatedStorage.Face

local CreatedFaces = 0

local StoredFaces = {} :: {BasePart}

-- PRIVATE
function CreateNewFace(doWarn: boolean?): BasePart
    if doWarn then warn("No faces stored") end
    CreatedFaces += 1

    local new = BaseFace:Clone()
    new.Parent = workspace.Faces
    return new
end

-- PUBLIC
function BlockFaceRecycler.RequestFace()
    return table.remove(StoredFaces,#StoredFaces) or CreateNewFace()
end

function BlockFaceRecycler.ReturnFaces(faces: {BasePart})
    local startIndex = #StoredFaces
    for i, face in faces do
        face.Transparency = 1
        StoredFaces[startIndex + i] = faces[i]
    end

end

function BlockFaceRecycler.CreateStoredFaces(count: number)
    local startIndex = #StoredFaces
    for i = 1, count do
        StoredFaces[startIndex + i] = CreateNewFace()
    end
end

function BlockFaceRecycler.GetStoredFacesCount()
    return #StoredFaces
end

-- init
task.spawn(function()
    while true do
        task.wait(3)
        print(CreatedFaces, #StoredFaces)
    end
end)

-- RETURN
return BlockFaceRecycler