-- uses mqtt, tmr, am2320, wifi
--DEBUG=true

-- MQTT_HOST, MQTT_USER, MQTT_PASSWORD
-- all defined in credentials.lua
dofile("credentials.lc")
file.close("credentials.lc")

chipId = node.chipid()

local we_have_temp_module = 0
local is_connected = false
local timer_mqtt_connect = tmr.create()
local m = mqtt.Client(chipId, 5, MQTT_USER, MQTT_PASSWORD, 1)

-- inspired by 
-- https://www.allaboutcircuits.com/projects/introduction-to-the-mqtt-protocol-on-nodemcu/
-- https://github.com/breagan/ESP8266_WiFi_File_Manager/tree/master/Lua_files
-- https://gondogblegudug.wordpress.com/2016/12/05/nodemcu-reconnect-mqtt-on-wifi-autoconnect/
-- https://github.com/nodemcu/nodemcu-firmware/blob/master/lua_examples/mqtt/mqtt_file.lua
-- https://github.com/nodemcu/nodemcu-firmware/issues/2197#issuecomment-362999363

sda, scl = 2,1
if pcall(i2c.setup(0, sda, scl, i2c.SLOW)) then
    we_have_temp_module = 1
    i2c.setup(0, sda, scl, i2c.SLOW)
    am2320.setup()
end

-- Holds dispatching keys to different topics. Serves as a makeshift callback
-- function dispatcher based on topic and message content
m_dis = {}

local function publishtemp()
     if we_have_temp_module == 1 then
       rh, t = am2320.read()
          m:publish("events/esp8266/".. chipId .."/temp",
          sjson.encode({
          temp = t,
          sensorId = chipId,
          humidity = rh,
          heap = node.heap()
       }), 0, 0)
     end
end

local function publishheartbeat()
    m:publish("events/esp8266/".. chipId .."/status",
      sjson.encode({
      type = "heartbeat",
      sensorId = chipId,
      status = 1,
      heap = node.heap(),
      now = tmr.now(),
      }), 0, 0)
end

local function cmdrestart()
     file.flush()
     disconnect()
     wifi.sta.disconnect()
     node.restart()
end
 
local function cmdfileinfo()
     l = file.list();
     r,u,t=file.fsinfo()
     
     m:publish("events/esp8266/".. chipId .."/fileinfo",
       sjson.encode({
       type = "fileinfo",
       sensorId = chipId,
       ls = l,
       total_bytes_used = t,
       unused_bytes = u,
       remaining_bytes = r
       }), 0, 0)
end
 
function handlecmd(m,pl)
     print("get cmd: "..pl)
     local pack = sjson.decode(pl)
     if pack.cmd == "restart" then cmdrestart()
         elseif pack.cmd == "fileinfo" then cmdfileinfo()
         elseif pack.cmd == "ping" then publishheartbeat()
         end
     if pack.content then
         if pack.cmd == "remove" then file.remove(pack.content)
         elseif pack.cmd == "run" then dofile(pack.content)
         end
     end
end

-- all messages to this topic -> handled by this function
m_dis["mcu/cmd/" .. chipId]=handlecmd

-- every 60 seconds
tmr.alarm(1, 60000, 1, function()
  publishheartbeat()
end)

--local function restart()
    -- [[ Temporary solution of a bug #2197 ]]
    -- [[ Restart ESP if disconnect occurred after connecting ]] --
--    print ("RESTART CHIP  RESTART CHIP  RESTART CHIP  Time:"..tmr.time())
--    node.restart()
--end

m:on("offline", function(client)
    print ("MQTT: Broker going to offline")
    is_connected = false
    restart()
end)

local function mqtt_connected(client)
    print("MQTT: Connected")
    publishheartbeat()
    publishtemp()

    m:subscribe("mcu/cmd/#", 0, function(m)
      if DEBUG then
        print("subscribed")
      end
    end)

    m:on("message", function(m,t,pl)
        print("PAYLOAD: ", pl)
        print("TOPIC: ", t)
    
        -- This is like client.message_callback_add() in the Paho python client.
        -- It allows different functions to be run based on the message topic
        if pl~=nil and m_dis[t] then
          m_dis[t](m,pl)
        end
    end)
end

local function mqtt_error(client, reason)
    print("MQTT: Connecting failed. Reason:"..reason)

    --if is_connected then
    --    restart()
    --    return
    --end
    
    is_connected = false
    timer_mqtt_connect:start()
end

local function do_mqtt_connect()
   print("\nMQTT: Trying to connect. Heap:"..node.heap().." Uptime:"..tmr.time())
    m:connect(MQTT_HOST, 1883, mqtt_connected, mqtt_error)

    m:lwt("events/esp8266/".. chipId .."/status",
       sjson.encode({
       type = "status",
       sensorId = chipId,
       status = 0,
       heap = node.heap(),
       temp_module_available = WE_HAVE_TEMP_MODULE,
     }), 0, 0)
end

timer_mqtt_connect:register(5000, tmr.ALARM_SEMI, function()
    do_mqtt_connect()
end)

timer_mqtt_connect:start()

-- every 5 mins
tmr.alarm(2, 60000 * 5, 1, function()
    publishtemp()
end)
