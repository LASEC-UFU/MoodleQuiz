# -*- coding: utf-8 -*-
import xml.etree.ElementTree as ET
import matplotlib.pyplot as plt
import base64
import os
import io

def create_images():
    images = {}
    
    # q10
    plt.figure(figsize=(4, 3))
    plt.plot([0, 50, 100], [0, 55, 100], 'r-o', label='Subida')
    plt.plot([100, 50, 0], [100, 45, 0], 'b-o', label='Descida')
    plt.title("Curva de Histerese")
    plt.legend()
    plt.grid(True)
    buf = io.BytesIO()
    plt.savefig(buf, format='png')
    images['q10_histerese_curva.png'] = base64.b64encode(buf.getvalue()).decode('utf-8')
    plt.close()

    # q12
    plt.figure(figsize=(4, 2))
    plt.axis('off')
    plt.text(0.1, 0.5, 'SP')
    plt.text(0.35, 0.5, 'Controlador', bbox=dict(facecolor='lightgrey'))
    plt.text(0.65, 0.5, 'Processo', bbox=dict(facecolor='lightgrey'))
    plt.text(0.85, 0.5, 'PV')
    plt.title("Malha SP-PV-MV")
    buf = io.BytesIO()
    plt.savefig(buf, format='png')
    images['q12_malha_sp_pv_mv.png'] = base64.b64encode(buf.getvalue()).decode('utf-8')
    plt.close()

    # q13
    plt.figure(figsize=(4, 4))
    plt.plot([1, 1, 2, 2], [4, 1, 1, 4], 'k')
    plt.title("Manometro em U")
    plt.axis('off')
    buf = io.BytesIO()
    plt.savefig(buf, format='png')
    images['q13_manometro_u.png'] = base64.b64encode(buf.getvalue()).decode('utf-8')
    plt.close()
    
    return images

def process_xml(input_file, output_file, images):
    tree = ET.parse(input_file)
    root = tree.getroot()
    mapping = {
        "Q10 - Histerese": "q10_histerese_curva.png",
        "Q12 - Ordenacao": "q12_malha_sp_pv_mv.png",
        "Q13 - Arrastar": "q13_manometro_u.png"
    }
    for question in root.findall('.//question'):
        name_node = question.find('name/text')
        if name_node is None or not name_node.text: continue
        filename = next((v for k, v in mapping.items() if k in name_node.text), None)
        if filename:
            qt_node = question.find('questiontext')
            if qt_node is not None:
                text_node = qt_node.find('text')
                img_tag = f'<p><img src="@@PLUGINFILE@@/{filename}" alt="{filename}"/></p>'
                text_node.text = img_tag + (text_node.text or "")
                file_node = ET.SubElement(qt_node, 'file')
                file_node.set('name', filename); file_node.set('path', '/'); file_node.set('encoding', 'base64')
                file_node.text = images[filename]
    tree.write(output_file, encoding='UTF-8', xml_declaration=True)

in_p = 'ININD03_banco_questoes_moodle_24_novo.xml'
out_p = 'ININD03_banco_questoes_moodle_24_novo_v2_imagens.xml'
process_xml(in_p, out_p, create_images())
size_mb = os.path.getsize(out_p) / (1024*1024)
root = ET.parse(out_p).getroot()
qs = root.findall('.//question')
print(f'Size: {size_mb:.2f} MB')
print(f'Total: {len(qs)}')
types = {}
for q in qs:
    t = q.get('type')
    types[t] = types.get(t, 0) + 1
for t, c in sorted(types.items()):
    print(f'{t}: {c}')
