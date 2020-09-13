package main

const CONFIG = `client
dev tun0
proto udp
remote SERVER 1197
nobind
persist-key
persist-tun
ca CA_FILE
cipher aes-256-cbc
auth sha256
tls-client
remote-cert-tls server
auth-user-pass AUTH_FILE
comp-lzo
verb 1
reneg-sec 0
crl-verify CRL_FILE

tun-mtu 1500
mssfix 1300
replay-window 16384 60
`
