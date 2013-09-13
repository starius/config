#!/usr/bin/python

from gzip import GzipFile
import os
import sys
import argparse
import tempfile
from random import randint, choice
import string

# The characters to make up the random password
chars = string.ascii_letters + string.digits

def random_password():
    return "".join(choice(chars) for x in range(randint(8, 12)))

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
    upload_file = os.path.join(args.dir, file)
    # encrypt
    encrypted = ''
    key = ''
    if args.encrypt:
        encrypted = tempfile.NamedTemporaryFile(delete=False)
        key = random_password()
        os.system("cat %(upload_file)s | ccrypt -e -K %(key)s > %(encrypted)s" %
                {'upload_file': upload_file, 'key': key,
                 'encrypted': encrypted.name})
        upload_file = encrypted.name
    # upload
    url = plowup(args, upload_file)
    # delete tmp files
    if args.encrypt:
        os.unlink(encrypted.name)
    if args.encrypt:
        o.write('plowdown -o $tmpdir %s\n' % url)
        o.write('f=$(find $tmpdir -type f)\n')
        o.write('cat $f|ccrypt -d -K %(key)s > %(file)s\n' %
                {'key': key, 'file': file})
        o.write('rm $f\n')
    else:
        o.write('plowdown %(dir_opt)s %(url)s\n' %
                {'dir_opt': dir_opt, 'url': url})

r = argparse.FileType('r')
w = argparse.FileType('w')

p = argparse.ArgumentParser(description='Plow Backup',
    formatter_class=argparse.ArgumentDefaultsHelpFormatter)
p.add_argument('-v','--version',action='version',version='%(prog)s 1.0')
p.add_argument('--dir',help='Directory',metavar='DIR', default='.')
p.add_argument('--out',help='Output file for script',
        metavar='FILE',type=w,default='-')
p.add_argument('--encrypt',help='Encrypt files with ccrypt',
        metavar='DIR',type=bool,default=True)

args = p.parse_args()
base_dir = args.dir

files = list_files(base_dir)
for file in files:
    o = args.out
    o.write('tmpdir=$(mktemp -d)\n')
    backup_file(args, file)
    o.write('rmdir $tmpdir\n')

