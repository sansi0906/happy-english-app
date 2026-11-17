# -*- coding: utf-8 -*-
"""试卷生成公共库：页面设置、卷头、得分表、题号、米字格、答题方格、页脚页码"""
import os, hashlib
from PIL import Image, ImageDraw, ImageFont
from docx import Document
from docx.shared import Pt, Cm, Emu, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.enum.table import WD_ALIGN_VERTICAL
from docx.enum.section import WD_SECTION
from docx.oxml.ns import qn, nsdecls
from docx.oxml import OxmlElement, parse_xml

TMP = os.path.join(os.path.dirname(os.path.abspath(__file__)), '_tmp')
os.makedirs(TMP, exist_ok=True)
FONT_MJ = r'C:\Windows\Fonts\simkai.ttf'
S = 480
LINE = (150, 150, 150, 255)
CHAR = (170, 170, 170, 255)
RATIO = 0.75
CELL_EMU = 529167          # 14.7mm 见方


def mizige(ch, out=None):
    """生成米字格 PNG（ch 为空则空格）"""
    tag = hashlib.md5((ch or 'blank').encode()).hexdigest()[:8]
    if out is None:
        out = os.path.join(TMP, 'mz_%s.png' % tag)
    if os.path.exists(out):
        return out
    img = Image.new('RGB', (S, S), (255, 255, 255))
    d = ImageDraw.Draw(img)
    lw = 5; m = 6; mid = S // 2
    d.rectangle([m, m, S - 1 - m, S - 1 - m], outline=LINE, width=lw)
    d.line([mid, m, mid, S - 1 - m], fill=LINE, width=lw)
    d.line([m, mid, S - 1 - m, mid], fill=LINE, width=lw)
    d.line([m, m, S - 1 - m, S - 1 - m], fill=LINE, width=lw)
    d.line([m, S - 1 - m, S - 1 - m, m], fill=LINE, width=lw)
    if ch:
        size = int((S - 2 * m) * RATIO)
        f = ImageFont.truetype(FONT_MJ, size)
        asc, desc = f.getmetrics()
        baseline = (S - (asc + desc)) // 2 + asc
        x = (S - size) // 2
        d.text((x, baseline), ch, font=f, fill=CHAR, anchor='ls')
    img.save(out)
    return out


def setup_page(doc, draw_line=True):
    sec = doc.sections[0]
    sec.page_width = Cm(21.0)
    sec.page_height = Cm(29.7)
    sec.top_margin = Cm(2.0)
    sec.bottom_margin = Cm(2.0)
    sec.left_margin = Cm(2.2)
    sec.right_margin = Cm(1.8)
    sec.header_distance = Cm(1.0)
    sec.footer_distance = Cm(1.0)
    if draw_line:
        sectPr = sec._sectPr
        old = sectPr.find(qn('w:pgBorders'))
        if old is not None:
            sectPr.remove(old)
        el = parse_xml('<w:pgBorders %s w:offsetFrom="page">'
                       '<w:left w:val="single" w:sz="4" w:space="30" w:color="999999"/>'
                       '</w:pgBorders>' % nsdecls('w'))
        sectPr.append(el)


def style_font(run, size, name='楷体', bold=False, color=None, latin='Times New Roman'):
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.name = latin
    rPr = run._element.get_or_add_rPr()
    rf = rPr.find(qn('w:rFonts'))
    if rf is None:
        rf = OxmlElement('w:rFonts'); rPr.append(rf)
    rf.set(qn('w:ascii'), latin)
    rf.set(qn('w:hAnsi'), latin)
    rf.set(qn('w:eastAsia'), name)
    if color:
        run.font.color.rgb = color


