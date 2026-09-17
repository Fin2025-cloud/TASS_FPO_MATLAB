"""Word97 compatibility: preserve all math as explicitly editable linear expressions."""
from pathlib import Path
from docx import Document
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
import sys
root=Path(__file__).resolve().parents[1]
def linear(x):
    tag=x.tag.split('}')[-1]
    children=lambda:''.join(linear(y) for y in x)
    at=lambda n:next((y for y in x if y.tag==qn('m:'+n)),None)
    text=lambda n:linear(at(n)) if at(n) is not None else ''
    if tag=='t':return x.text or ''
    if tag in ['rPr','ctrlPr','accPr','radPr','fPr']:return ''
    if tag=='f':return '('+text('num')+')/('+text('den')+')'
    if tag=='rad':return 'sqrt('+text('e')+')'
    if tag=='sSub':return text('e')+'_{'+text('sub')+'}'
    if tag=='sSup':return text('e')+'^{'+text('sup')+'}'
    if tag=='sSubSup':return text('e')+'_{'+text('sub')+'}^{'+text('sup')+'}'
    if tag=='acc':
        a=at('accPr');chars=[z.get(qn('m:val')) for z in a] if a is not None else []
        return ('dot' if '̇' in chars else 'mean')+'('+text('e')+')'
    return children()
doc=Document(root/'paper/TAAS-FPO_论文稿_待填实验结果.docx')
for om in list(doc.element.iter(qn('m:oMath'))):
    txt=linear(om)
    run=OxmlElement('w:r');pr=OxmlElement('w:rPr')
    ff=OxmlElement('w:rFonts');ff.set(qn('w:ascii'),'Cambria Math');ff.set(qn('w:hAnsi'),'Cambria Math');pr.append(ff)
    size=OxmlElement('w:sz');size.set(qn('w:val'),'18');pr.append(size);run.append(pr)
    t=OxmlElement('w:t');t.set(qn('xml:space'),'preserve');t.text=txt;run.append(t)
    om.getparent().replace(om,run)
for p in doc.paragraphs:
    if p.text.startswith('稿件状态：'):
        p.add_run(' DOC兼容版：公式为可编辑线性表达；标准公式请编辑DOCX主文件。')
out=Path(sys.argv[1]);out.parent.mkdir(parents=True,exist_ok=True);doc.save(out)
print('Word97 compatibility source built; all mathematical content preserved as linear text.')
