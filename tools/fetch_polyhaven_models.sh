#!/bin/bash
# Fetch a set of Poly Haven CC0 models (gltf + bin + textures) into
# assets/props/polyhaven/<slug>/ preserving the relative paths the .gltf expects.
#   bash tools/fetch_polyhaven_models.sh
set -e
DEST="assets/props/polyhaven"
SLUGS=(
  boulder_01 namaqualand_boulder_02 namaqualand_boulder_04 namaqualand_rocks_01
  fern_02 grass_medium_01 grass_medium_02 moss_01
  tree_stump_01 tree_stump_02 dead_tree_trunk dry_branches_medium_01
  pine_roots
)
for slug in "${SLUGS[@]}"; do
  echo "== $slug =="
  mkdir -p "$DEST/$slug/textures"
  json=$(curl -s "https://api.polyhaven.com/files/$slug")
  # gltf file
  gurl=$(echo "$json" | python3 -c "import json,sys;print(json.load(sys.stdin)['gltf']['1k']['gltf']['url'])")
  curl -sL -o "$DEST/$slug/$slug.gltf" "$gurl"
  # includes (bin + textures)
  echo "$json" | python3 -c "
import json,sys
inc=json.load(sys.stdin)['gltf']['1k']['gltf']['include']
for p,i in inc.items(): print(p+'\t'+i['url'])
" | while IFS=$'\t' read -r rel url; do
    mkdir -p "$DEST/$slug/$(dirname "$rel")"
    curl -sL -o "$DEST/$slug/$rel" "$url"
  done
done
echo "done -> $DEST"
