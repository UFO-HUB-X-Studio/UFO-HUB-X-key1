-- UI MAX Script.lua
-- UFO HUB X — Boot Loader (Key → Download → Main UI)
-- รองรับ Delta / syn / KRNL / Script-Ware / Fluxus / Solara ฯลฯ + loadstring(HttpGet)
-- จัดเต็ม: Patch Key/Download ให้ยิงสัญญาณ, Watchers หลายชั้น, Retry/Backoff, Force Main fallback
-- + เพิ่ม: FORCE_KEY_UI, Hotkey ลบคีย์แล้วรีโหลด (RightAlt), deleteState(), reloadSelf()
-- + เพิ่ม (ใหม่): Force Key First บังคับให้ Key UI แสดงก่อนเสมอ (ปรับได้ด้วย getgenv().UFO_FORCE_KEY_UI)
-- + FIX: กดปุ่ม X ใน Key UI จะไม่ไปหน้า Download อีกต่อไป (เรียก Download เฉพาะตอนคีย์ผ่าน)

--========================================================
-- Services + Compat
--========================================================
local HttpService  = game:GetService("HttpService")
local UIS          = game:GetService("UserInputService")

local function log(s)
    s = "[UFO-HUB-X] "..tostring(s)
    if rconsoleprint then rconsoleprint(s.."\n") else print(s) end
end

local function http_get(url)
    if http and http.request then
        local ok, res = pcall(http.request, {Url=url, Method="GET"})
        if ok and res and (res.Body or res.body) then return true, (res.Body or res.body) end
    end
    if syn and syn.request then
        local ok, res = pcall(syn.request, {Url=url, Method="GET"})
        if ok and res and (res.Body or res.body) then return true, (res.Body or res.body) end
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and body then return true, body end
    return false, "httpget_failed"
end

local function http_get_retry(urls, tries, delay_s)
    local list = {}
    if type(urls)=="table" then list = urls else list = {urls} end
    tries   = tries or 3
    delay_s = delay_s or 0.75
    local attempt = 0
    for round=1, tries do
        for _,u in ipairs(list) do
            attempt += 1
            log(("HTTP try #%d → %s"):format(attempt, u))
            local ok, body = http_get(u)
            if ok and body then return true, body, u end
        end
        task.wait(delay_s * round)
    end
    return false, "retry_failed"
end

local function safe_loadstring(src, tag)
    local f, e = loadstring(src, tag or "chunk")
    if not f then return false, "loadstring: "..tostring(e) end
    local ok, err = pcall(f)
    if not ok then return false, "pcall: "..tostring(err) end
    return true
end

--========================================================
-- FS: Persist key state
--========================================================
local DIR        = "UFOHubX"
local STATE_FILE = DIR.."/key_state.json"
local function ensureDir()
    if isfolder then
        if not isfolder(DIR) then pcall(makefolder, DIR) end
    end
end
ensureDir()

local function readState()
    if not (isfile and readfile and isfile(STATE_FILE)) then return nil end
    local ok, data = pcall(readfile, STATE_FILE)
    if not ok or not data or #data==0 then return nil end
    local ok2, decoded = pcall(function() return HttpService:JSONDecode(data) end)
    if ok2 then return decoded end
    return nil
end

local function writeState(tbl)
    if not (writefile and HttpService and tbl) then return end
    local ok, json = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok then pcall(writefile, STATE_FILE, json) end
end

-- ลบไฟล์ state (ใช้ตอนเคลียร์คีย์)
local function deleteState()
    if isfile and isfile(STATE_FILE) and delfile then pcall(delfile, STATE_FILE) end
end

--========================================================
-- [ADD] External key save + import (เพิ่มอย่างเดียว ไม่แตะของเดิม)
--========================================================
local EXT_DIR      = "UFO-HUB-X-Studio"          -- ตามที่ขอ
local EXT_KEY_FILE = EXT_DIR.."/UFO-HUB-X-key1"  -- ไฟล์ภายนอก

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
        -- fallback text
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

    -- JSON ก่อน
    local tryJson, decoded = pcall(function() return HttpService:JSONDecode(data) end)
    if tryJson and type(decoded) == "table" and decoded.key then
        return {
            key        = tostring(decoded.key or ""),
            permanent  = decoded.permanent and true or false,
            expires_at = tonumber(decoded.expires_at) or nil
        }
    end

    -- ข้อความธรรมดา
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

