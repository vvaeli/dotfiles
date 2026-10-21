#!/usr/bin/env python3
"""Bounded arithmetic and fd search, without evaluating Python or shell code."""
import ast
import json
import math
import operator
from pathlib import Path
import re
import subprocess
import sys

OPERATORS = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul,
             ast.Div: operator.truediv, ast.FloorDiv: operator.floordiv,
             ast.Mod: operator.mod, ast.Pow: operator.pow}
FUNCTIONS = {'sqrt': math.sqrt, 'sin': math.sin, 'cos': math.cos, 'tan': math.tan,
             'log': math.log, 'log10': math.log10, 'abs': abs, 'round': round}

def bounded(value):
    if isinstance(value, int) and value.bit_length() > 4096: raise ValueError('Слишком большое число')
    if isinstance(value, float) and not math.isfinite(value): raise ValueError('Результат вне диапазона')
    if not isinstance(value, (int, float)): raise ValueError('Недопустимый результат')
    return value

def evaluate(node):
    if isinstance(node, ast.Constant) and type(node.value) in (int, float): return bounded(node.value)
    if isinstance(node, ast.Name) and node.id in ('pi', 'e'): return getattr(math, node.id)
    if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.UAdd, ast.USub)):
        return bounded(evaluate(node.operand) * (-1 if isinstance(node.op, ast.USub) else 1))
    if isinstance(node, ast.BinOp) and type(node.op) in OPERATORS:
        left, right = evaluate(node.left), evaluate(node.right)
        if isinstance(node.op, ast.Pow) and abs(right) > 1000: raise ValueError('Слишком большая степень')
        return bounded(OPERATORS[type(node.op)](left, right))
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id in FUNCTIONS and not node.keywords and len(node.args) <= 2:
        return bounded(FUNCTIONS[node.func.id](*[evaluate(arg) for arg in node.args]))
    raise ValueError('Недопустимое выражение')

def calculate(query):
    expression = query.strip().removeprefix('=').strip()
    conversion = re.fullmatch(r'(.+?)\s+in\s+(dec|hex|bin|oct)', expression, re.I)
    if conversion: expression = conversion[1]
    if len(expression) > 200: raise ValueError('Слишком длинное выражение')
    value = evaluate(ast.parse(expression.replace('^', '**'), mode='eval').body)
    if conversion:
        if value != int(value): raise ValueError('Для смены системы счисления нужно целое число')
        return {'dec': str, 'hex': hex, 'bin': bin, 'oct': oct}[conversion[2].lower()](int(value))
    return format(value, '.12g') if isinstance(value, float) else str(value)

def disk_roots():
    # Disks live in /run/media/<user> (fstab automounts and udisks). Skip one whose disk is
    # unplugged: reading its automount point would block until the device timeout.
    media = Path('/run/media') / Path.home().name
    present = {}
    try:
        for line in Path('/etc/fstab').read_text().splitlines():
            fields = line.split()
            if len(fields) > 1 and fields[0].startswith('UUID=') and fields[1].startswith(str(media) + '/'):
                present[fields[1]] = Path('/dev/disk/by-uuid', fields[0][5:]).exists()
        children = sorted(media.iterdir())
    except OSError:
        return []
    return [str(path) for path in children if present.get(str(path), True) and path.is_dir()]

def search(query, roots=None):
    query = query.strip()
    results = []
    mathematical = bool(re.match(r'^[=\d(+-]|^(sqrt|sin|cos|tan|log|abs|round|pi\b|e\b)', query))
    if mathematical:
        try:
            answer = calculate(query)
            results.append(dict(kind='calc', name=answer, detail=query + ' · Enter — скопировать результат', value=answer))
            return results
        except (ValueError, SyntaxError, TypeError, ArithmeticError) as error:
            if query.startswith('='):
                return [dict(kind='error', name='Не удалось вычислить', detail=str(error))]
    term = query[1:].strip() if query.startswith('/') else query[5:].strip() if query.startswith('file ') else query
    if len(term) < 2: return results
    roots = roots or [str(Path.home()), *disk_roots()]
    command = ['fd', '--fixed-strings', '--ignore-case', '--absolute-path', '--print0', '--max-results', '60', '--', term, *roots]
    try:
        output = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=3, check=False).stdout
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b''
    for raw in output.split(b'\0'):
        if not raw: continue
        path = Path(raw.decode('utf-8', 'replace'))
        results.append(dict(kind='file', name=path.name, detail=str(path), path=str(path)))
    return results

if __name__ == '__main__':
    if sys.argv[1] == 'copy':
        subprocess.run(['wl-copy', '--type', 'text/plain;charset=utf-8'], input=sys.argv[2].encode(), check=True)
    else:
        print(json.dumps(search(sys.argv[2]), ensure_ascii=False))
