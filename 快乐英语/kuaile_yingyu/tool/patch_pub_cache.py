"""给 pub 缓存里的 Flutter 插件打两处兼容补丁（幂等）。

补丁一 · 注入阿里云 Maven 镜像
    插件在自己的 buildscript 里写死了 google()/mavenCentral()，绕过工程的
    settings 仓库配置。国内直连 repo.maven.apache.org 拉 kotlin-gradle-plugin、
    AGP 等大件时会长时间挂起（表现为 Gradle 卡在配置阶段、CPU 不动）。

补丁二 · 无条件设置 namespace
    AGP 9 强制要求每个 library 模块显式声明 namespace。audioplayers_android
    写的是 `if (project.android.hasProperty('namespace')) { namespace ... }`，
    这个判断在 AGP 9 下为假，于是 namespace 没被设置，配置阶段直接报
    "Namespace not specified"。

用法：python tool/patch_pub_cache.py
执行时机：flutter pub get 之后、Gradle 构建之前。本地和 CI 都必须跑，
         否则 pub get 重新下载插件后补丁会丢失。
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
REPO_PAT = re.compile(r"repositories\s*\{\s*\n(\s*)(google\(\)|mavenCentral\(\))")

# 包在 hasProperty 判断里的 namespace
NS_PAT = re.compile(
    r"if\s*\(\s*project\.android\.hasProperty\(\s*['\"]namespace['\"]\s*\)\s*\)\s*\{"
    r"\s*\n\s*namespace\s+['\"]([^'\"]+)['\"]\s*\n\s*\}"
)


def pub_cache_dir():
    """按 PUB_CACHE、Windows 默认位置、Linux/macOS 默认位置依次探测。"""
    env = os.environ.get("PUB_CACHE")
    cands = []
    if env:
        cands.append(os.path.join(env, "hosted", "pub.dev"))
    cands.append(os.path.expandvars(r"%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev"))
    cands.append(os.path.expanduser("~/.pub-cache/hosted/pub.dev"))
    cands.append(os.path.expanduser("~/AppData/Local/Pub/Cache/hosted/pub.dev"))
    for c in cands:
        if os.path.isdir(c):
            return c
    return None


def patch_mirror(text):
    if MARK in text:
        return text, 0
    return REPO_PAT.subn(
        lambda m: "repositories {\n"
        + "".join(m.group(1) + ln for ln in MIRRORS)
        + m.group(1)
        + m.group(2),
        text,
    )


def patch_namespace(text):
    return NS_PAT.subn(lambda m: "namespace '%s'" % m.group(1), text)


def main():
    cache = pub_cache_dir()
    if not cache:
        print("找不到 pub 缓存目录")
        return 1
    print("pub 缓存:", cache)
    stat = {}
    for name in sorted(os.listdir(cache)):
        gradle = os.path.join(cache, name, "android", "build.gradle")
        if not os.path.isfile(gradle):
            continue
        with open(gradle, encoding="utf-8") as f:
            text = f.read()

        new, n_repo = patch_mirror(text)
        new, n_ns = patch_namespace(new)

        if n_repo or n_ns:
            with open(gradle, "w", encoding="utf-8", newline="\n") as f:
                f.write(new)
            key = "repo+ns" if (n_repo and n_ns) else ("namespace" if n_ns else "mirror")
            stat[key] = stat.get(key, 0) + 1
            print("%-22s %-10s repo=%d ns=%d" % (name, "PATCHED", n_repo, n_ns))
        else:
            stat["skip"] = stat.get("skip", 0) + 1
    print("汇总:", stat)
    return 0


if __name__ == "__main__":
    sys.exit(main())
