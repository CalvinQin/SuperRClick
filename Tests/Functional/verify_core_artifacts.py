#!/usr/bin/env python3
"""Independently inspect actual output files; no application or user data access."""
import json
import pathlib
import posixpath
import sys
import xml.etree.ElementTree as ET
import zipfile

root = pathlib.Path(sys.argv[1]).resolve()
assert str(root).startswith('/private/tmp/superrclick-functional-core-') or str(root).startswith('/tmp/superrclick-functional-core-')
results = json.loads((root / 'swift-results.json').read_text())


def check(name, operation):
    try:
        detail = operation()
        status = 'PASS'
    except Exception as exc:
        status, detail = 'FAIL', str(exc)
    results.append({'name': name, 'status': status, 'detail': detail})
    print(f'{status} | {name} | {detail}')


def office(ext, main_part):
    path = root / 'templates' / ext / f'Untitled.{ext}'
    # Apple's zip stores UTF-8 filename bytes without the ZIP UTF-8 flag.
    # Set the native filename encoding explicitly for independent payload checks.
    with zipfile.ZipFile(path, metadata_encoding='utf-8') as archive:
        assert archive.testzip() is None, 'ZIP CRC check failed'
        names = archive.namelist()
        assert len(names) == len(set(names)), 'Duplicate ZIP entries'
        for required in ['[Content_Types].xml', '_rels/.rels', main_part]:
            assert required in names, f'Missing {required}'
        for name in names:
            assert not name.startswith('/') and '..' not in pathlib.PurePosixPath(name).parts, f'Unsafe member {name}'
            if name.endswith(('.xml', '.rels')):
                parsed = ET.fromstring(archive.read(name))
                if name.endswith('.rels'):
                    base = '' if name == '_rels/.rels' else posixpath.dirname(posixpath.dirname(name))
                    for rel in parsed:
                        if rel.attrib.get('TargetMode') == 'External':
                            continue
                        target = rel.attrib['Target']
                        resolved = target.lstrip('/') if target.startswith('/') else posixpath.normpath(posixpath.join(base, target))
                        assert resolved in names, f'Broken relationship: {name} -> {resolved}'
        content_types = ET.fromstring(archive.read('[Content_Types].xml'))
        assert any(part.attrib.get('PartName') == '/' + main_part for part in content_types), 'Main document content type is missing'
        return f'{path}: {len(names)} members, all CRC/XML/internal relationships valid'


for extension, part in [('docx', 'word/document.xml'), ('xlsx', 'xl/workbook.xml'), ('pptx', 'ppt/presentation.xml')]:
    check(f'office-{extension}-zip-xml-relationships', lambda extension=extension, part=part: office(extension, part))


def verify_archive(expectation):
    path = pathlib.Path(expectation['archive']).resolve()
    assert root in path.parents
    source = pathlib.Path(expectation['sourceDirectory'])
    with zipfile.ZipFile(path, metadata_encoding='utf-8') as archive:
        assert archive.testzip() is None, 'ZIP CRC check failed'
        actual_files = {name for name in archive.namelist() if not name.endswith('/')}
        expected_files = set(expectation['members'].splitlines())
        assert actual_files == expected_files, f'Unexpected entries: {actual_files ^ expected_files}'
        for name in expected_files:
            assert archive.read(name) == (source / name).read_bytes(), f'Payload changed for {name}'
    return f'{path}: CRC, complete membership, and byte-for-byte extracted payloads verified'


for index, expectation in enumerate(json.loads((root / 'archive-expectations.json').read_text())):
    check(f'archive-integrity-{index + 1}', lambda expectation=expectation: verify_archive(expectation))

counts = {status: sum(row['status'] == status for row in results) for status in ['PASS', 'FAIL', 'BLOCKED', 'NOT-RUN']}
(root / 'results.json').write_text(json.dumps({'counts': counts, 'fixtures': str(root), 'results': results}, ensure_ascii=False, indent=2))
lines = ['# Core file operation functional tests', '', f'Fixtures: `{root}`', '',
         'The production executor and planner ran against temporary files. Finder reveal was replaced with a no-op.',
         'No clipboard, Terminal launch, application opening, account permissions, remote AI, or user files were used.', '',
         'PASS means the case executed and its expected output/failure handling was checked. Expected blocked/failed action results can pass their checks.', '',
         '| Test | Status | Actual execution evidence |', '| --- | --- | --- |']
for row in results:
    detail = row['detail'].replace('|', '\\|').replace('\n', ' ')
    lines.append(f"| {row['name']} | {row['status']} | {detail} |")
lines += ['', f'Totals: {counts}', '',
          'Not covered by this harness: Finder menu integration, GUI panels/cancel/navigation, app launch, clipboard, external app execution, remote AI, signing/notarization, and Intel execution.',
          'Office validation covers ZIP integrity, XML parsing, required parts, and internal relationship targets; opening in Microsoft Office was not run.']
lines += ['Apple system zip entries are decoded as UTF-8, matching native filenames. Cross-platform ZIP filename compatibility was not tested.']
(root / 'matrix.md').write_text('\n'.join(lines) + '\n')
print('Totals:', counts)
sys.exit(1 if counts['FAIL'] else 0)
