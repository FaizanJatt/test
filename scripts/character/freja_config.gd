extends Resource
class_name FrejaConfig
## Serializable description of one customized Freja look.
## Mirrors the CloudRig settings we expose in-game (see assets/cloudrig_freja_cheatsheet.json).

## 0 Default(OW2) | 1 Heart of Courage | 2 Scarlett | 3 Streetwear | 4 Archangel
@export var outfit_id: int = 3

## Only meaningful for outfit 0. 0 (OW2) | 1 Rauðr | 2 Syren | 3 Lavendel | 4 Solsikke
@export var skin_color: int = 0

## piece_name -> bool. Which optional clothing pieces of the active outfit are shown.
@export var pieces: Dictionary = {}

## Free-form colour overrides applied on top of the outfit.
@export var hair_color: Color = Color(1, 1, 1)
@export var eye_color: Color = Color(1, 1, 1)

## Body shape blend (0..1 each), keyed by morph label.
@export var body: Dictionary = {}

func duplicate_config() -> FrejaConfig:
	var c := FrejaConfig.new()
	c.outfit_id = outfit_id
	c.skin_color = skin_color
	c.pieces = pieces.duplicate(true)
	c.hair_color = hair_color
	c.eye_color = eye_color
	c.body = body.duplicate(true)
	return c
