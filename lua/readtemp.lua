-- hello
sda, scl = 2,1
we_have_temp_module = 0

 -- call i2c.setup() only once

if pcall(i2c.setup(0, sda, scl, i2c.SLOW)) then
    we_have_temp_module = 1
end

if we_have_temp_module == 1 then
    am2320.setup()
    rh, t = am2320.read()
    -- for these to be useful you need a floating point firmware
    -- a better idea would be to leave them *10
    -- and sort at the server side
    -- which I guess is what the module author intended
    print(string.format("RH: %s%%", rh / 10))
    print(string.format("Temperature: %s degrees C", t / 10))
end