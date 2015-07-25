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

--mode:
    * append (default). Do not change previous content
      of output file, just append new. Old commands may be wrong,
      but will not be removed. This mode is safer (for
      previous content of output file.
    * write. Open file for writting. Previos content is
      removed (it can be reused depending on --reuse).
      You can lose previous content of file if error
      happens before reused content writting (see --backup).
    * verify. Read-only mode. Does not depend on --reuse.
      Opens script for verifying. Test commands and test sha256
      of downloaded files.
      Print 'OK' or "FAIL' and filename.

--reuse:
    * 'no'. Ignore previous content of output file.
    * 'yes'. Use previous content of output file for
      files with same names.
    * 'verify'. Use previous content of output file for
      files with same names, if they are equal to files,
      produced by these commands. This make sense because
      downloading is often much faster than uploading.
      Furthermore, this saves disk space on websites.

Good sites:
    * Sendspace
    * Sharebeast
    * rghost
    * mega (required plugin plowshare-plugin-mega)

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
    * gpg
    * xxd
    * rot13
    * sha256sum

For list of filters, see var FILTERS.
"""

from gzip import GzipFile
import os
import sys
import re
import argparse
import tempfile
import threading
from multiprocessing.pool import ThreadPool
from random import randint, choice
import string
import hashlib
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
        return random_password() + '_' + random_password() + '.mp3'
    return choice([photo, mhtml, mp4, txt, mp3])()

PARTS_DIR = '$parts_dir/'

def escape_file(arg):
    if arg in ('$f1', '$f2', '$f'):
        return arg
    if arg.startswith(PARTS_DIR):
        prefix_length = len(PARTS_DIR)
        other = arg[prefix_length:]
        return PARTS_DIR + escape_file(other)
    if arg.startswith('-'):
        arg = './' + arg
    return "'%s'" % arg.replace("'", r"'\''")

def unescape_file(arg):
    if arg in ('$f1', '$f2', '$f'):
        return arg
    if arg.startswith(PARTS_DIR):
        prefix_length = len(PARTS_DIR)
        other = arg[prefix_length:]
        return PARTS_DIR + unescape_file(other)
    if arg.startswith("'") and arg.endswith("'"):
        arg = arg[1:-1] # remove ' '
    arg = arg.replace(r"'\''", "'")
    if arg.startswith('./-'):
        arg = arg[2:] # remove ./
    return arg

def sha256sum(filename):
    m = hashlib.sha256()
    f = open(filename)
    while True:
        buf = f.read(100500)
        m.update(buf)
        if not buf:
            break
    f.close()
    return m.hexdigest()

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
        local = '/tmp/local_' + random_password() + '_'
        os.system("cp %(file)s %(local)s" %
                {'file': escape_file(file),
                 'local': escape_file(local)})
        return local
    else:
        site = choice(args.sites_list)
        name = random_filename()
        url = os.popen(("bash -c 'plowup %(quiet)s %(site)s " +
                  " %(file)s:%(name)s "+
                  "| tail -n 1'") %
                  {'file': escape_file(file), 'site': site,
                   'quiet': args.quiet_string,
                   'name': name}).read().strip()
        return url

class Filter(object):
    def __init__(self):
        self.pattern = 'cp %(in)s %(out)s'

    def encode(self, in_file, out_file):
        return self.pattern % \
                {'in': escape_file(in_file),
                 'out': escape_file(out_file)}

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
                {'in': escape_file(in_file),
                 'out': escape_file(out_file)}
        result = []
        result.append('f1=$(mktemp -t plowbackup.f1.XXXXXXXXXX)')
        result.append('f2=$(mktemp -t plowbackup.f1.XXXXXXXXXX)')
        result.append('cp %(in)s $f1' %\
                {'in': escape_file(in_file)})
        for filter in self.filters:
            result.append(filter.encode('$f1', '$f2'))
            result.append('mv $f2 $f1')
        result.append('cp $f1 %(out)s ' %\
                {'out': escape_file(out_file)})
        result.append('rm $f1')
        result.append('rm -f $f2')
        return '\n'.join(result) + '\n'

def encrypt_filters(args):
    cipher = choice(['AES256', 'TWOFISH'])
    key = random_password()
    CMD_COMMON = 'gpg --passphrase %s --batch --cipher-algo %s --force-mdc '
    CMD_E = CMD_COMMON + '--symmetric '
    CMD_D = CMD_COMMON + '--decrypt '
    cmd_e = CMD_E % (key, cipher)
    cmd_d = CMD_E % (key, cipher)
    class E(Filter):
        def __init__(self):
            self.pattern = "cat %(in)s | " + cmd_e + " > %(out)s"
    class D(Filter):
        def __init__(self):
            self.pattern = "cat %(in)s | " + cmd_d + " > %(out)s"
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
            head_1 = str(int(head) + 1)
            self.pattern =\
                    "tail -c +"+head_1+" %(in)s |"+\
                    "head -c $(expr "+\
                    "$(du -b %(in)s|cut -f1) "+\
                    " - "+head+" - "+tail+") > %(out)s"
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
    'gpg': encrypt_filters,
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

# relies on fact that last cmd for each file is 'chmod'
def parse_backup_script(file):
    result = {} # local file name to command to get it
    cmd = ''
    for line in file:
        if line.startswith('#'):
            continue
        cmd += line
        line = line.strip()
        if line:
            if line.startswith('chmod'):
                filename = line.split(' ', 2)[2]
                filename = unescape_file(filename)
                cmd = cmd.replace('plowdown -q', 'plowdown')
                if args.quiet:
                    cmd = cmd.replace('plowdown', 'plowdown -q')
                result[filename] = cmd
                cmd = ''
    return result

MD5_CMD = "if [ -f %(file)s ] && [ %(cond)s ]; then\n"+\
          "echo 'OK  ' %(file)s\n"+\
          'else\n'+\
          "echo 'FAIL' %(file)s\n"+\
          'fi\n'

def try_backup_file(args, file, o, local_args):
    local_upload_file = os.path.join(local_args.local_upload_dir, file)
    local_download_file = os.path.join(local_args.local_download_dir, file)
    upload_file = tempfile.NamedTemporaryFile(
            prefix='plowbackup.up.',
            delete=False).name
    encode_filter = FilterChain()
    decode_filter = FilterChain()
    # add filters
    add_filters(args, encode_filter, decode_filter)
    # run encode filters
    encode = encode_filter.encode(local_upload_file, upload_file)
    if args.verbose:
        print(encode)
    os.system(encode)
    # upload
    url = plowup(args, upload_file)
    # remove tmp
    os.unlink(upload_file)
    # write commands to download the file
    if url.startswith('/tmp'):
        o.write('f=%(url)s\n' % {'url': escape_file(url)})
    else:
        o.write('tmpdir=$(mktemp -d -t plowbackup.down.XXXXXXX)\n')
        o.write(('plowdown %(quiet)s -o $tmpdir %(url)s'+
                 ' > /dev/null \n') %\
                {'url': escape_file(url),
                 'quiet': args.quiet_string})
        o.write('f=$(find $tmpdir -type f)\n')
    o.write(decode_filter.encode('$f', local_download_file))
    if not url.startswith('/tmp'):
        o.write('rm $f\n')
        o.write('rmdir $tmpdir\n')
    sha256 = sha256sum(local_upload_file)
    cond = "`sha256sum %(file)s|awk '{print $1;}'` = '%(sha256)s'"%\
            {'file': escape_file(local_download_file), 'sha256': sha256}
    o.write(MD5_CMD % {'file': escape_file(local_download_file),
                       'cond': cond})

def verify_file_cmd_single_attempt(args, file, cmd):
    cmd0 = 'parts_dir=$(mktemp -d -t '+\
           'plowbackup.parts.verify.XXXXXXX)\n'
    cmd2 = 'rm -r $parts_dir\n'
    dir = os.path.dirname(file)
    if dir:
        cmd0 += 'mkdir -p %s\n' % escape_file(dir)
        cmd0 += 'mkdir -p $parts_dir/%s\n' % escape_file(dir)
    cmd = cmd0 + cmd + cmd2
    base_dir = tempfile.mkdtemp(prefix='plowbackup.down.')
    script = tempfile.NamedTemporaryFile(prefix='plowbackup.script.',
            delete=False)
    try:
        script.write(cmd) # python2
    except:
        script.write(bytes(cmd, 'UTF-8')) # python3
    script.close()
    result = tempfile.NamedTemporaryFile(prefix='plowbackup.result.',
            delete=False)
    result.close()
    c = "cd %(base_dir)s; sh %(script)s | tail -n 1 |"+\
        "awk '{print $1;}' > %(result)s"
    os.system(c % \
            {'base_dir': base_dir, 'script': script.name,
             'result': result.name})
    os.unlink(script.name)
    result_code = open(result.name).read().strip()
    os.unlink(result.name)
    ok = None
    if result_code == 'OK':
        ok = True
    elif result_code == 'FAIL':
        ok = False
    if ok == None:
        # script without sha256
        f1 = os.path.join(base_dir, file)
        f2 = os.path.join(args.local_upload_dir, file)
        try:
            ok = filecmp.cmp(f1, f2)
        except:
            ok = False
    os.system('rm -r ' + escape_file(base_dir))
    return ok

def verify_file_cmd(args, file, cmd):
    for i in range(0, args.verify_attempts):
        if verify_file_cmd_single_attempt(args, file, cmd):
            return True
    return False

def backup_file_signle(args, file, local_args):
    if args.verify:
        while True:
            o = StringIO()
            try_backup_file(args, file, o, local_args)
            cmd = o.getvalue()
            if args.verbose:
                print(cmd)
            if verify_file_cmd(args, file, cmd):
                return cmd
            else:
                time.sleep(1) # to break it with Ctrl+C
    else:
        o = StringIO()
        try_backup_file(args, file, o, local_args)
        cmd = o.getvalue()
        if args.verbose:
            print(cmd)
        return cmd

def backup_file_part(args, file, local_args):
    cmd = backup_file_signle(args, file, local_args)
    for i in range(1, args.count):
        cmd2 = backup_file_signle(args, file, local_args)
        cmd = re.sub(r"echo 'FAIL'.*\n", cmd2, cmd)
    return cmd

def cut_file(in_file, out_file, begin, end):
    out_size = end - begin
    head = begin + 1
    # 2> /dev/null because tail: write error
    c = "tail -c +%(head)i %(in)s 2> /dev/null |"+\
        "head -c %(out_size)i > %(out)s"
    c = c % {'in': escape_file(in_file),
             'out': escape_file(out_file),
             'head': head, 'out_size': out_size}
    os.system(c)

class LocalArgs(object):
    pass

def backup_file(args, file):
    local_args = LocalArgs() # thread-local
    local_args.local_upload_dir = args.dir
    o = StringIO()
    dir = os.path.dirname(file)
    if dir:
        o.write('mkdir -p %s\n' % escape_file(dir))
    abs_file = os.path.join(args.dir, file)
    sha256 = sha256sum(abs_file)
    cond = "`sha256sum %(file)s|awk '{print $1;}'` = '%(sha256)s'"%\
            {'file': escape_file(file), 'sha256': sha256}
    c = "if [ ! -f %(file)s ] || [ ! %(cond)s ]; then\n"
    o.write(c % {'file': escape_file(file), 'cond': cond})
    size = os.path.getsize(abs_file)
    max_part_size = 1024 ** 2 * args.max_part_size
    if size <= max_part_size:
        local_args.local_upload_dir = args.dir
        local_args.local_download_dir = '.'
        o.write(backup_file_part(args, file, local_args))
    else:
        o.write('parts_dir=$(mktemp -d -t '+
                'plowbackup.parts.down.XXXXXXX)\n')
        local_args.local_download_dir = '$parts_dir'
        parts_dir = tempfile.mkdtemp(prefix='plowbackup.parts.up.')
        dir = os.path.dirname(file)
        if dir:
            os.system('mkdir -p %s\n' %
                    escape_file(os.path.join(parts_dir, dir)))
            o.write('mkdir -p %s\n' %
                    escape_file(os.path.join('$parts_dir/', dir)))
        local_args.local_upload_dir = parts_dir
        pos = 0
        i = 0
        o.write('rm -f %(file)s\n' % {'file': escape_file(file)})
        while pos < size:
            part_size = randint(max_part_size // 2, max_part_size)
            if pos + part_size > size:
                part_size = size - pos
            part_path = file + '.' + str(i)
            abs_part_path = os.path.join(parts_dir, part_path)
            cut_file(abs_file, abs_part_path, pos, pos + part_size)
            cmd = backup_file_part(args, part_path, local_args)
            o.write(cmd)
            down_part_path = os.path.join('$parts_dir', part_path)
            o.write('cat %(down_part_path)s >> %(file)s\n' %
                    {'down_part_path': escape_file(down_part_path),
                     'file': escape_file(file)})
            o.write('rm %(down_part_path)s\n' %
                    {'down_part_path': escape_file(down_part_path)})
            os.unlink(abs_part_path)
            report_write(args, '%s %s.%i\n' % ('UP  ', file, i))
            pos += part_size
            i += 1
        os.system("rm -r %s" % escape_file(parts_dir))
        o.write('rm -r $parts_dir\n')
        o.write(MD5_CMD % {'file': escape_file(file),
                           'cond': cond})
    o.write("else\necho 'ASIS' %s\nfi\n" %
                 escape_file(file))
    # permissions
    permissions = os.popen('stat -c%a ' +
            escape_file(abs_file)).read().strip()
    o.write('chmod %s %s\n' %\
            (permissions, escape_file(file)))
    o_write(args, o.getvalue())

MODE_CHOICES = ('write', 'append', 'verify')
REUSE_MODE_CHOICES = ('no', 'yes', 'verify')

w = argparse.FileType('w')

p = argparse.ArgumentParser(description='Plow Backup',
    formatter_class=argparse.ArgumentDefaultsHelpFormatter)
p.add_argument('-v','--version',action='version',version='%(prog)s 1.0')
p.add_argument('--verbose',help='Verbose output',action='store_true')
p.add_argument('--dir',help='Directory',metavar='DIR', default='.')
p.add_argument('--out',help='Output file for script',
        metavar='FILE',default='-')
p.add_argument('--mode',
        help='What to do with output file %s' % str(MODE_CHOICES),
        metavar='MODE',default='append',
        choices=MODE_CHOICES)
p.add_argument('--reuse',
        help='If previous data in output file will be used %s' %\
                str(REUSE_MODE_CHOICES),
        metavar='MODE',default='yes',
        choices=REUSE_MODE_CHOICES)
p.add_argument('--report',help='Output file for verification report',
        metavar='FILE',type=w,default='-')
p.add_argument('--filters',help='Sequence of filters to apply. '+\
        'Probability in precent may be added after ":"',
        metavar='FF',type=str,
        default='xxd:25,head_tail:75,gz:50,gpg,head_tail:75')
p.add_argument('--sites',
        help='Sites used for upload separated by comma or "local"',
        metavar='SITES',type=str,default='Sendspace,Sharebeast,rghost')
p.add_argument('--count',
        help='How much times upload each file(part)',
        type=int,default=1)
p.add_argument('--max-part-size',
        help='Max size of uploaded file part in MB',
        type=int,default=5)
p.add_argument('--workers',
        help='Number of workers',
        type=int,default=1)
p.add_argument('--verify',
        help='Download file and compare it with original',
        type=int,default=1)
p.add_argument('--verify-attempts',
        help='How much times try to get file while verification',
        type=int,default=2)
p.add_argument('--backup',
        help='Backup output file is exists before changing it',
        type=int,default=1)
p.add_argument('--quiet', help='Tell plowshare be quiet',
        type=int,default=1)

args = p.parse_args()

if args.mode == 'verify' and args.out == '-':
    print("Provide script file for verification!")

append = args.mode == 'append'
read_cmd = args.reuse in('yes', 'verify') or args.mode == 'verify'
if args.out == '-':
    read_cmd = False

file2cmd = {}
if read_cmd and os.path.exists(args.out):
    f = open(args.out)
    file2cmd = parse_backup_script(f)
    f.close()

args.sites_list = args.sites.split(',')
args.quiet_string = '-q' if args.quiet else ''

args.local_upload_dir = args.dir
args.report_lock = threading.Lock()
args.o_lock = threading.Lock()

def report_write(args, data):
    with args.report_lock:
        args.report.write(data)
        args.report.flush()

def o_write(args, data):
    with args.o_lock:
        args.o.write(data)
        args.o.flush()

def do_upload(file):
    if file in file2cmd and (args.reuse == 'yes' or \
            (args.reuse == 'verify' and
                verify_file_cmd(args, file, file2cmd[file]))):
        cmd = file2cmd[file]
        if args.mode == 'write':
            o_write(args, cmd)
        status = 'OK  ' if args.reuse == 'verify' else 'ASIS'
        report_write(args, '%s %s\n' % (status, file))
    else:
        backup_file(args, file)
        report_write(args, '%s %s\n' % ('UP  ', file))

if args.mode == 'verify':
    for file, cmd in file2cmd.items():
        ok = verify_file_cmd(args, file, cmd)
        status = 'OK  ' if ok else 'FAIL'
        report_write(args, '%s %s\n' % (status, file))
        if not ok:
            time.sleep(0.5) # to break it with Ctrl+C
elif args.mode in ('write', 'append'):
    if os.path.exists(args.out):
        backup_name = args.out + '.orig'
        os.system('cp %s %s' %\
                (escape_file(args.out), escape_file(backup_name)))
    if args.out == '-':
        args.o = sys.stdout
    elif args.mode == 'write':
        args.o = open(args.out, 'w')
    elif args.mode == 'append':
        args.o = open(args.out, 'a')
    base_dir = args.dir
    files = list_files(base_dir)
    if args.mode in ('write', 'append') \
            and args.reuse in ('yes', 'verify'):
        files.sort(key=lambda file: 0 if file in file2cmd else 1)
    if append:
        o_write(args, "# PlowBackup begin\n")
    pool = ThreadPool(args.workers)
    async_result = pool.map_async(do_upload, files)
    while not async_result.ready():
        time.sleep(1) # to break it with Ctrl+C
    if append:
        o_write(args, "# PlowBackup end\n")

