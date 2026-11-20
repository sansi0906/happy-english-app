import json, os, sys, wave, statistics
import numpy as np
import miniaudio

# 以脚本自身位置推导工程根，便于在 CI（Linux）与本地复用
APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(APP, 'assets')
DATA = json.load(open(os.path.join(A, 'data', 'content.json'), encoding='utf-8'))

problems = []


def p(kind, msg):
    problems.append((kind, msg))


# ---------- 0. 版本号一致性 ----------
# 设置页「关于」里显示的版本来自 lib/data/app_meta.dart 的 kAppVersion，
# 忘了改就会像 v1.6.0 的包还显示 v1.0.0 那样露馅，所以在这里卡住。
import re
_pubspec = open(os.path.join(APP, 'pubspec.yaml'), encoding='utf-8').read()
_pv = re.search(r'^version:\s*([0-9.]+)\+?[0-9]*', _pubspec, re.M)
_meta = open(os.path.join(APP, 'lib', 'data', 'app_meta.dart'), encoding='utf-8').read()
_mv = re.search(r"kAppVersion\s*=\s*'([0-9.]+)'", _meta)
if not _pv or not _mv:
    p('VERSION', '读不到 pubspec 版本或 app_meta 的 kAppVersion')
elif _pv.group(1) != _mv.group(1):
    p('VERSION', 'pubspec %s 与 app_meta kAppVersion %s 不一致' % (_pv.group(1), _mv.group(1)))

# ---------- 1. 结构 ----------
colors = 0
for i, b in enumerate(DATA['books']):
    for k in ('book_id', 'book_name', 'book_name_en', 'grade', 'units'):
        if k not in b:
            p('STRUCT', 'book[%d] 缺字段 %s' % (i, k))
    if len(b.get('units', [])) == 0:
        p('STRUCT', 'book%d 无单元' % b.get('book_id'))
    ids = set()
    for u in b['units']:
        for k in ('unit_id', 'title', 'title_en', 'sentences', 'words'):
            if k not in u:
                p('STRUCT', 'book%d/u%s 缺字段 %s' % (b['book_id'], u.get('unit_id'), k))
        for s in u.get('sentences', []):
            for k in ('text', 'audio', 'image'):
                if not s.get(k):
                    p('STRUCT', 'book%d/u%s 句子缺 %s: %r' % (b['book_id'], u['unit_id'], k, s.get('text')))
            if s.get('id') in ids:
                p('STRUCT', '重复 id %s' % s.get('id'))
            ids.add(s.get('id'))
        for w in u.get('words', []):
            for k in ('text', 'meaning', 'audio', 'image'):
                if not w.get(k):
                    p('STRUCT', 'book%d/u%s 单词缺 %s: %r' % (b['book_id'], u['unit_id'], k, w.get('text')))
# ---------- 2. 资源缺失 ----------
ref_audio, ref_img, ref_other = set(), set(), set()
for b in DATA['books']:
    for u in b['units']:
        for it in u['sentences'] + u['words']:
            ref_audio.add(it['audio'])
            ref_img.add(it['image'])
            bk_dir = 'book%d' % b['book_id']
            if not it['audio'].startswith(bk_dir + '/'):
                p('MAP', 'audio 路径与册目录不符: %s' % it['audio'])
            if not it['image'].startswith(bk_dir + '/'):
                p('MAP', 'image 路径与册目录不符: %s' % it['image'])
for f in ref_audio:
    if not os.path.exists(os.path.join(A, 'audio', f)):
        p('MISSING', 'audio 缺失 %s' % f)
for f in ref_img:
    if not os.path.exists(os.path.join(A, 'images', f)):
        p('MISSING', 'image 缺失 %s' % f)

# ---------- 3. 冗余 ----------
extra = []
for root, _, files in os.walk(os.path.join(A, 'audio')):
    # 以下划线开头的目录（如 _backup_greeting_swap）是人工备份/临时素材，
    # 既不在 pubspec 的 assets 里、也不会打进 APK，不算"未引用"噪音。
    if os.path.basename(root).startswith('_'):
        continue
    for f in files:
        rel = os.path.join(os.path.relpath(root, os.path.join(A, 'audio')), f).replace('\\', '/')
        if rel.endswith('_slow.mp3'):
            if rel.replace('_slow.mp3', '.mp3') not in ref_audio:
                extra.append('孤立慢速: ' + rel)
        elif rel not in ref_audio:
            extra.append('未引用音频: ' + rel)
for root, _, files in os.walk(os.path.join(A, 'images')):
    for f in files:
        rel = os.path.join(os.path.relpath(root, os.path.join(A, 'images')), f).replace('\\', '/')
        if rel not in ref_img:
            extra.append('未引用图片: ' + rel)
for e in extra:
    p('EXTRA', e)

