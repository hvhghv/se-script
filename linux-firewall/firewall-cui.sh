#!/bin/bash

# 配置目录
CONFIG_DIR="/etc/iptables-manager"
PORT_CONFIG="${CONFIG_DIR}/ports.conf"
IPNET_CONFIG="${CONFIG_DIR}/ip_nets.conf"
RULES_FILE="/etc/iptables/rules.v4"

# 初始化配置
init_config() {
    mkdir -p "$CONFIG_DIR"
    touch "$PORT_CONFIG" "$IPNET_CONFIG"
    
    # 创建端口配置文件结构
    if [ ! -s "$PORT_CONFIG" ]; then
        echo "# 格式: <协议> <端口>" > "$PORT_CONFIG"
        echo "# 示例: tcp 80" >> "$PORT_CONFIG"
        echo "# 示例: udp 53" >> "$PORT_CONFIG"
    fi
}

# 加载历史规则
load_rules() {
    # 恢复端口规则
    while read -r line; do
        if [[ $line =~ ^(tcp|udp)[[:space:]]+[0-9]+$ ]]; then
            local proto=${line%% *}
            local port=${line##* }
            iptables -A INPUT -p "$proto" --dport "$port" -j ACCEPT
        fi
    done < <(grep -E '^(tcp|udp) [0-9]+' "$PORT_CONFIG")
    
    # 恢复IP网段规则
    while read -r cidr; do
        if [[ "$cidr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]{1,2}$ ]]; then
            iptables -A INPUT -s "$cidr" -j ACCEPT
        fi
    done < "$IPNET_CONFIG"
}

# 初始化防火墙
init_firewall() {
    # 清除所有规则
    iptables -F INPUT
    
    # 设置默认策略
    iptables -P INPUT DROP
    
    # 基本安全规则
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
    
    # 加载历史规则
    load_rules
}

# 放行端口
allow_port() {
    while :; do
        read -p "协议 (tcp/udp): " proto
        [[ "$proto" =~ ^(tcp|udp)$ ]] && break
        echo "无效协议! 请输入 'tcp' 或 'udp'"
    done
    
    while :; do
        read -p "端口号 (1-65535): " port
        [[ "$port" =~ ^[0-9]{1,5}$ ]] && ((port >= 1 && port <= 65535)) && break
        echo "无效端口号! 请输入 1-65535 之间的值"
    done
    
    # 检查是否已存在
    if grep -q "^${proto} ${port}$" "$PORT_CONFIG"; then
        echo "⚠️ 规则已存在: ${proto}/${port}"
        return
    fi
    
    # 添加规则和配置
    iptables -A INPUT -p "$proto" --dport "$port" -j ACCEPT
    echo "${proto} ${port}" >> "$PORT_CONFIG"
    echo "✅ 已放行: ${proto}/${port}"
}

# 取消放行端口
deny_port() {
    local count=1
    local entries=()
    
    echo "当前放行端口:"
    while read -r line; do
        if [[ "$line" =~ ^(tcp|udp)[[:space:]]+[0-9]+$ ]]; then
            printf "%-4s %-5s %s\n" "[$count]" "${line%% *}" "${line##* }"
            entries+=("$line")
            ((count++))
        fi
    done < "$PORT_CONFIG"
    
    if [ ${#entries[@]} -eq 0 ]; then
        echo "没有可管理的端口规则"
        read -p "按Enter返回"
        return
    fi
    
    while :; do
        read -p "选择要取消的规则编号 [1-$((count-1))], 或 'a' 取消所有: " choice
        if [[ "$choice" = "a" ]]; then
            # 删除所有端口规则
            while read -r line; do
                if [[ "$line" =~ ^(tcp|udp)[[:space:]]+[0-9]+$ ]]; then
                    local proto=${line%% *}
                    local port=${line##* }
                    iptables -D INPUT -p "$proto" --dport "$port" -j ACCEPT
                fi
            done < "$PORT_CONFIG"
            
            # 清空配置文件
            grep -vE '^(tcp|udp) [0-9]+' "$PORT_CONFIG" > "${PORT_CONFIG}.tmp"
            mv "${PORT_CONFIG}.tmp" "$PORT_CONFIG"
            
            echo "✅ 所有端口规则已取消"
            break
        elif [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#entries[@]})); then
            local entry="${entries[$((choice-1))]}"
            local proto=${entry%% *}
            local port=${entry##* }
            
            # 从iptables删除
            iptables -D INPUT -p "$proto" --dport "$port" -j ACCEPT
            
            # 从配置文件中删除
            sed -i "/^${proto} ${port}$/d" "$PORT_CONFIG"
            
            echo "✅ 已取消: ${proto}/${port}"
            break
        else
            echo "无效选择!"
        fi
    done
}

# 放行IP网段
allow_ipnet() {
    while :; do
        read -p "输入IP网段 (CIDR格式, 如 192.168.1.0/24): " cidr
        if [[ "$cidr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]{1,2}$ ]]; then
            # 检查是否已存在
            if grep -q "^${cidr}$" "$IPNET_CONFIG"; then
                echo "⚠️ 规则已存在: ${cidr}"
                return
            fi
            
            # 添加规则和配置
            iptables -A INPUT -s "$cidr" -j ACCEPT
            echo "$cidr" >> "$IPNET_CONFIG"
            echo "✅ 已放行网段: ${cidr}"
            break
        else
            echo "❌ 无效CIDR格式! 正确示例: 192.168.1.0/24"
        fi
    done
}

# 取消放行IP网段
deny_ipnet() {
    local count=1
    local entries=()
    
    echo "当前放行网段:"
    while read -r cidr; do
        if [[ "$cidr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]{1,2}$ ]]; then
            printf "%-4s %s\n" "[$count]" "$cidr"
            entries+=("$cidr")
            ((count++))
        fi
    done < "$IPNET_CONFIG"
    
    if [ ${#entries[@]} -eq 0 ]; then
        echo "没有可管理的网段规则"
        read -p "按Enter返回"
        return
    fi
    
    while :; do
        read -p "选择要取消的规则编号 [1-$((count-1))], 或 'a' 取消所有: " choice
        if [[ "$choice" = "a" ]]; then
            # 删除所有IP网段规则
            while read -r cidr; do
                if [[ "$cidr" =~ ^[0-9]+\.[0--9]+\.[0-9]+\.[0-9]+/[0-9]{1,2}$ ]]; then
                    iptables -D INPUT -s "$cidr" -j ACCEPT
                fi
            done < "$IPNET_CONFIG"
            
            # 清空配置文件
            : > "$IPNET_CONFIG"
            
            echo "✅ 所有网段规则已取消"
            break
        elif [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#entries[@]})); then
            local cidr="${entries[$((choice-1))]}"
            
            # 从iptables删除
            iptables -D INPUT -s "$cidr" -j ACCEPT
            
            # 从配置文件中删除
            sed -i "\|^${cidr}$|d" "$IPNET_CONFIG"
            
            echo "✅ 已取消网段: ${cidr}"
            break
        else
            echo "无效选择!"
        fi
    done
}

# 保存规则
save_rules() {
    echo "💾 正在保存规则..."
    mkdir -p "$(dirname "$RULES_FILE")"
    iptables-save > "$RULES_FILE"
    
    # 设置系统启动加载
    if [[ -f "/etc/init.d/iptables" || -d "/etc/systemd/system" ]]; then
        echo "  正在配置开机自动加载规则..."
        # Systemd系统
        if systemctl is-enabled iptables 2>/dev/null | grep -q enabled; then
            echo "  使用系统iptables服务"
            [ -d "/etc/iptables" ] || mkdir -p /etc/iptables
            cp "$RULES_FILE" "/etc/iptables/rules.v4"
            systemctl restart iptables
        else
            # 创建自定义服务
            cat << EOF > /etc/systemd/system/iptables-manager.service
[Unit]
Description=IPTables Persistent Service
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore -n "$RULES_FILE"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload
            systemctl enable --now iptables-manager
        fi
    elif [ -x "/etc/init.d/iptables" ]; then
        # SysVinit系统
        echo "  使用SysVinit iptables服务"
        /etc/init.d/iptables save
        /etc/init.d/iptables restart
    fi
    
    echo "✅ 规则已保存并将在系统重启后自动加载"
    read -p "按Enter返回菜单"
}

# 显示当前规则
show_current_rules() {
    clear
    echo "=================================================="
    echo "               当前防火墙规则"
    echo "=================================================="
    
    echo -e "\n------ 默认策略 -----"
    iptables -L | grep -E "Chain (INPUT|FORWARD|OUTPUT)"
    
    echo -e "\n------ 端口放行规则 -----"
    local count=0
    while read -r line; do
        if [[ "$line" =~ ^(tcp|udp)[[:space:]]+[0-9]+$ ]]; then
            printf "%-5s %-4s %s\n" "PORT" "${line%% *}" "${line##* }"
            ((count++))
        fi
    done < "$PORT_CONFIG"
    ((count == 0)) && echo "无"
    
    echo -e "\n------ IP网段放行规则 -----"
    count=0
    while read -r cidr; do
        if [[ "$cidr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]{1,2}$ ]]; then
            echo "NET   $cidr"
            ((count++))
        fi
    done < "$IPNET_CONFIG"
    ((count == 0)) && echo "无"
    
    echo -e "\n------ 活动连接统计 -----"
    iptables -L -v | grep -E "(ACCEPT|DROP)"
    
    echo "=================================================="
    read -p "按Enter返回菜单"
}

# 主菜单
main_menu() {
    while :; do
        clear
        echo "=================================================="
        echo "           iptables 防火墙管理 (黑名单模式)"
        echo "=================================================="
        echo " 1. 放行TCP/UDP端口"
        echo " 2. 取消放行端口"
        echo " 3. 放行IP网段"
        echo " 4. 取消放行IP网段"
        echo " 5. 查看当前规则"
        echo " 6. 保存规则并持久化"
        echo " 0. 退出"
        echo "=================================================="
        
        # 显示简单状态
        local port_count=$(grep -cE '^(tcp|udp) [0-9]+' "$PORT_CONFIG")
        local net_count=$(grep -cE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]{1,2}$' "$IPNET_CONFIG")
        printf " 状态: 放行端口:%-4d 放行网段:%-4d\n" "$port_count" "$net_count"
        echo "=================================================="


        read -p " 请输入选项 [0-6]: " choice
        case $choice in
            1) allow_port ;;
            2) deny_port ;;
            3) allow_ipnet ;;
            4) deny_ipnet ;;
            5) show_current_rules ;;
            6) save_rules ;;
            0)
                read -p "是否保存当前规则更改？ [y/N]: " save_choice
                if [[ "$save_choice" =~ ^[Yy]$ ]]; then
                    save_rules
                fi
                exit 0
                ;;
            *) echo "无效选项!"; sleep 1 ;;
        esac
    done
}

# 启动
if [ "$(id -u)" != "0" ]; then
    echo "❌ 必须使用 root 权限运行此脚本!" >&2
    exit 1
fi

# 初始化配置和环境
init_config
init_firewall

# 检查是否已有规则
if ! iptables -L INPUT -n &> /dev/null; then
    echo -e "\n⚠️ 警告: 当前系统未安装 iptables"
    if command -v apt &> /dev/null; then
        read -p "是否安装 iptables？ [Y/n]: " install_choice
        [[ "$install_choice" =~ ^[Nn]$ ]] || apt install -y iptables
    elif command -v yum &> /dev/null; then
        read -p "是否安装 iptables？ [Y/n]: " install_choice
        [[ "$install_choice" =~ ^[Nn]$ ]] || yum install -y iptables iptables-services
    fi
fi

# 启动主菜单
main_menu