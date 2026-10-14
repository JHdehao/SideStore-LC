#!/usr/bin/env bash
# 在 Linux 上编 SideStore 的无签名 IPA（不用 Mac / GitHub Actions），产物跟 CI 的 SideStore.ipa 同结构。
#
#   tools/linux-build.sh [--debug] [-n N] [-o OUT.ipa]
#
# 只编 SideStore 主程序（全部 Swift，SwiftPM 外壳 tools/linux/Package.swift）；Linux 做不出来的东西取自参考包缓存：
# storyboard/xib（ibtool）、Assets.car（actool）、Core Data 模型（momc）、App Intents 元数据、小组件、SideBackup.ipa。
# 改了这些对应的源文件时会提醒，需要拿 Mac/CI 新出的包跑 tools/linux/refresh-cache.sh。
# 版本号 0.7.0-<日期>.<N>+<提交>（同 CI 格式，-n 默认 1）。
# 需要：~/data/sdk/swift/env.sh（Swift 6.2.3 + xtool）、~/data/sdk/swift-sdks/darwin.artifactbundle（来自 Xcode 26.2）。
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
CONF=release N=1 OUT=build/linux/SideStore.ipa
while [ $# -gt 0 ]; do
  case "$1" in
    --debug) CONF=debug ;;
    -n) N=$2; shift ;;
    -o) OUT=$2; shift ;;
    *) sed -n '2,10p' "$0"; exit 2 ;;
  esac
  shift
done
# shellcheck source=/dev/null
. "${SWIFT_ENV:-$HOME/data/sdk/swift/env.sh}"
SDKS=${SWIFT_SDKS:-$HOME/data/sdk/swift-sdks}
MIRRORS=${SPM_MIRRORS:-$HOME/data/sdk/spm-mirrors}
B=build/linux P=build/linux/pkg C=build/linux/cache
RESOLVED=AltStore.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
mkdir -p $B

# 1. Xcode 构建时生成的代码（Intents 类、资源符号）：对应源文件改了就用 Mac 重新生成
tools/linux/mac-codegen.sh --check || { echo "== .intentdefinition/.xcassets 改过，用 Mac 重新生成代码"; tools/linux/mac-codegen.sh; }

# 2. 参考包缓存：没有就从 nightly 下载；缓存之后改过的资源/小组件/App Intents 要提醒（不拦，包照出，只是那部分是旧的）
[ -d $C/SideStore.app ] || tools/linux/refresh-cache.sh
cc=$(cat $C/commit)
changed=$(git diff --name-only "$cc" -- Shared AltStore SideStore AltWidget SideBackup "$RESOLVED" 2>/dev/null |
  grep -vE '\.swift$' ; git diff --name-only "$cc" -- AltWidget SideBackup Shared 'AltStore/Intents/App Intents' 'SideStore/Intents' 2>/dev/null) || true
[ -z "$changed" ] || { echo "!! 以下文件比缓存（提交 $cc）改过，包里对应部分还是旧的；要更新拿 Mac/CI 新包跑 tools/linux/refresh-cache.sh：" >&2
  sort -u <<<"$changed" | sed 's/^/   /' >&2; }

