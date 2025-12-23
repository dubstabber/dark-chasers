#!/usr/bin/env python3
"""
Convert mask images (white on black) to transparent images.

This script converts DOOM-style blood splat mask images where:
- White pixels = blood (should become opaque with the color)
- Black pixels = background (should become transparent)
- Gray pixels = anti-aliased edges (should become semi-transparent)

The conversion uses the luminance of each pixel to determine alpha:
- Luminance 0 (black) → Alpha 0 (fully transparent)
- Luminance 255 (white) → Alpha 255 (fully opaque)
- Gray values → Proportional alpha (preserves anti-aliasing)

Usage:
    python convert_mask_to_transparent.py <input_image> [output_image]
    python convert_mask_to_transparent.py --batch <directory>

Examples:
    python convert_mask_to_transparent.py bsplat1.png
    python convert_mask_to_transparent.py --batch ../images/particles/
"""

import sys
import os
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Error: Pillow library is required. Install it with:")
    print("  pip install Pillow")
    sys.exit(1)


def convert_mask_to_transparent(input_path: str, output_path: str = None) -> None:
    """
    Convert a mask image (white on black) to a transparent image.
    
    The luminance of each pixel determines the alpha value:
    - Black (0) → Transparent (alpha 0)
    - White (255) → Opaque (alpha 255)
    - Gray → Semi-transparent (proportional alpha)
    
    The output image will be white with varying alpha, so it can be
    tinted with any color using modulate in Godot.
    """
    if output_path is None:
        output_path = input_path
    
    # Load the image
    img = Image.open(input_path)
    
    # Convert to RGBA if not already
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # Get pixel data
    pixels = img.load()
    width, height = img.size
    
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            
            # Calculate luminance (perceived brightness)
            # Using standard luminance formula: 0.299*R + 0.587*G + 0.114*B
            luminance = int(0.299 * r + 0.587 * g + 0.114 * b)
            
            # The luminance becomes the alpha value
            # White pixels (high luminance) → high alpha (opaque)
            # Black pixels (low luminance) → low alpha (transparent)
            new_alpha = luminance
            
            # Set pixel to white with calculated alpha
            # This allows the sprite to be tinted with any color via modulate
            pixels[x, y] = (255, 255, 255, new_alpha)
    
    # Save the result
    img.save(output_path, 'PNG')
    print(f"Converted: {input_path} → {output_path}")


def batch_convert(directory: str, pattern: str = "bsplat*.png") -> None:
    """
    Convert all matching mask images in a directory.
    """
    import glob
    
    dir_path = Path(directory)
    if not dir_path.exists():
        print(f"Error: Directory not found: {directory}")
        sys.exit(1)
    
    # Find all matching files
    files = list(dir_path.glob(pattern))
    
    if not files:
        print(f"No files matching '{pattern}' found in {directory}")
        return
    
    print(f"Found {len(files)} files to convert:")
    for file_path in files:
        convert_mask_to_transparent(str(file_path))
    
    print(f"\nDone! Converted {len(files)} files.")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    if sys.argv[1] == '--batch':
        if len(sys.argv) < 3:
            print("Error: --batch requires a directory path")
            print("Usage: python convert_mask_to_transparent.py --batch <directory>")
            sys.exit(1)
        batch_convert(sys.argv[2])
    elif sys.argv[1] == '--help' or sys.argv[1] == '-h':
        print(__doc__)
    else:
        input_path = sys.argv[1]
        output_path = sys.argv[2] if len(sys.argv) > 2 else None
        
        if not os.path.exists(input_path):
            print(f"Error: File not found: {input_path}")
            sys.exit(1)
        
        convert_mask_to_transparent(input_path, output_path)


if __name__ == '__main__':
    main()
