class_name AudioWranglerUtil
extends Object

static func get_bus_names() -> Array[String]:
	var busses:Array[String] = []
	
	for i in AudioServer.bus_count:
		var bus := AudioServer.get_bus_name(i)
		busses.append(bus)
	
	busses.sort()
	
	return busses

