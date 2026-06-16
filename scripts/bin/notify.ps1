# notify.ps1
Import-Module BurntToast

# 建立通知內容，這裡可以帶入 Duration 'Short'
$Text = New-BTText -Content 'Build 完成！'
$Binding = New-BTBinding -Children $Text
$Visual = New-BTVisual -BindingGeneric $Binding
$Content = New-BTContent -Visual $Visual -Duration 'Short'

# 這裡設定過期時間為現在加 1 秒
# 過期意味著通知會從「通知中心」消失，不再留存
$Content.ExpirationTime = [DateTime]::Now.AddSeconds(1)

Submit-BTNotification -Content $Content