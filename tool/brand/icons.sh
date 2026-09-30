#!/bin/sh
# Renders every app icon from the Loomia mark (Figma `07 — Loomia logo`, E5b).
# Needs rsvg-convert (`brew install librsvg`). Run from the repo root after
# changing the geometry below; commit the PNGs it writes.
set -eu

BRAND='#E8964A'

# The mark in its own units (100px type): ring r 28.5 / 15.5, three dots.
# Centred on its bounding box and scaled to 56% of the canvas height.
mark() { # $1 = fill
  cat <<SVG
<g transform="translate(512 512) scale(7.7096) translate(5.1847 8.6905)" fill="$1">
  <circle r="22" fill="none" stroke="$1" stroke-width="13"/>
  <circle cx="-35.119" cy="-16.376" r="3.75"/>
  <circle cx="-18.046" cy="-35.418" r="4.75"/>
  <circle cx="7.076" cy="-40.131" r="5.75"/>
</g>
SVG
}

# $1 = corner radius of the tile (0 = full bleed, for masked platforms)
icon() {
  cat <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024">
  <rect width="1024" height="1024" rx="$1" fill="$BRAND"/>
  $(mark white)
</svg>
SVG
}

tmp=$(mktemp -d)
icon 0 > "$tmp/square.svg"
icon 229 > "$tmp/tile.svg"   # 22.37%, the Figma icon radius

png() { # $1 = svg, $2 = size, $3 = output
  rsvg-convert -w "$2" -h "$2" "$tmp/$1.svg" -o "$3"
}

# iOS masks the icon itself and rejects alpha: full bleed, no transparency.
ios=ios/Runner/Assets.xcassets/AppIcon.appiconset
png square 1024 "$tmp/ios.png"
magick "$tmp/ios.png" -background "$BRAND" -alpha remove -alpha off \
  "$ios/Icon-App-1024x1024@1x.png"

# Web: rounded tile where the browser shows it as is, full bleed where it masks.
png tile 32 web/favicon.png
png tile 192 web/icons/Icon-192.png
png tile 512 web/icons/Icon-512.png
png square 192 web/icons/Icon-maskable-192.png
png square 512 web/icons/Icon-maskable-512.png
png square 180 web/icons/apple-touch-icon.png

# Android below 8.0; 8.0+ uses the adaptive vector in mipmap-anydpi-v26.
res=android/app/src/main/res
png tile 48 $res/mipmap-mdpi/ic_launcher.png
png tile 72 $res/mipmap-hdpi/ic_launcher.png
png tile 96 $res/mipmap-xhdpi/ic_launcher.png
png tile 144 $res/mipmap-xxhdpi/ic_launcher.png
png tile 192 $res/mipmap-xxxhdpi/ic_launcher.png

rm -r "$tmp"
