#!/usr/bin/python

from gzip import GzipFile
import os
import sys
import argparse
import tempfile

def list_files(base_dir):
    result = []
    def list_files_(dir, prefix):
        for item in os.listdir(dir):
            if os.path.isfile(os.path.join(dir, item)):
                result.append(os.path.join(prefix, item))
            elif os.path.isdir(os.path.join(dir, item)):
                list_files_(os.path.join(dir, item),
                        os.path.join(prefix, item))
    list_files_(base_dir, '')
    return result

def plowup(args, file):
    file = os.path.join(args.dir, file)
    output = tempfile.NamedTemporaryFile(delete=False)
    os.system("bash -c 'plowup Sendspace %(file)s | tail -n 1 &> %(output)s'" %
            {'file': file, 'output': output.name})
    url = open(output.name).read().strip()
    os.unlink(output.name)
    return url

def backup_file(args, file):
    o = args.out
    dir = os.path.dirname(file)
    dir_opt = ''
    if dir:
        o.write('mkdir -p %s\n' % dir)
        dir_opt = '-o ' + dir
    url = plowup(args, file)
    o.write('plowdown %(dir_opt)s %(url)s\n' %
            {'dir_opt': dir_opt, 'url': url})

r = argparse.FileType('r')
w = argparse.FileType('w')

p = argparse.ArgumentParser(description='Plow Backup',
    formatter_class=argparse.ArgumentDefaultsHelpFormatter)
p.add_argument('-v','--version',action='version',version='%(prog)s 1.0')
p.add_argument('--dir',help='Directory',metavar='DIR')
p.add_argument('--out',help='Output file for script',
        metavar='FILE',type=w,default='-')

args = p.parse_args()
base_dir = args.dir

files = list_files(base_dir)
for file in files:
    backup_file(args, file)

