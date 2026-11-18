"""给 pub 缓存里的 Flutter 插件 build.gradle 注入国内 Maven 镜像。

背景：Flutter 插件在自己的 buildscript 里写死了 google()/mavenCentral()，
绕过了工程的 settings 仓库配置。国内直连 repo.maven.apache.org 拉
kotlin-gradle-plugin、AGP 等大件时会长时间挂起（表现为 gradle 卡在
配置阶段、CPU 不动）。把阿里云镜像插到 buildscript repositories 最前面，
命中率最高、下载也快。

用法（在项目根执行）：python tool/patch_pub_cache.py
幂等：已注入过的文件会跳过。flutter pub get 重新下载插件后重跑一次即可。
"""
import os
import re
import sys

MIRRORS = (
    "maven { url 'https://maven.aliyun.com/repository/public' }\n",
    "maven { url 'https://maven.aliyun.com/repository/google' }\n",
)
MARK = "maven.aliyun.com/repository/public"

# repositories { 后紧跟 google() 或 mavenCentral() 的位置
PAT = re.compile(r"repositories\s*\{\s*\n(\s*)(google\(\)|mavenCentral\(\))")


def patch_file(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    if MARK in text:
        return "skip"
    new, n = PAT.subn(
        lambda m: "repositories {\n"
        + "".join(m.group(1) + ln for ln in MIRRORS)
        + m.group(1)
        + m.group(2),
        text,
    )
    if n == 0:
        return "nomatch"
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(new)
    return "patched(%d)" % n


def main():
    cache = os.path.expandvars(r"%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev")
    if not os.path.isdir(cache):
        print("找不到 pub 缓存:", cache)
        return 1
    stat = {}
    for name in sorted(os.listdir(cache)):
        gradle = os.path.join(cache, name, "android", "build.gradle")
        if not os.path.isfile(gradle):
            continue
        r = patch_file(gradle)
        stat[r.split("(")[0]] = stat.get(r.split("(")[0], 0) + 1
        if r != "skip":
            print("%-24s %s" % (r, name))
    print("汇总:", stat)
    return 0


if __name__ == "__main__":
    sys.exit(main())