def para(doc, text='', size=16, name='楷体', bold=False,
         align='left', before=0, after=0, line=None, indent_first=0, indent_left=0):
    p = doc.add_paragraph()
    pf = p.paragraph_format
    pf.space_before = Pt(before)
    pf.space_after = Pt(after)
    if line:
        pf.line_spacing = Pt(line)
        pf.line_spacing_rule = WD_LINE_SPACING.EXACTLY
    if indent_first:
        pf.first_line_indent = Pt(indent_first)
    if indent_left:
        pf.left_indent = Pt(indent_left)
    p.alignment = {'left': WD_ALIGN_PARAGRAPH.LEFT, 'center': WD_ALIGN_PARAGRAPH.CENTER,
                   'right': WD_ALIGN_PARAGRAPH.RIGHT, 'justify': WD_ALIGN_PARAGRAPH.JUSTIFY}[align]
    if text:
        r = p.add_run(text)
        style_font(r, size, name, bold)
    return p


def set_cell_border(cell, sz=6, color='000000'):
    tcPr = cell._tc.get_or_add_tcPr()
    borders = parse_xml('<w:tcBorders %s>'
                        '<w:top w:val="single" w:sz="%d" w:space="0" w:color="%s"/>'
                        '<w:left w:val="single" w:sz="%d" w:space="0" w:color="%s"/>'
                        '<w:bottom w:val="single" w:sz="%d" w:space="0" w:color="%s"/>'
                        '<w:right w:val="single" w:sz="%d" w:space="0" w:color="%s"/>'
                        '</w:tcBorders>' % (nsdecls('w'), sz, color, sz, color, sz, color, sz, color))
    tcPr.append(borders)


def add_score_table(doc, n_parts):
    """得分栏：题号行 + 得分行"""
    cols = n_parts + 2
    tbl = doc.add_table(rows=2, cols=cols)
    tbl.autofit = False
    total_w = Cm(16.6)
    cell_w = total_w / cols
    heads = ['题号'] + ['一', '二', '三', '四', '五', '六', '七', '八', '九'][:n_parts] + ['总分']
    cells0 = tbl.rows[0].cells
    cells1 = tbl.rows[1].cells
    for i in range(cols):
        for cell in (cells0[i], cells1[i]):
            cell.width = cell_w
            set_cell_border(cell)
            cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
        for cell, txt in ((cells0[i], heads[i]), (cells1[i], '得分' if i == 0 else '')):
            p = cell.paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.space_before = Pt(2)
            p.paragraph_format.space_after = Pt(2)
            r = p.add_run(txt)
            style_font(r, 10.5, '宋体', bold=(txt == '题号'))
    for row in tbl.rows:
        row.height = Cm(0.85)
    return tbl


def add_footer_page(doc, total_pages=4):
    footer = doc.sections[0].footer
    footer.is_linked_to_previous = False
    p = footer.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run('第 ')
    style_font(r, 10.5, '宋体')
    _field(p, ' PAGE ')
    r2 = p.add_run(' 页（共 %d 页）' % total_pages)
    style_font(r2, 10.5, '宋体')


def _field(p, code):
    r = p.add_run()
    style_font(r, 10.5, '宋体')
    f1 = OxmlElement('w:fldChar'); f1.set(qn('w:fldCharType'), 'begin')
    it = OxmlElement('w:instrText'); it.set(qn('xml:space'), 'preserve'); it.text = code
    f2 = OxmlElement('w:fldChar'); f2.set(qn('w:fldCharType'), 'separate')
    t = OxmlElement('w:t'); t.text = '1'
    f3 = OxmlElement('w:fldChar'); f3.set(qn('w:fldCharType'), 'end')
    r._r.append(f1); r._r.append(it); r._r.append(f2); r._r.append(t); r._r.append(f3)


def exam_head(doc, title, sub, n_parts, note=None):
    para(doc, title, size=22, name='黑体', bold=True, align='center', after=4, line=30)
    para(doc, sub, size=12, name='宋体', align='center', after=8, line=18)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(6)
    r = p.add_run('学校：____________　班级：__________　姓名：__________　学号：__________')
    style_font(r, 11, '宋体')
    add_score_table(doc, n_parts)
    if note:
        para(doc, note, size=10.5, name='宋体', after=4, line=16)


