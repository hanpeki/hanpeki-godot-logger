extends HanpekiLogger.Transport

##
## HanpekiLoggerTestTransport is a [HanpekiLogger.Transport] aimed to get
## information for unit tests. It could have been done with GUT Doubles, but 
## this provides a better semantic way to access the data anyways.
##
class_name HanpekiLoggerTestTransport

## All processed data. Messages sent with a disabled level won't reach the transport,
## therefore they won't be stored here
var _all_processed: Array[HanpekiLogger.MsgData] = []
## Processed data per level (int -> Array[HanpekiLogger.MsgData])
var _processed: Dictionary[int, Variant] = {}

##
## [method process] is needed when implementing a [HanpekiLogger.Transport]
##
func process(data: HanpekiLogger.MsgData) -> void:
	_all_processed.append(data)
	_processed.get_or_add(data.level, []).append(data)

##
## Get the list of processed messages. If a [param level] is given, it will return
## only the list of processed messages for that level.
##
func get_processed(level: int = HanpekiLogger.NONE) -> Array[HanpekiLogger.MsgData]:
	if (level == HanpekiLogger.NONE): return _all_processed
	return _processed[level] if _processed.has(level) else []

##
## Search the processed information for a given (exact) [param msg]. If a [param level] is given,
## it will search only in the list of processed messages for that level.
##
func get_processed_message(msg: String, level: int = HanpekiLogger.NONE) -> HanpekiLogger.MsgData:
	var list = (
		_all_processed if level == HanpekiLogger.NONE
		else _processed.get(level, [])
	) as Array[HanpekiLogger.MsgData]
	var index = list.find_custom(func (data) -> bool: return data.msg == msg)
	return null if index == -1 else list[index]

##
## Check if a given (exact) [param msg] has been processed. If a [param level] is given,
## it will search only in the list of processed messages for that level.
##
func has_processed_message(msg: String, level: int = HanpekiLogger.NONE) -> bool:
	return get_processed_message(msg, level) != null
  
