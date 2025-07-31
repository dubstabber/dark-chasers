# Component-Based Ammo System

This document describes the component-based ammo management system that replaces the previous per-weapon ammo storage and is designed for multiplayer compatibility.

## Overview

The component-based ammo system provides:

- **Weapon-independent ammo pickup**: Players can collect ammo for weapons they don't currently own
- **Shared ammo pools**: Multiple weapons can share the same ammo type
- **Per-player isolation**: Each player has their own ammo component (multiplayer ready)
- **Centralized configuration**: Shared ammo type definitions across all players

## Architecture

### PlayerAmmoComponent

Each player has a `PlayerAmmoComponent` that manages their individual ammo:

```gdscript
# Access through player's component
player.ammo_component.add_ammo("pistol_ammo", 30)
player.ammo_component.consume_ammo("pistol_ammo", 2)
var current = player.ammo_component.get_ammo("pistol_ammo")
```

### AmmoConfig (Shared Configuration)

The `AmmoConfig` class provides shared ammo type definitions:

```gdscript
# Get ammo configuration
var config = AmmoConfig.get_instance()
var max_pistol_ammo = config.get_max_ammo_for_type("pistol_ammo")
```

### Ammo Types

Default ammo types configured in the system:

- `pistol_ammo`: For pistol weapons (max: 200, default: 100)
- `lighter_fuel`: For lighter weapons (max: 2000, default: 100)
- `shotgun_shells`: For shotgun weapons (max: 100, default: 50)
- `rifle_rounds`: For rifle weapons (max: 300, default: 150)
- `energy_cells`: For energy weapons (max: 400, default: 200)

### WeaponResource Integration

Weapons now have an `ammo_type` property:

```gdscript
# In weapon resource files
ammo_type = "pistol_ammo"
ammo_per_shot = 2
```

When `ammo_type` is specified, the weapon uses the centralized system. When empty, it falls back to the legacy per-weapon system.

## Usage Examples

### Creating Ammo Pickups

#### New Centralized System (Recommended)

```gdscript
# In ammo pickup scene
ammo_type = "pistol_ammo"
ammo_value = 30
```

#### Legacy System (Still Supported)

```gdscript
# In ammo pickup scene
target_weapon_name = "Hiroshi pistol"
ammo_value = 30
```

### Weapon Configuration

#### New System

```gdscript
# In weapon .tres file
ammo_type = "pistol_ammo"
ammo_per_shot = 2
infinite_ammo = false
```

#### Legacy System

```gdscript
# In weapon .tres file
ammo_type = ""  # Empty = use legacy system
max_ammo = 100
current_ammo = 68
ammo_per_shot = 2
infinite_ammo = false
```

## Migration Guide

### Existing Weapons

1. **Hiroshi Pistol**: Now uses `ammo_type = "pistol_ammo"`
2. **Doom Lighter**: Now uses `ammo_type = "lighter_fuel"`
3. **Melee Weapons**: Unchanged (still use `infinite_ammo = true`)

### Existing Ammo Pickups

1. **Pistol Ammo**: Now uses `ammo_type = "pistol_ammo"`
2. **Gasoline Can**: Now uses `ammo_type = "lighter_fuel"`
3. **Universal Ammo**: Still uses legacy `target_all_weapons = true`

### Code Changes

The system maintains backwards compatibility, but new code should use:

```gdscript
# Get current ammo for display
var current = weapon.get_current_ammo()
var maximum = weapon.get_max_ammo_amount()

# Check if weapon can fire
if weapon.can_fire():
    weapon.consume_ammo()
```

## Benefits

1. **Shared Ammo Pools**: Multiple pistols can share the same ammo pool
2. **Future-Proof Pickup**: Collect ammo for weapons you don't own yet
3. **Centralized Management**: All ammo logic in one place
4. **Easy Balancing**: Adjust ammo limits globally
5. **Save/Load Support**: Centralized state is easier to persist

## Technical Details

### AmmoManager API

```gdscript
# Core methods
AmmoManager.get_ammo(ammo_type: String) -> int
AmmoManager.get_max_ammo(ammo_type: String) -> int
AmmoManager.has_ammo(ammo_type: String, amount: int = 1) -> bool
AmmoManager.consume_ammo(ammo_type: String, amount: int = 1) -> bool
AmmoManager.add_ammo(ammo_type: String, amount: int) -> bool

# Utility methods
AmmoManager.get_ammo_percentage(ammo_type: String) -> float
AmmoManager.get_all_ammo_types() -> Array[String]
AmmoManager.debug_print_ammo_status()
```

### Signals

```gdscript
# Emitted when ammo changes
AmmoManager.ammo_changed(ammo_type: String, current_amount: int, max_amount: int)
```

### WeaponResource Helper Methods

```gdscript
# Use these instead of direct property access
weapon.get_current_ammo() -> int
weapon.get_max_ammo_amount() -> int
weapon.get_ammo_percentage() -> float
weapon.can_fire() -> bool
weapon.consume_ammo(amount: int = -1) -> bool
weapon.reload(amount: int = -1) -> bool
```

## Future Enhancements

- Save/load system integration
- Ammo crafting system
- Dynamic ammo type registration
- Per-level ammo limits
- Ammo rarity system
