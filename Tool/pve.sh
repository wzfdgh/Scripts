#!/bin/bash
#ivanhao/pvetools

js='/usr/share/pve-manager/js/pvemanagerlib.js'
pm='/usr/share/perl5/PVE/API2/Nodes.pm'
pjs='/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js'

sub() {
echo "去除订阅提示"
if [ `grep "data.status.toLowerCase() !== 'active'" $pjs |wc -l` -gt 0 ];then
  sed -i "s/data.status.toLowerCase() !== 'active'/false/g" $pjs
else
  echo "无需更改"
fi
}

web() {
echo "Web管理页增加数据"
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
else
  echo "无需更改"
fi
}

as() {
echo "sources.list"
if [ `grep "https://mirrors.bfsu.edu.cn/debian/" /etc/apt/sources.list |wc -l` -gt 0 ];then
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
if [ `grep "https://mirrors.ustc.edu.cn/proxmox/debian/ceph-quincy" /etc/apt/sources.list.d/ceph.list|wc -l` -gt 0 ];then
  cat << EOF > /etc/apt/sources.list.d/ceph.list
deb https://mirrors.ustc.edu.cn/proxmox/debian/ceph-quincy bookworm no-subscription
EOF
  sed -i "$d" /etc/apt/sources.list.d/ceph.list
else
  echo "无需更改"
fi

echo "pve-no-subscription.list"
if [ `grep "https://mirrors.bfsu.edu.cn/proxmox/debian/pve" /etc/apt/sources.list.d/pve-no-subscription.list |wc -l` -gt 0];then
  cat << EOF > /etc/apt/sources.list.d/pve-no-subscription.list
deb https://mirrors.bfsu.edu.cn/proxmox/debian/pve bookworm pve-no-subscription
EOF
  sed -i "$d" /etc/apt/sources.list.d/pve-no-subscription.list
else
  echo "无需更改"
fi

if [ -f /etc/apt/sources.list.d/pve-subscription.list ];then
  rm /etc/apt/sources.list.d/pve-subscription.list
  echo "已删除企业源"
fi
}

grub() {
if [ `grep 'GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt i915.enable_gvt=1 intel_pstate=passive cpufreq.default_governor=conservative"' /etc/default/grub |wc -l` -gt 0 ];then
  l=`sed -n "/GRUB_CMDLINE_LINUX_DEFAULT/=" /etc/default/grub`
  sed -i ''$l'c GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt i915.enable_gvt=1 intel_pstate=passive cpufreq.default_governor=conservative"' /etc/default/grub
else
  echo "无需更改"
fi
}

sub
web
systemctl restart pveproxy
