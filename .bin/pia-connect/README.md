# pia-connect, OpenVPN wrapper for PIA

The tool creates all needed files and runs `openvpn` against [PIA][pia].
It has servers' addresses embedded, so DNS is not needed to start. It also
starts caching DNS server on 53 port, forwarding requests to 8.8.8.8.
After starting all the stuff, it collects new addresses of servers
for future use.

## Build and run

Install Go. You can use tool [gohere][gohere] for this.

```
$ go get github.com/starius/config/.bin/pia-connect
$ sudo pia-connect
```

The tool will ask you to choose Regional Gateways for PIA (like "nl" for
Netherlands; the tool prints the full list and some common suggestions)
and user credentials (username and password). This information is stored
in a directory accessible only for the user. When you run the tool next
time, it will pick up this data so you will not need to enter it again.
Then the tool chooses PIA server randomly among chosen zones. This does
not depend on DNS: all addresses are embedded into the tool. This was done
to support operation on ISPs interfering with DNS. This also means that you
don't have to allow DNS traffic in your firewall rules for underlying
connection: everything except UDP port 1197 can be blocked. After the tool
creates all needed files and starts `openvpn`, it collects addresses of
PIA servers and saves them to the same directory. This is needed to keep up
with addresses' changes (some servers are added, some are removed) without
rebuilding the tool from source.

[gohere]: https://github.com/starius/gohere
[pia]: https://privateinternetaccess.com/

The tool creates the following files in `~root/.cache/pia-connect/`
directory, all are accessible only for the user:

  * `auth.txt` user credentials;
  * `zones.txt` is list of zones chosen to connect to;
  * `servers.json` is list of known servers.

The files above can be edited by human.

The following files are not expected to be edited by human:

  * `ca.rsa.4096.crt` and `crl.rsa.4096.pem` is public crypto data needed
    to connect to [PIA][pia] using stong crypto;
  * `config.ovpn` is config for `openvpn`.

## For developers

To collect a lot of server addresses, build the tool and then run:

```
$ ./collect.sh
```

To update generated Go sources (you need to build the tool before):

```
$ go generate
```

## First session demo

```
$ pia-connect
Creating file /root/.cache/pia-connect/auth.txt
Username and password will be stored in plaintext in the file.
If you are uncomfortable with this, press Ctrl+C.
Enter username: p0123456
Enter password: ********
The list of known countries and servers of PIA:
  Netherlands: nl.  Sweden: sweden.  Finland: fi.  Switzerland: swiss.  Romania: ro.  Singapore: sg.
  United Kingdom: uk-london,uk-southampton.  Australia: aus,aus-melbourne.  Mexico: mexico.  Denmark: denmark.  South Korea: kr.
  Hong Kong: hk.  Japan: japan.  India: in.  Canada: ca-toronto,ca.  Norway: no.  Brazil: brazil.  New Zealand: nz.  France: france.
  Ireland: ireland.  Italy: italy.  Turkey: turkey.  Israel: israel.
  United States: us-california,us-east,us-midwest,us-chicago,us-texas,us-florida,us-seattle,us-west,us-siliconvalley,us-newyorkcity.
  Germany: germany.
North America: us-california,us-east,us-midwest,ca,ca-toronto
Europe: italy,nl,ro,germany,fi,no,denmark,swiss,sweden
Asia: aus,aus-melbourne,nz,kr,hk,sg,japan,in
Please choose zones (for instance nl,brazil): us-california,us-east,us-midwest,ca,ca-toronto
Chosen zones were saved to file /root/.cache/pia-connect/zones.txt
2017/03/26 10:20:30 Using VPN server: 1.2.3.4.
Sun Mar 26 10:20:30 2017 OpenVPN 2.3.10 built on Aug  1 2013
Sun Mar 26 10:20:30 2017 library versions: OpenSSL 1.0.0
Sun Mar 26 10:20:30 2017 WARNING: normally if you use --mssfix and/or --fragment, you should also set --tun-mtu 1500 (currently it is 1350)
Sun Mar 26 10:20:30 2017 UDPv4 link local: [undef]
Sun Mar 26 10:20:30 2017 UDPv4 link remote: [AF_INET]1.2.3.4:1197
Sun Mar 26 10:20:30 2017 WARNING: this configuration may cache passwords in memory -- use the auth-nocache option to prevent this
2017/03/26 10:20:30 pia-connect: openvpn started. Starting DNS server.
2017/03/26 10:20:30 pia-connect: waiting 1m0s.
2017/03/26 10:20:30 Running sudo iptables-save
Sun Mar 26 10:20:30 2017 WARNING: 'link-mtu' is used inconsistently, local='link-mtu 1420', remote='link-mtu 1542'
Sun Mar 26 10:20:30 2017 WARNING: 'tun-mtu' is used inconsistently, local='tun-mtu 1350', remote='tun-mtu 1500'
Sun Mar 26 10:20:30 2017 WARNING: 'cipher' is used inconsistently, local='cipher AES-256-CBC', remote='cipher BF-CBC'
Sun Mar 26 10:20:30 2017 WARNING: 'auth' is used inconsistently, local='auth SHA256', remote='auth SHA1'
Sun Mar 26 10:20:30 2017 WARNING: 'keysize' is used inconsistently, local='keysize 256', remote='keysize 128'
Sun Mar 26 10:20:30 2017 [517a3fceb4b09a4a9ae53a782d5726ee] Peer Connection Initiated with [AF_INET]1.2.3.4:1197
Sun Mar 26 10:20:30 2017 TUN/TAP device tun0 opened
Sun Mar 26 10:20:30 2017 do_ifconfig, tt->ipv6=0, tt->did_ifconfig_ipv6_setup=0
Sun Mar 26 10:20:30 2017 /usr/sbin/ip link set dev tun0 up mtu 1350
Sun Mar 26 10:20:30 2017 /usr/sbin/ip addr add dev tun0 local 10.11.12.6 peer 10.11.12.5
Sun Mar 26 10:20:30 2017 Initialization Sequence Completed
2017/03/26 10:20:30 Running sudo iptables-save
```
