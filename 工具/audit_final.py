# -*- coding: utf-8 -*-
import os, re
import pypdfium2 as pdfium
from docx import Document

T = os.path.join(os.path.dirname(os.path.abspath(__file__)), '_tmp')
E = r"E:\happy-english-app\学生习题\期末卷"
JOBS = [
    ("语文·基础", "期末卷_语文基础.docx", "ex1.pdf", 100),
    ("语文·提高", "期末卷_语文提高.docx", "ex3.pdf", 100),
    ("数学·基础", "期末卷_数学基础.docx", "ex2.pdf", 100),
    ("数学·提高", "期末卷_数学提高.docx", "ex4.pdf", 100),
]
problems = []

for name, fn, pdfn, expect in JOBS:
    print("=" * 60)
    print(name)
    # 1) 纸张与页边距
    s = Document(os.path.join(E, fn)).sections[0]
    print("  纸张 %.2fx%.2f cm 边距 上%.1f 下%.1f 左%.1f 右%.1f"
          % (s.page_width.cm, s.page_height.cm, s.top_margin.cm, s.bottom_margin.cm,
             s.left_margin.cm, s.right_margin.cm))
    if abs(s.page_width.cm - 21) > 0.03 or abs(s.page_height.cm - 29.7) > 0.03:
        problems.append(name + " 非A4")

    # 2) 页数与逐页文本
    pdf = pdfium.PdfDocument(os.path.join(T, pdfn))
    n = len(pdf)
    pages = [pdf[i].get_textpage().get_text_range().replace("\r\n", "\n") for i in range(n)]
    print("  页数", n)
    if n != 4:
        problems.append(name + " 页数=%d" % n)

    # 3) 页脚页码
    foot = [re.search(r"第\s*(\d+)\s*页（共\s*(\d+)\s*页）", t) for t in pages]
    ok_foot = all(f and int(f.group(1)) == i + 1 and int(f.group(2)) == n
                  for i, f in enumerate(foot))
    print("  页脚页码", "OK 1~%d（共%d页）" % (n, n) if ok_foot else "异常 %s" % [f.group(0) if f else None for f in foot])
    if not ok_foot:
        problems.append(name + " 页脚页码异常")

    # 4) 大题分值
    txt = "\n".join(pages)
    big = re.findall(r"([一二三四五六七八]+、[^（\n]{1,20})\s*（\s*(\d+)\s*分）", txt)
    tot = sum(int(b) for _, b in big)
    print("  大题", [(a.strip(), b) for a, b in big], "合计", tot)
    if tot != expect:
        problems.append(name + " 大题合计 %d≠%d" % (tot, expect))

    # 5) 每页末行是否孤悬题号（题干落页底）
    for i, t in enumerate(pages):
        lines = [x.strip() for x in t.split("\n") if x.strip()]
        body = [x for x in lines if not re.match(r"第\s*\d+\s*页", x)]
        if body:
            last = body[-1]
            if re.match(r"[0-9]+\s*\.", last) and i < n - 1:
                problems.append("%s P%d 页末孤悬题干：%s" % (name, i + 1, last[:30]))
    print("  页末孤悬题干：已逐页扫描")

print("=" * 60)
print("问题清单：", problems if problems else "无")
