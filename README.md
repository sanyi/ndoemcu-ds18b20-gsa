# ndoemcu-ds18b20-gsa

NodeMCU (esp8266) lua library for handling  DS18B20 type sensors.


On 12 bit resolution DS18B20 needs rather big conversion times. Using **tmr.delay** is not the best option for delays bigger than 50ms. During this wait times one should return control to the microcontroller, otherwise network stack problems may happen.

One option is to use **tmr.alarm** to achieve that. I chosed the coroutines approach to avoid the callback spagetti. The whole main function is a coroutine yielding the delay times.

Example application:

```lua
function main()
  for i =1, 100 do
    print('sleeping 10 sec')
    coroutine.yield(10000)
  end
end

function resume (co)
     local _, delay = coroutine.resume(co)     
     if coroutine.status(co) ~= 'dead' then
        tmr.alarm(2, delay, 0, function () resume(co) end)
     end
end

resume(coroutine.create(main))
```

The library **_requires_** to be used from a coroutine like function **main()** from the example. 

Most functions retund **success, result**. Where if status == false the result contains the error.
The **addr** parameter can be a hexadecimal representation of the device serial ex: "2883AE6F060000E7" or the binary representation of this, the library auto detects the type.

Using the library:
------------------

```lua
--load the library
local sl = require("gsa_ds18b20")

--initialize the pin where the devices are wired
local pin = 2
local power = 1
sl.setup(2)

--list the devices as binary representation
success, devices_binary = sl.get_devices(pin, 0)

--list the devices as hexadecimal representation
success, devices_hexa = sl.get_devices(pin, 1)

-- get resolution
success, resolution = sl.get_resolution(pin, '2883AE6F060000E7', power)
success, resolution = sl.get_resolution(pin, devices_binary[0], power)
success, resolution = sl.get_resolution(pin, devices_hexa[0], power)

--set resolution
sl.set_resolution(pin, '2883AE6F060000E7', sl.RES_9_BIT, power))

-- get temperature for a specific device the temperature is in milli celsius
success, value = sl.get_temp(pin, '2883AE6F060000E7', power))
success, value = sl.get_temp(pin, devices_binary[0], power))
success, value = sl.get_temp(pin, devices_hexa[0], power))

- get temperature for multiple devices
success, values = sl.get_temperatures(pin, nil, power)) -- will list automatically call get_devices
success, values = sl.get_temperatures(pin, {'2883AE6F060000E7'}, power))
success, values = sl.get_temperatures(pin, devices_binary, power))
success, values = sl.get_temperatures(pin, devices_hexa, power))

--values = { hexadecimal representation of the device : temperature in milli celsius}
for key,value in pairs(values) do print(key,value) end

```

Other:
-----
- this modle was tested with **"NodeMCU 0.9.6 build 20150704  powered by Lua 5.1.4"**, 
- **get_devices** is not very stable, sometime doesn't return all sensors. I do have this problem even with the default library, so I presume threre is something wrong with the NodeMCU one wire library.
- even if **get_devices** fails, **get_temp** and **get_temperatures** are working correctly when called with address.