# 3. SwiftPM 外壳：源码目录软链回仓库，依赖版本照 Package.resolved
mkdir -p $P/Sources/SideStore $P/deps
cp tools/linux/Package.swift $P/Package.swift
[ -f $P/Package.resolved ] && cmp -s "$RESOLVED" $P/Package.resolved || cp "$RESOLVED" $P/Package.resolved
for d in Shared AltStore SideStore; do ln -sfn ../../../../../$d $P/Sources/SideStore/$d; done
ln -sfn ../../../../../tools/linux/generated $P/Sources/SideStore/Generated
# 清单按宿主判断平台的依赖：检出同一提交，把判断改成 iOS 下的结果（用 xcframework / 系统 Compression，不碰宿主的库）
patch_dep() {  # 名字 identity 原判断行 改成
  local name=$1 id=$2 from=$3 to=$4 d=$P/deps/$1 rev url src
  rev=$(python3 -c 'import json,sys;print(next(p["state"]["revision"] for p in json.load(open(sys.argv[1]))["pins"] if p["identity"]==sys.argv[2]))' "$RESOLVED" "$id")
  [ "$(cat "$d/.linux-version" 2>/dev/null)" = "$rev" ] && return
  url=$(python3 -c 'import json,sys;print(next(p["location"] for p in json.load(open(sys.argv[1]))["pins"] if p["identity"]==sys.argv[2]))' "$RESOLVED" "$id")
  src=$url; [ -d "$MIRRORS/$name.git" ] && src=$MIRRORS/$name.git
  rm -rf "$d" && git clone -q --no-checkout "$src" "$d"
  git -C "$d" -c advice.detachedHead=false checkout -q "$rev"
  grep -qxF "$from" "$d/Package.swift" || { echo "$name 清单的平台判断变了（找不到 '$from'），改 linux-build.sh"; exit 1; }
  sed -i "s/^$(sed 's/[][\.*^$/]/\\&/g' <<<"$from")\$/$to/" "$d/Package.swift"
  echo "$rev" >"$d/.linux-version"
}
patch_dep AnisetteKit anisettekit '#if canImport(Darwin)' '#if true'
patch_dep GSACryptoKit gsacryptokit '#if canImport(Darwin)' '#if true'
patch_dep CodeSignKit codesignkit '#if canImport(Darwin)' '#if true'
patch_dep ZIPFoundation zipfoundation '#if canImport(Compression)' '#if true'
# 清单里的排除列表和 deps/ 覆盖是按目录现算的，SwiftPM 却按清单文本缓存解析结果：把这些输入的哈希写进清单
{ ls $P/deps; find -L Shared AltStore SideStore -type f | sort; } | sha256sum | sed 's#^#// 输入: #; s# .*##' >>$P/Package.swift
if [ -d "$MIRRORS" ]; then
  mkdir -p $P/.swiftpm/configuration
  python3 - "$RESOLVED" "$MIRRORS" >$P/.swiftpm/configuration/mirrors.json <<'PY'
import json, os, sys
m = []
for p in json.load(open(sys.argv[1]))["pins"]:
    local = os.path.join(sys.argv[2], os.path.basename(p["location"]).removesuffix(".git") + ".git")
    if os.path.isdir(local):
        m.append({"original": p["location"], "mirror": local})
print(json.dumps({"object": m, "version": 1}, indent=1))
PY
fi

# 4. 编译。OpenSSL.xcframework 里是 OpenSSL.framework，C 代码写 <openssl/ssl.h>：Mac 文件系统不分大小写能找到，
#    Linux 上给它一个小写名的框架软链
(cd $P && swift package resolve >/dev/null)
ossl=$(ls -d $P/.build/artifacts/remotepairingkit/OpenSSL/OpenSSL.xcframework/ios-arm64/OpenSSL.framework)
# IDevice 内嵌的 libplist 头比 libimobiledevice 带的旧，plist_write_options_t 少一个成员；Swift 6.2 的 clang 把两个模块里
# 不一致的同名枚举当 ODR 错误。补上这一行让两份定义一致（只是声明，不影响二进制）
idh=$P/.build/artifacts/devicegateway/IDevice/IDevice.xcframework/ios-arm64/Headers/idevice.h
grep -q PLIST_OPT_COERCE $idh || {
  grep -q '^        PLIST_OPT_INDENT = 1 << 3,' $idh || { echo "idevice.h 的 plist_write_options_t 变了，改 linux-build.sh"; exit 1; }
  sed -i 's/^        PLIST_OPT_INDENT = 1 << 3,.*/&\n        PLIST_OPT_COERCE = 1 << 4, \/* linux-build.sh 补，同 libimobiledevice 的 plist.h *\//' $idh; }
