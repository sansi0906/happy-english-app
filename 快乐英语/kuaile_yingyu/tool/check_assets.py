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
slow_missing, slow_bad = [], []
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
            sp = ap.replace('.mp3', '_slow.mp3')
            if it in u['sentences']:
                if not os.path.exists(sp):
                    slow_missing.append(it['audio'])
                else:
                    r2 = probe(sp)
                    if r2 is None:
                        slow_bad.append((it['audio'], '慢速解码失败'))
                    elif r2['dur'] < 0.2:
                        slow_bad.append((it['audio'], '慢速时长异常'))
                    elif r2['dur'] / r['dur'] < 1.05:
                        slow_bad.append((it['audio'], '慢速比例 %.2f 未变慢' % (r2['dur'] / r['dur'])))
for a, m in bad_audio:
    p('AUDIO', '%s %s' % (a, m))
for a in slow_missing:
    p('SLOW', '缺慢速版 %s' % a)
for a, m in slow_bad:
    p('SLOW', '%s %s' % (a, m))

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
