# Linux 本机出包（SideStore → LiveContainer+SideStore）

不用 Mac / GitHub Actions，在 omarchy 上编 SideStore 并换进 LiveContainer 合体包。

```
tools/linux-build.sh                       # → build/linux/SideStore.ipa（Release 约 4 分钟，增量更快）
~/data/projects/LiveContainer/tools/linux-embed-sidestore.sh \
    <现网 LiveContainer+SideStore.ipa> build/linux/SideStore.ipa -v 3.8.10.N
                                           # → LiveContainer/build/linux/LiveContainer+SideStore.ipa
```

发布：IPA 传到 OCI `~/conch-www/<令牌>/livecontainer/`，在 `source.json` 里加一条 version（跟 `-v` 一致）；
手机上 LiveContainer 里的 SideStore 点更新。`-v` 用四段版本号：SideStore 把非语义化版本按字符串比较，不同就提示更新。

## 怎么做到的

- **编译**：`Package.swift` 是 SwiftPM 外壳，Sources 软链回 `Shared/ AltStore/ SideStore/`，只编 SideStore 主程序（全 Swift）。
  依赖版本照 `Package.resolved`；Swift 5 模式、`BETA`、`-Osize`、`-no_exported_symbols`，Release 剥符号，同 Xcode 设置。
- **Xcode 专属的东西**
  - storyboard/xib、Assets.car、Core Data 模型、App Intents 元数据、小组件、SideBackup.ipa：取自参考包
    （`refresh-cache.sh [ipa]`，默认下载 nightly），放 `build/linux/cache/`。对应源文件改过时构建会列出来提醒。
  - Intents 类和资源符号（`ColorResource.xxx`）：`mac-codegen.sh` 用 Mac 的 intentbuilderc / actool 生成到 `generated/`，
    源文件 sha256 变了构建时自动重跑（要 Mac 在线）。
- **Linux 上的坑**（都在 `linux-build.sh` 里处理，注释写了原因）
  - AnisetteKit / GSACryptoKit / CodeSignKit / ZIPFoundation 的清单按宿主判断平台 → 检出同一提交改判断，根包本地覆盖。
  - xtool 工具集的 librarian 跟 SwiftPM 传参不匹配 → 覆盖成 llvm-ar。
  - `<openssl/ssl.h>` 在区分大小写的文件系统上找不到 `OpenSSL.framework` → 小写软链。
  - IDevice 内嵌的 libplist 头少一个枚举成员，clang 报 ODR → 补一行。
  - IDevice / libimobiledevice / EMProxy 静态库之间有同名符号，ld64 取第一个、lld 报错 → 另两个库里重名的改名，
    外部引用落到 IDevice（跟 CI 包一致，按机器码核对过）。
- **dylib 化**：LiveContainer 仓库 `tools/linux/dylibify.py`，照 LiveContainer 自己的 `LCPatchExecSlice` 做
  （保留并缩小 `__PAGEZERO`，不用再修 seg_count）。签名用 `~/data/sdk/rcodesign` ad-hoc。

## 跟 CI 包的差别

文件清单一致；主程序多链了 `SwiftUICore`（iOS 18 起才有，所以 Linux 包要 iOS 18+）、SDK 版本 26.2（CI 是 26.4）。
