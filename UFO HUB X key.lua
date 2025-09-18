-- UFO HUB X key.lua
-- Key UI เชื่อมต่อเซิร์ฟเวอร์ (Render) สำหรับแจก/ยืนยันคีย์
-- รองรับ: Delta / syn / KRNL / SW / Fluxus / Solara + loadstring(HttpGet)

--========================[ CONFIG ]========================
local SERVER_BASE = "https://ufo-hub-x-server-key2.onrender.com"  -- << เปลี่ยนเป็นของคุณ
local DEFAULT_TTL_SECONDS = 48 * 60 * 60 -- 48 ชั่วโมง เผื่อกรณีเซิร์ฟเวอร์ไม่ส่ง expires_at มา

-- คีย์อนุญาตพิเศษ (สำรอง)
local ALLOW_KEYS = {
    ["JJJMAX"] = { permanent = true, reusable = true },
    ["GMPANUPHONGARTPHAIRIN"] = { permanent = true, reusable = true },
}

--=======================[ SERVICES ]=======================
local TS   = game:GetService("TweenService")
local CG   = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local LP = game.Players and game.Players.LocalPlayer
local USER_ID  = (LP and LP.UserId) or 0
local PLACE_ID = game.PlaceId or 0

--=======================[ HELPERS ]========================
local function safeParent(gui)
    local ok=false
    if syn and syn.protect_gui then pcall(function() syn.protect_gui(gui) end) end
    if gethui then ok = pcall(function() gui.Parent = gethui() end) end
    if not ok then gui.Parent = CG end
end

local function normKey(s)
    s = tostring(s or ""):gsub("%c",""):gsub("%s+",""):gsub("[^%w%-]","")
    return string.upper(s)
end

local function http_get(url)
    if http and http.request then
        local ok,res = pcall(http.request,{Url=url,Method="GET"})
        if ok and res and (res.Body or res.body) then return true,(res.Body or res.body) end
    end
    if syn and syn.request then
        local ok,res = pcall(syn.request,{Url=url,Method="GET"})
        if ok and res and (res.Body or res.body) then return true,(res.Body or res.body) end
    end
    local ok,body = pcall(function() return game:HttpGet(url) end)
    if ok and body then return true,body end
    return false,"httpget_failed"
end

local function verify_with_server(key)
    key = normKey(key)
    local url = string.format(
        "%s/verify?key=%s&uid=%s&place=%s",
        SERVER_BASE,
        HttpService:UrlEncode(key),
        HttpService:UrlEncode(tostring(USER_ID)),
        HttpService:UrlEncode(tostring(PLACE_ID))
    )
    local ok, raw = http_get(url)
    if not ok then return false, nil, "unreachable" end

    local okj, js = pcall(function() return HttpService:JSONDecode(raw) end)
    if not okj or type(js)~="table" then
        -- บางทีเซิร์ฟเวอร์อาจตอบเป็น string: "valid" / "ok"
        local low = tostring(raw):lower()
        local valid = (low:find("valid") or low:find("ok") or low:find("true")) and true or false
        return valid, nil, valid and nil or "invalid"
    end

    if js.valid == true then
        -- รองรับทั้ง expires_at (epoch) และ expires_in (วินาที)
        local exp_at = js.expires_at
        if not exp_at and js.expires_in then
            exp_at = os.time() + tonumber(js.expires_in)
        end
        if not exp_at then
            exp_at = os.time() + DEFAULT_TTL_SECONDS
        end
        return true, exp_at, nil
    else
        return false, nil, js.reason or "invalid"
    end
end

local function is_allowed_key(k)
    local meta = ALLOW_KEYS[normKey(k)]
    return (meta ~= nil), meta
end

--=======================[ UI BUILD ]=======================
local ACCENT      = Color3.fromRGB(0,255,140)
local BG          = Color3.fromRGB(10,10,10)
local FG          = Color3.fromRGB(235,235,235)

local gui = Instance.new("ScreenGui")
gui.Name = "UFOHubX_KeyUI"; gui.IgnoreGuiInset=true; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
safeParent(gui)

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(740,430); panel.AnchorPoint=Vector2.new(0.5,0.5); panel.Position=UDim2.fromScale(0.5,0.5)
panel.BackgroundColor3=BG; panel.BorderSizePixel=0; panel.Active=true; panel.Draggable=true; panel.Parent=gui
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,22)
local s = Instance.new("UIStroke",panel) s.Color=ACCENT; s.Thickness=2; s.Transparency=0.1

local head = Instance.new("Frame", panel)
head.BackgroundTransparency=0.15; head.BackgroundColor3=Color3.fromRGB(14,14,14)
head.Size=UDim2.new(1,-28,0,68); head.Position=UDim2.new(0,14,0,14)
Instance.new("UICorner",head).CornerRadius=UDim.new(0,16)
local hs = Instance.new("UIStroke",head) hs.Color=ACCENT; hs.Transparency=0.85

