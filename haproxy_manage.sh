#!/bin/bash

# 检查是否有超级用户权限
if [ "$(id -u)" -ne 0 ]; then
    echo "请以 root 用户运行脚本"
    exit 1
fi

# 安装 HAProxy
install_haproxy() {
    echo "正在安装 HAProxy ..."
    apt update && apt upgrade -y
    apt install -y haproxy
    if [ $? -eq 0 ]; then
        echo "HAProxy 安装成功"
    else
        echo "HAProxy 安装失败"
        exit 1
    fi
}

# 配置 HAProxy
configure_haproxy() {
    echo "请选择配置模式"
    echo "1) 单一模式（单一后端）"
    echo "2) 负载均衡模式"
    echo "3) 故障转移模式"
    read -p "请输入选择的模式 [1/2/3]: " mode

    case $mode in
        1)
            echo "配置单一模式"
            read -p "请输入后端服务的 IP 或域名: " backend_ip
            read -p "请输入后端服务的端口号: " backend_port
            read -p "请输入监听端口号: " listen_port
            echo "frontend http_front" >> /etc/haproxy/haproxy.cfg
            echo "    bind *:$listen_port" >> /etc/haproxy/haproxy.cfg
            echo "    default_backend http_back" >> /etc/haproxy/haproxy.cfg
            echo "backend http_back" >> /etc/haproxy/haproxy.cfg
            echo "    server server1 $backend_ip:$backend_port check" >> /etc/haproxy/haproxy.cfg
            ;;
        2)
            echo "配置负载均衡模式"
            read -p "请输入监听端口号: " listen_port
            read -p "请输入多个后端服务的 IP 或域名，空格分隔: " backend_ips
            read -p "请输入后端服务端口号: " backend_port
            echo "frontend http_front" >> /etc/haproxy/haproxy.cfg
            echo "    bind *:$listen_port" >> /etc/haproxy/haproxy.cfg
            echo "    default_backend http_back" >> /etc/haproxy/haproxy.cfg
            echo "backend http_back" >> /etc/haproxy/haproxy.cfg
            echo "    balance roundrobin" >> /etc/haproxy/haproxy.cfg
            for ip in $backend_ips; do
                echo "    server $ip $ip:$backend_port check" >> /etc/haproxy/haproxy.cfg
            done
            ;;
        3)
            echo "配置故障转移模式"
            read -p "请输入监听端口号: " listen_port
            read -p "请输入多个后端服务的 IP 或域名，空格分隔: " backend_ips
            read -p "请输入后端服务端口号: " backend_port
            echo "frontend http_front" >> /etc/haproxy/haproxy.cfg
            echo "    bind *:$listen_port" >> /etc/haproxy/haproxy.cfg
            echo "    default_backend http_back" >> /etc/haproxy/haproxy.cfg
            echo "backend http_back" >> /etc/haproxy/haproxy.cfg
            echo "    mode tcp" >> /etc/haproxy/haproxy.cfg
            echo "    option tcp-check" >> /etc/haproxy/haproxy.cfg
            for ip in $backend_ips; do
                echo "    server $ip $ip:$backend_port check fall 3 rise 2" >> /etc/haproxy/haproxy.cfg
            done
            ;;
        *)
            echo "无效的选择"
            exit 1
            ;;
    esac

    echo "规则已添加，重新加载 HAProxy 配置..."
    systemctl reload haproxy
    echo "HAProxy 配置已更新"
}

# 启动 HAProxy 服务
start_haproxy() {
    systemctl start haproxy
    systemctl enable haproxy
    echo "HAProxy 服务已启动并设置为开机自启"
}

# 查看 HAProxy 服务状态
status_haproxy() {
    systemctl status haproxy
}

# 停止 HAProxy 服务
stop_haproxy() {
    systemctl stop haproxy
    echo "HAProxy 服务已停止"
}

# 重启 HAProxy 服务
restart_haproxy() {
    systemctl restart haproxy
    echo "HAProxy 服务已重启"
}

# 删除 HAProxy 程序
remove_haproxy() {
    systemctl stop haproxy
    apt remove --purge haproxy -y
    echo "HAProxy 已卸载"
}

# 检查 VPS 系统信息
check_vps() {
    echo "检查 VPS 系统信息..."
    uname -a
    free -h
    df -h
}

# 显示当前 HAProxy 运行中的配置规则
show_running_haproxy_rules() {
    echo "当前 HAProxy 运行中的配置规则："
    echo "--------------------"
    haproxy -vv
    echo "--------------------"
    ps aux | grep haproxy
    echo "--------------------"
    echo "HAProxy stats 页面： http://your-server-ip:9000/stats"
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if ss -tuln | grep ":$port" > /dev/null; then
        return 1  # 端口被占用
    else
        return 0  # 端口未被占用
    fi
}

