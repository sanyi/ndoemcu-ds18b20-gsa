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

The library **requires** to be used from a coroutine like function **main()** from the example.

