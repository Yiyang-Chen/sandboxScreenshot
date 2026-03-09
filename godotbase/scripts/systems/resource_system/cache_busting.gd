class_name CacheBusting extends RefCounted

## CacheBusting
##
## URL cache busting utility.
## Generates and caches timestamps for URLs to prevent browser caching.
##
## Features:
## - Same URL gets same timestamp within a session (avoids re-downloading)
## - Different URLs get different timestamps (independent caching)
## - Page refresh generates new timestamps (breaks browser cache)

## URL timestamp cache (key: base_url, value: timestamp string)
static var _url_timestamps: Dictionary = {}


## Add cache busting parameter to URL
##
## @param url The original URL
## @return URL with cache buster timestamp parameter
static func add_cache_buster(url: String) -> String:
	if url.is_empty():
		return url
	
	# Extract base URL (remove existing query parameters for lookup)
	var base_url: String = url.split("?")[0]
	
	# Check if this URL already has a cached timestamp
	var timestamp: String
	if _url_timestamps.has(base_url):
		timestamp = _url_timestamps[base_url]
	else:
		# First use: generate new timestamp and cache it
		timestamp = str(Time.get_unix_time_from_system())
		_url_timestamps[base_url] = timestamp
		print("[CacheBusting] New timestamp for %s: %s" % [base_url, timestamp])
	
	# Add timestamp parameter (preserve existing query parameters)
	var separator: String = "&" if url.contains("?") else "?"
	return "%s%st=%s" % [url, separator, timestamp]


## Reset all cached timestamps (for testing purposes)
static func reset_timestamps() -> void:
	_url_timestamps.clear()


## Get the number of cached timestamps (for testing/debugging)
static func get_cache_count() -> int:
	return _url_timestamps.size()
