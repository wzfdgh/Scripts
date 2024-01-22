#!/bin/sh
#LOVE FROM ATRI

dir=$(cd `dirname $0`; pwd)
api=https://api.github.com/repos/wzfdgh/ClashRepo/releases/latest
version=$(curl -s $api | awk -F '"' '/body/ {split($4, v, "-" ); print v[2]}')
#获取脚本路径及最新版本

checkbak() {
if [ -e /tmp/clash.bak ]; then
  mv /tmp/clash.bak $dir/clash
  echo 把原来的核心还给你了喵
else
  echo 没有找到备份核心喵
fi
}

update() {
case $(uname) in
  Darwin) os=darwin ;;
  *)
    case $(uname -o) in
      Android) os=android ;;
      *) os=linux ;;
    esac
    ;;
esac
#获取操作系统

arch=$(uname -m)
case $arch in
  mipsel_24kc) arch=mipsle-hardfloat ;;
  i386|x86) arch=386 ;;
  amd64|x86_64) arch=amd64 ;;
  arm64|aarch64|armv8) arch=arm64 ;;
  armv7|armv7l) arch=armv7 ;;
esac

if [ $arch = amd64 ]; then
  flags=$(awk '/^flags/ {print $0; exit}' /proc/cpuinfo)
  flags=" ${flags#*:} "
  has_flags() {
    for flag; do
      case "$flags" in
        *" $flag "*) :;;
        *) return 1;;
      esac
    done
  }
  determine_level() {
    level=0
    if has_flags lm cmov cx8 fpu fxsr mmx syscall sse2; then
      level=1
      if has_flags cx16 lahf_lm popcnt sse4_1 sse4_2 ssse3; then
        level=2
        if has_flags avx avx2 bmi1 bmi2 f16c fma abm movbe xsave; then
          level=3
          if has_flags avx512f avx512bw avx512cd avx512dq avx512vl; then
            level=4
          fi
        fi
      fi
    fi
  }
  determine_level
  case $level in
    [34]) arch=amd64 ;;
    *) arch=amd64-compatible ;;
  esac
fi
#获取架构-mips未完全包括
#arch=
#如需指定架构,请取消注释,填上你需要的架构,并把下面的试运行删去

gh=https://raw.githubusercontent.com/wzfdgh/ClashRepo/release/clash.meta-$os-$arch
gp=https://mirror.ghproxy.com/raw.githubusercontent.com/wzfdgh/ClashRepo/release/clash.meta-$os-$arch
js=https://cdn.jsdelivr.net/gh/wzfdgh/ClashRepo@release/clash.meta-$os-$arch
size=$(curl -s $api | grep clash.meta-$os-$arch\" -B 4 | awk -F ': ' '/size/ {split($2, s, ","); print s[1]}')

if [ "$(curl -s https://1.0.0.1/cdn-cgi/trace | awk -F '=' '/loc/ {print $2}')" = "CN" ]; then
  url=$gp
else
  url=$gh
fi
#url=$js
echo "$os $arch $version $size"
#显示系统与架构,核心版本,仓库文件大小

wget --show-progress -nv -O /tmp/clash $url

filesize=`stat /tmp/clash | awk -F ' ' '/Size/ {print $2}'`
if [ -z $filesize ]; then
  filesize=`stat /tmp/clash | awk -F '：' '/大小/ {print $2}'`
elif [ -z $filesize ]; then
  filesize=`stat /tmp/clash | awk -F '"' '{print $NF}'`
fi

if [ $size = $filesize ]; then
  if [ -f $dir/clash ]; then
    mv $dir/clash /tmp/clash.bak
  fi
  chmod 755 /tmp/clash
  mv /tmp/clash $dir/clash
  t=`$dir/clash -v | awk -F ' ' '/alpha/ {split($3, t, "-"); print t[2]}'`
#  echo $version > $dir/.clash-meta-version
#  echo 更新完成了喵
#  exit 0
#如果指定架构,把上面三句取消注释
#并把下面if
  if [ $t = $version ]; then
    echo $version > $dir/.clash-meta-version
    echo 更新完成了喵
    exit 0
  else
    rm $dir/clash
    echo 更新失败了喵,核心试运行没过
    checkbak
    exit 1
  fi
#到这个fi删掉
else
  rm /tmp/clash
  echo 更新失败了喵,核心文件大小校验失败
  checkbak
  exit 1
fi
}

if [ -f $dir/.clash-meta-version ] && [ $(cat $dir/.clash-meta-version) = $version ]; then
  echo 没有更新喵,还是等等吧
  exit 0
else
  update
fi
