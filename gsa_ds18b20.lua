--------------------------------------------------------------------------------
-- DS18B20 one wire module for NODEMCU
-- Sandor Attila Gerendi
-- LICENCE: http://opensource.org/licenses/MIT
--------------------------------------------------------------------------------

local table = table
local string = string
local ow = ow

local STARTCONVO=0x44
local COPYSCRATCH=0x48
local READSCRATCH=0xBE
local WRITESCRATCH=0x4E

local SP_TEMP_LSB=1
local SP_TEMP_MSB=2
local SP_HIGH_ALARM_TEMP=3
local SP_LOW_ALARM_TEMP=4
local SP_CONFIGURATION=5
local SP_COUNT_REMAIN=7
local SP_COUNT_PER_C=8

local RES_9_BIT = 0x1F
local RES_10_BIT = 0x3F
local RES_11_BIT = 0x5F
local RES_12_BIT = 0x7F

local MODEL_DS18S20=0x10
local MODEL_DS1820=0x10
local MODEL_DS18B20=0x28
local MODEL_DS1822=0x22
local MODEL_DS1825=0x3B

function setup(pin)
    ow.setup(pin)
end

function bs2hex(b)
     local t = {}
     for i = 1, #b do
          t[i] = string.format('%02X', b:byte(i))
     end
     return table.concat(t)
end

function hex2bs(h)
    local t={}
    for k in h:gmatch"(%x%x)" do
        table.insert(t,string.char(tonumber(k,16)))
    end
    return table.concat(t)
end

function adr2adr(addr)
    if addr == nil then return false, 'nil-address' end
    if #addr == 16 then
        addr = hex2bs(addr)
    end
    if addr:byte(8) ~= ow.crc8(string.sub(addr,1,7)) then
        return false, 'invalid-address'
    end
    return true, addr
end

function get_conv_time(res)
    local t = 750
    if res == RES_9_BIT then t = 94
    elseif res == RES_10_BIT then t = 188
    elseif res == RES_11_BIT then t = 375
    end
    return t
end

function extract_temp(addr, scrp)
    local sgn, temp
    local msb = scrp:byte(SP_TEMP_MSB)
    local lsb = scrp:byte(SP_TEMP_LSB)
    if addr:byte(1) == MODEL_DS18S20 then
        sgn = bit.isset(msb, 7)
        temp = lsb
        temp = bit.lshift(bit.band(temp, 0xfff0), 3)
        if sgn then temp = -1 * temp end
        temp = temp - 16 + (scrp:byte(SP_COUNT_PER_C) - bit.lshift(scrp:byte(SP_COUNT_REMAIN),7)) / scrp:byte(SP_COUNT_PER_C)
    else
        sgn = bit.isset(msb, 7)
        temp = bit.band(msb, 0x07) * 256 + lsb
        if sgn then temp = -1 * temp end
    end
    temp = temp * 625
    return temp
end

function get_resolution(pin, addr, pow)
    local st, scrp
    st, addr = adr2adr(addr)
    if not st then return st, addr end
    if addr:byte(1) == DS18S20MODEL then
        return false, 'not-suported'
    end
    local st, scrp = read_scrp(pin, addr, pow)
    if not st then return st, scrp end
    return true, scrp:byte(SP_CONFIGURATION)
end

function set_resolution(pin, addr, res, pow)
    local st, scrp
    st, addr = adr2adr(addr)
    if not st then return st, addr end
    if addr:byte(1) == DS18S20MODEL then
        return false, 'not-suported'
    end
    st, scrp = read_scrp(pin, addr, pow)
    if not st then return st, scrp end
    scrp = scrp:sub(1,SP_CONFIGURATION-1)..string.char(res)..scrp:sub(SP_CONFIGURATION+1)
    write_scrp(pin, addr, scrp, pow)
    return true
end

function get_devices(pin, hex)
    local t = {}
    ow.reset_search(pin)
    repeat
        local addr = ow.search(pin)
        if(addr ~= nil) then
            local fb = addr:byte(1)
            if (fb==MODEL_DS18S20)or(fb==MODEL_DS18B20)or(fb==MODEL_DS1822)or(fb==MODEL_DS1825) then
                if hex then addr = bs2hex(addr) end
                table.insert(t, addr)
            end
        end
        coroutine.yield(50)
    until (addr == nil)
    ow.reset_search(pin)
    return t
end

function write_scrp(pin, addr, scrp, pow)
    ow.reset(pin)
    ow.select(pin, addr)
    ow.write(pin, WRITESCRATCH)
    ow.write(pin, scrp:byte(SP_HIGH_ALARM_TEMP))
    ow.write(pin, scrp:byte(SP_LOW_ALARM_TEMP))
    if addr:byte(1) ~= MODEL_DS18S20 then
        ow.write(pin, scrp:byte(SP_CONFIGURATION))
    end
    ow.reset(pin)
    ow.select(pin, addr)
    ow.write(pin, COPYSCRATCH, pow)
    if pow then
        coroutine.yield(300)
    else
        coroutine.yield(200)
    end
end

function read_scrp(pin, addr, pow)
    ow.reset(pin)
    ow.select(pin, addr)
    ow.write(pin, READSCRATCH, pow)
    local b = ow.read_bytes(pin, 8)
    if ow.crc8(b) ~= ow.read(pin) then
        return false, "CRC error"
    else
        return true, b
    end
end

function get_temp(pin, addr, pow, res)
    local st, scrp
    st, addr = adr2adr(addr)
    if not st then return st, addr end
    ow.reset(pin)
    ow.select(pin, addr)
    ow.write(pin, STARTCONVO, pow)
    coroutine.yield(get_conv_time(res))
    st, scrp = read_scrp(pin, addr, pow)
    if not st then return st, scrp	end
    return true, extract_temp(addr, scrp)
end

function get_temperatures(pin, addr_list, pow, res)
    if addr_list == nil then addr_list = get_devices(pin) end
    if #addr_list == 0 then return false, 'no-devices' end
    ow.reset(pin)
    ow.skip(pin)
    ow.write(pin, STARTCONVO, pow)
    coroutine.yield(get_conv_time(res))
    local result = {}
    local st, addr, scrp
    for i = 1, #addr_list do
        st, addr = adr2adr(addr_list[i])
        if not st then
            print("invalid address", bs2hex(addr_list[i]), scrp)
        else
            st, scrp = read_scrp(pin, addr, pow)
            if st == true then
                result[bs2hex(addr)] = extract_temp(addr, scrp)
            else
                print("problem reading", bs2hex(addr), scrp)
            end
        end
    end
    return true, result
end

return {
    bs2he=bs2hex,
    hex2bs=hex2bs,
    get_devices=get_devices,
    get_temp=get_temp,
    get_temperatures=get_temperatures,
    setup=setup,
    set_resolution=set_resolution,
    get_resolution=get_resolution,
    RES_9_BIT=RES_9_BIT,
    RES_10_BIT=RES_10_BIT,
    RES_11_BIT=RES_11_BIT,
    RES_12_BIT=RES_12_BIT
}
