#!/bin/bash
nodemcu-tool upload --port /dev/cu.wchusbserial1410 --baud 115200 --optimize --compile --connection-delay 6000 ./lua_install/credentials.lua ./lua_install/mqtt-client.lua ./lua_install/tftpd.lua ./lua_install/readtemp.lua
nodemcu-tool upload --port /dev/cu.wchusbserial1410 --baud 115200 --connection-delay 6000 ./lua_install/init.lua