def h1(doc, text):
    p = para(doc, text, size=17, name='黑体', bold=True, before=16, after=6, line=28)
    p.paragraph_format.keep_with_next = True
    return p


def q(doc, text, size=17, before=0, after=2, line=32, indent=16):
    return para(doc, text, size=size, name='楷体', before=before, after=after, line=line, indent_left=indent)


def answer_line(doc, label='', size=16, line=28, indent=16):
    p = doc.add_paragraph()
    pf = p.paragraph_format
    pf.left_indent = Pt(indent)
    pf.space_before = Pt(0); pf.space_after = Pt(2)
    pf.line_spacing = Pt(line); pf.line_spacing_rule = WD_LINE_SPACING.EXACTLY
    if label:
        r = p.add_run(label)
        style_font(r, size, '楷体')
    return p


def mizige_strip(chars, out=None):
    """整行米字格画在一张横条 PNG 上，相邻格共用一条边框线"""
    tag = hashlib.md5(('S3' + '|'.join(chars)).encode()).hexdigest()[:8]
    if out is None:
        out = os.path.join(TMP, 'mzs_%s.png' % tag)
    if os.path.exists(out):
        return out
    n = len(chars)
    lw = 6; m = 6; mid = S // 2
    cw = S - 2 * m                 # 共用边框后的单格宽
    W = cw * n + 2 * m
    img = Image.new('RGB', (W, S), (255, 255, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([m, m, W - 1 - m, S - 1 - m], outline=LINE, width=lw)   # 整行外框
    ys = m; ye = S - 1 - m
    for i in range(1, n):
        x = m + i * cw
        d.line([x, ys, x, ye], fill=LINE, width=lw)                     # 格间竖线
    for i in range(n):
        x0 = m + i * cw; x1 = x0 + cw; xm = x0 + cw // 2
        d.line([xm, ys, xm, ye], fill=LINE, width=lw)                   # 竖中线
        d.line([x0, mid, x1, mid], fill=LINE, width=lw)                 # 横中线
        d.line([x0, ys, x1, ye], fill=LINE, width=lw)                   # 对角线
        d.line([x0, ye, x1, ys], fill=LINE, width=lw)
    canvas = img
    canvas.save(out)
    return out


def mizige_row(doc, chars, indent=14, after=4, per_line=8):
    """一行米字格（chars 可为范字或空；indent=None 表示整行居中）"""
    p = doc.add_paragraph()
    pf = p.paragraph_format
    if indent is None:
        pf.alignment = WD_ALIGN_PARAGRAPH.CENTER
    else:
        pf.left_indent = Pt(indent)
    pf.space_before = Pt(2); pf.space_after = Pt(after)
    # 行距用"最小值"规则，避免单倍行距把内联图片按行高压扁
    pPr = p._p.get_or_add_pPr()
    sp = pPr.find(qn('w:spacing'))
    if sp is None:
        sp = OxmlElement('w:spacing'); pPr.append(sp)
    sp.set(qn('w:line'), '960'); sp.set(qn('w:lineRule'), 'atLeast')
    # 整行拼成一张图（单张内联图不会被裁），按格数给定总宽，每格约 1.47cm
    n = len(chars)
    p.add_run().add_picture(mizige_strip(list(chars)), width=Emu(CELL_EMU * n))
    return p


def write_grid(doc, rows=3, cols=16, cell_cm=0.95, indent=14):
    """写话方格"""
    tbl = doc.add_table(rows=rows, cols=cols)
    tbl.autofit = False
    for row in tbl.rows:
        row.height = Cm(cell_cm)
        # 行内禁止跨页，整块格子不被拆开
        trPr = row._tr.get_or_add_trPr()
        cs = OxmlElement('w:cantSplit')
        trPr.append(cs)
        for cell in row.cells:
            cell.width = Cm(cell_cm)
            set_cell_border(cell, sz=6, color='808080')
    return tbl
