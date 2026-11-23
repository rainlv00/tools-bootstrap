#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""打包技能为分发 zip，并在打包过程中抹掉真实客户/项目名。

母本（~/.workbuddy/skills/清单整理）保持原样，只在副本上替换。
    python build_bundle.py
    python build_bundle.py --check-only      # 只扫有没有漏网的敏感词
"""
import argparse
import os
import re
import shutil
import sys
import tempfile
import zipfile

SRC = r'C:/Users/Administrator/.workbuddy/skills/清单整理'
OUT = 'bundle.zip'
TOP = '清单整理'
TEXT_EXT = {'.md', '.py', '.json', '.txt', '.ps1'}
SKIP_DIRS = {'__pycache__', '.git', '.pytest_cache'}

# 长的放前面，避免被短词先吃掉
MAP = [
    ('佛山市南海雅格美天家具有限公司', '某家具制造有限公司'),
    ('雅格美天酒店家具报价单', '酒店家具报价单'),
    ('雅格美天', '某家具'),
    ('GPH Grand Papua', '某海外项目'),
    ('GRM Nakuru', '某海外项目'),
    ('海风小区希尔顿', '某酒店项目'),
    ('Hilton Jaipur', '某酒店项目'),
    ('Fili Bridgetown Hotel', '某酒店'),
    ('Fili Bridgetowne Hotel', '某酒店'),
    ('AIRWAYS RESIDENCES|Papua New Guinea|', ''),
    ('AIRWAYS RESIDENCES', '项目名称'),
    ('Grand Papua', '某海外项目'),
    ('Nakuru', '某海外项目'),
    ('海风小区', '某酒店项目'),
    ('希尔顿', '某酒店'),
    ('Hilton', '某酒店'),
    ('Jaipur', ''),
    ('Bridgetown', ''),
    ('Fili', ''),
    ('KM 方舟', '某项目'),
    ('KM方舟', '某项目'),
    ('肯尼亚', '海外'),
    ('GRAND BAR', '吧台区域'),
    ('GPH', '某项目'),
    ('GRM', '某项目'),
    ('FHB', '某项目'),
]

BANNED = ['GPH', 'GRM', 'Nakuru', 'Papua', 'Hilton', '希尔顿', '海风', '方舟',
          '肯尼亚', 'Jaipur', 'Fili', 'Bridgetown', 'FHB', 'GRAND BAR',
          'AIRWAYS RESIDENCES', 'Oscar', '雅格美天', '南海']


def scrub(text, stats):
    for old, new in MAP:
        n = text.count(old)
        if n:
            text = text.replace(old, new)
            stats[old] = stats.get(old, 0) + n
    return text


def check(root):
    hits = []
    for d, dirs, fs in os.walk(root):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
        for f in fs:
            if os.path.splitext(f)[1].lower() not in TEXT_EXT:
                continue
            p = os.path.join(d, f)
            try:
                t = open(p, encoding='utf-8').read()
            except UnicodeDecodeError:
                continue
            for w in BANNED:
                if w in t:
                    line = t[:t.index(w)].count('\n') + 1
                    hits.append((os.path.relpath(p, root), line, w))
    return hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check-only', action='store_true')
    ap.add_argument('--src', default=SRC)
    ap.add_argument('--out', default=OUT)
    a = ap.parse_args()

    if a.check_only:
        hits = check(a.src)
        if not hits:
            print('干净：没扫到敏感词')
            return
        print('发现 %d 处：' % len(hits))
        for f, ln, w in hits:
            print('  %s:%d  %s' % (f, ln, w))
        sys.exit(1)

    tmp = tempfile.mkdtemp(prefix='bundle_')
    dst = os.path.join(tmp, TOP)
    shutil.copytree(a.src, dst, ignore=shutil.ignore_patterns(*SKIP_DIRS))

    stats, files = {}, 0
    for d, dirs, fs in os.walk(dst):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
        for f in sorted(fs):
            p = os.path.join(d, f)
            if os.path.splitext(f)[1].lower() in TEXT_EXT:
                try:
                    t = open(p, encoding='utf-8').read()
                except UnicodeDecodeError:
                    continue
                t2 = scrub(t, stats)
                if t2 != t:
                    open(p, 'w', encoding='utf-8', newline='').write(t2)
            files += 1

    left = check(dst)
    if left:
        print('!! 仍有 %d 处敏感词，已中止：' % len(left))
        for f, ln, w in left:
            print('   %s:%d  %s' % (f, ln, w))
        shutil.rmtree(tmp, ignore_errors=True)
        sys.exit(2)

    with zipfile.ZipFile(a.out, 'w', zipfile.ZIP_DEFLATED) as z:
        for d, dirs, fs in os.walk(dst):
            dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS)
            for f in sorted(fs):
                p = os.path.join(d, f)
                z.write(p, TOP + '/' + os.path.relpath(p, dst).replace('\\', '/'))

    size = os.path.getsize(a.out) / 1024
    print('打包完成 %s  %.1f KB  %d 个文件' % (a.out, size, files))
    print('脱敏替换：')
    for k, v in sorted(stats.items(), key=lambda x: -x[1]):
        print('  %-22s %d 处' % (k, v))
    print('残留敏感词：0')
    shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    main()