# 按端口添加新的规则
add_rule() {
    while true; do
        read -p "请输入要监听的端口号: " listen_port

        # 检查端口是否被占用
        check_port $listen_port
        if [ $? -eq 1 ]; then
            echo "端口 $listen_port 已被占用，请选择另一个端口。"
        else
            break  # 端口可用，跳出循环
        fi
    done

    read -p "请输入后端服务的 IP 或域名: " backend_ip
    read -p "请输入后端服务的端口号: " backend_port
    read -p "请输入服务备注（可选）: " service_note

    # 检查是否是多个后端服务
    read -p "是否有多个后端服务? (y/n): " multiple_services

    if [ "$multiple_services" == "y" ]; then
        read -p "请输入多个后端服务（IP 或域名），用空格分隔: " backend_ips
        echo "请选择负载均衡模式或故障转移模式"
        echo "1) 负载均衡"
        echo "2) 故障转移"
        read -p "请输入选择的模式 [1/2]: " mode

        case $mode in
            1)
                echo "配置负载均衡模式"
                echo "frontend http_front" >> /etc/haproxy/haproxy.cfg
                echo "    bind *:$listen_port" >> /etc/haproxy/haproxy.cfg
                echo "    default_backend http_back" >> /etc/haproxy/haproxy.cfg
                echo "backend http_back" >> /etc/haproxy/haproxy.cfg
                echo "    balance roundrobin" >> /etc/haproxy/haproxy.cfg
                for ip in $backend_ips; do
                    echo "    # $service_note" >> /etc/haproxy/haproxy.cfg
                    echo "    server $ip $ip:$backend_port check" >> /etc/haproxy/haproxy.cfg
                done
                ;;
            2)
                echo "配置故障转移模式"
                echo "frontend http_front" >> /etc/haproxy/haproxy.cfg
                echo "    bind *:$listen_port" >> /etc/haproxy/haproxy.cfg
                echo "    default_backend http_back" >> /etc/haproxy/haproxy.cfg
                echo "backend http_back" >> /etc/haproxy/haproxy.cfg
                echo "    mode tcp" >> /etc/haproxy/haproxy.cfg
                echo "    option tcp-check" >> /etc/haproxy/haproxy.cfg
                for ip in $backend_ips; do
                    echo "    # $service_note" >> /etc/haproxy/haproxy.cfg
                    echo "    server $ip $ip:$backend_port check fall 3 rise 2" >> /etc/haproxy/haproxy.cfg
                done
                ;;
            *)
                echo "无效的选择"
                exit 1
                ;;
        esac
    else
        echo "配置单一后端服务"
        echo "frontend http_front" >> /etc/haproxy/haproxy.cfg
        echo "    bind *:$listen_port" >> /etc/haproxy/haproxy.cfg
        echo "    default_backend http_back" >> /etc/haproxy/haproxy.cfg
        echo "backend http_back" >> /etc/haproxy/haproxy.cfg
        echo "    # $service_note" >> /etc/haproxy/haproxy.cfg
        echo "    server server1 $backend_ip:$backend_port check" >> /etc/haproxy/haproxy.cfg
    fi

    echo "规则已添加，重新加载 HAProxy 配置..."
    systemctl reload haproxy
    echo "HAProxy 配置已更新"
}

# 按端口删除规则
delete_rule() {
    read -p "请输入要删除规则的端口号或备注: " identifier
    if [[ "$identifier" =~ ^[0-9]+$ ]]; then
        echo "删除端口 $identifier 的规则..."
        sed -i "/frontend .*:$identifier/,/backend .*:/d" /etc/haproxy/haproxy.cfg
    else
        echo "删除备注为 $identifier 的规则..."
        sed -i "/# $identifier/d" /etc/haproxy/haproxy.cfg
    fi
    systemctl reload haproxy
    echo "规则已删除，HAProxy 配置已更新"
}

# 导出配置到文件
export_config() {
    read -p "请输入导出文件名（如：haproxy_backup.cfg）: " export_file
    cp /etc/haproxy/haproxy.cfg "$export_file"
    echo "配置已导出到 $export_file"
}

# 导入配置文件
import_config() {
    read -p "请输入导入的配置文件路径: " import_file
    if [ -f "$import_file" ]; then
        cp "$import_file" /etc/haproxy/haproxy.cfg
        systemctl reload haproxy
        echo "配置已从 $import_file 导入并重新加载"
    else
        echo "文件不存在"
    fi
}

# 主菜单交互
while true; do
    echo "--------------------------------"
    echo "欢迎使用 HAProxy 配置脚本"
    echo "请选择操作："
    echo "1) 安装 HAProxy"
    echo "2) 配置 HAProxy"
    echo "3) 按端口添加新规则"
    echo "4) 按端口或备注删除规则"
    echo "5) 导出 HAProxy 配置"
    echo "6) 导入 HAProxy 配置"
    echo "7) 查看 HAProxy 服务状态"
    echo "8) 启动 HAProxy 服务"
    echo "9) 停止 HAProxy 服务"
    echo "10) 重启 HAProxy 服务"
    echo "11) 删除 HAProxy 安装"
    echo "12) 检查 VPS 信息"
    echo "13) 显示当前 HAProxy 运行配置"
    echo "14) 退出"
    read -p "请输入你的选择 [1-14]: " choice

    case $choice in
        1)
            install_haproxy
            ;;
        2)
            configure_haproxy
            ;;
        3)
            add_rule
            ;;
        4)
            delete_rule
            ;;
        5)
            export_config
            ;;
        6)
            import_config
            ;;
        7)
            status_haproxy
            ;;
        8)
            start_haproxy
            ;;
        9)
            stop_haproxy
            ;;
        10)
            restart_haproxy
            ;;
        11)
            remove_haproxy
            ;;
        12)
            check_vps
            ;;
        13)
            show_running_haproxy_rules
            ;;
        14)
            echo "退出脚本"
            exit 0
            ;;
        *)
            echo "无效的选择，请重新选择"
            ;;
    esac
done
