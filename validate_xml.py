import xml.etree.ElementTree as ET
from collections import Counter
import html

filename = "ININD03_banco_questoes_moodle_24_novo.xml"
required_types = ["calculatedmulti", "multichoice", "calculated", "numerical", "matching", "ddwtos", "gapselect", "ordering"]

try:
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pre-process content to handle undefined entities if necessary, 
    # but let's try a safer way to parse or fix the common ones.
    # ET.parse might fail on &nbsp; etc.
    
    # Simple fix for common HTML entities that are not standard XML
    content = content.replace('&nbsp;', '&#160;')
    
    root = ET.fromstring(content)
    print("1) O arquivo e bem-formado: Sim")
    
    questions = root.findall(".//question")
    total_questions = len(questions)
    print(f"2) Total de <question>: {total_questions}")
    
    types = [q.get("type") for q in questions if q.get("type") is not None]
    type_counts = Counter(types)
    print("3) Contagem por atributo type:")
    for t, count in sorted(type_counts.items()):
        print(f"   - {t}: {count}")
    
    print("\nVerificacao de tipos obrigatorios (3 de cada):")
    all_ok = True
    for rt in required_types:
        count = type_counts.get(rt, 0)
        status = "OK" if count == 3 else "FALHA"
        print(f"   - {rt}: {count} ({status})")
        if count != 3:
            all_ok = False
    
    if all_ok:
        print("\nResultado: Todos os tipos obrigatorios possuem exatamente 3 questoes.")
    else:
        print("\nResultado: Nem todos os tipos obrigatorios possuem exatamente 3 questoes.")

except ET.ParseError as e:
    print(f"1) O arquivo e bem-formado: Nao (Erro: {e})")
    # Tentar extrair contagem bruta via regex se o XML falhar
    import re
    print("\nTentando extrair dados via Regex devido ao erro de parser:")
    q_matches = re.findall(r'<question\s+type="([^"]+)"', content)
    total_q = len(q_matches)
    print(f"2) Total de <question> (Regex): {total_q}")
    counts = Counter(q_matches)
    print("3) Contagem por atributo type (Regex):")
    for t, count in sorted(counts.items()):
        print(f"   - {t}: {count}")
    
    all_ok = True
    for rt in required_types:
        count = counts.get(rt, 0)
        status = "OK" if count == 3 else "FALHA"
        print(f"   - {rt}: {count} ({status})")
        if count != 3:
            all_ok = False
    if all_ok:
        print("\nResultado (Regex): Todos os tipos obrigatorios possuem 3.")
    else:
        print("\nResultado (Regex): Falha na contagem.")

except Exception as e:
    print(f"Erro inesperado: {e}")
