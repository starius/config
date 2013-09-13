#!/usr/bin/python

""" PlowBackup, tool for encrypted backup across several web-sites
Copyright (C) 2013 Boris Nagaev <bnagaev@gmail.com>

PlowBackup is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

PlowBackup is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with PlowBackup.  If not, see <http://www.gnu.org/licenses/>.

Usage:

Backup:
$ cd backup
$ plowbackup --out /path/to/download.sh

Restore:
$ cd /empty/dir
$ sh /path/to/download.sh

By default, all files are encrupted with one-off keys.
Obscurity through other filters like xxd, rot13 etc is added.
You can add your own filters (see xxd_filters for example).
Set of sites to be used is specified by command line
option --sites.

Good sites:
    * Sendspace
    * Sharebeast
    * mega (required plugin plowshare-plugin-mega

Working with delay:
    * hipfile
    * 1fichier
    * uptobox
    * netload_in
    * bayfiles

Requirements:
    * plowshare (tested Sep 1 2013)
    * bash
    * cut
    * ccrypt
    * xxd
    * rot13

For list of filters, see var FILTERS.
"""

from gzip import GzipFile
import os
import sys
import argparse
import tempfile
from random import randint, choice
import string
import filecmp
import time
try:
    from StringIO import StringIO
except ImportError:
    from io import StringIO

# The characters to make up the random password
chars = string.ascii_letters + string.digits

def random_password():
    return "".join(choice(chars) for x in range(randint(8, 12)))

def random_filename():
    def photo():
        return 'P' + str(randint(1000000, 2000000)) + '.JPG'
    def mhtml():
        return random_password() + '.mhtml'
    def mp4():
        return random_password() + '.mp4'
    def txt():
        return random_password() + '.txt'
    def mp3():
        return random_password() + '.mp3'
    return choice([photo, mhtml, mp4, txt, mp3])()

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
    if args.sites == 'local':
        name = file.replace('/', '_')
        local = '/tmp/local_' + random_password() + '_' + name
        os.system("cp %(file)s %(local)s" %
                {'file': file, 'local': local})
        return local
    else:
        output = tempfile.NamedTemporaryFile(delete=False)
        site = choice(args.sites_list)
        name = random_filename()
        os.system(("bash -c 'plowup %(site)s " +
                  " %(file)s:%(name)s "+
                  "| tail -n 1 &> %(output)s'") %
                  {'file': file, 'site': site,
                   'output': output.name, 'name': name})
        url = open(output.name).read().strip()
        os.unlink(output.name)
        return url

class Filter(object):
    def __init__(self):
        self.pattern = 'cp %(in)s %(out)s'

    def encode(self, in_file, out_file):
        return self.pattern % \
                {'in': in_file, 'out': out_file}

class FilterChain(object):
    def __init__(self):
        self.filters = []

    def push_back(self, filter):
        self.filters.append(filter)

    def push_front(self, filter):
        self.filters.insert(0, filter)

    def encode(self, in_file, out_file):
        if not self.filters:
            return 'cp %(in)s %(out)s\n' %\
                   {'in': in_file, 'out': out_file}
        result = []
        result.append('f1=$(mktemp)')
        result.append('f2=$(mktemp)')
        result.append('cp %(in)s $f1' % {'in': in_file})
        for filter in self.filters:
            result.append(filter.encode('$f1', '$f2'))
            result.append('mv $f2 $f1')
        result.append('cp $f1 %(out)s ' % {'out': out_file})
        result.append('rm $f1')
        result.append('rm -f $f2')
        return '\n'.join(result) + '\n'

def encrypt_filters(args):
    key = random_password()
    class E(Filter):
        def __init__(self):
            self.pattern = "cat %(in)s | ccrypt -e -K " + \
                    key + " > %(out)s"
    class D(Filter):
        def __init__(self):
            self.pattern = "cat %(in)s | ccrypt -d -K " + \
                    key + " > %(out)s"
    return E(), D()

def head_tail_filters(args):
    head = str(randint(10, 1000))
    tail = str(randint(10, 1000))
    class E(Filter):
        def __init__(self):
            self.pattern =\
                    "head -c " + head +\
                    " /dev/urandom > %(out)s;"+\
                    "cat %(in)s >> %(out)s;"+\
                    "head -c " + tail +\
                    " /dev/urandom >> %(out)s"
    class D(Filter):
        def __init__(self):
            self.pattern =\
                    "dd if=%(in)s of=%(out)s bs=1 "+\
                    "skip="+head+" count=$(expr "+\
                    "$(du -b %(in)s|cut -f1) "+\
                    " - "+head+" - "+tail+")"
    return E(), D()

