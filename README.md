# esp8266-nodecmu
A small application in lua for nodemcu on an esp8266.

This connects to an mqtt broker, and every 1 minute sends a heartbeat.
Every 5 minutes we read the temperature / humidity from an am2320 that's
attached and publish that to MQTT.
There's also an tiny tftp server running - if you upload some lua it will
compile it and remove the lua.

This does all basically work, and NodeMCu was really easy to get
started and working with, but I'm now toying with platformio, which
seems to have a number of benefits.
