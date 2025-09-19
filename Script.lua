--========================================================
-- [ADD] External key save + import (ENCRYPTED)
--========================================================
local EXT_DIR      = "UFO-HUB-X-Studio"
local EXT_KEY_FILE = EXT_DIR.."/UFO-HUB-X-key1"

-- ความลับสำหรับเข้ารหัส
local ENC_SECRET = "UFOX|2025-KEY-SEALED|:)"
local ENC_VER    = 1

local function ensureExtDir()
    if isfolder and not isfolder(EXT_DIR) then pcall(makefolder, EXT_DIR) end
end

-- helpers
local function str_to_bytes(s)
    local t = {}
    for i=1,#s do t[i] = string.byte(s,i) end
    return t
end
local function bytes_to_str(t)
    local c = {}
    for i=1,#t do c[i] = string.char(t[i] % 256) end
    return table.concat(c)
end

-- base64
local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function b64_encode(data)
    local bytes = type(data)=="table" and data or str_to_bytes(tostring(data or ""))
    local out, val, valb = {}, 0, -6
    for i=1,#bytes do
        val = (val << 8) | (bytes[i] & 0xFF)
        valb = valb + 8
        while valb >= 0 do
            local idx = ((val >> valb) & 0x3F) + 1
            out[#out+1] = string.sub(B64, idx, idx)
            valb = valb - 6
        end
    end
    if valb > -6 then
        local idx = (((val << 8) >> (valb + 8)) & 0x3F) + 1
        out[#out+1] = string.sub(B64, idx, idx)
    end
    while (#out % 4) ~= 0 do out[#out+1] = "=" end
    return table.concat(out)
end
local function b64_decode(s)
    s = tostring(s or ""):gsub("[^%w%+/%=]", "")
    local T = {}
    for i=1,#B64 do T[string.sub(B64,i,i)] = i-1 end
    local out, val, valb = {}, 0, -8
    for i=1,#s do
        local c = string.sub(s,i,i)
        if c ~= "=" then
            local v = T[c]; if not v then goto continue end
            val = (val << 6) | v
            valb = valb + 6
            if valb >= 0 then
                out[#out+1] = ( (val >> valb) & 0xFF )
                val = val & ((1 << valb) - 1)
                valb = valb - 8
            end
        end
        ::continue::
    end
    return out
end

local function bxor(a,b) return (a ~ b) & 0xFF end

-- stream key
local function derive_stream(len, iv)
    local seed = 0
    local mix  = (ENC_SECRET .. "|" .. tostring(iv or ""))
    for i=1,#mix do
        seed = ( (seed * 131) + string.byte(mix,i) ) % 4294967296
    end
    local function next_byte()
        seed = (1103515245 * seed + 12345) % 4294967296
        return seed % 256
    end
    local t = {}
    for i=1,len do t[i] = next_byte() end
    return t
end

local function simple_checksum(bytes, iv)
    local sum = 2166136261
    for i=1,#bytes do
        sum = (sum ~ bytes[i]) & 0xFFFFFFFF
        sum = (sum * 16777619) % 4294967296
    end
    local ivb = str_to_bytes(tostring(iv or ""))
    for i=1,#ivb do
        sum = (sum ~ ivb[i]) & 0xFFFFFFFF
        sum = (sum * 16777619) % 4294967296
    end
    return tostring(sum)
end

local function encrypt_str(plain, iv)
    local pbytes = str_to_bytes(plain)
    local key    = derive_stream(#pbytes, iv)
    local out    = {}
    for i=1,#pbytes do out[i] = bxor(pbytes[i], key[i]) end
    local b64 = b64_encode(out)
    local sig = simple_checksum(pbytes, iv)
    return b64, sig
end

local function decrypt_str(b64, iv, sig)
    local bytes = b64_decode(b64 or "")
    if #bytes == 0 then return false, "empty" end
    local key   = derive_stream(#bytes, iv)
    local out   = {}
    for i=1,#bytes do out[i] = bxor(bytes[i], key[i]) end
    local plain = bytes_to_str(out)
    local okSig = (simple_checksum(out, iv) == tostring(sig or ""))
    if not okSig then return false, "bad_signature" end
    return true, plain
end

local function saveKeyExternal(key, expires_at, permanent)
    if not writefile then return end
    ensureExtDir()
    local payload = {
        key        = tostring(key or ""),
        permanent  = permanent and true or false,
        expires_at = expires_at or nil,
        saved_at   = os.time(),
    }
    local json = HttpService:JSONEncode(payload)
    local iv   = ("%08x%08x"):format(os.time() % 0xFFFFFFFF, math.random(0, 0x7FFFFFFF))
    local data, sig = encrypt_str(json, iv)
    local envelope = { v=ENC_VER, enc="xor-b64", iv=iv, sig=sig, data=data }
    local ok, outJson = pcall(function() return HttpService:JSONEncode(envelope) end)
    if ok and outJson then pcall(writefile, EXT_KEY_FILE, outJson) end
end

local function readKeyExternal()
    if not (isfile and readfile and isfile(EXT_KEY_FILE)) then return nil end
    local ok, data = pcall(readfile, EXT_KEY_FILE)
    if not ok or not data or #data == 0 then return nil end

    -- new format (encrypted)
    local ok1, env = pcall(function() return HttpService:JSONDecode(data) end)
    if ok1 and type(env)=="table" and env.enc=="xor-b64" and env.data and env.iv then
        local ok2, plain = decrypt_str(env.data, env.iv, env.sig)
        if not ok2 then return nil end
        local ok3, decoded = pcall(function() return HttpService:JSONDecode(plain) end)
        if ok3 and type(decoded)=="table" then
            return {
                key        = tostring(decoded.key or ""),
                permanent  = decoded.permanent and true or false,
                expires_at = tonumber(decoded.expires_at) or nil
            }
        end
        return nil
    end
    return nil
end
