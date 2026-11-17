# -*- coding: utf-8 -*-
"""用 WPS 把 docx 转 PDF，并输出页数"""
import sys, os, time
import win32com.client
import pypdfium2 as pdfium

src = os.path.abspath(sys.argv[1])
pdf = os.path.abspath(sys.argv[2])

app = win32com.client.Dispatch("KWps.Application")
app.Visible = False
try:
    doc = app.Documents.Open(src)
    time.sleep(0.3)
    try:
        doc.SaveAs(pdf, 17)
    except Exception:
        doc.SaveAs2(pdf, 17)
    doc.Close(0)
finally:
    try:
        app.Quit()
    except Exception:
        pass

d = pdfium.PdfDocument(pdf)
print('pages', len(d))
