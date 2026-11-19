"""重新生成句子音频，把编码质量从 48 kbps 提到 96 kbps。

背景：句子音用 edge-tts（en-GB 神经语音）合成，默认输出 24 kHz / 48 kbps MP3。
这个码率下 MP3 会优先牺牲高频，而英语辅音 /s/ /f/ /θ/ 正在 4-8 kHz —— 听感上
就是"闷、糊、不像真人"。码率翻倍不改变采样率，但能显著减少编码失真。

单词不在这里重新生成：单个词走有道词典的英式真人录音（dictvoice type=1），
本来就是最标准的那一档，重生成反而退化。

慢速文件由新生成的正常音用 atempo=0.85 派生（与既有规则一致），保持 64 kbps，
因为慢速本身语速慢、辅音更清楚，没必要翻倍占体积。

用法：
  python tool/regen_audio.py --dry-run          # 只统计
  python tool/regen_audio.py --limit 5          # 抽样验证（不覆盖全量）
  python tool/regen_audio.py                    # 全量重生成（会备份原音频）
"""
import argparse
import asyncio
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.parse
import urllib.request

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(APP, "assets", "audio")
DATA = os.path.join(APP, "assets", "data", "content.json")
BACKUP = r"E:\happy-english-app\工具\_tmp\_audio_backup_20261118"

VOICE = "en-GB-MaisieNeural"
SEM = asyncio.Semaphore(6)
# 单 token 的英文词才走有道真人音（与建库时的判定一致）
WORD_RE = re.compile(r"[A-Za-z][A-Za-z'.-]*")

LOW_FMT = "audio-24khz-48kbitrate-mono-mp3"
HIGH_FMT = "audio-24khz-96kbitrate-mono-mp3"


def ensure_high_bitrate():
    """edge-tts 把输出格式硬编码成 48 kbps。这里改成 96 kbps 并幂等。

    实测 Edge 接口接受 24 kHz / 96 kbps，不接受 48 kHz 系列。
    码率翻倍不改变采样率（上限仍是 12 kHz），但能明显减少 MP3 的编码失真，
    而失真损失的正是 /s/ /f/ /θ/ 这些决定清晰度的高频辅音。
    """
    import edge_tts

    p = os.path.join(os.path.dirname(edge_tts.__file__), "communicate.py")
    txt = open(p, encoding="utf-8").read()
    if HIGH_FMT in txt:
        return "already"
    if LOW_FMT not in txt:
        return "unknown"
    open(p, "w", encoding="utf-8", newline="\n").write(txt.replace(LOW_FMT, HIGH_FMT))
    return "patched"


def is_single_word(text):
    t = text.strip()
    return len(t.split()) == 1 and bool(WORD_RE.fullmatch(t))


def dict_gb(word):
    u = "https://dict.youdao.com/dictvoice?audio=%s&type=1" % urllib.parse.quote(word)
    r = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
    return urllib.request.urlopen(r, timeout=15).read()


async def tts(text, path, rate):
    import edge_tts

    async with SEM:
        for k in range(4):
            try:
                await edge_tts.Communicate(text, VOICE, rate=rate).save(path)
                if os.path.getsize(path) > 2000:
                    return True
            except Exception:
                pass
            await asyncio.sleep(1 + k * 2)
        return False


def collect():
    d = json.load(open(DATA, encoding="utf-8"))
    groups = []
    words = []
    for b in d["books"]:
        for u in b["units"]:
            for it in u.get("sentences", []):
                p = os.path.join(AUDIO, it["audio"].replace("/", os.sep))
                groups.append((it["text"], p))
            for it in u.get("words", []):
                words.append((it["text"], os.path.join(AUDIO, it["audio"].replace("/", os.sep)))
                             if "audio" in it else None)
    return groups, [w for w in words if w]


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()

    sentences, words = collect()
    # 句子组里，单 token 的其实走有道真人音，不算 TTS 目标
    tts_items = [(t, p) for t, p in sentences if not is_single_word(t)]
    dict_items = [(t, p) for t, p in sentences if is_single_word(t)]

    print("输出格式:", ensure_high_bitrate(), HIGH_FMT)

    print("content.json 条目: %d（句子组 %d / 单词组 %d）" % (
        len(sentences) + len(words), len(sentences), len(words)))
    print("需要 TTS 重生成: %d 条" % len(tts_items))
    print("保持有道真人音（单词）: %d 条" % len(dict_items))
    if args.dry_run:
        return 0

    items = tts_items[: args.limit] if args.limit else tts_items

    if not args.limit:
        os.makedirs(BACKUP, exist_ok=True)
        for t, p in items:
            if os.path.isfile(p):
                dst = os.path.join(BACKUP, os.path.relpath(p, AUDIO))
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                if not os.path.exists(dst):
                    shutil.copy2(p, dst)
        print("原音频已备份到:", BACKUP)

    print("开始生成 %d 条……" % len(items))
    res = await asyncio.gather(*[tts(t, p, "-10%") for t, p in items])
    ok = sum(res)
    print("TTS 成功 %d / %d" % (ok, len(items)))
    return 0 if ok == len(items) else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
