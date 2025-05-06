function randomWhiteListCode()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local randomString = ''

    math.randomseed(os.time())
    for i = 1, 6 do
        local randomChar = math.random(#chars)
        randomString = randomString .. chars:sub(randomChar, randomChar)
    end
    randomString = Config.Prefix .. '-' .. randomString

    local result = MySQL.scalar.await('select count(0) from player_whitelist where whitelist_code = ?;', { randomString })

    if result > 0 then
        return randomWhiteListCode()
    end
    return randomString
end

function getIdentifierByType(identifiers, type)
    for _, v in pairs(identifiers) do
        if string.find(v, type) then
            return v
        end
    end
    return ''
end

function whiteListProcess(identifiers)
    local license = getIdentifierByType(identifiers, 'license')
    local license2 = getIdentifierByType(identifiers, 'license2')
    local fivem = getIdentifierByType(identifiers, 'fivem')
    local steam = getIdentifierByType(identifiers, 'steam')
    local live = getIdentifierByType(identifiers, 'live')
    local xbl = getIdentifierByType(identifiers, 'xbl')
    local ip = getIdentifierByType(identifiers, 'ip')

    local result = MySQL.prepare.await('select approved, whitelist_code from player_whitelist where license = ?;', { license })

    if result ~= nil and result.approved == 1 then
        return true, '', ''
    end

    local whitelistCode = ''

    if result == nil then
        whitelistCode = randomWhiteListCode()
        MySQL.insert(
            'INSERT INTO player_whitelist (whitelist_code, license, license2, ip, fivem, steam, live, xbl) VALUES (?, ?, ?, ?, ?, ?, ?, ?);',
            { whitelistCode, license, license2, ip, fivem, steam, live, xbl }
        )
    else
        whitelistCode = result.whitelist_code
    end

    return false, whitelistCode, license
end

AddEventHandler('playerConnecting', function(name, _, deferrals)
    deferrals.defer()

    local identifiers = GetPlayerIdentifiers(source)
    local success, whiteListCode, license = whiteListProcess(identifiers)
    
    if not success then
        print('未通过的白名单：' .. whiteListCode .. ' ' .. license)
        local card = [[
            {
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "body": [
                    {
                        "items": [
                            {
                                "size": "ExtraLarge",
                                "horizontalAlignment": "Center",
                                "text": "欢迎来到 ]] .. Config.ServerName .. [[",
                                "type": "TextBlock",
                                "color": "Accent"
                            },
                            {
                                "size": "ExtraLarge",
                                "horizontalAlignment": "Center",
                                "text": "您在本服务器的白名单识别码为：**]] .. whiteListCode .. [[**",
                                "type": "TextBlock",
                                "color": "Accent"
                            },
                            {
                                "size": "ExtraLarge",
                                "horizontalAlignment": "Center",
                                "text": "您目前还不在本服务器白名单列表中，请您加入KOOK频道填写白名单申请",
                                "type": "TextBlock",
                                "color": "Accent"
                            }
                        ],
                        "type": "Container"
                    },
                    {
                        "type": "ActionSet",
                        "actions": [
                            {
                                "type": "Action.OpenUrl",
                                "title": "点击加入QQ群聊",
                                "url": "]] .. Config.QQ .. [["
                            },
                            {
                                "type": "Action.OpenUrl",
                                "title": "点击加入KOOK频道",
                                "url": "]] .. Config.Kook .. [["
                            }
                        ],
                        "horizontalAlignment": "Center"
                    }
                ],
                "type": "AdaptiveCard",
                "version": "1.5"
            }
        ]]
        while true do
			deferrals.presentCard(card, function(pData, pRawData)
				
			end);
			Wait(0);
		end
    else
        deferrals.done()
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        PerformHttpRequest('https://www.kookapp.cn/api/v3/message/list', function(statusCode, responseText, headers)
            local responseData = json.decode(responseText)
            if responseData and responseData.code == 0 then
                local messages = responseData.data.items
                if messages and #messages > 0 then
                    local message = messages[#messages]
                    local messageid = message.id
                    local content = message.content
                    if string.match(content, "识别码：" .. Config.Prefix .. "%-([%w%-]+)") then
                        local userid = message.author.id
                        local code = string.match(content, "识别码：" .. Config.Prefix .. "%-([%w%-]+)")
                        local reactions = message.reactions or {}
                        
                        if not code then
                            SendMessage('不正确', messageid, userid)
                        else
                            for _, reaction in ipairs(reactions) do
                                if reaction.emoji.name == "✅" then
                                    MySQL.Async.execute('UPDATE player_whitelist SET approved = @approved, user_kook = @user_kook WHERE whitelist_code = @whitelist_code', {
                                        ['@approved'] = 1,
                                        ['@user_kook'] = userid,
                                        ['@whitelist_code'] = Config.Prefix .. '-' .. code,
                                    }, function(rowsChanged)
                                        if rowsChanged > 0 then
                                            SendMessage('正确', messageid, userid)
                                        else
                                            SendMessage('失败', messageid, userid)
                                        end
                                    end)
                                end
                            end
                        end
                    end
                end
            end
        end, 'GET', json.encode({ target_id = Config.TargetId, flag = before }), { ['Content-Type'] = 'application/json', ['Authorization'] = 'Bot ' .. Config.BotToken })
    end
end)

function SendMessage(success, msgid, userid)
    local message = ''
    if success == '不正确' then
        message = '您的格式不正确'
    elseif success == '正确' then
        message = '白名单信息获取成功,已隐私发送!\n(met)' .. userid .. '(met) 绑定成功!现在你可以直接登录 ' .. Config.ServerName .. '.'
    elseif success == '失败' then
        message = '(met)' .. userid .. '(met) 绑定失败,请联系管理员!'
    end
    PerformHttpRequest('https://www.kookapp.cn/api/v3/message/create', function(statusCode, responseText, headers)
        local responseData = json.decode(responseText)
        if responseData and responseData.code == 0 then
            --print('卡片消息成功发送到Kook频道')
        else
            print('发送卡片消息失败 = ' .. (responseData.message or '未知错误'))
        end
    end, 'POST', json.encode({ type = 9, target_id = Config.TargetId, content = message, quote = msgid }), { ['Content-Type'] = 'application/json', ['Authorization'] = 'Bot ' .. Config.BotToken })
end