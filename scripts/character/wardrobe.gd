extends RefCounted
## In-game wardrobe for Freja.
##
## Under every outfit there is ONLY the nude skin body + eyes + the outfit's hair
## (hair is never removable). Everything else is a toggleable "piece" - turn them
## all off and you're left with skin + hair.
##
## Piece lists + defaults mirror what CloudRig shows for that skin
## (assets/cloudrig_freja_truth_table.json). Heart of Courage is deliberately
## dressed by default (its CloudRig default is an undressed NSFW state).

const SHARED_ALWAYS := ["Freja_Eye", "Freja_EyeShadow"]
const BODY_MESH := "Freja_Nude_Body"

## Underwear layer - works under any outfit (CloudRig Accessories group).
const SHARED_PIECES := [
	{"id": "sports_bra", "label": "Sports Bra", "on": false, "meshes": ["Freja_SportsBra"]},
	{"id": "panties", "label": "Panties", "on": false, "meshes": ["Freja_SportsPanties"]},
	{"id": "stockings", "label": "Stockings", "on": false, "meshes": ["Freja_Stockings"]},
]

const OUTFITS := {
	0: {
		"name": "Combat (OW2)",
		"has_skin_color": true,
		"always": ["Freja_OW2_Hair", "Freja_OW2_Hair-Front", "Freja_OW2_Hair-Side", "Freja_OW2_Hair_Straps"],
		"accessories_on": [],
		"pieces": [
			{"id": "chest_armor", "label": "Chest Armor", "on": true, "meshes": ["Freja_OW2_Chest_Armor"]},
			{"id": "hoodie", "label": "Hood", "on": true, "meshes": ["Freja_OW2_Chest_Armor_Hoodie"]},
			{"id": "fur_collar", "label": "Fur Collar", "on": true, "meshes": ["Freja_OW2_Collar_Fur"]},
			{"id": "gloves", "label": "Gloves", "on": true, "meshes": ["Freja_OW2_Gloves"]},
			{"id": "boots", "label": "Boots", "on": true, "meshes": ["Freja_OW2_Boots"]},
			{"id": "earring", "label": "Earring", "on": true, "meshes": ["Freja_OW2_Earring"]},
			{"id": "nose_ring", "label": "Nose Ring", "on": true, "meshes": ["Freja_OW2_Nose_Piercing"]},
			{"id": "bodysuit", "label": "Bodysuit", "on": true, "meshes": ["Freja_OW2_Bodysuit"]},
			{"id": "shirt", "label": "Shirt", "on": false, "meshes": ["Freja_OW2_Shirt"]},
			{"id": "belt", "label": "Belt", "on": false,
				"meshes": ["Freja_OW2_Belt", "Freja_OW2_Belt_Arrows", "Freja_OW2_Belt_Utility"]},
			{"id": "cape", "label": "Cape", "on": false, "meshes": ["Freja_OW2_Cape"]},
			{"id": "necklace", "label": "Necklace", "on": false, "meshes": ["Freja_OW2_Necklance"]},
		],
	},
	1: {
		"name": "Heart of Courage",
		"has_skin_color": false,
		"always": ["Freja_Heart_of_Courage_Hair", "Freja_Heart_of_Courage_HairTail",
			"Freja_Heart_of_Courage_Hair_Side"],
		"accessories_on": [],
		"pieces": [
			{"id": "dress", "label": "Dress", "on": true,
				"meshes": ["Freja_Heart_of_Courage_UpperBody", "Freja_Heart_of_Courage_UpperBody_Breasts",
					"Freja_Heart_of_Courage_Skirt", "Freja_Heart_of_Courage_Skirt_Bind"]},
			{"id": "gloves", "label": "Gauntlets", "on": true,
				"meshes": ["Freja_Heart_of_Courage_Gloves", "Freja_Heart_of_Courage_UpperBody_Wrist"]},
			{"id": "highheels", "label": "Greaves", "on": true, "meshes": ["Freja_Heart_of_Courage_Highheels"]},
			{"id": "earring", "label": "Earring", "on": true, "meshes": ["Freja_Heart_of_Courage_Earring"]},
			{"id": "head_wings", "label": "Head Wings", "on": true, "meshes": ["Freja_Heart_of_Courage_Hair_Misc_Wings"]},
			{"id": "head_ornaments", "label": "Head Ornaments", "on": true,
				"meshes": ["Freja_Heart_of_Courage_Hair_MiscRibbon", "Freja_Heart_of_Courage_Hair_Misc"]},
			{"id": "neck_ribbon", "label": "Neck Ribbon", "on": true, "meshes": ["Freja_Heart_of_Courage_Ribbon_Neck"]},
			{"id": "cape", "label": "Cape", "on": false, "meshes": ["Freja_Heart_of_Courage_Cape"]},
			{"id": "sash", "label": "Waist Sashes", "on": false,
				"meshes": ["Freja_Heart_of_Courage_Ribbon_Pelvis", "Freja_Heart_of_Courage_Ribbon_Back"]},
		],
	},
	2: {
		"name": "Scarlett",
		"has_skin_color": false,
		"always": ["Freja_Scarlett_Hair", "Freja_Scarlett_Hair_Back", "Freja_Scarlett_Hair_Front"],
		"accessories_on": ["sports_bra", "panties"],
		"pieces": [
			{"id": "suit", "label": "Bodysuit", "on": true,
				"meshes": ["Freja_Scarlett_Chest_Open", "Freja_Scarlett_Outfit_Arms", "Freja_Scarlett_Outfit_Neck_Zipper"]},
			{"id": "hood", "label": "Hood Collar", "on": true, "meshes": ["Freja_Scarlett_Chest_Hoodie"]},
			{"id": "gloves", "label": "Gloves", "on": true, "meshes": ["Freja_Scarlett_Gloves"]},
			{"id": "boots", "label": "Boots", "on": true, "meshes": ["Freja_Scarlett_Boots"]},
			{"id": "wrist", "label": "Wrist Guard", "on": true, "meshes": ["Freja_Scarlett_Wrist"]},
			{"id": "straps_upper", "label": "Chest Straps", "on": true, "meshes": ["Freja_Scarlett_Straps_Upper"]},
			{"id": "thigh_strap", "label": "Thigh Strap", "on": true, "meshes": ["Freja_Scarlett_Thight_Strap"]},
			{"id": "earring", "label": "Earring", "on": true, "meshes": ["Freja_Scarlett_Earring"]},
			{"id": "hood_up", "label": "Hood Up", "on": false, "meshes": ["Freja_Scarlett_Chest_HoodieOn"]},
			{"id": "cape", "label": "Cape", "on": false, "meshes": ["Freja_Scarlett_Cape"]},
		],
	},
	3: {
		"name": "Streetwear",
		"has_skin_color": false,
		"always": ["Freja_Streetwear_Hair"],
		"accessories_on": [],
		"pieces": [
			{"id": "bodysuit", "label": "Bodysuit", "on": true,
				"meshes": ["Freja_Streetwear_Body", "Freja_Streetwear_BodyStrapConnect"]},
			{"id": "sleeves", "label": "Jacket", "on": true,
				"meshes": ["Freja_Streetwear_Sleeves", "Freja_Streetwear_Sleeves_Glass"]},
			{"id": "pants", "label": "Pants", "on": true, "meshes": ["Freja_Streetwear_Pants"]},
			{"id": "shoes", "label": "Sneakers", "on": true, "meshes": ["Freja_Streetwear_Shoes"]},
			{"id": "belt", "label": "Belt", "on": true, "meshes": ["Freja_Streetwear_Belt"]},
			{"id": "gloves", "label": "Gloves", "on": true, "meshes": ["Freja_Streetwear_Gloves"]},
			{"id": "hat", "label": "Cap", "on": true, "meshes": ["Freja_Streetwear_Hat"]},
			{"id": "headphones", "label": "Headphones", "on": true, "meshes": ["Freja_Streetwear_Headphone"]},
			{"id": "nose_ring", "label": "Nose Ring", "on": true, "meshes": ["Freja_Streetwear_NosePiercing"]},
			{"id": "cape", "label": "Poncho", "on": false, "meshes": ["Freja_Streetwear_Cape"]},
		],
	},
	4: {
		"name": "Archangel",
		"has_skin_color": false,
		"always": ["Freja_Archangel_Hair"],
		"accessories_on": ["sports_bra", "panties"],
		"pieces": [
			{"id": "dress", "label": "Dress", "on": true,
				"meshes": ["Freja_Archangel_UpperBody_Armor", "Freja_Archangel_UpperbodyBackCloth",
					"Freja_Archangel_LegsUpper", "Freja_Archangel_Legs"]},
			{"id": "arms", "label": "Arm Armor", "on": true,
				"meshes": ["Freja_Archangel_ArmsL_Armor", "Freja_Archangel_ArmsR"]},
			{"id": "helmet", "label": "Helmet", "on": true, "meshes": ["Freja_Archangel_Helmet"]},
			{"id": "pauldrons", "label": "Pauldrons", "on": true, "meshes": ["Freja_Archangel_Shoulderguard"]},
			{"id": "wings", "label": "Feather Wings", "on": true, "meshes": ["Freja_Archangel_SideArmor"]},
			{"id": "cape", "label": "Cape", "on": false, "meshes": ["Freja_Archangel_Cape"]},
		],
	},
}

