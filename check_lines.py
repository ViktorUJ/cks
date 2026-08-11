import sys

path = sys.argv[1]
in_code = False
with open(path, encoding='utf-8') as f:
    for i, line in enumerate(f, 1):
        line = line.rstrip('\n')
        stripped = line.strip()
        if stripped.startswith('```'):
            in_code = not in_code
            continue
        if in_code:
            continue
        if stripped.startswith('|') or stripped.startswith('---'):
            continue
        if len(line) > 95:
            print(i, len(line), line)
