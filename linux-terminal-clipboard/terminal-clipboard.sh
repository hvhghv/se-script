#!/bin/bash

# 检查是否提供了name参数
if [ $# -eq 0 ]; then
    echo "Usage: $0 <name>"
    exit 1
fi

NAME=$1
CHAT_DIR="/tmp/terminal_chat_$NAME"
LOG_FILE="${CHAT_DIR}/chat.log"
LOCK_FILE="${CHAT_DIR}/lock"
MSG_COUNTER_FILE="${CHAT_DIR}/counter"

# 创建聊天目录
mkdir -p "$CHAT_DIR"
chmod 777 "$CHAT_DIR" 2>/dev/null || true

# 初始化消息计数器
if [ ! -f "$MSG_COUNTER_FILE" ]; then
    echo "0" > "$MSG_COUNTER_FILE"
fi

# 清理函数
cleanup() {
    # 释放锁
    rm -f "$LOCK_FILE.$$"
    exit 0
}

# 设置信号处理
trap cleanup INT TERM EXIT

# 获取锁函数
acquire_lock() {
    local max_attempts=10
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if ln -s $$ "$LOCK_FILE.$$" 2>/dev/null; then
            return 0
        fi
        sleep 0.1
        attempt=$((attempt + 1))
    done
    return 1
}

# 释放锁函数
release_lock() {
    rm -f "$LOCK_FILE.$$" 2>/dev/null
}

# 函数：发送消息
send_message() {
    local message="$1"
    
    # 获取锁
    if acquire_lock; then
        # 获取并递增消息计数器
        local counter=$(cat "$MSG_COUNTER_FILE")
        echo $((counter + 1)) > "$MSG_COUNTER_FILE"
        
        # 使用base64编码消息内容，保留所有格式（包括空消息）
        local encoded_message=$(echo -n "$message" | base64 -w 0)
        
        # 写入编码后的消息到日志文件
        echo "$counter:$$:$encoded_message" >> "$LOG_FILE"
        
        # 释放锁
        release_lock
    fi
}

# 函数：获取消息计数器值
get_message_counter() {
    cat "$MSG_COUNTER_FILE" 2>/dev/null || echo "0"
}

# 函数：处理新消息
process_new_messages() {
    local current_counter=$1
    local last_counter=$2
    
    # 计算有多少条新消息
    local num_new_messages=$((current_counter - last_counter))
    
    # 读取新消息
    local new_messages=$(tail -n "$num_new_messages" "$LOG_FILE" 2>/dev/null)
    
    # 处理每条新消息
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            # 提取编码的消息内容和发送者终端ID
            local encoded_message=$(echo "$line" | cut -d: -f3-)
            local sender_pid=$(echo "$line" | cut -d: -f2)
            
            # 解码消息内容
            local msg_content=$(echo "$encoded_message" | base64 -d)
            
            # 只显示其他终端发送的消息（包括空消息）
            if [ "$sender_pid" -ne "$$" ]; then
                echo "$msg_content"
            fi
        fi
    done <<< "$new_messages"
}

# 后台进程：监听新消息
{
    # 获取当前消息计数器值
    last_counter=$(get_message_counter)
    
    # 父进程PID
    PARENT_PID=$$
    
    # 监听循环
    while true; do
        # 检查父进程是否还在运行
        if ! kill -0 $PARENT_PID 2>/dev/null; then
            exit 0
        fi
        
        # 获取锁
        if acquire_lock; then
            # 检查是否有新消息
            current_counter=$(get_message_counter)
            
            if [ "$current_counter" -gt "$last_counter" ]; then
                # 处理新消息
                process_new_messages "$current_counter" "$last_counter"
                
                # 更新最后计数器
                last_counter="$current_counter"
            fi
            
            # 释放锁
            release_lock
        fi
        
        # 短暂休眠以减少CPU使用
        sleep 0.5
    done
} &

# 主循环 - 读取用户输入并发送
while true; do
    IFS= read -r message
    if [ "$message" = "exit" ]; then
        break
    fi
    # 发送所有输入，包括空输入
    # 发送消息到其他终端（包括空消息）
    send_message "$message"
done

cleanup