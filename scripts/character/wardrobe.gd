extends RefCounted
## Curated in-game wardrobe for Freja, distilled from the CloudRig rig
## (assets/cloudrig_freja_customization_schema.json). Each outfit lists the meshes
## that are always shown plus optional "pieces" the player can toggle.
##
## Mesh names match nodes in assets/characters/freja/freja.glb.

const SHARED_ALWAYS := [
	"Freja_Eye", "Freja_EyeShadow",
	"Freja_Teeth_Upper", "Freja_Teeth_Lower", "Freja_Tongue",
]

## Base skin mesh. Kept visible under every outfit (arms / face / neck).
const BODY_MESH := "Freja_Nude_Body"

## outfit_id -> definition
const OUTFITS := {
	0: {
		"name": "Combat (OW2)",
		"prefix": "Freja_OW2_",
		"body_material": "Freja_Body_OW2",
		"has_skin_color": true,
		"always": ["Freja_OW2_Bodysuit", "Freja_OW2_Hair"],
		"pieces": [
			{"id": "chest_armor", "label": "Chest Armor", "on": true,
				"meshes": ["Freja_OW2_Chest_Armor"]},
			{"id": "fur_collar", "label": "Fur Collar", "on": true,
				"meshes": ["Freja_OW2_Collar_Fur"]},
			{"id": "hoodie", "label": "Hood", "on": false,
				"meshes": ["Freja_OW2_Chest_Armor_Hoodie"]},
			{"id": "shirt", "label": "Shirt", "on": false,
				"meshes": ["Freja_OW2_Shirt"]},
			{"id": "gloves", "label": "Gloves", "on": true,
				"meshes": ["Freja_OW2_Gloves"]},
			{"id": "boots", "label": "Boots", "on": true,
				"meshes": ["Freja_OW2_Boots"]},
			{"id": "belt", "label": "Belt", "on": true,
				"meshes": ["Freja_OW2_Belt", "Freja_OW2_Belt_Arrows", "Freja_OW2_Belt_Utility"]},
			{"id": "cape", "label": "Cape", "on": false,
				"meshes": ["Freja_OW2_Cape"]},
			{"id": "necklace", "label": "Necklace", "on": false,
				"meshes": ["Freja_OW2_Necklance"]},
			{"id": "earring", "label": "Earring", "on": true,
				"meshes": ["Freja_OW2_Earring"]},
			{"id": "nose_ring", "label": "Nose Ring", "on": false,
				"meshes": ["Freja_OW2_Nose_Piercing"]},
			{"id": "hair_front", "label": "Hair Fringe", "on": true,
				"meshes": ["Freja_OW2_Hair-Front"]},
			{"id": "hair_side", "label": "Hair Sides", "on": true,
				"meshes": ["Freja_OW2_Hair-Side"]},
			{"id": "hair_straps", "label": "Hair Wraps", "on": true,
				"meshes": ["Freja_OW2_Hair_Straps"]},
		],
	},
	1: {
		"name": "Heart of Courage",
		"prefix": "Freja_Heart_of_Courage_",
		"body_material": "Freja_Heart_of_Courage_Body",
		"has_skin_color": false,
		"always": [
			"Freja_Heart_of_Courage_UpperBody", "Freja_Heart_of_Courage_UpperBody_Breasts",
			"Freja_Heart_of_Courage_Skirt", "Freja_Heart_of_Courage_Hair",
			"Freja_Heart_of_Courage_HairTail",
		],
		"pieces": [
			{"id": "gloves", "label": "Gauntlets", "on": true,
				"meshes": ["Freja_Heart_of_Courage_Gloves", "Freja_Heart_of_Courage_UpperBody_Wrist"]},
			{"id": "highheels", "label": "Boots", "on": true,
				"meshes": ["Freja_Heart_of_Courage_Highheels"]},
			{"id": "cape", "label": "Cape", "on": true,
				"meshes": ["Freja_Heart_of_Courage_Cape"]},
			{"id": "earring", "label": "Earring", "on": true,
				"meshes": ["Freja_Heart_of_Courage_Earring"]},
			{"id": "head_wings", "label": "Head Wings", "on": true,
				"meshes": ["Freja_Heart_of_Courage_Hair_Misc_Wings"]},
			{"id": "head_ribbon", "label": "Head Ribbon", "on": true,
				"meshes": ["Freja_Heart_of_Courage_Hair_MiscRibbon", "Freja_Heart_of_Courage_Hair_Misc"]},
			{"id": "hair_side", "label": "Hair Sides", "on": true,
				"meshes": ["Freja_Heart_of_Courage_Hair_Side"]},
			{"id": "neck_ribbon", "label": "Neck Ribbon", "on": true,
				"meshes": ["Freja_Heart_of_Courage_Ribbon_Neck"]},
			{"id": "pelvis_ribbon_f", "label": "Sash (Front)", "on": true,
				"meshes": ["Freja_Heart_of_Courage_Ribbon_Pelvis"]},
			{"id": "pelvis_ribbon_b", "label": "Sash (Back)", "on": true,
				"meshes": ["Freja_Heart_of_Courage_Ribbon_Back"]},
			{"id": "cat", "label": "Kitten", "on": false,
				"meshes": ["Freja_Heart_of_Courage_Kittie"]},
		],
	},
	2: {
		"name": "Scarlett",
		"prefix": "Freja_Scarlett_",
		"body_material": "Freja_Scarlett_Body",
		"has_skin_color": false,
		"always": [
			"Freja_Scarlett_Chest_Closed", "Freja_Scarlett_Outfit_Arms",
			"Freja_Scarlett_Outfit_Neck_Zipper", "Freja_Scarlett_Hair",
			"Freja_Scarlett_Hair_Back", "Freja_Scarlett_Hair_Front",
		],
		"pieces": [
			{"id": "hoodie", "label": "Hood", "on": false,
				"meshes": ["Freja_Scarlett_Chest_Hoodie", "Freja_Scarlett_Chest_HoodieOn"]},
			{"id": "gloves", "label": "Gloves", "on": true,
				"meshes": ["Freja_Scarlett_Gloves"]},
			{"id": "boots", "label": "Boots", "on": true,
				"meshes": ["Freja_Scarlett_Boots"]},
			{"id": "cape", "label": "Cape", "on": false,
				"meshes": ["Freja_Scarlett_Cape"]},
			{"id": "wrist", "label": "Wrist Guard", "on": true,
				"meshes": ["Freja_Scarlett_Wrist"]},
			{"id": "straps_upper", "label": "Chest Straps", "on": true,
				"meshes": ["Freja_Scarlett_Straps_Upper"]},
			{"id": "thigh_strap", "label": "Thigh Strap", "on": true,
				"meshes": ["Freja_Scarlett_Thight_Strap"]},
			{"id": "earring", "label": "Earring", "on": true,
				"meshes": ["Freja_Scarlett_Earring"]},
		],
	},
	3: {
		"name": "Streetwear",
		"prefix": "Freja_Streetwear_",
		"body_material": "Streetwear_Body",
		"has_skin_color": false,
		"always": ["Freja_Streetwear_Body", "Freja_Streetwear_Hair"],
		"pieces": [
			{"id": "pants", "label": "Pants", "on": true,
				"meshes": ["Freja_Streetwear_Pants"]},
			{"id": "shoes", "label": "Sneakers", "on": true,
				"meshes": ["Freja_Streetwear_Shoes"]},
			{"id": "sleeves", "label": "Jacket", "on": true,
				"meshes": ["Freja_Streetwear_Sleeves", "Freja_Streetwear_Sleeves_Glass",
					"Freja_Streetwear_BodyStrapConnect"]},
			{"id": "belt", "label": "Belt", "on": true,
				"meshes": ["Freja_Streetwear_Belt"]},
			{"id": "gloves", "label": "Gloves", "on": false,
				"meshes": ["Freja_Streetwear_Gloves"]},
			{"id": "hat", "label": "Cap", "on": false,
				"meshes": ["Freja_Streetwear_Hat"]},
			{"id": "headphones", "label": "Headphones", "on": true,
				"meshes": ["Freja_Streetwear_Headphone"]},
			{"id": "cape", "label": "Poncho", "on": false,
				"meshes": ["Freja_Streetwear_Cape"]},
			{"id": "nose_ring", "label": "Nose Ring", "on": false,
				"meshes": ["Freja_Streetwear_NosePiercing"]},
		],
	},
	4: {
		"name": "Archangel",
		"prefix": "Freja_Archangel_",
		"body_material": "Archangel_Body",
		"has_skin_color": false,
		"always": [
			"Freja_Archangel_Upperbody", "Freja_Archangel_UpperBody_Armor",
			"Freja_Archangel_LegsUpper", "Freja_Archangel_Legs",
			"Freja_Archangel_ArmsL", "Freja_Archangel_ArmsL_Armor", "Freja_Archangel_ArmsR",
			"Freja_Archangel_Hair",
		],
		"pieces": [
			{"id": "helmet", "label": "Helmet", "on": true,
				"meshes": ["Freja_Archangel_Helmet"]},
			{"id": "pauldrons", "label": "Pauldrons", "on": true,
				"meshes": ["Freja_Archangel_Shoulderguard"]},
			{"id": "side_armor", "label": "Hip Armor", "on": true,
				"meshes": ["Freja_Archangel_SideArmor"]},
			{"id": "cape", "label": "Cape", "on": true,
				"meshes": ["Freja_Archangel_Cape"]},
			{"id": "back_cloth", "label": "Back Cloth", "on": true,
				"meshes": ["Freja_Archangel_UpperbodyBackCloth"]},
			{"id": "panties", "label": "Underlayer", "on": true,
				"meshes": ["Freja_Archangel_Panties"]},
		],
	},
}

const SKIN_COLORS := ["OW2", "Raudr", "Syren", "Lavendel", "Solsikke"]

static func outfit_ids() -> Array:
	return OUTFITS.keys()

static func get_outfit(outfit_id: int) -> Dictionary:
	return OUTFITS.get(outfit_id, OUTFITS[0])

## All mesh names referenced by any outfit (for the "hide everything first" pass).
static func all_outfit_meshes() -> PackedStringArray:
	var out := PackedStringArray()
	for oid in OUTFITS:
		var o: Dictionary = OUTFITS[oid]
		for m in o["always"]:
			out.append(m)
		for p in o["pieces"]:
			for m in p["meshes"]:
				out.append(m)
	return out

## Default piece states for an outfit -> { piece_id: bool }
static func default_pieces(outfit_id: int) -> Dictionary:
	var d := {}
	for p in get_outfit(outfit_id)["pieces"]:
		d[p["id"]] = p["on"]
	return d
