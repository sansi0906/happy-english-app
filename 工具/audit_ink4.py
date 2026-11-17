# -*- coding: utf-8 -*-
import os
import pypdfium2 as pdfium

T = os.path.join(os.path.dirname(os.path.abspath(__file__)), '_tmp')
JOBS = [("语文·基础", "ex1.pdf"), ("语文·提高", "ex3.pdf"),
        ("数学·基础", "ex2.pdf"), ("数学·提高", "ex4.pdf"),
        ("参考答案", "ans.pdf")]

for name, pdfn in JOBS:
    print("=" * 64)
    print(name)
    pdf = pdfium.PdfDocument(os.path.join(T, pdfn))
    for i in range(len(pdf)):
        im = pdf[i].render(scale=1.0).to_pil().convert("L")
        W, H = im.size
        data = im.tobytes()
        x0, x1 = int(2.6 * W / 21.0), int(18.9 * W / 21.0)   # 仅正文列，排除装订线
        footer_top = H - 55                                  # 页脚区起点（约 2cm）
        last = 0
        for y in range(60, footer_top):
            row = data[y * W + x0: y * W + x1]
            ink = sum(1 for v in row if v < 240)
            if ink > 6:
                last = y
        gap = (H - last) / 28.35 - 2.0
        print("  P%d 正文最低墨迹 y=%dpt｜距纸底 %.2fcm｜下边距外余白 %.2fcm｜占版心 %.0f%%"
              % (i + 1, last, (H - last) / 28.35, gap, (25.7 - gap) / 25.7 * 100))
