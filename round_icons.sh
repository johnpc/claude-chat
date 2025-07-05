#!/bin/bash

# Script to add rounded corners to macOS app icons
# This matches the standard macOS app icon style

ICON_DIR="ClaudeChat/Assets.xcassets/AppIcon.appiconset"
BACKUP_DIR="icon_backups"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Adding rounded corners to app icons..."
echo "Creating backups in $BACKUP_DIR/"

# Function to calculate corner radius based on icon size
# macOS uses approximately 22.37% of the icon size as corner radius
calculate_radius() {
    local size=$1
    echo $(( size * 2237 / 10000 ))
}

# Function to process each icon
process_icon() {
    local file=$1
    local filename=$(basename "$file")
    
    # Extract size from filename (e.g., icon_128x128.png -> 128)
    local size=$(echo "$filename" | grep -o '[0-9]\+x[0-9]\+' | head -1 | cut -d'x' -f1)
    
    if [ -z "$size" ]; then
        echo "Warning: Could not determine size for $filename, skipping..."
        return
    fi
    
    local radius=$(calculate_radius $size)
    
    echo "Processing $filename (${size}x${size}, radius: ${radius}px)..."
    
    # Create backup
    cp "$file" "$BACKUP_DIR/$filename"
    
    # Create rounded corners using ImageMagick
    # This creates a mask and applies it to create smooth rounded corners
    magick "$file" \
        \( +clone -alpha extract \
           -draw "fill black polygon 0,0 0,$radius $radius,0 fill white circle $radius,$radius $radius,0" \
           \( +clone -flip \) -compose Multiply -composite \
           \( +clone -flop \) -compose Multiply -composite \
        \) -alpha off -compose CopyOpacity -composite \
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
echo "✅ Done! All icons now have rounded corners."
echo "📁 Original icons backed up to: $BACKUP_DIR/"
echo ""
echo "To restore original icons if needed:"
echo "cp $BACKUP_DIR/* $ICON_DIR/"
