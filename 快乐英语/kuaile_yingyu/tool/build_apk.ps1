# 本地出 APK（Windows）
#
# 为什么要绕一层英文路径：
#   工程目录含中文（...\快乐英语\...），AGP 靠 android.overridePathCheck=true
#   才肯放行，但 NDK 的 CMake/Ninja 不认非 ASCII 路径——它会把中文路径按 GBK
#   解释成乱码，libdartjni.so 被链接到错误位置，构建报
#   "Expected output file ... libdartjni.so ... but there was none"。
#   因此统一用 E:\he_app（junction -> 真实工程目录）作为构建根目录。
#
# 用法：pwsh -File tool\build_apk.ps1 [-release]
param([switch]$release)

$root  = "E:\happy-english-app\快乐英语\kuaile_yingyu"
$link  = "E:\he_app"
$flutter = "D:\dev\flutter\bin\flutter.bat"

if (-not (Test-Path $link)) {
    New-Item -ItemType Junction -Path $link -Target $root | Out-Null
    Write-Host "已创建英文路径联接: $link -> $root"
}

# 插件 buildscript 绕过工程仓库配置，需先补镜像（flutter pub get 后要重跑）
python tool\patch_pub_cache.py

$env:PATH = "C:\Windows\System32;C:\Windows;C:\Program Files\Git\cmd;D:\dev\flutter\bin;" + $env:PATH
Set-Location $link

if ($release) {
    # 工程显式只打 arm64-v8a（android/app/build.gradle.kts 的 ndk.abiFilters）。
    # 不能用 --split-per-abi：那会设置 splits.abi，与 abiFilters 冲突，报
    # "Conflicting configuration : 'arm64-v8a' in ndk abiFilters cannot be present
    #  when splits abi filters are set"。用 --target-platform 表达同一意图。
    & $flutter build apk --release --target-platform android-arm64
    $apk = Join-Path $link "build\app\outputs\flutter-apk\app-release.apk"
} else {
    & $flutter build apk --debug
    $apk = Join-Path $link "build\app\outputs\flutter-apk\app-debug.apk"
}

if (Test-Path $apk) {
    $mb = [math]::Round((Get-Item $apk).Length / 1MB, 1)
    Write-Host ""
    Write-Host "APK 已生成（$mb MB）：$apk"
    Write-Host "真机安装：adb install -r `"$apk`""
} else {
    Write-Host "构建未产出 APK，请检查上方 Gradle 报错。"
    exit 1
}
