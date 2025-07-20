# DirectionalSprite3D System

A complete directional sprite rendering system for Godot 4 that automatically displays different sprite directions based on camera viewing angle.

## Features

- **Per-camera directional calculation**: Each camera sees the sprite independently
- **THREE_DIRECTIONAL support**: Front, back, and side views with automatic horizontal flipping
- **Texture atlas generation**: Automatically creates optimized atlases from individual sprites
- **Shader-based rendering**: Custom shader samples correct atlas regions
- **Godot editor integration**: Respects Alpha Cut, Billboard, and Shaded properties
- **Runtime and editor preview**: Works in both game and Godot editor

## How It Works

### 1. Atlas Generation

The system automatically generates texture atlases from your sprite collections:

- **Row layout**: Each direction gets its own row (front=0, side=1, back=2)
- **Column layout**: Idle sprite in column 0, movement frames in subsequent columns
- **Optimized sampling**: Shader only displays the relevant atlas region

### 2. Camera Direction Calculation

Based on the camera position relative to the target object:

- **Front**: Camera is in front of target (forward_dot < -0.5)
- **Back**: Camera is behind target (forward_dot > 0.5)
- **Side**: Camera is to the side (abs(forward_dot) <= 0.5)

### 3. Horizontal Flipping

For THREE_DIRECTIONAL mode:

- Side sprites automatically flip horizontally based on camera position
- Right side of target shows flipped sprite, left side shows normal sprite

## Setup Instructions

### 1. Add DirectionalSprite3D to Your Scene

```gdscript
# In your scene, add a Sprite3D node and attach the DirectionalSprite3D script
# Or use the DirectionalSprite3D class directly
```

### 2. Configure Sprites in Inspector

- Set **Direction Mode** to THREE_DIRECTIONS
- Add sprites to **Idle Sprites** group:
  - `front_idle_sprite`: Sprite when camera is in front
  - `side_idle_sprite`: Sprite when camera is to the side
  - `back_idle_sprite`: Sprite when camera is behind
- If target has movement, add **Movement Sprites** arrays for each direction

### 3. Set Target Node (Optional)

- Leave `target_node_path` empty to use parent node as target
- Or set path to specific target node for direction calculation

### 4. Configure Sprite3D Properties

- **Billboard**: Set to "Y-Axis" (2) for sprites that rotate to face camera horizontally
- **Shaded**: Enable for lighting effects
- **Alpha Cut**: Set transparency threshold (0.0-1.0)

**Note**: The custom shader implements Y-axis billboard functionality directly, so the sprite will properly face the camera while maintaining correct directional sprite selection.

## Example Usage

```gdscript
# The player scene already demonstrates this:
# - DirectionalSprite3D with front/side/back sprites
# - Automatic direction switching based on camera
# - Movement state detection from parent node
```

## Testing

Use the provided test scene:

1. Open `test_directional_sprite.tscn`
2. Add your sprites to the DirectionalSprite3D node
3. Use arrow keys/WASD to orbit camera around target
4. Observe automatic direction switching

## Technical Details

### Shader Uniforms

- `atlas_texture`: The generated texture atlas
- `atlas_dimensions`: Full atlas size in pixels
- `frame_size`: Individual sprite size in pixels
- `current_direction`: Direction index (0=front, 1=side, 2=back)
- `current_frame`: Animation frame (0=idle, 1+=movement)
- `flip_horizontal`: Whether to flip sprite horizontally
- `billboard_enabled`: Whether Y-axis billboard rotation is active
- `alpha_cut`: Alpha testing threshold
- `albedo_color`: Base color multiplier

### Billboard Implementation

The shader implements Y-axis billboard functionality in the vertex shader:

- Calculates camera direction in world space
- Creates rotation matrix to face camera horizontally
- Maintains vertical Y-axis orientation
- Handles edge cases (camera directly above/below)
- Automatically syncs with Sprite3D's billboard property

### Universal Camera Detection

The system now calculates directions directly in the shader for universal compatibility:

- **Editor Preview**: Works with Godot editor cameras in 3D viewport
- **Mirror Rendering**: Correctly handles reflective surfaces and virtual cameras
- **Multiple Cameras**: Works with any camera context, not just main viewport
- **Real-time Calculation**: Direction determined per-pixel based on actual rendering camera
- **Automatic Updates**: No script-based camera polling required

### Performance

- **Efficient**: Single draw call per sprite using atlas
- **Optimized**: Only updates when direction or movement state changes
- **Scalable**: Works with multiple DirectionalSprite3D instances

## Compatibility

- **Godot Version**: 4.x
- **Render Pipeline**: Compatible with Forward+ and Mobile renderers
- **Platform**: All platforms supported by Godot 4

## Troubleshooting

### Sprites Not Showing

1. Check that sprites are assigned in inspector
2. Verify atlas generation succeeded (check texture property)
3. Ensure shader material is properly assigned

### Wrong Direction Displayed

1. Verify target_node_path points to correct object
2. Check that target object has proper transform/rotation
3. Test with different camera positions

### Editor Preview Not Working

1. Ensure sprites are assigned in inspector
2. Move editor camera around object in 3D viewport
3. Check that auto_direction is enabled in shader
4. Verify target_position is being updated

### Mirror Rendering Issues

1. Check that mirrors use proper reflection setup
2. Verify DirectionalSprite3D is in mirror's view
3. Test with different mirror angles
4. Ensure target object is positioned correctly

### Performance Issues

1. Limit number of DirectionalSprite3D instances
2. Use appropriate sprite resolutions
3. Consider LOD system for distant sprites
