class_name UUIDGenerator extends RefCounted

## UUID v4 Generator
## Generates RFC 4122 compliant UUID v4 strings

## Generate standard UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
static func generate() -> String:
	var uuid: String = ""
	for i: int in range(36):
		if i == 8 or i == 13 or i == 18 or i == 23:
			uuid += "-"
		elif i == 14:
			uuid += "4"  # version 4
		elif i == 19:
			uuid += "89ab"[randi() % 4]  # variant bits (10xx in binary)
		else:
			uuid += "0123456789abcdef"[randi() % 16]
	return uuid

## Generate short UUID without hyphens (32 hex characters)
static func generate_short() -> String:
	var id: String = ""
	for i: int in range(32):
		id += "0123456789abcdef"[randi() % 16]
	return id

## Generate time-based UUID (timestamp + random)
## Format: {unix_timestamp}_{uuid_short}
## Example: 1734364800_7f3a8b2c4d5e6f7a8b9c0d1e2f3a4b5c
## More collision-resistant and sortable by creation time
static func generate_with_timestamp() -> String:
	var timestamp: int = int(Time.get_unix_time_from_system())
	var random: String = generate_short()
	return "%d_%s" % [timestamp, random]