--========================================================
-- Config
--========================================================
local URL_KEYS = {
    "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X%20key.lua",
}
local URL_DOWNLOADS = {
    "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua",
}
local URL_MAINS = {
    "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-3/refs/heads/main/UFO%20HUB%20X%20UI.lua",
}

local ALLOW_KEYS = {
    ["JJJMAX"]                = { permanent=true,  reusable=true, expires_at=nil },
    ["GMPANUPHONGARTPHAIRIN"] = { permanent=true,  reusable=true, expires_at=nil },
}

-- ตัวเลือกบังคับแสดง Key UI (ไว้เทสต์)
local FORCE_KEY_UI = false

-- Hotkey เคลียร์คีย์ + รีโหลดสคริปต์ (RightAlt)
local ENABLE_CLEAR_HOTKEY = true
local CLEAR_HOTKEY        = Enum.KeyCode.RightAlt

-- ใช้กับ reloadSelf (ตั้งค่านี้ตอนเรียก)
-- getgenv().UFO_BootURL = "https://raw.githubusercontent.com/<YOU>/<REPO>/main/UI%20MAX%20Script.lua"

local function normKey(s)
    s = tostring(s or ""):gsub("%c",""):gsub("%s+",""):gsub("[^%w]","")
    return string.upper(s)
end

--========================================================
-- Key state helpers
--========================================================
local function isKeyStillValid(state)
    if not state or not state.key then return false end
    if state.permanent == true then return true end
    if state.expires_at and typeof(state.expires_at)=="number" then
        if os.time() < state.expires_at then return true end
    end
    return false
end

local function saveKeyState(key, expires_at, permanent)
    local st = {
        key        = key,
        permanent  = permanent and true or false,
        expires_at = expires_at or nil,
        saved_at   = os.time(),
    }
    writeState(st)
end

--========================================================
-- Reload ตัวเอง
--========================================================
local function reloadSelf()
    local boot = (getgenv and getgenv().UFO_BootURL) or nil
    if boot and #boot > 0 then
        task.delay(0.15, function()
            local ok, src = http_get(boot)
            if ok then
                local f = loadstring(src)
                if f then pcall(f) end
            else
                log("reloadSelf: fetch failed, check UFO_BootURL")
            end
        end)
    else
        log("reloadSelf: getgenv().UFO_BootURL not set.")
    end
end

--========================================================
-- Global callbacks (Key/Download/Main เรียกใช้)
--========================================================
_G.UFO_SaveKeyState = function(key, expires_at, permanent)
    log(("SaveKeyState: key=%s exp=%s perm=%s"):format(tostring(key), tostring(expires_at), tostring(permanent)))
    saveKeyState(key, expires_at, permanent)

    -- [ADD] Duplicate-save ไปยัง UFO-HUB-X-Studio/UFO-HUB-X-key1
    pcall(saveKeyExternal, key, expires_at, permanent)

    _G.UFO_HUBX_KEY_OK   = true
    _G.UFO_HUBX_KEY      = key
    _G.UFO_HUBX_KEY_EXP  = expires_at
    _G.UFO_HUBX_KEY_PERM = permanent and true or false
end

_G.UFO_StartDownload = function()
    if _G.__UFO_Download_Started then return end
    _G.__UFO_Download_Started = true
    log("Start Download UI (signal)")
    local ok, src, used = http_get_retry(URL_DOWNLOADS, 5, 0.8)
    if not ok then
        log("Download UI fetch failed → Force Main UI fallback")
        if _G and _G.UFO_ShowMain then _G.UFO_ShowMain() end
        return
    end
    -- Patch Download UI: เรียก UFO_ShowMain ตอนจบเสมอ
    do
        local patched = src
        local injected = 0
        patched, injected = patched:gsub(
            "gui:Destroy%(%);?",
            [[
if _G and _G.UFO_ShowMain then _G.UFO_ShowMain() end
gui:Destroy();
]]
        )
        if injected > 0 then
            log("Patched Download UI to always call UFO_ShowMain() on finish.")
            src = patched
        else
            log("No patch point found in Download UI (ok if it calls itself).")
        end
    end
    local ok2, err = safe_loadstring(src, "UFOHubX_Download")
    if not ok2 then
        log("Download UI run failed: "..tostring(err))
        if _G and _G.UFO_ShowMain then _G.UFO_ShowMain() end
        return
    end
