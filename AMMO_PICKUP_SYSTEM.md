# Ammo Pickup System

This document describes the ammo pickup system implementation for the Dark Chasers project.

## Overview

The ammo pickup system allows players to collect ammo items that replenish ammunition for their weapons. The system is designed to be flexible and follows the same pattern as other pickup items (health, armor, weapons).

## Components

### 1. Ammo Script (`scenes/items/ammo.gd`)

The main script that handles ammo pickup logic. It extends `Area3D` and provides several targeting options:

- **ammo_value**: Amount of ammo to add (default: 20)
- **pickup_sound**: Sound to play when picked up
- **event_string**: Message to display in HUD
- **target_weapon_name**: Target specific weapon by name (e.g., "Hiroshi pistol")
- **target_weapon_slot**: Target weapons in specific slot (1-9, 0 = any slot)
- **target_all_weapons**: Add ammo to all non-infinite weapons

### 2. Player Integration

Added `add_ammo()` method to the Player class with the following signature:

```gdscript
func add_ammo(amount: int, weapon_name: String = "", target_slot: int = 0, all_weapons: bool = false) -> bool
```

This method:
- Returns `true` if ammo was successfully added to at least one weapon
- Returns `false` if no ammo could be added (weapons at max, infinite ammo, etc.)
- Only affects weapons that are not infinite ammo and have max_ammo > 0

### 3. Weapon Manager Integration

Added `get_slot_weapons()` method to WeaponManager for public access to weapon slots:

```gdscript
func get_slot_weapons(slot_index: int) -> Array[WeaponResource]
```

## Available Pickup Scenes

### Generic Ammo (`scenes/items/ammo.tscn`)
- Basic ammo pickup that adds ammo to current weapon
- Default: 20 ammo

### Pistol Ammo (`scenes/items/pistol_ammo.tscn`)
- Specifically targets "Hiroshi pistol"
- Adds 30 ammo

### Lighter Fuel (`scenes/items/lighter_fuel.tscn`)
- Specifically targets "Doom lighter"
- Adds 100 fuel
- Uses gasoline can sprite

### Universal Ammo (`scenes/items/universal_ammo.tscn`)
- Adds ammo to ALL non-infinite weapons
- Adds 50 ammo to each weapon

## Usage Examples

### In Level Design

1. **Add generic ammo pickup:**
   - Drag `scenes/items/ammo.tscn` into your scene
   - Configure `ammo_value` and `event_string` as needed

2. **Add weapon-specific ammo:**
   - Use `pistol_ammo.tscn` for pistol ammo
   - Use `lighter_fuel.tscn` for lighter fuel
   - Or create custom scenes with specific `target_weapon_name`

3. **Add universal ammo pack:**
   - Use `universal_ammo.tscn` for ammo that refills all weapons

### Creating Custom Ammo Pickups

1. Create a new scene with `Area3D` as root
2. Add the `ammo.gd` script
3. Configure the export variables:
   ```gdscript
   ammo_value = 25
   event_string = "Picked up shotgun shells."
   target_weapon_name = "Shotgun"
   ```
4. Add visual representation (Sprite3D or MeshInstance3D)
5. Add CollisionShape3D
6. Connect the `body_entered` signal to `_on_body_entered`

## Technical Details

### Ammo Addition Logic

The system follows this priority order:
1. If `target_all_weapons` is true: Add ammo to all non-infinite weapons
2. If `target_weapon_name` is set: Add ammo to specific weapon by name
3. If `target_weapon_slot` > 0: Add ammo to all weapons in that slot
4. Default: Add ammo to currently equipped weapon

### Weapon Filtering

Only weapons that meet ALL these criteria can receive ammo:
- `infinite_ammo` is false
- `max_ammo` > 0
- Current ammo < max ammo

### Integration with Existing Systems

- Uses the same pickup pattern as health and armor items
- Emits `item_pickedup` signal for HUD integration
- Plays pickup sound using `Utils.play_sound()`
- Only consumes the pickup if ammo was successfully added

## Testing

To test the ammo pickup system:

1. Place ammo pickups in a level
2. Ensure player has weapons that use ammo (not infinite ammo)
3. Fire weapons to consume ammo
4. Walk over ammo pickups to replenish ammunition
5. Check HUD ammo display updates correctly

## Future Enhancements

Possible improvements:
- Visual feedback when ammo can't be picked up (weapon full)
- Different ammo types for different weapon categories
- Ammo scarcity mechanics
- Maximum carry limits for different ammo types