local title = Instance.new("TextLabel", head)
title.BackgroundTransparency=1; title.Position=UDim2.new(0,18,0,18)
title.Size=UDim2.new(1,-36,0,32); title.Font=Enum.Font.GothamBlack; title.TextSize=20
title.Text="UFO HUB X — KEY SYSTEM"; title.TextColor3=ACCENT; title.TextXAlignment=Enum.TextXAlignment.Left

local keyLbl = Instance.new("TextLabel", panel)
keyLbl.BackgroundTransparency=1; keyLbl.Position=UDim2.new(0,28,0,188)
keyLbl.Size=UDim2.new(0,140,0,22); keyLbl.Font=Enum.Font.Gotham; keyLbl.TextSize=16
keyLbl.Text="Enter Key"; keyLbl.TextColor3=Color3.fromRGB(200,200,200); keyLbl.TextXAlignment=Enum.TextXAlignment.Left

local keyBox = Instance.new("TextBox", panel)
keyBox.ClearTextOnFocus=false; keyBox.PlaceholderText="paste your key here (e.g. UFO-KEY-AAA111)"
keyBox.Font=Enum.Font.Gotham; keyBox.TextSize=16; keyBox.Text=""; keyBox.TextColor3=FG
keyBox.BackgroundColor3=Color3.fromRGB(22,22,22); keyBox.BorderSizePixel=0
keyBox.Size=UDim2.new(1,-56,0,40); keyBox.Position=UDim2.new(0,28,0,214)
Instance.new("UICorner",keyBox).CornerRadius=UDim.new(0,12)
local kStroke = Instance.new("UIStroke",keyBox) kStroke.Color=ACCENT; kStroke.Transparency=0.75

local btnSubmit = Instance.new("TextButton", panel)
btnSubmit.Text="🔒  Submit Key"; btnSubmit.Font=Enum.Font.GothamBlack; btnSubmit.TextSize=20
btnSubmit.TextColor3=Color3.new(1,1,1); btnSubmit.AutoButtonColor=false
btnSubmit.BackgroundColor3=Color3.fromRGB(210,60,60); btnSubmit.BorderSizePixel=0
btnSubmit.Size=UDim2.new(1,-56,0,50); btnSubmit.Position=UDim2.new(0,28,0,268)
Instance.new("UICorner",btnSubmit).CornerRadius=UDim.new(0,14)

local statusLabel = Instance.new("TextLabel", panel)
statusLabel.BackgroundTransparency=1; statusLabel.Position=UDim2.new(0,28,0,268+50+6)
statusLabel.Size=UDim2.new(1,-56,0,24); statusLabel.Font=Enum.Font.Gotham; statusLabel.TextSize=14
statusLabel.Text=""; statusLabel.TextColor3=Color3.fromRGB(200,200,200); statusLabel.TextXAlignment=Enum.TextXAlignment.Left

-- ปุ่ม Get Key (เปิดลิงก์เซิร์ฟเวอร์)
local getKeyBtn = Instance.new("TextButton", panel)
getKeyBtn.Size=UDim2.new(0,160,0,34); getKeyBtn.Position=UDim2.new(0,28,0,328)
getKeyBtn.Text="🌐  Get Key Link"; getKeyBtn.Font=Enum.Font.GothamBold; getKeyBtn.TextSize=14
getKeyBtn.BackgroundColor3=Color3.fromRGB(32,32,32); getKeyBtn.TextColor3=Color3.new(1,1,1); getKeyBtn.AutoButtonColor=false
Instance.new("UICorner",getKeyBtn).CornerRadius=UDim.new(0,10)
local helpLbl = Instance.new("TextLabel", panel)
helpLbl.BackgroundTransparency=1; helpLbl.Font=Enum.Font.Gotham; helpLbl.TextSize=13; helpLbl.TextWrapped=true
helpLbl.TextColor3=Color3.fromRGB(180,180,180)
helpLbl.Text="กดเพื่อคัดลอกลิงก์รับคีย์ไปยังคลิปบอร์ด แล้วเปิดในเบราว์เซอร์ /getkey"
helpLbl.Size=UDim2.new(1,-200,0,34); helpLbl.Position=UDim2.new(0,200,0,328); helpLbl.TextXAlignment=Enum.TextXAlignment.Left