end

_G.UFO_ShowMain = function()
    if _G.__UFO_Main_Started then return end
    _G.__UFO_Main_Started = true
    log("Show Main UI")
    local ok, src, used = http_get_retry(URL_MAINS, 5, 0.8)
    if not ok then
        log("Main UI fetch failed. Please check your GitHub raw URL.")
        return
    end
    local ok2, err = safe_loadstring(src, "UFOHubX_Main")
    if not ok2 then
        log("Main UI run failed: "..tostring(err))
        return
    end
end

--========================================================
-- Watchers / Fallback หลายชั้น
--========================================================
local function startKeyWatcher(timeout_sec)
    timeout_sec = timeout_sec or 120
    task.spawn(function()
        local t0 = os.clock()
        while (os.clock() - t0) < timeout_sec do
            if _G and _G.UFO_HUBX_KEY_OK then
                log("Watcher: KEY_OK detected → start download")
                if _G and _G.UFO_StartDownload then _G.UFO_StartDownload() end
                return
            end
            task.wait(0.25)
        end
        log("Watcher: Key stage timeout (still waiting for user input).")
    end)
end

local function startDownloadWatcher(timeout_sec)
    timeout_sec = timeout_sec or 90
    task.spawn(function()
        local t0 = os.clock()
        while (os.clock() - t0) < timeout_sec do
            if _G and _G.__UFO_Main_Started then return end
            task.wait(0.5)
        end
        log("Watcher: Download timeout → Force Main UI")
        if _G and _G.UFO_ShowMain then _G.UFO_ShowMain() end
    end)
end

local function startUltimateWatchdog(total_sec)
    total_sec = total_sec or 180
    task.spawn(function()
        local t0 = os.clock()
        while (os.clock() - t0) < total_sec do
            if _G and _G.__UFO_Main_Started then return end
            task.wait(1)
        end
        log("Ultimate Watchdog: Forcing Main UI (safety).")
        if _G and _G.UFO_ShowMain then _G.UFO_ShowMain() end
    end)
end

--========================================================
-- Hotkey เคลียร์คีย์ + รีโหลด
--========================================================
if ENABLE_CLEAR_HOTKEY then
    UIS.InputBegan:Connect(function(i, gpe)
        if gpe then return end
        if i.KeyCode == CLEAR_HOTKEY then
            log("Hotkey: clear key state and reload")
            deleteState()
            reloadSelf()
        end
    end)
end

--========================================================
-- Boot Flow
--========================================================
startUltimateWatchdog(180)

-- Force Key First (บังคับ Key UI ก่อนเสมอถ้าไม่ตั้งค่าเอง)
do
    local env = (getgenv and getgenv().UFO_FORCE_KEY_UI)
    if env == nil then
        FORCE_KEY_UI = true
    else
        FORCE_KEY_UI = env and true or false
    end
end

local cur   = readState()
local valid = isKeyStillValid(cur)

-- [ADD] ถ้า state เดิมยังไม่ valid → ลองโหลดจากไฟล์ภายนอก
do
    if not valid then
        local ext = readKeyExternal()
        if ext and ext.key and #tostring(ext.key) > 0 then
            local okToUse = false
            if ext.permanent == true then
                okToUse = true
            elseif ext.expires_at and typeof(ext.expires_at)=="number" and os.time() < ext.expires_at then
                okToUse = true
            end
            if okToUse and _G and type(_G.UFO_SaveKeyState) == "function" then
                _G.UFO_SaveKeyState(ext.key, ext.expires_at, ext.permanent)
                cur   = readState()
                valid = isKeyStillValid(cur)
                log("Imported key from external file: " .. tostring(ext.key))
            end
        end
    end
end

