"""Dependency-free source integrity check; NOT a Dart compiler or analyzer."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]

def check_delimiters(text, path):
    size=len(text)
    def string(i, raw=False):
        quote=text[i]; i+=1
        while i<size:
            if text[i]==quote:return i+1
            if not raw and text[i]=='\\': i+=2;continue
            if not raw and text.startswith('${',i): i=code(i+2,True);continue
            i+=1
        raise AssertionError(f'{path}: unclosed string')
    def code(i, interpolation=False):
        stack=[]
        while i<size:
            if text.startswith('//',i):
                end=text.find('\n',i);i=size if end<0 else end+1;continue
            if text.startswith('/*',i):
                end=text.find('*/',i+2);assert end>=0,f'{path}: unclosed comment';i=end+2;continue
            if text[i]=='r' and i+1<size and text[i+1] in "\"'":i=string(i+1,True);continue
            if text[i] in "\"'":i=string(i);continue
            ch=text[i]
            if ch in '([{':stack.append((ch,i))
            elif ch in ')]}':
                if interpolation and ch=='}' and not stack:return i+1
                assert stack,f'{path}: extra {ch} at {i}'
                prev,j=stack.pop();assert '([{'.index(prev)==')]}'.index(ch),f'{path}: mismatched {prev} at {j} vs {ch} at {i}'
            i+=1
        assert not stack,f'{path}: unclosed {stack}'
        assert not interpolation,f'{path}: unclosed interpolation'
        return i
    code(0)

files=list((root/'lib').rglob('*.dart'))+list((root/'test').rglob('*.dart'))
for file in files:
    source=file.read_text();check_delimiters(source,file.relative_to(root))
    for target in re.findall(r"import '([^']+)'",source):
        if not target.startswith(('package:','dart:')):
            assert (file.parent/target).resolve().is_file(),(file,target)
        elif target.startswith('package:foodieit/'):
            assert (root/'lib'/target.removeprefix('package:foodieit/')).is_file(),(file,target)
assert 'admin@example' in (root/'lib/services/app_store.dart').read_text()
assert 'admin 123' in (root/'lib/services/app_store.dart').read_text()
print(f'PASS: {len(files)} Dart files: balanced delimiters, local imports and demo credentials present')