const SKIN_COLORS := ["OW2", "Raudr", "Syren", "Lavendel", "Solsikke"]

static func outfit_ids() -> Array:
	return OUTFITS.keys()

static func get_outfit(outfit_id: int) -> Dictionary:
	return OUTFITS.get(outfit_id, OUTFITS[0])

## outfit pieces followed by the shared underwear pieces
static func pieces_for(outfit_id: int) -> Array:
	return get_outfit(outfit_id)["pieces"] + SHARED_PIECES

## how many entries in pieces_for belong to the outfit (rest are underwear)
static func outfit_piece_count(outfit_id: int) -> int:
	return get_outfit(outfit_id)["pieces"].size()

static func all_outfit_meshes() -> PackedStringArray:
	var out := PackedStringArray()
	for oid in OUTFITS:
		for m in OUTFITS[oid]["always"]:
			out.append(m)
		for p in OUTFITS[oid]["pieces"]:
			for m in p["meshes"]:
				out.append(m)
	for p in SHARED_PIECES:
		for m in p["meshes"]:
			out.append(m)
	return out

static func default_pieces(outfit_id: int) -> Dictionary:
	var d := {}
	var acc_on: Array = get_outfit(outfit_id).get("accessories_on", [])
	for p in pieces_for(outfit_id):
		d[p["id"]] = p["on"] or (p["id"] in acc_on)
	return d
