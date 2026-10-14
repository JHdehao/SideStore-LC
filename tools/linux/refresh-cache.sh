#!/usr/bin/env bash
# 从一个 Mac / CI 出的 SideStore.ipa 里取 Linux 上做不出来的部分，放进 build/linux/cache/：
#   整个 SideStore.app 去掉主程序和签名——storyboard/xib 编译结果、Assets.car、Core Data 模型、App Intents 元数据、
#   小组件 AltWidgetExtension.appex、SideBackup.ipa、依赖的资源包。linux-build.sh 往里放新编的主程序。
# 不给参数就下载 JHdehao/SideStore-LC 的 nightly。只有改了资源/小组件/App Intents 才需要换一个新包重取。
# 用法: tools/linux/refresh-cache.sh [SideStore.ipa]
set -euo pipefail
cd "$(dirname "$0")/../.."
C=build/linux/cache
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
if [ $# -gt 0 ]; then ipa=$(realpath "$1"); else
  ipa=$t/SideStore.ipa
  curl -fsSL https://github.com/JHdehao/SideStore-LC/releases/download/nightly/SideStore.ipa -o "$ipa"
fi
unzip -q "$ipa" -d "$t"
A=$t/Payload/SideStore.app
# 这些资源来自哪个提交：Linux 出的包记在 SSResourcesCommit（资源本身是旧缓存），Mac/CI 包取版本号里的提交
commit=$(python3 -c '
import plistlib,sys; d=plistlib.load(open(sys.argv[1],"rb"))
print(d.get("SSResourcesCommit") or d["CFBundleShortVersionString"].split("+")[1].removesuffix("-dirty"))' "$A/Info.plist")
git cat-file -e "$commit^{commit}" 2>/dev/null || { echo "本仓库里没有提交 $commit，换个包"; exit 1; }
rm -rf "$A/SideStore" "$A/_CodeSignature" "$A/embedded.mobileprovision"
rm -rf $C && mkdir -p $C && mv "$A" $C/SideStore.app
echo "$commit" >$C/commit
echo "缓存已更新（资源来自提交 $commit）"