-- ======= โหมดบังคับ Key UI ก่อนเสมอ =======
if FORCE_KEY_UI then
    log("FORCE_KEY_UI = true → show Key UI (first)")
    startKeyWatcher(120)
    startDownloadWatcher(120)

    local ok, src = http_get_retry(URL_KEYS, 5, 0.8)
    if not ok then
        log("Key UI fetch failed (cannot continue without Key UI)")
        return
    end
    do
        local patched = src
        local injected = 0
        -- FIX: เรียก Download เฉพาะเมื่อ KEY_OK จริง
        patched, injected = patched:gsub(
            "gui:Destroy%(%);?",
            [[
if _G and _G.UFO_HUBX_KEY_OK and _G.UFO_StartDownload then _G.UFO_StartDownload() end
gui:Destroy();
]]
        )
        if injected == 0 then
            -- สำรอง: inject หลังข้อความ "✅ Key accepted"
            patched, injected = patched:gsub(
                'btnSubmit.Text%s*=%s*"✅ Key accepted"',
                [[btnSubmit.Text = "✅ Key accepted"
if _G and _G.UFO_StartDownload then _G.UFO_StartDownload() end
]]
            )
        end
        if injected > 0 then
            log("Patched Key UI to call UFO_StartDownload() only when key is OK.")
            src = patched
        else
            log("No patch point found in Key UI (ok if it calls itself).")
        end
    end
    local ok2, err = safe_loadstring(src, "UFOHubX_Key")
    if not ok2 then log("Key UI run failed: "..tostring(err)) end
    return
end

-- ======= โหมดปกติ (ไม่ force) =======
if valid then
    log("Key valid → skip Key UI → go Download")
    _G.UFO_HUBX_KEY_OK   = true
    _G.UFO_HUBX_KEY      = cur.key
    _G.UFO_HUBX_KEY_EXP  = cur.expires_at
    _G.UFO_HUBX_KEY_PERM = cur.permanent and true or false

    startDownloadWatcher(90)
    local ok, src = http_get_retry(URL_DOWNLOADS, 5, 0.8)
    if not ok then
        log("Download UI fetch failed on skip-key path → Force Main")
        if _G and _G.UFO_ShowMain then _G.UFO_ShowMain() end
        return
    end
    do
        local patched = src
        local injected = 0
        patched, injected = patched:gsub(
            "gui:Destroy%(%);?",
            [[
if _G and _G.UFO_ShowMain then _G.UFO_ShowMain() end
gui:Destroy();
]]
        )
        if injected > 0 then
            log("Patched Download UI (skip-key path) to always call UFO_ShowMain().")
            src = patched
        end
    end
    local ok2, err = safe_loadstring(src, "UFOHubX_Download")
    if not ok2 then
        log("Download UI run failed (skip-key path): "..tostring(err))
        if _G and _G.UFO_ShowMain then _G.UFO_ShowMain() end
        return
    end
else
    log("No valid key → show Key UI")
    startKeyWatcher(120)
    startDownloadWatcher(120)

    local ok, src = http_get_retry(URL_KEYS, 5, 0.8)
    if not ok then
        log("Key UI fetch failed (cannot continue without Key UI)")
        return
    end
    do
        local patched = src
        local injected = 0
        -- FIX: เรียก Download เฉพาะเมื่อ KEY_OK จริง
        patched, injected = patched:gsub(
            "gui:Destroy%(%);?",
            [[
if _G and _G.UFO_HUBX_KEY_OK and _G.UFO_StartDownload then _G.UFO_StartDownload() end
gui:Destroy();
]]
        )
        if injected == 0 then
            patched, injected = patched:gsub(
                'btnSubmit.Text%s*=%s*"✅ Key accepted"',
                [[btnSubmit.Text = "✅ Key accepted"
if _G and _G.UFO_StartDownload then _G.UFO_StartDownload() end
]]
            )
        end
        if injected > 0 then
            log("Patched Key UI to call UFO_StartDownload() only when key is OK.")
            src = patched
        else
            log("No patch point found in Key UI (ok if it calls itself).")
        end
    end
    local ok2, err = safe_loadstring(src, "UFOHubX_Key")
    if not ok2 then
        log("Key UI run failed: "..tostring(err))
        return
    end
end

-- Done boot loader
