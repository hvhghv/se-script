# se-script
分享一些个人编写（AI编写）或改良的脚本

## 用户管理
[脚本](./linux-user-manager/user-manager.sh)

- 添加好可执行权限后直接运行即可
- 需要Root权限

### cui菜单如下
```
"======================================="
"      Linux 用户管理系统"
"======================================="
"  1. 创建普通用户"
"  2. 创建管理员用户"
"  3. 修改用户密码"
"  4. 列出所有用户"
"  5. 删除用户"
"  6. 退出"
======================================="
```

## 防火墙
[脚本](./linux-firewall/firewall-cui.sh)

通过修改iptables input链规则来放行传入端口与网段

### 警告
一旦执行该脚本就会立即清空iptables input链，请确保iptables input链为空或者仅包含本脚本添加的规则，以免网络发送异常

执行`sudo iptables -S INPUT`查看iptables input链

### 原理
1. 启动脚本后会将iptables input链清空
2. 创建/etc/iptables-manager文件夹，用于存放规则文件
3. 重新加载/etc/iptables-manager下的规则到iptables input链
4. 启动cui 菜单界面
5. 保存新的规则并添加systemctl服务开机自启动
6. 重新加载规则到iptables input链

### CUI 菜单界面

```
"=================================================="
"           iptables 防火墙管理 (黑名单模式)"
"=================================================="
" 1. 放行TCP/UDP端口"
" 2. 取消放行端口"
" 3. 放行IP网段"
" 4. 取消放行IP网段"
" 5. 查看当前规则"
" 6. 保存规则并持久化"
" 0. 退出"
"=================================================="
```

### 运行方式
- 添加好可执行权限后直接运行即可

## systemctl服务模版
[脚本路径](./systemctl-service-template)

快速创建systemctl自启动服务

### 使用方式
1. (非必须)复制整个模版文件夹到随便一个地方并进入复制后的文件夹
2. 重命名`./system/conf`为`xxx`(`xxx`自己随便起一个名)
3. 打开`./system/xxx`, 根据里面的注释来修改（一般只需修改`Type`，`WorkingDirectory`，`ExecStart`就行）
4. (非必须) 如需要添加环境变量，则往`./env/env`里添加环境变量就行
5. 运行`./ser.sh`即可（会自动执行systemctl enable xxx; systemctl start xxx）
6. (非必须) 可通过`systemctl status xxx`查看服务状态
7. (非必须) 后续若要修改服务内容，先执行`./ser.sh clean`, 之后重复3-6即可
8. (非必须) 若需要删除该服务, 执行`./ser.sh clean`

### 原理
1. 获取`./system`文件夹中第一个文件名记为`xxx`
2. 执行 cp `./env/env` `/etc/conf.d/xxx`
3. 复制`./system/xxx`到`/etc/systemd/system/xxx.service`
4. 追加下述内容到`/etc/systemd/system/xxx.service`
```
"EnvironmentFile=/etc/conf.d/xxx.conf"
"[Install]"
"WantedBy=multi-user.target"
```
5. 执行`systemctl enable xxx` 与 `systemctl start xxx`

6. 执行`./ser.sh clean`时，会执行下列命令
    - `systemctl disable xxx`
    - `systemctl stop xxx`
    - `rm /etc/systemd/system/xxx.service`
    - `rm /etc/conf.d/xxx.conf`

### 端口转发

[脚本](./linux-socat-forward/port-forward.sh)

快速创建socat端口转发服务
需要安装好socat (注: `sudo apt install socat`)

运行方式:

`./port-forward.sh <本地端口> <远程地址> <远程端口>`

示例:

`./port-forward.sh 80 192.168.1.1 8080`
- 80 -> 192.168.1.1:8080
- 绑定`0.0.0.0:80`端口，将80端口的请求转发到`192.168.1.1:8080`

## 简化screen操作
[脚本](./linux-screen-tool/screen-tool.sh)

用于简化screen操作

### 用法:
- screen-tool.sh write <name> <command>  向名称为name的screen终端写入命令（不存在则创建）（自动添加换行符\n）
- screen-tool.sh read <name>             读取名称为name的screen终端当前所有输出
- screen-tool.sh del <name>              关闭名称为name的screen终端
- screen-tool.sh ls                      列出所有screen终端
- screen-tool.sh [-h|--help]             显示此帮助信息

### 示例:
- screen-tool.sh write myterm "ls -l"
- screen-tool.sh read myterm
- screen-tool.sh del myterm


### screen-tool.sh write
向指定的screen终端写入命令并自动添加换行符\n 若不存在该终端则会后台自动创建

### screen-tool.sh read
读取名称为name的screen终端当前所有输出

