# Shooting Sprites Implementation

## Overview
This document outlines the implementation of shooting sprites for the DirectionalSprite3D system in the Dark Chasers game project.

## Changes Made

### 1. Player Class (`scenes/player/player.gd`)
- **Added**: `shooting_state` variable (line 85)
  ```gdscript
  var shooting_state := "idle"
  ```
- This variable will be used to track the player's shooting state (idle, shooting, reloading, etc.)
- The DirectionalSprite3D system automatically detects this variable to show shooting sprite properties in the inspector

### 2. DirectionalSprite3D Class (`scenes/components/directional_sprite_3d/directional_sprite_3d.gd`)

#### Constants
- **Added**: `SHOOTING_SUFFIX = "_shooting_sprites"` (line 14)
- This constant defines the suffix used for shooting sprite properties in the inspector

#### Variables
- **Added**: `has_shooting_state := false` (line 27)
- **Added**: `shooting_sprites := {}` (line 30)
- The `has_shooting_state` flag determines whether to show shooting sprite properties
- The `shooting_sprites` dictionary stores arrays of shooting sprites for each direction

#### Property System Updates
- **Updated**: `_get()` method to handle shooting sprite properties
- **Updated**: `_set()` method to handle shooting sprite assignment and trigger atlas regeneration
- **Updated**: `_get_property_list()` method to conditionally show "Shooting sprites" group when target has `shooting_state`

#### Target Detection
- **Updated**: `_get_target_node()` method to detect `shooting_state` variable in target scripts
- The system now checks for both `moving_state` and `shooting_state` variables

#### Atlas Generation
- **Updated**: `_has_any_sprites()` method to include shooting sprites in validation
- **Updated**: `_get_sprite_max_dimensions()` method to consider shooting sprites for atlas sizing
- **Updated**: `_collect_direction_sprites()` method to include shooting sprites in the atlas

## How It Works

1. **Automatic Detection**: When a DirectionalSprite3D component is attached to a node or targets a node with a `shooting_state` variable, it automatically detects this and shows shooting sprite properties in the inspector.

2. **Inspector Properties**: The inspector will show a "Shooting sprites" group with properties for each direction (e.g., "front_shooting_sprites", "side_shooting_sprites", etc.) based on the selected direction mode.

3. **Atlas Integration**: Shooting sprites are seamlessly integrated into the existing atlas generation system:
   - They contribute to maximum sprite dimension calculations
   - They are included in the sprite collection process
   - They are properly positioned in the generated atlas texture

4. **Flexible Arrays**: Each direction can have multiple shooting sprite frames (stored as arrays), allowing for shooting animations.

## Usage

1. **Setup**: Ensure your target node (like the Player) has a `shooting_state` variable
2. **Inspector**: The DirectionalSprite3D inspector will automatically show shooting sprite properties
3. **Assignment**: Assign Texture2D resources to the shooting sprite arrays for each direction
4. **Atlas**: The system automatically regenerates the atlas when shooting sprites are added or modified

## Atlas Layout

The atlas now includes three types of sprites per direction:
1. **Idle sprite** (single texture)
2. **Movement sprites** (array of textures)
3. **Shooting sprites** (array of textures)

All sprites are arranged horizontally by frame and vertically by direction, with proper padding and centering for different sized sprites.

## Testing

- Updated test file: `tests/test_directional_sprite_atlas.gd`
- Verification script: `verify_shooting_sprites.gd`
- Both scripts validate the shooting sprite implementation

## Shooting Animation Logic

### Player Class Updates (`scenes/player/player.gd`)

#### New Method: `_update_shooting_state()`
- **Purpose**: Detects when the player is shooting based on weapon manager animation state
- **Logic**: 
  - Checks if weapon manager, animation player, and current weapon exist
  - Determines if a shooting animation is currently playing
  - Compares current animation with `shoot_anim_name` or `repeat_shoot_anim_name`
  - Updates `shooting_state` to "shoot" or "idle" accordingly

#### Updated Method: `_update_animation_state()`
- **Enhanced Logic**: Now handles both movement and shooting states
- **Animation Priority System**:
  1. **Shooting** (highest priority): Plays "shoot" sprite animation
  2. **Movement**: Plays "move" sprite animation when running
  3. **Idle** (default): Plays "RESET" animation

### Animation Flow

1. **Frame Update**: `_update_animation_state()` called every physics frame
2. **State Detection**: 
   - Movement state updated based on velocity
   - Shooting state updated via `_update_shooting_state()`
3. **Animation Selection**: Priority system determines which animation to play
4. **Sprite Animation**: `SpriteAnimationPlayer` plays the appropriate animation
5. **DirectionalSprite3D**: Responds to state changes and displays correct sprites

### Integration with Weapon System

- **Weapon Manager**: Existing weapon system handles shooting input and weapon animations
- **Animation Detection**: Player monitors weapon animation player state
- **Automatic Sync**: Shooting state automatically syncs with weapon animations
- **No Manual Triggers**: No need to manually set shooting state - it's detected automatically

## Next Steps

The complete shooting sprite and animation system is now implemented:
1. ✅ **Sprite Assignment**: Add shooting sprite textures through the inspector
2. ✅ **Animation Logic**: Shooting state management implemented in player controller
3. **Shader Integration**: Update shaders to handle shooting sprite selection based on `shooting_state`
4. **Visual Testing**: Test the complete pipeline with actual sprite assets

## Notes

- The implementation maintains backward compatibility with existing idle and movement sprites
- No changes are required to existing DirectionalSprite3D instances that don't use shooting sprites
- The system is designed to be extensible for future sprite types (e.g., death sprites, special ability sprites)
