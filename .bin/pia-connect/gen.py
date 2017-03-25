#!/usr/bin/env python

""" Generate source files from official PIA files. """

import StringIO
import urllib2
import zipfile

URL = "https://www.privateinternetaccess.com/openvpn/openvpn-strong.zip"
GO_TMPL = '''package main

// Source: %(url)s
const %(var)s = `%(content)s
`
'''

zip_content = urllib2.urlopen(URL).read()
compressed_file = StringIO.StringIO(zip_content)
zip_viewer = zipfile.ZipFile(compressed_file)

ca = zip_viewer.open('ca.rsa.4096.crt').read().strip()
ca_go = GO_TMPL % {'content': ca, 'var': 'CA', 'url': URL}
with open('ca.rsa.4096.crt.go', 'w') as ca_file:
    ca_file.write(ca_go)

crl = zip_viewer.open('crl.rsa.4096.pem').read().strip()
crl_go = GO_TMPL % {'content': crl, 'var': 'CRL', 'url': URL}
with open('crl.rsa.4096.pem.go', 'w') as crl_file:
    crl_file.write(crl_go)
