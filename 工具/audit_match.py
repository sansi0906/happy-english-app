# -*- coding: utf-8 -*-
import os, re
import pypdfium2 as pdfium

T = os.path.join(os.path.dirname(os.path.abspath(__file__)), '_tmp')
PAIRS = [("语文基础", "ex1.pdf", "ans.pdf", 0), ("语文提高", "ex3.pdf", "ans.pdf", 1),
         ("数学基础", "ex2.pdf", "ans.pdf", 2), ("数学提高", "ex4.pdf", "ans.pdf", 3)]

def nums(pdf, idx):
    s = pdf[idx].get_textpage().get_text_range().replace("\r\n", "\n")
    s = re.sub(r"第\s*\d+\s*页（共\s*\d+\s*页）", "", s)
    return re.findall(r"(?m)^\s*(\d{1,2})\s*\.", s)

for name, exam, ansf, pi in PAIRS:
    e = nums(pdfium.PdfDocument(os.path.join(T, exam)), 0) if False else None
    ex_pdf = pdfium.PdfDocument(os.path.join(T, exam))
    seq_e = []
    for i in range(len(ex_pdf)):
        seq_e += nums(ex_pdf, i)
    ans_pdf = pdfium.PdfDocument(os.path.join(T, ansf))
    seq_a = nums(ans_pdf, pi)
    print("%-10s 卷面题号 %s" % (name, seq_e))
    print("%-10s 答案题号 %s" % ("", seq_a))
    miss = [x for x in seq_e if x not in seq_a]
    extra = [x for x in seq_a if x not in seq_e]
    print("           缺失 %s / 多出 %s" % (miss if miss else "无", extra if extra else "无"))
    print()
