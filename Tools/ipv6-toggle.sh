#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

function header_info() {
  clear
  cat <<"EOF"
    ____  __  _______ __________  ____  __  ____________  ______
   / __ \/ / / / ___// ____/ __ \/ __ \/ / / / ____/ __ \/ ____/
  / /_/ / / / /\__ \/ /   / / / / / / / /_/ / __/ / /_/ / __/
 / ____/ /_/ /___/ / /___/ /_/ / /_/ / __  / /___/ _, _/ /___
/_/    \____//____/\____/_____/_____/_/ /_/_____/_/ |_/_____/

    ______________  ______  ______
   /_  __/  _/ __ \/ __ \ \/ / __ \
    / /  / // / / / / / /\  / / / /
   / / _/ // /_/ / /_/ / / / /_/ /
  /_/ /___/_____/_____/_/ /_____/

EOF
}
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
CM='\xE2\x9C\x94\033'
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
YW=$(echo "\033[33m")
header_info
echo "Loading..."

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
    echo -e "${RD}Error: This script must be run as root${CL}"
    exit 1
fi

# 检查当前 IPv6 状态
check_ipv6_status() {
    local status="enabled"
    
    # 检查 sysctl 配置
    if [[ -f /etc/sysctl.d/99-disable-ipv6.conf ]]; then
        if grep -q "net.ipv6.conf.all.disable_ipv6 = 1" /etc/sysctl.d/99-disable-ipv6.conf 2>/dev/null; then
            status="disabled"
        fi
    fi
    
    # 检查 grub 配置
    if [[ -f /etc/default/grub ]]; then
        if grep -q "ipv6.disable=1" /etc/default/grub 2>/dev/null; then
            status="disabled"
        fi
    fi
    
    echo "$status"
}

# 禁用 IPv6
disable_ipv6() {
    header_info
    echo -e "${BL}[Info]${GN} Disabling IPv6...${CL}\n"
    
    # 创建 sysctl 配置文件
    cat > /etc/sysctl.d/99-disable-ipv6.conf << 'EOF'
# Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    
    # 应用 sysctl 配置
    sysctl --system > /dev/null 2>&1
    
    # 修改 GRUB 配置
    if [[ -f /etc/default/grub ]]; then
        if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1 /' /etc/default/grub
        fi
        if grep -q "GRUB_CMDLINE_LINUX=" /etc/default/grub; then
            if ! grep -q "ipv6.disable=1" /etc/default/grub; then
                sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="ipv6.disable=1 /' /etc/default/grub
            fi
        fi
        update-grub > /dev/null 2>&1
    fi
    
    # 修改 hosts 文件，注释掉 IPv6 条目
    if [[ -f /etc/hosts ]]; then
        sed -i 's/^::1/#::1/' /etc/hosts
        sed -i 's/^ff02::1/#ff02::1/' /etc/hosts
        sed -i 's/^ff02::2/#ff02::2/' /etc/hosts
    fi
    
    echo -e "${GN}IPv6 has been disabled successfully.${CL}"
    echo -e "${YW}Note: A system reboot is required for all changes to take full effect.${CL}"
}

# 启用 IPv6
enable_ipv6() {
    header_info
    echo -e "${BL}[Info]${GN} Enabling IPv6...${CL}\n"
    
    # 删除 sysctl 配置文件
    if [[ -f /etc/sysctl.d/99-disable-ipv6.conf ]]; then
        rm -f /etc/sysctl.d/99-disable-ipv6.conf
    fi
    
    # 重新启用 IPv6
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 > /dev/null 2>&1
    sysctl -w net.ipv6.conf.default.disable_ipv6=0 > /dev/null 2>&1
    sysctl -w net.ipv6.conf.lo.disable_ipv6=0 > /dev/null 2>&1
    
    # 修改 GRUB 配置
    if [[ -f /etc/default/grub ]]; then
        sed -i 's/ipv6.disable=1 //g' /etc/default/grub
        sed -i 's/ ipv6.disable=1//g' /etc/default/grub
        update-grub > /dev/null 2>&1
    fi
    
    # 恢复 hosts 文件
    if [[ -f /etc/hosts ]]; then
        sed -i 's/^#::1/::1/' /etc/hosts
        sed -i 's/^#ff02::1/ff02::1/' /etc/hosts
        sed -i 's/^#ff02::2/ff02::2/' /etc/hosts
    fi
    
    echo -e "${GN}IPv6 has been enabled successfully.${CL}"
    echo -e "${YW}Note: A system reboot is required for all changes to take full effect.${CL}"
}

# 主菜单
main_menu() {
    local current_status=$(check_ipv6_status)
    
    while true; do
        header_info
        echo -e "${BL}Current IPv6 Status: ${GN}${current_status}${CL}\n"
        
        local choice
        choice=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
            --title "IPv6 Toggle Tool" \
            --menu "\nSelect an option:\n" \
            15 60 4 \
            "1" "Disable IPv6" \
            "2" "Enable IPv6" \
            "3" "Check Current Status" \
            "4" "Exit" 3>&1 1>&2 2>&3) || exit
        
        case $choice in
            1)
                if [[ "$current_status" == "disabled" ]]; then
                    whiptail --msgbox "IPv6 is already disabled!" 8 40
                else
                    if whiptail --yesno "This will disable IPv6 on your system.\n\nA reboot will be required.\n\nContinue?" 12 50; then
                        disable_ipv6
                        current_status="disabled"
                        whiptail --msgbox "IPv6 has been disabled.\n\nPlease reboot your system for changes to take full effect." 10 50
                    fi
                fi
                ;;
            2)
                if [[ "$current_status" == "enabled" ]]; then
                    whiptail --msgbox "IPv6 is already enabled!" 8 40
                else
                    if whiptail --yesno "This will enable IPv6 on your system.\n\nA reboot will be required.\n\nContinue?" 12 50; then
                        enable_ipv6
                        current_status="enabled"
                        whiptail --msgbox "IPv6 has been enabled.\n\nPlease reboot your system for changes to take full effect." 10 50
                    fi
                fi
                ;;
            3)
                local status_msg
                if [[ "$current_status" == "enabled" ]]; then
                    status_msg="IPv6 is currently ENABLED on this system."
                else
                    status_msg="IPv6 is currently DISABLED on this system."
                fi
                whiptail --msgbox "$status_msg" 8 50
                ;;
            4)
                exit 0
                ;;
        esac
    done
}

main_menu
