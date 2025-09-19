-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- [ADD] External key save + import (ไม่แก้ของเดิม แค่เพิ่ม)
local EXT_DIR      = "UFO-HUB-X-Studio"
local EXT_KEY_FILE = EXT_DIR.."/UFO-HUB-X-key1"

local function ensureExtDir()
    if isfolder and not isfolder(EXT_DIR) then
        pcall(makefolder, EXT_DIR)
    end
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
    local ok, json = pcall(function() return HttpService:JSONEncode(payload) end)
    if ok and json and #json > 0 then
        pcall(writefile, EXT_KEY_FILE, json)
    else
        local line = string.format("%s|perm=%s|exp=%s|t=%d",
            tostring(key or ""), tostring(permanent and true or false),
            tostring(expires_at or "nil"), os.time())
        pcall(writefile, EXT_KEY_FILE, line)
    end
end

local function readKeyExternal()
    if not (isfile and readfile and isfile(EXT_KEY_FILE)) then return nil end
    local ok, data = pcall(readfile, EXT_KEY_FILE)
    if not ok or not data or #data == 0 then return nil end

    local tryJson, decoded = pcall(function() return HttpService:JSONDecode(data) end)
    if tryJson and type(decoded) == "table" and decoded.key then
        return {
            key        = tostring(decoded.key or ""),
            permanent  = decoded.permanent and true or false,
            expires_at = tonumber(decoded.expires_at) or nil
        }
    end

    local line = tostring(data):gsub("%s+$","")
    local key  = line:match("^[^|\r\n]+") or line
    local perm = line:match("perm%s*=%s*(%w+)") or "false"
    local exp  = line:match("exp%s*=%s*(%d+)")
    return {
        key        = key,
        permanent  = (perm:lower() == "true"),
        expires_at = exp and tonumber(exp) or nil
    }
end
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
