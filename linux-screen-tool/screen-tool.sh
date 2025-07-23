#!/bin/bash

# 工具名称和版本
TOOL_NAME="screen-tool.sh"
VERSION="1.0"

# 显示帮助信息
show_help() {
    cat << EOF
${TOOL_NAME} - 封装 screen 命令的实用工具
版本: ${VERSION}

用法:
  $TOOL_NAME write <name> <command>  向指定终端写入命令（不存在则创建）
  $TOOL_NAME read <name>             读取终端输出
  $TOOL_NAME del <name>              关闭终端
  $TOOL_NAME ls                      列出所有终端
  $TOOL_NAME [-h|--help]             显示此帮助信息

示例:
  $TOOL_NAME write myterm "ls -l"
  $TOOL_NAME read myterm
  $TOOL_NAME del myterm
EOF
}

# 检查会话是否存在
session_exists() {
    screen -ls | grep -q "[0-9]\.$1\s"
}

# 创建新会话
create_session() {
    screen -dmS "$1" /bin/bash -c "echo 'Session initialized'; exec /bin/bash"
}

# 写入命令到终端
write_command() {
    local name="$1"
    local command="$2"
    
    # 检查会话是否存在，不存在则创建
    if ! session_exists "$name"; then
        echo "创建新会话: $name"
        create_session "$name"
        sleep 0.1  # 等待会话初始化
    fi
    
    # 发送命令并执行（追加换行符模拟回车）
    screen -S "$name" -X stuff "$command"$'\n'
}

# 读取终端输出
read_output() {
    local name="$1"
    local tmpfile
    
    # 检查会话是否存在
    if ! session_exists "$name"; then
        echo "错误: 会话 '$name' 不存在" >&2
        exit 1
    fi
    
    # 创建临时文件存放输出
    tmpfile=$(mktemp)
    
    # 捕获当前屏幕内容
    screen -S "$name" -X hardcopy -h "$tmpfile"
    
    # 显示内容并清理
    cat "$tmpfile"
    rm -f "$tmpfile"
}

# 关闭终端会话
delete_session() {
    local name="$1"
    
    if session_exists "$name"; then
        screen -S "$name" -X quit
        screen -wipe "$name"
        echo "已关闭会话: $name"
    else
        echo "错误: 会话 '$name' 不存在" >&2
        exit 0
    fi
}

# 列出所有会话
list_sessions() {
    screen -ls
}

# 主程序逻辑
case "$1" in
    write)
        if [ $# -lt 3 ]; then
            echo "错误: 缺少参数" >&2
            show_help
            exit 1
        fi
        write_command "$2" "${*:3}"
        ;;
    read)
        if [ $# -ne 2 ]; then
            echo "错误: 需要指定会话名称" >&2
            exit 1
        fi
        read_output "$2"
        ;;
    del)
        if [ $# -ne 2 ]; then
            echo "错误: 需要指定会话名称" >&2
            exit 1
        fi
        delete_session "$2"
        ;;
    ls)
        list_sessions
        ;;
    -h|--help|*)
        show_help
        exit 0
        ;;
esac