local util = require("xlua.util")

local toastQueue = {}
local isShowing = false
local customHintGO = nil

local function getCustomHint()
    if customHintGO ~= nil then
        return customHintGO
    end

    local orig = CS.UnityEngine.GameObject.Find("UIRoot/AboveDialog/PileToastDialog(Clone)/PileContainer/HintInfoDialog(Clone)")
    if orig == nil then
        return nil
    end

    customHintGO = CS.UnityEngine.GameObject.Instantiate(orig)
    customHintGO.name = "CustomHint(Clone)"
    customHintGO.transform:SetParent(orig.transform.parent, false)
    customHintGO:SetActive(true)

    return customHintGO
end

local function waitSeconds(seconds)
    local startTime = CS.UnityEngine.Time.time
    while CS.UnityEngine.Time.time - startTime < seconds do
        coroutine.yield(nil)
    end
end

local function runToast(textname)
    local hintGO = getCustomHint()
    if hintGO == nil then
        return false
    end

    local hint = hintGO:GetComponent(typeof(CS.RPG.Client.ToastHintItem))
    if hint == nil then
        return false
    end

    local textObj = hintGO.transform:Find("Title/Text")
    if textObj == nil then
        return false
    end

    local localizedTextComponent = textObj:GetComponent(typeof(CS.RPG.Client.LocalizedText))
    if localizedTextComponent == nil then
        return false
    end

    hintGO:SetActive(true)
    localizedTextComponent.text = tostring(textname)

    local fadeInDuration = 0.1
    local showDuration = 2.5
    local fadeOutDuration = 2.5

    hint:FadeIn()
    waitSeconds(fadeInDuration)

    waitSeconds(showDuration)

    hint:FadeOut()
    waitSeconds(fadeOutDuration)

    return true
end

local function processQueue()
    if isShowing or #toastQueue == 0 then
        return
    end
    isShowing = true
    local text = table.remove(toastQueue, 1)

    local function runner()
        -- If UI isn't ready yet, retry later without losing the message.
        if not runToast(text) then
            table.insert(toastQueue, 1, text)
            waitSeconds(0.5)
        end
        isShowing = false
        processQueue()
    end

    CS.RPG.Client.CoroutineUtils.StartCoroutine(util.cs_generator(runner))
end

function queueToast(text)
    table.insert(toastQueue, text)
    processQueue()
end

queueToast("Hi, CastoricePS is a free server for Honkai Star Rail")
queueToast("If you paid for it, you got scammed. Please refund yourself")
queueToast("Join our Discord for more info: https://discord.gg/dyn9NjBwzZ")
              
