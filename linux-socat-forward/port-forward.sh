#!/bin/sh

# 参数说明:
# $1 = BIND_PORT    (本地监听端口)
# $2 = REMOTE_IP    (远程目标IP)
# $3 = REMOTE_PORT  (远程目标端口)

# 检查必需参数是否定义
if [ -z "$1" ]; then
  echo "BIND_PORT not defined"
  exit 1
elif [ -z "$2" ]; then
  echo "REMOTE_IP not defined"
  exit 1
elif [ -z "$3" ]; then
  echo "REMOTE_PORT not defined"
  exit 1
fi

# 执行端口转发
socat "TCP-LISTEN:$1,fork,reuseaddr" "TCP:$2:$3"