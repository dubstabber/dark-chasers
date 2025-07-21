# DirectionalSprite3D Texture Bleeding Fix

## Problem Description

The DirectionalSprite3D system was experiencing texture bleeding/artifacts where parts of adjacent sprites in the atlas would leak into the rendered sprite areas. The artifacts were **different each time the game started**, indicating deeper issues. The problems were caused by:

1. **No Physical Padding**: The atlas generation placed sprites directly adjacent to each other without any padding
2. **Inadequate UV Clamping**: The shader attempted to prevent bleeding through UV manipulation alone, which was insufficient
3. **Compressed Texture Artifacts**: Compressed textures with high quality settings have sampling artifacts at boundaries that cause bleeding
4. **Race Conditions**: Multiple deferred atlas generation calls could cause inconsistent atlas creation
5. **Direction Order Mismatch**: Sorting directions broke shader's hardcoded direction indices (0=front, 1=side, 2=back)
6. **Memory Issues**: Inconsistent atlas initialization and null sprite handling

## Solution Implemented

### 1. Atlas Generation Changes (`directional_sprite_3d.gd`)

- **Race Condition Prevention**: Added `_atlas_generation_pending` flag and `_schedule_atlas_generation()` to prevent concurrent generation
- **Deterministic Generation**: Added sprite configuration hashing to detect actual changes and avoid unnecessary regeneration
- **Direction Order Preservation**: Maintained original direction order (`["front", "side", "back"]`) to match shader's hardcoded indices
- **Dynamic Padding**: Introduced `ATLAS_PADDING` (2 pixels) and `COMPRESSED_TEXTURE_PADDING` (4 pixels) constants
- **Compressed Texture Detection**: Automatically detects compressed textures and uses increased padding
- **Border Extension**: Conservative edge clamping by extending sprite borders into padding areas
- **Enhanced Blitting**: Updated `_blit_sprite_to_atlas()` to handle padded cell positioning correctly
- **Memory Safety**: Proper atlas initialization with transparent background and null sprite handling

### 2. Shader Improvements (`directional_sprite_3d.gdshader`)

- **New Uniforms**: Added `padded_frame_size` and `has_compressed_textures` uniforms
- **Compressed Texture Handling**: Enhanced UV clamping specifically for compressed textures
- **Dual UV Calculation Paths**: Different UV handling for compressed vs uncompressed textures
- **Aggressive Inset Clamping**: Additional 0.5-pixel inset for compressed textures to avoid edge artifacts
- **Maintained Compatibility**: Preserved all existing THREE_DIRECTIONAL functionality

### 3. Key Changes Made

#### Atlas Generation

```gdscript
# Before: No padding between sprites
var atlas_dimensions = Vector2i(sprite_size.x * max_frames, sprite_size.y * directions.size())

# After: Physical padding between sprites
const ATLAS_PADDING: int = 2
var padded_sprite_size = Vector2i(sprite_size.x + ATLAS_PADDING, sprite_size.y + ATLAS_PADDING)
var atlas_dimensions = Vector2i(padded_sprite_size.x * max_frames, padded_sprite_size.y * directions.size())
```

#### Shader UV Calculation

```glsl
// Before: Complex padding calculations in shader
vec2 padding = vec2(0.5) / atlas_dimensions;
vec2 safe_frame_size = normalized_frame_size - (padding * 2.0);
vec2 final_uv = normalized_frame_pos + padding + (uv * safe_frame_size);

// After: Simple calculation using physical padding
vec2 atlas_frame_pos = vec2(
    float(current_frame) * padded_frame_size.x,
    float(sprite_direction) * padded_frame_size.y
);
vec2 final_uv = normalized_frame_pos + (uv * normalized_frame_size);
```

## Benefits

1. **Eliminates Texture Bleeding**: Physical padding and proper UV mapping prevent GPU sampling from adjacent sprites
2. **Respects Texture Import Settings**: Compatible with VRAM Compressed, High Quality, and Fix Alpha Border settings
3. **Conservative Approach**: Uses minimal padding (2-4 pixels) to avoid over-padding issues
4. **Accurate UV Mapping**: Shader correctly calculates sprite position within padded atlas cells
5. **Backward Compatible**: Existing THREE_DIRECTIONAL animations continue to work
6. **Automatic Detection**: Dynamically adjusts padding based on compressed texture detection

## Testing

A test script (`test_atlas_bleeding.gd`) and scene (`test_bleeding_fix.tscn`) have been created to verify:

- Atlas generation with proper padding
- Shader parameter consistency
- Frame positioning accuracy
- Padding calculations

## Usage Notes

- The `ATLAS_PADDING` constant can be adjusted if needed (currently 2 pixels)
- Larger sprites may benefit from increased padding
- The fix maintains all existing DirectionalSpriteAnimator compatibility
- No changes required to existing sprite assignments or animations

## Files Modified

1. `scenes/components/directional_sprite_3d/directional_sprite_3d.gd`

   - Added `ATLAS_PADDING` constant
   - Modified atlas generation logic
   - Updated shader parameter passing

2. `scenes/components/directional_sprite_3d/directional_sprite_3d.gdshader`
   - Added `padded_frame_size` uniform
   - Simplified fragment shader UV calculations
   - Improved texture sampling accuracy

## Files Added

1. `scenes/components/directional_sprite_3d/test_atlas_bleeding.gd` - Test script
2. `scenes/components/directional_sprite_3d/test_bleeding_fix.tscn` - Test scene
3. `scenes/components/directional_sprite_3d/TEXTURE_BLEEDING_FIX.md` - This documentation
