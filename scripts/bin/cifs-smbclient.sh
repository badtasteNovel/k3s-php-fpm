#!/bin/bash
# cifs / smbclient 整合工具

# 建立掛載點
makeMountPoint(){
    # 外部變數改名為 _out_ 開頭，避免與 _browse 內部的 nasIp, user 等名稱衝突
    local _out_nasIp _out_user _out_password _out_path
    local localPath
    _browse _out_nasIp _out_user _out_password _out_path
    localPath=$(gum input  --placeholder "請輸入掛載資料夾名稱，都將掛載至mnt。" --value='nas' )
    
    sudo mkdir -p /mnt/$localPath
    sudo mount -t cifs "//$_out_nasIp/$_out_path" /mnt/$localPath \
        -o credentials=/root/.nascredentials,iocharset=utf8,vers=3.0,dir_mode=0700,file_mode=0600
    
    if [ $? -eq 0 ]; then
        echo "🎉 成功掛載至 /mnt/$localPath"
    else
        echo "❌ 掛載失敗，請檢查權限。"
    fi
}
config(){
    if [ -f /root/.nascredentials ]; then
        echo "已有：憑證，可進行下一步。"
        exit 0
    fi
    _checkTool
    local credFile
    local userName
    local password
    credFile="/root/.nascredentials"
    sudo touch $credFile
    userName=$(gum input --placeholder "輸入username")
    password=$(gum input --password --placeholder "請輸入 NAS 密碼")
    
    echo "username=$userName" | sudo tee $credFile > /dev/null
    echo "password=$password" | sudo tee -a $credFile > /dev/null
    
    sudo chmod 600 "$credFile"
}

exportBrowse(){
    # 外部變數改名，確保傳入 _browse 時不會引發 circular reference
    local _out_nasIp _out_user _out_password _out_path
    _browse _out_nasIp _out_user _out_password _out_path
    echo "${_out_nasIp}|${_out_path}"
}
# 瀏覽掛載位置 - 保持內部變數名稱正常
_browse(){
    local -n nasIp=$1
    local -n user=$2
    local -n password=$3
    local -n selectedFolder=$4
    local _rawList
    local _share
    local _subPath
    local _choice
    nasIp=$(gum input --placeholder "輸入 NAS IP")
    user=$(sudo grep "username=" /root/.nascredentials | cut -d'=' -f2)
    password=$(sudo grep "password=" /root/.nascredentials | cut -d'=' -f2)

    selectedFolder=""
    while true; do
        if [ -z "$selectedFolder" ]; then
        _rawList=$(smbclient -L "//$nasIp" -U "$user%$password" 2>/dev/null | grep "Disk" | awk '{print $1}')
        else
        _share=$(echo "$selectedFolder" | cut -d'/' -f1)
        _subPath=$(echo "$selectedFolder" | cut -d'/' -f2-)

        if [ -z "$_subPath" ] || [ "$_subPath" = "$_share" ]; then
            _rawList=$(smbclient "//$nasIp/$_share" -U "$user%$password" -c "ls" 2>/dev/null \
            | awk '$2 ~ /^D/' | awk '{print $1}' | grep -v '^\.$' | grep -v '^\.\.$') || true
        else
            _rawList=$(smbclient "//$nasIp/$_share" -U "$user%$password" -c "cd \"$_subPath\"; ls" 2>/dev/null \
            | awk '$2 ~ /^D/' | awk '{print $1}' | grep -v '^\.$' | grep -v '^\.\.$') || true
        fi
        fi

        if [ -z "$_rawList" ]; then
        _choice=$(echo "🟢 [確認掛載目前路徑: /$selectedFolder]" | gum choose --header "正在瀏覽: /$selectedFolder (無子資料夾)")
        else
        _choice=$(printf "🟢 [確認掛載目前路徑: /$selectedFolder]\n%s\n" "$_rawList" | gum choose --header "正在瀏覽: /$selectedFolder")
        fi

        if [[ "$_choice" == "🟢 [確認掛載目前路徑"* ]]; then
        [ -z "$selectedFolder" ] && echo "未選擇路徑" && exit 1
        break
        elif [ -z "$_choice" ]; then
        exit 1
        else
        if [ -z "$selectedFolder" ]; then
            selectedFolder="$_choice"
        else
            selectedFolder="$selectedFolder/$_choice"
        fi
        fi
    done

}
_checkTool(){
    dpkg -s cifs-utils >/dev/null 2>&1 || (sudo apt update && sudo apt install -y cifs-utils)
    dpkg -s smbclient >/dev/null 2>&1 || (sudo apt update && sudo apt install -y smbclient)
}

main() {
  local command="${1:-}"
  shift || true
  case "$command" in
    makeMountPoint) makeMountPoint "$@" ;;
    config) config "$@" ;;
    exportBrowse) exportBrowse "$@" ;;
    *) help "$@" ;;
  esac
}
_checkTool
main "$@"