def xxd_filters(args):
    class E(Filter):
        def __init__(self):
            self.pattern = "xxd %(in)s > %(out)s"
    class D(Filter):
        def __init__(self):
            self.pattern = "xxd -r %(in)s > %(out)s"
    return E(), D()

def rot13_filters(args):
    class E(Filter):
        def __init__(self):
            self.pattern = "cat %(in)s | rot13 > %(out)s"
    return E(), E()

def gz_filters(args):
    class E(Filter):
        def __init__(self):
            self.pattern = "cat %(in)s | gzip > %(out)s"
    class D(Filter):
        def __init__(self):
            self.pattern = "cat %(in)s | gunzip > %(out)s"
    return E(), D()

FILTERS = {
    'ccrypt': encrypt_filters,
    'head_tail': head_tail_filters,
    'xxd': xxd_filters,
    'rot13': rot13_filters,
    'gz': gz_filters,
}

def add_filter(generator, encode_filter, decode_filter):
    e, d = generator(args)
    encode_filter.push_back(e)
    decode_filter.push_front(d)

def add_filters(args, encode_filter, decode_filter):
    for filter in args.filters.split(','):
        if ':' in filter:
            filter, prob = filter.split(':')
            if randint(0, 100) > int(prob):
                continue
        add_filter(FILTERS[filter], encode_filter, decode_filter)

def try_backup_file(args, file, o):
    dir = os.path.dirname(file)
    dir_opt = ''
    if dir:
        o.write('mkdir -p %s\n' % dir)
        dir_opt = '-o ' + dir
    local_file = os.path.join(args.dir, file)
    upload_file = tempfile.NamedTemporaryFile(delete=False).name
    encode_filter = FilterChain()
    decode_filter = FilterChain()
    # add filters
    add_filters(args, encode_filter, decode_filter)
    # run encode filters
    encode = encode_filter.encode(local_file, upload_file)
    if args.verbose:
        print(encode)
    os.system(encode)
    # upload
    url = plowup(args, upload_file)
    # remove tmp
    os.unlink(upload_file)
    # permissions
    permissions = os.popen('stat -c%a ' + local_file).read().strip()
    # write commands to download the file
    if url.startswith('/tmp'):
        o.write('f=%(url)s\n' % {'url': url})
    else:
        o.write('tmpdir=$(mktemp -d)\n')
        o.write('plowdown -o $tmpdir %s\n' % url)
        o.write('f=$(find $tmpdir -type f)\n')
    o.write(decode_filter.encode('$f', file))
    if not url.startswith('/tmp'):
        o.write('rm $f\n')
        o.write('rmdir $tmpdir\n')
    o.write('chmod %s %s\n' %(permissions, file))

def backup_file(args, file):
    if args.verify:
        while True:
            o = StringIO()
            try_backup_file(args, file, o)
            cmd = o.getvalue()
            base_dir = tempfile.mkdtemp()
            script = tempfile.NamedTemporaryFile(delete=False)
            try:
                script.write(cmd) # python2
            except:
                script.write(bytes(cmd, 'UTF-8')) # python3
            script.close()
            os.system('cd %(base_dir)s; sh %(script)s' %\
                    {'base_dir': base_dir, 'script': script.name})
            os.unlink(script.name)
            f1 = os.path.join(base_dir, file)
            f2 = os.path.join(args.dir, file)
            ok = False
            try:
                ok = filecmp.cmp(f1, f2)
            except:
                pass
            os.system('rm -r ' + base_dir)
            if ok:
                args.out.write(cmd)
                break
            else:
                time.sleep(1) # to break it with Ctrl+C
    else:
        try_backup_file(args, file, args.out)

r = argparse.FileType('r')
w = argparse.FileType('w')

p = argparse.ArgumentParser(description='Plow Backup',
    formatter_class=argparse.ArgumentDefaultsHelpFormatter)
p.add_argument('-v','--version',action='version',version='%(prog)s 1.0')
p.add_argument('--verbose',help='Verbose output',action='store_true')
p.add_argument('--dir',help='Directory',metavar='DIR', default='.')
p.add_argument('--out',help='Output file for script',
        metavar='FILE',type=w,default='-')
p.add_argument('--filters',help='Sequence of filters to apply. '+\
        'Probability in precent may be added after ":"',
        metavar='FF',type=str,default='xxd:25,head_tail:75,ccrypt')
p.add_argument('--sites',
        help='Sites used for upload separated by comma or "local"',
        metavar='SITES',type=str,default='Sendspace,Sharebeast')
p.add_argument('--verify',
        help='Download file and compare it with original',
        type=int,default=1)

args = p.parse_args()
base_dir = args.dir
args.sites_list = args.sites.split(',')

files = list_files(base_dir)
for file in files:
    o = args.out
    backup_file(args, file)