# ---------- 4. 音频质量 ----------
import imageio_ffmpeg, subprocess

FF = imageio_ffmpeg.get_ffmpeg_exe()
SR = 16000


def probe(path):
    """ffmpeg 解码为 16k 单声道；返回 dict：时长/首静音/尾静音/有声时长/峰值"""
    proc = subprocess.run([FF, '-v', 'error', '-i', path, '-f', 's16le', '-ac', '1',
                           '-ar', str(SR), '-'], capture_output=True)
    if proc.returncode != 0 or not proc.stdout:
        return None
    data = np.frombuffer(proc.stdout, dtype=np.int16)
    if data.size == 0:
        return None
    dur = data.size / SR
    frame = int(SR * 0.02)
    usable = data.size // frame
    if usable == 0:
        return dict(dur=dur, lead=dur, tail=dur, speech=0.0, peak=int(np.abs(data).max()))
    blk = data[:usable * frame].reshape(usable, frame)
    loud = np.abs(blk).max(axis=1) >= 500   # 20ms 帧是否有人声
    lead = int(np.argmax(loud)) * 0.02 if loud.any() else dur
    tail = (usable - 1 - int(len(loud) - 1 - np.argmax(loud[::-1]))) * 0.02 if loud.any() else dur
    return dict(dur=dur, lead=lead, tail=tail, speech=float(loud.sum()) * 0.02,
                peak=int(np.abs(data).max()))


bad_audio = []
# 慢速版音频（*_slow.mp3）在 V1.5.4 已整体下线：跟读页不再提供慢速示范，
# AudioService 也删掉了 slow 分支，884 条 slow 文件一并移除（省 20MB）。
# 因此这里不再要求"每句都必须有慢速版"，改为反过来卡"不能有遗留 slow 文件"。
for b in DATA['books']:
    for u in b['units']:
        for it in u['sentences'] + u['words']:
            ap = os.path.join(A, 'audio', it['audio'])
            if not os.path.exists(ap):
                continue
            r = probe(ap)
            if r is None:
                bad_audio.append((it['audio'], '解码失败(格式异常)'))
                continue
            if r['dur'] < 0.25:
                bad_audio.append((it['audio'], '时长过短 %.2fs' % r['dur']))
            elif r['dur'] > 12:
                bad_audio.append((it['audio'], '时长过长 %.1fs' % r['dur']))
            if r['speech'] < 0.15:
                bad_audio.append((it['audio'], '几乎无声(有声 %.2fs)' % r['speech']))
            if r['lead'] > 1.2 or r['tail'] > 1.2:
                bad_audio.append((it['audio'], '首尾静音过大 lead %.2f tail %.2f' % (r['lead'], r['tail'])))
            if r['peak'] < 2000:
                bad_audio.append((it['audio'], '音量过低 peak=%d' % r['peak']))
for a, m in bad_audio:
    p('AUDIO', '%s %s' % (a, m))

# ---------- 5. 图片 ----------
big_img = []
for root, _, files in os.walk(os.path.join(A, 'images')):
    for f in files:
        fp = os.path.join(root, f)
        sz = os.path.getsize(fp)
        if sz > 600 * 1024:
            big_img.append((os.path.relpath(fp, A), sz))
for f, sz in big_img:
    p('IMAGE', '图片过大 %s %.0fKB' % (f, sz / 1024))

# ---------- 6. 体积 ----------
def dirsize(d):
    return sum(os.path.getsize(os.path.join(r, f)) for r, _, fs in os.walk(d) for f in fs)

rep = {
    'books': len(DATA['books']),
    'items': sum(len(u['sentences']) + len(u['words']) for b in DATA['books'] for u in b['units']),
    'sentences': sum(len(u['sentences']) for b in DATA['books'] for u in b['units']),
    'audio_ref': len(ref_audio),
    'slow_files': sum(1 for r, _, fs in os.walk(os.path.join(A, 'audio')) for f in fs if f.endswith('_slow.mp3')),
    'extra_by_book': {},
    'sizes_MB': {k: round(dirsize(os.path.join(A, k)) / 1e6, 1) for k in ('audio', 'images', 'data', 'models') if os.path.isdir(os.path.join(A, k))},
    'problems_total': len(problems),
}
for e in extra:
    bk = e.split(': ')[1].split('/')[0]
    rep['extra_by_book'][bk] = rep['extra_by_book'].get(bk, 0) + 1
print(json.dumps(rep, ensure_ascii=False, indent=1))
groups = {}
for k, m in problems:
    groups.setdefault(k, []).append(m)
for k, v in groups.items():
    print('\n[%s] %d' % (k, len(v)))
    for m in v[:8]:
        print('  -', m)
    if len(v) > 8:
        print('  ... 其余 %d 条' % (len(v) - 8))
