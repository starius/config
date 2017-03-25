package main

const CONFIG = `client
dev tun0
proto udp
remote 46.166.137.234 1197 # TODO make cache of servers' addresses
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

tun-mtu 1350
mssfix
sndbuf 0
rcvbuf 0
`
