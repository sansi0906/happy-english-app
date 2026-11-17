# -*- coding: utf-8 -*-
import os, re
import pypdfium2 as pdfium

T = os.path.join(os.path.dirname(os.path.abspath(__file__)), '_tmp')
JOBS = [("语文·基础", "ex1.pdf"), ("语文·提高", "ex3.pdf"),
        ("数学·基础", "ex2.pdf"), ("数学·提高", "ex4.pdf")]

SCALE = 1.35
for name, pdfn in JOBS:
    print("=" * 58)
    print(name)
    pdf = pdfium.PdfDocument(os.path.join(T, pdfn))
    for i in range(len(pdf)):
        pg = pdf[i]
        tp = pg.get_textpage()
        h = pg.get_size()[1]
        ys = []
        for k in range(tp.count_chars()):
            b = tp.get_charbox(k)
            if b:
                y = b[1] / SCALE      # 顶部为 0 的 pt 坐标
                if 50 < y < h - 100:  # 排除页眉与页脚
                    ys.append(y)
        if ys:
            last, first = max(ys), min(ys)
            gap_cm = (h - 57 - last) / 28.35
            print("  P%d 正文 y: %.0f~%.0f，正文末行距纸底 %.1fcm（扣除边距后余白 %.1fcm）"
                  % (i + 1, first, last, (h - last) / 28.35, gap_cm))
print()

print("=" * 58)
print("小题分与大题分核对（逐行扫描）")
for name, pdfn in JOBS:
    pdf = pdfium.PdfDocument(os.path.join(T, pdfn))
    lines = []
    for i in range(len(pdf)):
        for ln in pdf[i].get_textpage().get_text_range().replace("\r\n", "\n").split("\n"):
            ln = ln.strip()
            if ln and not re.match(r"第\s*\d+\s*页", ln):
                lines.append(ln)
    cur, big, subs = None, 0, []
    def report(cur, big, subs):
        if cur is None:
            return
        ssum = sum(subs)
        ok = (ssum == big) or (not subs)
        print("    %-26s 大题%3d 小题%3d %s%s"
              % (cur[:24], big, ssum, "OK" if ok else "不一致", "" if ok else "  小题=%s" % subs))
    for ln in lines:
        m = re.match(r"([一二三四五六七八]+、.*?)（\s*(\d+)\s*分）", ln)
        if m and not ln.startswith(("①", "②", "③")):
            report(cur, big, subs)
            cur, big, subs = m.group(1), int(m.group(2)), []
        else:
            for v in re.findall(r"（\s*(\d+)\s*分）", ln):
                subs.append(int(v))
    report(cur, big, subs)
