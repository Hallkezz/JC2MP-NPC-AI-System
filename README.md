# JC2MP-NPC-AI-System
NPC AI System for Just Cause 2: Multiplayer Mod

## Documentation
### Server Events
#### `SpawnNPC`

**Arguments**
|Name| Type| Description|
|-|-|-|
|target| `number`|Player ID for NPC Target|
|model| `number`|NPC Model ID|
|pos| `Vector3`|NPC Spawn Position|
|weapon| `number`|Weapon for NPC|

**Usage**
```lua
Events:Fire("SpawnNPC", {
    target = 0, -- Player with ID 0
    model = 66, -- Government Soldier 1
    pos = Vector3(-6550, 209, -3290), -- International Airport
    weapon = 2 -- Handgun
})
```

#### `RemoveAllNPCs`
**Usage**
```lua
Events:Fire("RemoveAllNPCs")
```

### Client Events
#### `NPCDeath`
Triggered when an NPC dies

**Usage**
```lua
Events:Subscribe("NPCDeath", function()
    print("NPC died")
end)
```

## Examples
- [NPC-AI-SpawnMenu](https://github.com/Hallkezz/NPC-AI-SpawnMenu)
