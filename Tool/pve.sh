#!/bin/bash

js='/usr/share/pve-manager/js/pvemanagerlib.js'
pm='/usr/share/perl5/PVE/API2/Nodes.pm'
pjs='/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js'
apm='/usr/share/perl5/PVE/APLInfo.pm'
rc='/etc/rc.local'

#ivanhao/pvetools
web() {
echo "去除订阅提示"
if [ `grep "data.status.toLowerCase() !== 'active'" $pjs |wc -l` -gt 0 ];then
  sed -i "s/data.status.toLowerCase() !== 'active'/false/g" $pjs
else
  echo "无需去除"
fi

echo "Web管理页增加数据"
as
apt update && apt upgrade -y && apt install linux-cpupower lm-sensors -y
if [ `grep "cpu_tdp" $pm |wc -l` -eq 0 ];then
  cat << EOF > /tmp/js
	{
	    itemId: 'cputdp',
	    colspan: 2,
	    printBar: false,
	    title: gettext('CPU(s) TDP'),
	    textField: 'cpu_tdp',
	    renderer: function(value) {
	        var tdp = value.split(/[\n,]/g);
	        return \`\${tdp[2]} W\`;
	    }
	},
	{
	    itemId: 'sensorsjson',
	    colspan: 2,
	    printBar: false,
	    title: gettext('Temperature'),
	    textField: 'sensors_json',
	    renderer: function(value) {
	        value = JSON.parse(value);
	        const cpu0 = value['coretemp-isa-0000']['Package id 0']['temp1_input'].toFixed(1);
	        const nvme01 = value['nvme-pci-0500']['Sensor 1']['temp2_input'].toFixed(1);
	        const nvme02 = value['nvme-pci-0500']['Sensor 2']['temp3_input'].toFixed(1);
	        return \`CPU: \${cpu0}°C | NVME: \${nvme01}°C \${nvme02}°C\`;
	    }
	},
EOF

  cat << EOF > /tmp/pm
	\$res->{sensors_json} = \`sensors -j\`;
	\$res->{cpu_tdp} = \`turbostat --quiet -s PkgWatt -i 0.01 -n 1\`;
EOF

  l=`sed -n "/title: gettext('CPU(s)')/,/\}/=" $js |sed -n '$p'`
  sed -i ''$l' r /tmp/js' $js

  l=`sed -n '/pveversion/,/version_text/=' $pm |sed -n '$p'`
  sed -i ''$l' r /tmp/pm' $pm

  l=`sed -n '/widget.pveNodeStatus/,/height/=' $js |sed -n '$p'`
  h=`grep -3 'widget.pveNodeStatus' $js |awk -F': ' '/height/ {print $2}' |sed 's/.$//g'`
  let t=$h+50
  sed -i ''$l'c \ \ \ \ height:\ '$t',' $js

  chmod +s /usr/sbin/turbostat
  echo "添加开机启动项"
  rclocal
  if [ `grep "chmod +s /usr/sbin/turbostat" $rc |wc -l` -eq 0 ];then
    l=`sed -n "/exit 0/=" $rc`
    sed -i ''$l'i chmod +s /usr/sbin/turbostat' $rc
  else
    echo "无需添加"
  fi
  systemctl restart pveproxy
else
  echo "无需增加"
fi
}

as() {
echo "sources.list"
if [ `grep "https://mirrors.bfsu.edu.cn/debian/" /etc/apt/sources.list |wc -l` -eq 0 ];then
  cat << EOF > /etc/apt/sources.list
deb https://mirrors.bfsu.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
# deb-src https://mirrors.bfsu.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb https://mirrors.bfsu.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
# deb-src https://mirrors.bfsu.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://mirrors.bfsu.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware
# deb-src https://mirrors.bfsu.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware
deb https://mirrors.bfsu.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware
# deb-src https://mirrors.bfsu.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware
EOF
  sed -i "$d" /etc/apt/sources.list
else
  echo "无需更改"
fi

echo "ceph.list"
if [ `grep "https://mirrors.ustc.edu.cn/proxmox/debian/ceph-quincy" /etc/apt/sources.list.d/ceph.list |wc -l` -eq 0 ];then
  cat << EOF > /etc/apt/sources.list.d/ceph.list
deb https://mirrors.ustc.edu.cn/proxmox/debian/ceph-quincy bookworm no-subscription
EOF
  sed -i "$d" /etc/apt/sources.list.d/ceph.list
else
  echo "无需更改"
fi

echo "pve-no-subscription.list"
if [ `grep "https://mirrors.bfsu.edu.cn/proxmox/debian/pve" /etc/apt/sources.list.d/pve-no-subscription.list |wc -l` -eq 0 ];then
  cat << EOF > /etc/apt/sources.list.d/pve-no-subscription.list
deb https://mirrors.bfsu.edu.cn/proxmox/debian/pve bookworm pve-no-subscription
EOF
  sed -i "$d" /etc/apt/sources.list.d/pve-no-subscription.list
else
  echo "无需更改"
fi

if [ -f /etc/apt/sources.list.d/pve-enterprise.list ];then
  rm /etc/apt/sources.list.d/pve-enterprise.list
  echo "已删除企业源"
fi
}

apt() {
echo "补充软件包"
apt install ntfs-3g libgl1 libegl1 -y
apt install apcupsd
}

nupst() {
echo "配置 Network UPS Tool
apt install nut nut-cgi -y

}

ct() {
echo "更改 CT 镜像源"
if [ `grep "https://mirrors.bfsu.edu.cn/proxmox" $apm |wc -l` -eq 0 ];then
  sed -i 's|http://download.proxmox.com|https://mirrors.bfsu.edu.cn/proxmox|g' $apm
  systemctl restart pvedaemon
else
  echo "无需更改"
fi
}

grub() {
echo "更改grub"
if [ `grep 'GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt i915.enable_guc=3 i915.max_vfs=7 intel_pstate=passive cpufreq.default_governor=conservative"' /etc/default/grub |wc -l` -eq 0 ];then
  l=`sed -n "/GRUB_CMDLINE_LINUX_DEFAULT/=" /etc/default/grub`
  sed -i ''$l'c GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt i915.enable_guc=3 i915.max_vfs=7 intel_pstate=passive cpufreq.default_governor=conservative"' /etc/default/grub
  #https://www.intel.cn/content/www/cn/zh/support/articles/000093216/graphics/processor-graphics.html
  #i915.enable_gvt=1
else
  echo "无需更改"
fi
}

vgpu() {
#apt install proxmox-kernel-6.5 proxmox-kernel-6.5.13-5-pve-signed pve-headers-6.5.13-5-pve -y
#proxmox-boot-tool kernel pin 6.5.13-5-pve
apt update && apt install git mokutil dkms pve-headers-$(uname -r) sysfsutils -y
rm -rf /var/lib/dkms/i915-sriov-dkms*
rm -rf /usr/src/i915-sriov-dkms*
rm -rf ~/i915-sriov-dkms
KERNEL=$(uname -r); KERNEL=${KERNEL%-pve}
cd ~
git clone https://github.com/strongtz/i915-sriov-dkms.git
cd ~/i915-sriov-dkms
#cp -a ~/i915-sriov-dkms/dkms.conf{,.bak}
sed -i 's/"@_PKGBASE@"/"i915-sriov-dkms"/g' ~/i915-sriov-dkms/dkms.conf
sed -i 's/"@PKGVER@"/"'"$KERNEL"'"/g' ~/i915-sriov-dkms/dkms.conf
sed -i 's/ -j$(nproc)//g' ~/i915-sriov-dkms/dkms.conf
cat ~/i915-sriov-dkms/dkms.conf
#issue-151
if [ "$KERNEL" = "6.5.13-5" ]; then
#  mv ./drivers/gpu/drm/i915/display/intel_dp_mst.c ./drivers/gpu/drm/i915/display/intel_dp_mst.c.bak
  wget https://raw.githubusercontent.com/makazeu/i915-sriov-dkms/ffc23727f106995d89bc7ad32df4f1a3809ee737/drivers/gpu/drm/i915/display/intel_dp_mst.c -O ./drivers/gpu/drm/i915/display/intel_dp_mst.c
fi
dkms add .
dkms install -m i915-sriov-dkms -v $KERNEL -k $(uname -r) --force
dkms status
cd /usr/src/i915-sriov-dkms-$KERNEL
dkms status
grub
update-grub
update-initramfs -u -k all
echo "devices/pci0000:00/0000:00:02.0/sriov_numvfs = 3" > /etc/sysfs.conf
#proxmox-boot-tool kernel pin $(uname -r)
#proxmox-boot-tool kernel unpin
}

kernel() {
# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

function header_info {
  clear
  cat <<"EOF"
    __ __                     __   ________
   / //_/__  _________  ___  / /  / ____/ /__  ____ _____
  / ,< / _ \/ ___/ __ \/ _ \/ /  / /   / / _ \/ __ `/ __ \
 / /| /  __/ /  / / / /  __/ /  / /___/ /  __/ /_/ / / / /
/_/ |_\___/_/  /_/ /_/\___/_/   \____/_/\___/\__,_/_/ /_/

EOF
}
YW=$(echo "\033[33m")
RD=$(echo "\033[01;31m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
current_kernel=$(uname -r)
available_kernels=$(dpkg --list | grep 'kernel-.*-pve' | awk '{print $2}' | grep -v "$current_kernel" | sort -V)
header_info

function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

whiptail --backtitle "Proxmox VE Helper Scripts" --title "Proxmox VE Kernel Clean" --yesno "This will Clean Unused Kernel Images, USE AT YOUR OWN RISK. Proceed?" 10 68 || exit
if [ -z "$available_kernels" ]; then
  whiptail --backtitle "Proxmox VE Helper Scripts" --title "No Old Kernels" --msgbox "It appears there are no old Kernels on your system. \nCurrent kernel ($current_kernel)." 10 68
  echo "Exiting..."
  sleep 2
  clear
  exit
fi
  KERNEL_MENU=()
  MSG_MAX_LENGTH=0
while read -r TAG ITEM; do
  OFFSET=2
  ((${#ITEM} + OFFSET > MSG_MAX_LENGTH)) && MSG_MAX_LENGTH=${#ITEM}+OFFSET
  KERNEL_MENU+=("$TAG" "$ITEM " "OFF")
done < <(echo "$available_kernels")

remove_kernels=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Current Kernel $current_kernel" --checklist "\nSelect Kernels to remove:\n" 16 $((MSG_MAX_LENGTH + 58)) 6 "${KERNEL_MENU[@]}" 3>&1 1>&2 2>&3 | tr -d '"') || exit
[ -z "$remove_kernels" ] && {
  whiptail --backtitle "Proxmox VE Helper Scripts" --title "No Kernel Selected" --msgbox "It appears that no Kernel was selected" 10 68
  echo "Exiting..."
  sleep 2
  clear
  exit
}
whiptail --backtitle "Proxmox VE Helper Scripts" --title "Remove Kernels" --yesno "Would you like to remove the $(echo $remove_kernels | awk '{print NF}') previously selected Kernels?" 10 68 || exit

msg_info "Removing ${CL}${RD}$(echo $remove_kernels | awk '{print NF}') ${CL}${YW}old Kernels${CL}"
/usr/bin/apt purge -y $remove_kernels >/dev/null 2>&1
msg_ok "Successfully Removed Kernels"

msg_info "Updating GRUB"
/usr/sbin/update-grub >/dev/null 2>&1
msg_ok "Successfully Updated GRUB"
msg_info "Exiting"
sleep 2
msg_ok "Finished"
}

rclocal() {
echo "启用 rc.local"
if [ -e "$rc" ];then
  echo "无需更改"
else
  cat << EOF > /etc/rc.local
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

exit 0
EOF

  chmod +x /etc/rc.local
  systemctl start rc-local
fi
}

lr() {
echo "删除 local-lvm"
lvremove pve/data
lvextend -l +100%FREE -r pve/root
echo "请在 web 删除 local-lvm 储存 并编辑 local 的内容"
}

web
ct
