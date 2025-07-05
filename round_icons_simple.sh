#!/bin/bash

# Script to add macOS-style rounded corners to app icons
# Simple version without external dependencies

ICON_DIR="ClaudeChat/Assets.xcassets/AppIcon.appiconset"
BACKUP_DIR="icon_backups"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Adding macOS-style rounded corners to app icons..."
echo "Creating backups in $BACKUP_DIR/"

# Function to calculate corner radius (simplified)
calculate_radius() {
    local size=$1
    case $size in
        16) echo 4 ;;
        32) echo 7 ;;
        64) echo 14 ;;
        128) echo 29 ;;
        256) echo 57 ;;
        512) echo 115 ;;
        1024) echo 229 ;;
        *) echo $((size / 4)) ;;  # Fallback: 25% of size
    esac
}

# Function to process each icon
process_icon() {
    local file=$1
    local filename=$(basename "$file")
    
    # Extract size from filename
    local size=$(echo "$filename" | grep -o '[0-9]\+x[0-9]\+' | head -1 | cut -d'x' -f1)
    
    if [ -z "$size" ]; then
        echo "Warning: Could not determine size for $filename, skipping..."
        return
    fi
    
    local radius=$(calculate_radius $size)
    
    echo "Processing $filename (${size}x${size}, radius: ${radius}px)..."
    
    # Create backup
    cp "$file" "$BACKUP_DIR/$filename"
    
    # Create macOS-style rounded corners
    magick "$file" \
        \( -size ${size}x${size} xc:none -draw "roundrectangle 0,0 $((size-1)),$((size-1)) $radius,$radius" \) \
        -compose SrcIn -composite \
        "$file"
}

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null; then
    echo "Error: ImageMagick is not installed."
    echo "Please install it using: brew install imagemagick"
    exit 1
fi

# Process all PNG files in the icon directory
for icon_file in "$ICON_DIR"/*.png; do
    if [ -f "$icon_file" ]; then
        process_icon "$icon_file"
    fi
done

echo ""
echo "✅ Done! All icons now have macOS-style rounded corners."
echo "📁 Original icons backed up to: $BACKUP_DIR/"
echo ""
echo "To restore original icons if needed:"
echo "cp $BACKUP_DIR/* $ICON_DIR/"
echo ""
echo "You can now build your app in Xcode to see the new rounded icons!"
