local itemsData = {
	Air = {
		isTransparent = true,
	},

	Water = {
		isTransparent = true,
	},

	Stone = {
		Hardness = 20,
		PreferredTool = 'Pickaxe',
		DropItem = 'Cobblestone',
		Type = 'Block',
	},

	Cobblestone = {
		Hardness = 20,
		PreferredTool = 'Pickaxe',
		Type = 'Block',
	},

	['Grass Block'] = {
		Hardness = 6,
		PreferredTool = 'Shovel',
		DropItem = 'Dirt',
		Type = 'Block',
	},

	Dirt = {
		Hardness = 5,
		PreferredTool = 'Shovel',
		Type = 'Block',
	},

	['Oak Wood Planks'] = {
		Hardness = 20,
		PreferredTool = 'Axe',
		Type = 'Block',
	},

	Bedrock = {},

	Sand = {
		Hardness = 8,
		PreferredTool = 'Shovel',
		Type = 'Block',
	},

	['Oak Log'] = {
		Hardness = 20,
		PreferredTool = 'Axe',
		Type = 'Block',
	},

	['Oak Leaves'] = {
		Hardness = 2,
		Type = 'Block',
		isTransparent = true,
	},

	Glass = {
		isTransparent = true,
	},
	
	Grass = {
		Hardness = 0,
		Type = 'Plant',
	}
	
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemsIDs = require(ReplicatedStorage.Shared.ItemsIDs)

function _init()
	
	for itemID, itemName in ipairs(ItemsIDs) do

		if not itemsData[itemName] then
			itemsData[itemName] = {}
		end
		
		itemsData[itemName]['ID'] = itemID
	end
	print(itemsData)
end

-- Init
_init()

return itemsData