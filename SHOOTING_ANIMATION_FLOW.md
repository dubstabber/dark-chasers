# Shooting Animation Flow Diagram

## System Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Input System  │    │  Weapon Manager  │    │      Player         │
│                 │    │                  │    │                     │
│ • Mouse Click   │───▶│ • Detects Input  │    │ • _physics_process  │
│ • "hit" Action  │    │ • Plays Weapon   │    │ • _update_animation │
│                 │    │   Animation      │    │   _state()          │
└─────────────────┘    │ • shoot_anim_name│    │                     │
                       └──────────────────┘    └─────────────────────┘
                                │                         │
                                │                         │
                                ▼                         ▼
                       ┌──────────────────┐    ┌─────────────────────┐
                       │ AnimationPlayer  │    │ _update_shooting_   │
                       │                  │    │ state()             │
                       │ • is_playing()   │◀───│                     │
                       │ • current_       │    │ • Checks weapon     │
                       │   animation      │    │   animation state   │
                       └──────────────────┘    │ • Updates shooting_ │
                                               │   state variable    │
                                               └─────────────────────┘
                                                         │
                                                         ▼
                                               ┌─────────────────────┐
                                               │ Animation Priority  │
                                               │ System              │
                                               │                     │
                                               │ 1. shooting_state   │
                                               │    == "shoot"       │
                                               │ 2. moving_state     │
                                               │    == "run"         │
                                               │ 3. Default: "RESET" │
                                               └─────────────────────┘
                                                         │
                                                         ▼
                                               ┌─────────────────────┐
                                               │ SpriteAnimation     │
                                               │ Player              │
                                               │                     │
                                               │ • play("shoot")     │
                                               │ • play("move")      │
                                               │ • play("RESET")     │
                                               └─────────────────────┘
                                                         │
                                                         ▼
                                               ┌─────────────────────┐
                                               │ DirectionalSprite3D │
                                               │                     │
                                               │ • Detects shooting_ │
                                               │   state changes     │
                                               │ • Displays shooting │
                                               │   sprites from atlas│
                                               └─────────────────────┘
```

## State Flow

### 1. Idle State
```
Player Input: None
Weapon Manager: No animation playing
shooting_state: "idle"
moving_state: "idle"
Animation: "RESET"
Sprites: Idle sprites displayed
```

### 2. Movement State
```
Player Input: WASD movement
Weapon Manager: No shooting animation
shooting_state: "idle"
moving_state: "run"
Animation: "move"
Sprites: Movement sprites displayed
```

### 3. Shooting State
```
Player Input: Mouse click / "hit" action
Weapon Manager: shoot_anim_name playing
shooting_state: "shoot"
moving_state: "idle" or "run"
Animation: "shoot" (priority over movement)
Sprites: Shooting sprites displayed
```

### 4. Shooting While Moving
```
Player Input: WASD + Mouse click
Weapon Manager: shoot_anim_name playing
shooting_state: "shoot"
moving_state: "run"
Animation: "shoot" (shooting takes priority)
Sprites: Shooting sprites displayed
```

## Key Features

### ✅ Automatic Detection
- No manual state management required
- Shooting state automatically syncs with weapon animations
- Real-time detection of weapon animation player state

### ✅ Priority System
- Shooting animations take priority over movement
- Smooth transitions between states
- Fallback to idle when no other states are active

### ✅ Integration
- Works with existing weapon system
- Compatible with DirectionalSprite3D
- Maintains backward compatibility

### ✅ Performance
- Minimal overhead (simple state checks)
- No additional input handling required
- Leverages existing animation system

## Animation Timing

```
Time:     0ms    100ms   200ms   300ms   400ms
Input:    Click  ----    ----    ----    Release
Weapon:   Start  Play    Play    Play    Stop
State:    shoot  shoot   shoot   shoot   idle
Sprite:   Shoot  Shoot   Shoot   Shoot   Idle/Move
```

## Error Handling

The system gracefully handles missing components:
- No weapon manager → shooting_state = "idle"
- No animation player → shooting_state = "idle"
- No current weapon → shooting_state = "idle"
- Invalid animation names → shooting_state = "idle"