-- Toast เล็ก ๆ
local toast = Instance.new("TextLabel",panel)
toast.BackgroundTransparency=0.15; toast.BackgroundColor3=Color3.fromRGB(30,30,30)
toast.Size=UDim2.fromOffset(0,32); toast.Position=UDim2.new(0.5,0,0,16); toast.AnchorPoint=Vector2.new(0.5,0)
toast.Visible=false; toast.Font=Enum.Font.GothamBold; toast.TextSize=14; toast.Text=""; toast.TextColor3=Color3.new(1,1,1); toast.ZIndex=200
Instance.new("UICorner",toast).CornerRadius=UDim.new(0,10)
local function showToast(msg, ok)
    toast.Text = msg
    toast.BackgroundColor3 = ok and Color3.fromRGB(20,120,60) or Color3.fromRGB(150,35,35)
    toast.Size = UDim2.fromOffset(math.max(180, (#msg*8)+28), 32)
    toast.Visible = true
    toast.BackgroundTransparency = 0.15
    TS:Create(toast, TweenInfo.new(.08), {BackgroundTransparency = 0.05}):Play()
    task.delay(1.1, function()
        TS:Create(toast, TweenInfo.new(.15), {BackgroundTransparency = 1}):Play()
        task.delay(.15, function() toast.Visible=false end)
    end)
end

local function setStatus(txt, ok)
    statusLabel.Text = txt or ""
    if ok==nil then statusLabel.TextColor3=Color3.fromRGB(200,200,200)
    elseif ok then statusLabel.TextColor3=Color3.fromRGB(120,255,170)
    else statusLabel.TextColor3=Color3.fromRGB(255,120,120) end
end

local function flashError()
    TS:Create(kStroke, TweenInfo.new(.05), {Color=Color3.fromRGB(255,90,90), Transparency=0}):Play()
    task.delay(.22, function() TS:Create(kStroke, TweenInfo.new(.12), {Color=ACCENT, Transparency=0.75}):Play() end)
end

--=======================[ LOGIC ]=========================
local submitting=false
local function refreshBtn()
    if submitting then return end
    local has = keyBox.Text and #keyBox.Text>0
    if has then
        TS:Create(btnSubmit, TweenInfo.new(.08), {BackgroundColor3=Color3.fromRGB(60,200,120)}):Play()
        btnSubmit.TextColor3=Color3.new(0,0,0)
        btnSubmit.Text="🔓  Submit Key"
    else
        TS:Create(btnSubmit, TweenInfo.new(.08), {BackgroundColor3=Color3.fromRGB(210,60,60)}):Play()
        btnSubmit.TextColor3=Color3.new(1,1,1)
        btnSubmit.Text="🔒  Submit Key"
    end
end
keyBox:GetPropertyChangedSignal("Text"):Connect(function() setStatus("",nil); refreshBtn() end)
refreshBtn()

-- กดปุ่ม Get Key → คัดลอกลิงก์ไปคลิปบอร์ด
getKeyBtn.MouseButton1Click:Connect(function()
    local link = SERVER_BASE.."/getkey?uid="..tostring(USER_ID).."&place="..tostring(PLACE_ID)
    if setclipboard then
        setclipboard(link)
        showToast("คัดลอกลิงก์แล้ว: /getkey", true)
    else
        showToast("เปิดลิงก์: "..link, true)
    end
end)

local function successAndClose(k, expires_at, permanent)
    -- ส่งต่อให้ bootloader
    if getgenv and type(getgenv)=="function" then
        local g = getgenv()
        if g and g.UFO_SaveKeyState then g.UFO_SaveKeyState(k, expires_at, permanent and true or false) end
        if g and g.UFO_StartDownload then g.UFO_StartDownload() end
    elseif _G then
        if _G.UFO_SaveKeyState then _G.UFO_SaveKeyState(k, expires_at, permanent and true or false) end
        if _G.UFO_StartDownload then _G.UFO_StartDownload() end
    end
    gui:Destroy()
end

local function doSubmit()
    if submitting then return end
    submitting=true; btnSubmit.Active=false

    local raw = keyBox.Text or ""
    if raw=="" then
        flashError()
        setStatus("โปรดใส่รหัสก่อน", false)
        submitting=false; btnSubmit.Active=true; return
    end

    -- allow-list แบบถาวร
    local okAllow, meta = is_allowed_key(raw)
    if okAllow then
        setStatus("คีย์ถาวร: ยืนยันแล้ว!", true)
        task.delay(.15, function() successAndClose(raw, nil, true) end)
        return
    end

    -- ตรวจกับ server
    setStatus("กำลังยืนยันกับเซิร์ฟเวอร์...", nil)
    btnSubmit.Text="⏳ Verifying..."

    local ok, exp, reason = verify_with_server(raw)
    if not ok then
        flashError()
        if reason=="unreachable" then
            setStatus("เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ลองใหม่/ตรวจเน็ต", false)
        else
            setStatus("คีย์ไม่ถูกต้อง: "..tostring(reason or ""), false)
        end
        submitting=false; btnSubmit.Active=true; btnSubmit.Text="🔒  Submit Key"; return
    end

    setStatus("ยืนยันสำเร็จ! พร้อมใช้งาน 48 ชั่วโมง", true)
    btnSubmit.Text="✅ Key accepted"
    task.delay(.25, function()
        successAndClose(raw, exp or (os.time()+DEFAULT_TTL_SECONDS), false)
    end)
end

btnSubmit.MouseButton1Click:Connect(doSubmit)
keyBox.FocusLost:Connect(function(enter) if enter then doSubmit() end end)

-- แอนิเมชันเข้า
panel.Position = UDim2.fromScale(0.5,0.5) + UDim2.fromOffset(0,14)
TS:Create(panel, TweenInfo.new(.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position=UDim2.fromScale(0.5,0.5)}):Play()

local SERVER_BASE = "https://ufo-hub-x-server-key2.onrender.com"
local URL_KEYS = {
  "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-key1/refs/heads/main/UFO%20HUB%20X%20key.lua"
}
