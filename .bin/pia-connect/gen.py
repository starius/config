#!/usr/bin/env python

""" Generate source files from official PIA files. """

import StringIO
import subprocess
import urllib2
import zipfile

ZIP_URL = 'https://www.privateinternetaccess.com/openvpn/openvpn-strong.zip'
SERVERS_URL = 'https://www.privateinternetaccess.com/pages/client-support/ubuntu-openvpn'
GO_TMPL = '''package main

// Source: %(url)s
const %(var)s = `%(content)s
`
'''
COUNTRY2ZONES_TMPL = '''package main

// Source: %(url)s
var %(var)s = %(content)s
'''

zip_content = urllib2.urlopen(ZIP_URL).read()
compressed_file = StringIO.StringIO(zip_content)
zip_viewer = zipfile.ZipFile(compressed_file)

ca = zip_viewer.open('ca.rsa.4096.crt').read().strip()
ca_go = GO_TMPL % {'content': ca, 'var': 'CA', 'url': ZIP_URL}
with open('ca.rsa.4096.crt.go', 'w') as ca_file:
    ca_file.write(ca_go)

crl = zip_viewer.open('crl.rsa.4096.pem').read().strip()
crl_go = GO_TMPL % {'content': crl, 'var': 'CRL', 'url': ZIP_URL}
with open('crl.rsa.4096.pem.go', 'w') as crl_file:
    crl_file.write(crl_go)

servers_html = urllib2.urlopen(SERVERS_URL).read()
html2text = subprocess.Popen(['html2text'], stdout=subprocess.PIPE, stdin=subprocess.PIPE)
servers_text = html2text.communicate(input=servers_html)[0]
needed_part = servers_text.split('*** Regional_Gateways ***')[1].split('Why')[0]
country = None
country2zones_lines = ['map[string][]string{']
for line in needed_part.split('\n'):
    line = line.strip()
    if line.startswith('*') and line.endswith(' VPN)'):
        if country is not None:
            country2zones_lines.append('\t},')
        country = line[2:].split(' (')[0]
        country2zones_lines.append('\t"%s": []string{' % country)
    elif line.endswith('.privateinternetaccess.com'):
        zone = line.split('.privateinternetaccess.com')[0]
        country2zones_lines.append('\t\t"%s",' % zone)
country2zones_lines.append('\t},')
country2zones_lines.append('}')
c2z_go = COUNTRY2ZONES_TMPL % {'content': '\n'.join(country2zones_lines), 'var': 'COUNTRY2ZONES', 'url': SERVERS_URL}
with open('country2zones.go', 'w') as c2z_file:
    c2z_file.write(c2z_go)
