# The Armory

## Preset Flowchart

| NetChannel       | Description                                      | Client Usage                          | Server Usage                          |
|------------------|--------------------------------------------------|---------------------------------------|---------------------------------------|
| GetUserVanity    | Requests vanity data for a specific user         | Sends request to server               | Responds with vanity data             |
| SendOutPresetPools | Sends preset pool data to clients               | Receives updated preset pool data     | Broadcasts preset pool data to clients |
| GetUserPresetPool | Requests the preset pool for a specific user     | Sends request to server               | Responds with preset pool data        |
| UpdateUserPreset | Updates the server with a modified user preset   | Sends updated preset to server        | Saves updated preset and executes changes |

### Initialization

```mermaid
sequenceDiagram
	autonumber

	box Server
	participant UPP as User Preset Pool Manager
	end

	box Client: User One
	participant 1PP as Preset Proxy
	end

	box Client: User Two
	participant 2PP as Preset Proxy
	end
	
	note over UPP: Level Loaded or Reset Completed
	activate UPP
	activate 1PP
	UPP-)1PP: GetUserVanity
	activate 2PP
	UPP-)2PP: GetUserVanity
	1PP->>UPP: Vanity
	deactivate 1PP
	2PP->>UPP: Vanity
	deactivate 2PP
	UPP-->UPP: PresetPool{[userId] : Vanity}
	UPP-)1PP: SendOutPresetPools({[user2] : PresetIds[]})
	UPP-)2PP: SendOutPresetPools({[user1] : PresetIds[]})
	deactivate UPP
```

### Opening Preset Manager

```mermaid
sequenceDiagram
	autonumber

	box Server
	participant UPP as User Preset Pool Manager
	end

	box Client: User One
	participant 1PP as Preset Proxy
	participant 1PM as Preset Manager
	end
	
	note over 1PM: User Opens Preset Manager
	activate 1PM
		1PM-)UPP: GetUserPresetPool
		UPP-)1PM: SendPresetPool{[user 2]: Vanity}
		1PM-->1PM: buildSection(otherUsersSection)
	deactivate 1PM
```

### User 2 Modifies Active Preset

```mermaid
sequenceDiagram
	autonumber

	box Server
	participant SPM as Server Preset Manager
	participant UPP as User Preset Pool Manager
	end

	box Client: User One
	participant 1PP as Preset Proxy
	participant 1PM as Preset Manager
	end

	box Client: User Two
	participant 2PP as Preset Proxy
	participant 2M as Main
	end
	

	note over 2M: User Modifies Preset
	activate 2M
		2M-)SPM: UpdateUserPreset{presetId = presetId, vanityPreset = Export(vanity)}
		SPM-->SPM: Save exported vanity to table, execute transmogs
		loop for each user presetId[] in UPP 
			opt If the updated presetId belongs to the same user that sent the update event
				SPM->>UPP: GetVanitiesFromUsers(user2)
				UPP-)2PP: GetUserVanity
				2PP->>UPP: Vanity
				UPP-)1PP: SendOutPresetPools({[user2] : PresetIds[]})
				UPP-)1PM: UpdateUserPresetPool({[user2] : Vanity})
				1PM-->1PM: buildSection(otherUsersSection)
				note over SPM: break
			end
		end
	deactivate 2M
```

### User 1 Activates User 2's Preset

```mermaid
sequenceDiagram
	autonumber

	box Server
	participant SPM as Server Preset Manager
	participant UPP as User Preset Pool Manager
	end

	box Client: User One
	participant 1PP as Preset Proxy
	participant 1PM as Preset Manager
	participant 1M as Main
	participant 1EM as Export Manager
	end
	note over 1PM: User Activates U2 Preset
	1PM->>1M: Activate U2 Preset
	1M->>1PP: Get Preset
	1PP->>1PP: Check PresetPool, see it belongs to User2
	1PP-)UPP: GetUserSpecificPreset(user2)
	UPP->>1PP: Vanity
	1PP->>1M: Preset
	1M->>1EM: PresetId 
	note left of 1EM: (as this logic needs to work for in-memory and mod-provided presets too)
	1EM->>1PP: PresetId
	1PP->>1EM: Vanity (cached)
	1EM->>1M: Vanity containing preset and related effects/name cache
	1M-)SPM: UpdateUserPreset{presetId = presetId, vanityPreset = Export(vanity)}
	SPM-->SPM: Save exported vanity to table, execute transmogs
	loop for each user presetId[] in UPP 
		opt If the updated presetId belongs to the same user that sent the update event
			note over SPM: Check won't succeed, UPP won't be invoked
		end
	end
```
