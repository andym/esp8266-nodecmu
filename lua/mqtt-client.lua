-- uses mqtt, tmr, am2320, wifi
--DEBUG=true

-- MQTT_HOST, MQTT_USER, MQTT_PASSWORD
-- all defined in credentials.lua

-- inspired by 
-- https://www.allaboutcircuits.com/projects/introduction-to-the-mqtt-protocol-on-nodemcu/
-- https://github.com/breagan/ESP8266_WiFi_File_Manager/tree/master/Lua_files
-- https://gondogblegudug.wordpress.com/2016/12/05/nodemcu-reconnect-mqtt-on-wifi-autoconnect/

chipId = node.chipid()
we_have_temp_module = 0

sda, scl = 2,1
if pcall(i2c.setup(0, sda, scl, i2c.SLOW)) then
    we_have_temp_module = 1
    am2320.setup()
end

-- Holds dispatching keys to different topics. Serves as a makeshift callback
-- function dispatcher based on topic and message content
m_dis = {}

m = mqtt.Client("clientid", 120, MQTT_USER, MQTT_PASSWORD)

m:on("connect", function(client) print ("connected") end)
m:on("offline", function(client) print ("offline") end)

local function publishtemp()
    if we_have_temp_module == 1 then
      rh, t = am2320.read()
         m:publish("events/esp8266/".. chipId .."/temp",
         sjson.encode({
         temp = (t / 10),
         sensorId = chipId,
         humidity = (rh / 10),
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
    file.flush() -- just in case
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

-- As part of the dispatcher algorithm, this assigns a topic name as a key or
-- index to a particular function name
m_dis["mcu/cmd/restart"] = cmdrestart
m_dis["mcu/cmd/fileinfo"] = cmdfileinfo
-- delete a file
-- start a new file
-- append a line (or block?) to a file - base64 encode?
-- compile a file?
-- do file

local function mqtt_init()
  m = mqtt.Client(chipId, 5, mqttUser, mqttUserPassword)

  m:lwt("events/esp8266/".. chipId .."/status",
    sjson.encode({
    type = "status",
    sensorId = chipId,
    status = 0,
    heap = node.heap(),
    temp_module_available = we_have_temp_module,
    }), 0, 0)

  m:on("offline", function(m)
    if DEBUG then
      print ("Connecting to the broker ...")
    end
  end)

  m:on("connect", function(m)
    if DEBUG then
      print("connected")
    end

    publishheartbeat()

    m:subscribe("mcu/cmd/#", 0, function(m)
      if DEBUG then
        print("subscribed")
      end
    end)

    publishtemp()
  end)

  --m:on("message", switch_relay)
  --m:on("message", function() print ("relay switched") end)
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

local function connect()
  m:connect(MQTT_HOST, 1883, 0)
end

local function disconnect()
  if DEBUG then
    print ("Closing connections ...")
  end
  if m:close() then
    print ("Connection's closed ...")
  else
    print ("Connection's close failed ...")
  end
end

-- every 60 seconds
tmr.alarm(1, 60000, 1, function()
--  if DEBUG then
--    print('IP: ',wifi.sta.getip())
--  end

  publishheartbeat()

  if wifi.sta.getip() == nil then
    restart = true
  else
    if restart == true then
      restart = false
      m = nil
      mqtt_init()
      connect()
    end
  end
end)

-- every 5 mins
tmr.alarm(2, 60000 * 5, 1, function()
    publishtemp()
end)

mqtt_init()
connect()