mkdir -p $B/fw-alias && ln -sfn "$ROOT/$ossl" $B/fw-alias/openssl.framework
# 静态库之间的同名导出符号。Apple 的 ld64 对静态库之间的重名不报错、取先出现的那份；lld 报错：
# ① IDevice（Rust）和 libimobiledevice 重了 132 个（libplist 和 afc_/lockdownd_ 等接口，实现不同）。CI 包里用的是 IDevice
#    那份（按机器码比对过 afc_client_new、lockdownd_get_value 等），默认后端 idevice 也靠它
# ② IDevice 和 EMProxy 都带 Rust 标准库，重了几百个（compiler_builtins、rust_eh_personality 等）
# 都把另一个库里的重名符号加前缀改名（定义和引用一起改，库内部照旧一致），外部引用只剩 IDevice 一份；每次从原件重做。
# Rust 目标文件嵌着 bitcode，llvm-nm 默认读 bitcode 里的符号，要 --no-llvm-bc 才看到链接器用的那份
ad=$P/.build/artifacts
idev=$(ls $ad/devicegateway/IDevice/IDevice.xcframework/ios-arm64/libidevice_ffi.a)
syms() { llvm-nm --no-llvm-bc -g --defined-only "$1" 2>/dev/null | awk 'NF==3{print $3}' | LC_ALL=C sort -u; }
rename_dups() {  # 库 前缀
  local lib=$1 map=$B/rename-$2.txt
  [ -f "$lib.orig" ] || cp "$lib" "$lib.orig"
  LC_ALL=C comm -12 <(syms "$lib.orig") <(syms "$idev") | sed "s/^_\(.*\)/_\1 _$2\1/" >"$map"
  llvm-objcopy --redefine-syms="$map" "$lib.orig" "$lib"
  [ -z "$(LC_ALL=C comm -12 <(syms "$lib") <(syms "$idev"))" ] || { echo "$(basename "$lib") 改名后仍与 IDevice 重名"; exit 1; }
  echo "== $(basename "$lib")：$(wc -l <"$map") 个与 IDevice 重名的符号改名"
}
rename_dups "$(ls $ad/devicegateway/libimobiledevice/libimobiledevice.xcframework/ios-arm64/libimobiledevice.a)" limd_
rename_dups "$(ls $ad/minimuxer/EMProxy/EMProxy.xcframework/ios-arm64/libem_proxy.a)" emproxy_
export SS_IOS_SDK=$(ls -d "$SDKS"/darwin.artifactbundle/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS[0-9]*.sdk | tail -1)
# xtool 工具集的 librarian 是 llvm-libtool-darwin，SwiftPM 6.2 却按 ar 传参（crs），归档静态库（SideSign）时报错：换成 llvm-ar
printf '{"schemaVersion":"1.0","librarian":{"path":"%s"}}\n' "$(dirname "$(command -v swiftc)")/llvm-ar" >$B/toolset.json
echo "== swift build ($CONF)"
(cd $P && swift build --swift-sdks-path "$SDKS" --swift-sdk arm64-apple-ios --toolset "$ROOT/$B/toolset.json" -c $CONF -Xcc -F"$ROOT/$B/fw-alias" 2>&1) | tee $B/build.log |
  grep -E "error:|Build complete|Linking" || true
grep -q "Build complete" $B/build.log || {
  grep -E "error:" $B/build.log | sed -E "s#^$ROOT/##; s#^.*/build/linux/pkg/Sources/SideStore/##" | sort -u | head -40
  echo "编译失败（完整日志 $B/build.log）"; exit 1
}
bin=$P/.build/arm64-apple-ios/$CONF

# 5. 组装 SideStore.app：参考包换上新主程序和实际链接的 OpenSSL.framework，改版本号
APP=$B/Payload/SideStore.app
rm -rf $B/Payload && mkdir -p $B/Payload && cp -R $C/SideStore.app $APP
cp $bin/SideStore $APP/SideStore
[ $CONF = release ] && llvm-objcopy --strip-all $APP/SideStore  # 同 Xcode 归档（STRIP_STYLE = all）
rm -rf $APP/Frameworks/OpenSSL.framework && cp -R "$ossl" $APP/Frameworks/OpenSSL.framework
rm -rf $APP/Frameworks/OpenSSL.framework/{Headers,Modules,_CodeSignature}
commit=$(git rev-parse --short=8 HEAD)$(git diff --quiet HEAD -- Shared AltStore SideStore Dependencies || echo -dirty)
ver="$(sed -n 's/^MARKETING_VERSION *= *//p' Build.xcconfig)-$(date +%Y%m%d).$N+$commit"
python3 - "$APP/Info.plist" "$ver" "$cc" <<'PY'
import plistlib, sys
p, ver, cc = sys.argv[1:]
d = plistlib.load(open(p, "rb"))
d["CFBundleShortVersionString"] = ver
d["SSResourcesCommit"] = cc  # 资源取自哪个提交的缓存（refresh-cache.sh 认这个）
plistlib.dump(d, open(p, "wb"), fmt=plistlib.FMT_BINARY)
PY

# 6. 打包
mkdir -p "$(dirname "$OUT")"
OUT=$(realpath "$OUT")
rm -f "$OUT" && (cd $B && zip -qry "$OUT" Payload)
echo "== 出包 $OUT ($(du -h "$OUT" | cut -f1)，$ver)"
