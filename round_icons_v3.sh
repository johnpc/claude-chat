#!/bin/bash

# Script to add macOS-style rounded corners to app icons
# Version 3: Using a different approach for better results

ICON_DIR="ClaudeChat/Assets.xcassets/AppIcon.appiconset"
BACKUP_DIR="icon_backups_v3"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Adding macOS-style rounded corners to app icons (version 3)..."
echo "Creating new backups in $BACKUP_DIR/"

# Function to calculate corner radius (more accurate to macOS)
calculate_radius() {
    local size=$1
    # macOS uses approximately 22.37% corner radius
    case $size in
        16) echo 3 ;;
        32) echo 7 ;;
        64) echo 14 ;;
        128) echo 28 ;;
        256) echo 57 ;;
        512) echo 114 ;;
        1024) echo 228 ;;
        *) echo $((size * 22 / 100)) ;;
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
    
    # Method: Create rounded rectangle path and use it as a mask
    # This should preserve colors better
    magick "$file" \
        \( +clone -alpha extract -blur 0x1 -level 50%,100% \
           -draw "roundrectangle 1,1 $((size-2)),$((size-2)) $radius,$radius" \) \
        -compose CopyOpacity -composite \
        -background none -compose Over -flatten \
        "$file"
}

# Alternative method function
process_icon_alt() {
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
    
    # Simpler approach: create mask and apply
    magick \( -size ${size}x${size} xc:none -fill white -draw "roundrectangle 0,0 $((size-1)),$((size-1)) $radius,$radius" \) \
           "$file" \
           -compose DstIn -composite \
           "$file"
}

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null; then
    echo "Error: ImageMagick is not installed."
    echo "Please install it using: brew install imagemagick"
    exit 1
fi

echo "Using alternative method for better results..."
echo ""

# Process all PNG files in the icon directory
for icon_file in "$ICON_DIR"/*.png; do
    if [ -f "$icon_file" ]; then
        process_icon_alt "$icon_file"
    fi
done

echo ""
echo "✅ Done! All icons now have macOS-style rounded corners."
echo "📁 Original icons backed up to: $BACKUP_DIR/"
echo ""
echo "To restore original icons if needed:"
echo "cp $BACKUP_DIR/* $ICON_DIR/"
