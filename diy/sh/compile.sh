#!/bin/bash
set -x
# chown -R 1000:1000 /builder

# 添加并安装源
cp -rdp /builder/git_workspace/feeds/ /builder/custom_feeds
echo "src-link custom /builder/custom_feeds" >> feeds.conf.default
./scripts/feeds update -a
./scripts/feeds install -a

cp -rf custom.config .config
make defconfig

# 获取编译的包列表
cd /builder/git_workspace
if [[ $1 == "true" ]];then
  ipk_list=($(git log --name-status | grep -oP '(?<=feeds/)[-\w]+(?=/)' | sort | uniq))
else
  ipk_list=($(git log -1 --name-status | grep -oP '(?<=feeds/)[-\w]+(?=/)' | sort | uniq))
fi
cd /builder/

# 编译
make package/feeds/luci/luci-base/compile -j2
# for ipk in ${ipk_list[@]}
# {
#   echo "start compile $ipk"
#   make package/feeds/custom/$ipk/compile -j2    || make package/$ipk/compile V=s >> error/error_$ipk.log 2>&1 
# }
make package/feeds/custom/brook/compile -j2
target_path=`find bin/packages -name custom`

# 解决单编译kmod 导致package不存在问题
if [[ ${target_path} == "" ]];then
  make package/feeds/custom/tcping/compile -j2
  target_path=`find bin/packages -name custom`
fi

# 移动Kmod
function mvKmod(){
  if [[ `find bin/targets -name $1` ]];then
    for ipk in `find bin/targets -name $1`; do
      mv $ipk `find bin/packages -name custom`
    done
  fi
}

mvKmod "kmod-r8125*.ipk"

# 删除旧的ipk
if [[ $1 == "true" ]];then
  rm -rf /builder/packages/*
else
  for newipk in `ls $target_path`; do
    rm -f /builder/packages/${newipk%%_*}_*
  done
fi

# 生成索引
mv /builder/packages/* $target_path
make package/index >> /dev/null 2>&1 
mv $target_path/* /builder/packages

