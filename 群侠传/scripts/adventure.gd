extends RefCounted
## Generic sparring fixture; story battles live in data/story.json.
static func encounter(_location: String) -> Dictionary:
	return {"id":"training", "name":"江湖切磋", "enemy":"江湖武者", "count":3, "hp":120, "attack":32, "defense":18, "money":200, "exp":120,
		"martial":["狂风刀法"], "skill_power_percent":75}
