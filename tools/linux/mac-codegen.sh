#!/usr/bin/env bash
# 用 Mac 上的 Xcode 生成 Linux 编不出来的两类代码（Xcode 构建时自动做），放进 tools/linux/generated/：
#   intentbuilderc：.intentdefinition → Intents 的类（ViewAppIntent、RefreshAllIntent…）
#   actool：.xcassets → 资源符号（ColorResource.blurTint 之类）
# 只有这些源文件改了才要重跑：linux-build.sh 先 `mac-codegen.sh --check`（按 sha256 比对），过期才调用。需要 Mac（MAC=user@host）装着 Xcode。
set -euo pipefail
cd "$(dirname "$0")/../.."
MAC=${MAC:-tj@100.123.211.12}
DEV=/Applications/Xcode.app/Contents/Developer/usr/bin  # intentbuilderc 经 xcrun 调用会丢参数
DEFS=(Shared/Intents/ViewApp.intentdefinition AltStore/Intents/Legacy/Intents.intentdefinition)
ASSETS=(AltStore/Core/Resources/Colors.xcassets AltStore/Resources/Assets.xcassets AltStore/Resources/Icons.xcassets)
out=tools/linux/generated
sums() { find "${DEFS[@]}" "${ASSETS[@]}" -type f -print0 | sort -z | xargs -0 sha256sum; }
[ "${1:-}" = --check ] && { [ "$(sums)" = "$(cat "$out/.sources.sha256" 2>/dev/null)" ]; exit; }
r=$(ssh "$MAC" mktemp -d)
trap 'ssh "$MAC" rm -rf "$r"' EXIT
tar cf - "${DEFS[@]}" "${ASSETS[@]}" | ssh "$MAC" "tar xf - -C $r"
ssh "$MAC" "set -e; cd $r; mkdir out car
  for f in ${DEFS[*]}; do $DEV/intentbuilderc generate -input $r/\$f -output $r/out -language Swift -swiftVersion 5.0 -visibility public -moduleName SideStore >/dev/null; done
  xcrun actool --compile car --platform iphoneos --minimum-deployment-target 15.0 --target-device iphone --target-device ipad \
    --bundle-identifier com.SideStore.SideStore --generate-swift-asset-symbol-extensions NO \
    --generate-swift-asset-symbols $r/out/GeneratedAssetSymbols.swift --output-format human-readable-text ${ASSETS[*]} >/dev/null"
rm -rf "$out" && mkdir -p "$out"
scp -q "$MAC:$r/out/*.swift" "$out/"
# 外壳是 SwiftPM，会定义 SWIFT_PACKAGE 而走 Bundle.module；Xcode 编的 app 走类所在的 bundle（LiveContainer 里是 SideStoreApp.framework）
sed -i 's/^#if SWIFT_PACKAGE$/#if false  \/\/ linux: 同 Xcode 构建，见 mac-codegen.sh/' "$out/GeneratedAssetSymbols.swift"
grep -q '^#if false  // linux' "$out/GeneratedAssetSymbols.swift" || { echo "GeneratedAssetSymbols.swift 格式变了，改 mac-codegen.sh"; exit 1; }
sums >"$out/.sources.sha256"
echo "已生成：$(ls "$out" | tr '\n' ' ')"
