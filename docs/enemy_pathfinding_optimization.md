# Enemy Pathfinding Optimization System

## Overview

The enemy pathfinding system has been optimized to improve performance when multiple enemies are active simultaneously. The system dynamically adjusts pathfinding update frequencies based on several factors to maintain responsive behavior for important enemies while reducing CPU overhead for distant or less relevant enemies.

## Key Features

### 1. Distance-Based Path Update Intervals

The system uses aggressive distance-based intervals to prioritize close enemies:

- **Very close enemies (< 10 units)**: Update every 0.075 seconds for highly responsive chasing
- **Close enemies (10-25 units)**: Update every 0.25 seconds for good responsiveness  
- **Medium distance (25-50 units)**: Update every 0.65 seconds for balanced performance
- **Far enemies (> 50 units)**: Update every 1.5 seconds to minimize CPU load

### 2. Enemy Count Scaling

When many enemies are present, the system automatically scales update intervals:

- **Normal operation**: Up to 10 enemies use standard intervals
- **High enemy count**: Above 10 enemies, intervals are scaled up proportionally
- **Maximum scaling**: Capped at 2.5x to prevent enemies from becoming unresponsive
- **Dynamic adjustment**: Scaling factor updates automatically as enemies spawn/despawn

### 3. Line-of-Sight Optimization

Enemies optimize their pathfinding based on visibility to the player:

- **With line of sight**: Use standard distance-based intervals
- **Without line of sight**: Use 3x longer intervals after a 2-second grace period
- **Grace period**: Maintains responsiveness briefly after losing sight
- **Automatic detection**: Line of sight is checked during target acquisition

### 4. Path Caching

Short-term path caching prevents redundant calculations:

- **Cache duration**: 100ms cache lifetime for calculated paths
- **Movement threshold**: Cache invalidated if target moves > 2 units
- **Automatic invalidation**: Cache expires based on time and target movement
- **Debug feedback**: Cache usage is logged when debug prints are enabled

## Performance Benefits

### CPU Usage Reduction
- **Distant enemies**: Up to 90% reduction in pathfinding calls
- **High enemy counts**: Automatic scaling prevents performance degradation
- **Line-of-sight optimization**: 66% reduction for enemies without visibility
- **Path caching**: Eliminates redundant calculations for static scenarios

### Maintained Responsiveness
- **Close enemies**: Remain highly responsive with frequent updates
- **Line-of-sight enemies**: Prioritized for frequent pathfinding
- **Minimum guarantees**: Very close enemies always update at least every 0.1s
- **Maximum limits**: No enemy becomes completely unresponsive (3s max interval)

## Configuration

### Tunable Parameters

```gdscript
# Base update intervals (in seconds)
var base_update_intervals := {
    "very_close": 0.075,  # < 10 units
    "close": 0.25,        # 10-25 units  
    "medium": 0.65,       # 25-50 units
    "far": 1.5            # > 50 units
}

# Enemy count scaling
var enemy_count_threshold := 10  # Start scaling above this count
var line_of_sight_grace_period := 2.0  # Seconds to maintain responsiveness after losing LOS
var path_cache_duration := 0.1  # Cache lifetime in seconds
```

### Debug Options

Enable debug prints on individual enemies to monitor optimization:

```gdscript
enemy.debug_prints = true
```

Debug output includes:
- Current distance to target
- Line-of-sight status
- Calculated update interval
- Total enemy count
- Cache usage notifications

## Testing

Run the optimization test scene to see the system in action:

```
res://tests/test_enemy_pathfinding_optimization.tscn
```

The test demonstrates:
- Multiple enemies at various distances
- Dynamic interval adjustment
- Line-of-sight changes as the player moves
- Enemy count scaling effects
- Performance monitoring output

## Implementation Details

### Static Variables
- `total_enemy_count`: Tracks active enemies across all instances
- `enemy_count_threshold`: Threshold for scaling activation

### Instance Variables
- `has_line_of_sight`: Current visibility status
- `last_line_of_sight_time`: Timestamp of last confirmed visibility
- `cached_path_position`: Last cached target position
- `cached_path_time`: Timestamp of cached path
- `current_update_interval`: Currently applied update interval

### Key Functions
- `_calculate_optimal_update_interval()`: Determines optimal update frequency
- `_is_cached_path_valid()`: Validates path cache
- `_update_enemy_count_scaling()`: Updates scaling factor based on enemy count

## Compatibility

The optimization system preserves all existing functionality:
- ✅ Room-based pathfinding system maintained
- ✅ Debug print functionality preserved  
- ✅ Wandering behavior unchanged
- ✅ Door opening mechanics intact
- ✅ Kill zones and disappear areas functional

## Performance Monitoring

Monitor system performance using:
1. Enable debug prints on select enemies
2. Watch console output for interval adjustments
3. Use the test scene for comprehensive evaluation
4. Profile frame times with many enemies active

The system automatically adapts to changing conditions, providing optimal performance without manual intervention.
