-- MQTT_HOST, MQTT_USER, MQTT_PASSWORD
-- all defined in credentials.lua

m = mqtt.Client("clientid", 120, MQTT_USER, MQTT_PASSWORD)

m:on("connect", function(client) print ("connected") end)
m:on("offline", function(client) print ("offline") end)

-- silly
lighton=0
pin=4
gpio.mode(pin,gpio.OUTPUT)
-- silly

-- on publish message receive event
m:on("message", function(client, topic, data) 
  print(topic .. ":" ) 
  if data ~= nil then
    print(data)
  end
  -- silly
      if lighton==0 then
        lighton=1
        gpio.write(pin,gpio.HIGH)
    else
        lighton=0
         gpio.write(pin,gpio.LOW)
    end
  --client:publish("home/esp/" .. node.chipid() , "node: " .. node.chipid() .. " says ping", 0, 0, function(client) print("sent") end)
  --
end)

-- for TLS: m:connect("192.168.11.118", secure-port, 1)
m:connect(MQTT_HOST, 1883, 0, function(client)
  print("connected")
  -- Calling subscribe/publish only makes sense once the connection
  -- was successfully established. You can do that either here in the
  -- 'connect' callback or you need to otherwise make sure the
  -- connection was established (e.g. tracking connection status or in
  -- m:on("connect", function)).

  -- subscribe topic with qos = 0
  client:subscribe("home/esp/" .. node.chipid(), 0, function(client) print("subscribe success") end)
  -- publish a message with data = hello, QoS = 0, retain = 0
  client:publish("home/esp/" .. node.chipid() , "node: " .. node.chipid() .. " says hello", 0, 0, function(client) print("sent") end)
end,
function(client, reason)
  print("failed reason: " .. reason)
end)

m:close();
-- you can call m:connect again
-- moo
