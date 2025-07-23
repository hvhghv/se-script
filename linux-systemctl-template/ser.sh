#!/bin/bash

# 获取 ./system/ 目录中的第一个文件
shopt -s nullglob
system_files=(./system/*)
shopt -u nullglob

# 检查目录下是否有文件
if [ ${#system_files[@]} -eq 0 ]; then
    echo "Error: No files found in ./system/"
    exit 1
fi

# 提取文件名（不含路径和后缀）
filename=$(basename -- "${system_files[0]}")
CONF_OVERRIDE="${filename%.*}"

# 检查文件名是否为"CONF"（不区分大小写）
if [[ "${CONF_OVERRIDE,,}" == "conf" ]]; then
    echo "Error: Filename 'conf' is not allowed"
    exit 1
fi

# 如果用户没有设置 CONF，使用目录中的文件名
if [ -z "$CONF" ]; then
    CONF="$CONF_OVERRIDE"
fi

# 根据命令参数执行操作
case "$1" in
    clean)
        # 清理操作
        sudo systemctl stop "$CONF".service 2>/dev/null
        sudo systemctl disable "$CONF".service 2>/dev/null
        sudo rm -f /etc/conf.d/"$CONF".conf
        sudo rm -f /usr/lib/systemd/system/"$CONF".service
        ;;
    *)
        # 默认操作（安装服务）
        sudo mkdir -p /etc/conf.d
        sudo rm -f /etc/conf.d/"$CONF".conf
        sudo cp ./env/env /etc/conf.d/"$CONF".conf
        
        # 使用 ./system/ 中的第一个文件
        sudo cp "${system_files[0]}" /usr/lib/systemd/system/"$CONF".service
        {
            echo "EnvironmentFile=/etc/conf.d/$CONF.conf"
            echo
            echo "[Install]"
            echo "WantedBy=multi-user.target"
        } | sudo tee -a /usr/lib/systemd/system/"$CONF".service > /dev/null
        
        sudo systemctl daemon-reload
        sudo systemctl enable "$CONF".service
        sudo systemctl start "$CONF".service
        ;;
esac