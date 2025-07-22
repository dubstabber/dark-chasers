# DirectionalSprite3D Component

## Overview

The DirectionalSprite3D component provides automatic directional sprite rendering with proper texture sizing and atlas preview functionality. It extends Sprite3D and uses a custom shader to display different sprites based on camera viewing direction.

## New Features

### 1. Atlas Preview
- **Property**: `atlas_preview` (read-only)
- **Description**: Shows the complete generated texture atlas in the inspector
- **Purpose**: Allows you to visually inspect how all sprites are arranged in the atlas
- **Note**: This property is not editable and updates automatically when sprites change

### 2. Proper Texture Sizing
- **Property**: `texture` (the main Sprite3D texture)
- **Description**: Contains the currently selected sprite with proper dimensions
- **Sizing**: Uses the maximum width and height of all provided sprites (idle + movement)
- **Centering**: Smaller sprites are automatically centered within the properly sized canvas
- **Purpose**: Ensures consistent sprite sizing regardless of individual sprite dimensions

## How It Works

1. **Atlas Generation**: All idle and movement sprites are combined into a single atlas texture
2. **Size Calculation**: The component finds the largest width and height among all sprites
3. **Display Texture**: Creates a properly sized texture showing the current sprite (based on direction and movement state)
4. **Shader Rendering**: Uses the atlas texture for actual 3D rendering with per-camera independence

## Usage Example

```gdscript
# Set up a THREE_DIRECTIONS sprite with different sized sprites
var sprite = DirectionalSprite3D.new()
sprite.direction_mode = DirectionalSprite3D.DirectionMode.THREE_DIRECTIONS

# Add idle sprites (different sizes)
sprite.front_idle_sprite = load("res://sprites/front_64x64.png")
sprite.side_idle_sprite = load("res://sprites/side_48x72.png")  
sprite.back_idle_sprite = load("res://sprites/back_32x48.png")

# The texture property will be 64x72 (max width x max height)
# Each sprite will be centered within this canvas
# The atlas_preview will show the complete atlas layout
```

## Inspector Properties

- **Atlas Preview**: Read-only texture showing the complete atlas
- **Direction Mode**: THREE_DIRECTIONS, FOUR_DIRECTIONS, etc.
- **Idle Sprites**: Individual idle sprites for each direction
- **Movement Sprites**: Arrays of movement animation frames for each direction

## Benefits

1. **Consistent Sizing**: All sprites appear with the same bounding box size
2. **Visual Atlas Inspection**: Easy to see how the atlas is generated
3. **Proper Centering**: Smaller sprites are automatically centered
4. **Shader Compatibility**: Atlas generation works seamlessly with the directional shader
5. **Per-Camera Independence**: Each camera sees the correct directional sprite

## Testing

Use the included test scene (`test_directional_sprite.tscn`) to see the component in action:
- Move around with WASD to see directional changes
- Press Space to print debug information
- Observe both the atlas preview and display texture in the inspector
