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
$ sudo setcap "cap_net_bind_service=+ep" "$(which pia-connect)"
$ pia-connect
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

The tool creates the following files in `~/.cache/pia-connect/` directory,
all are accessible only for the user:

  * `auth.txt` user credentials;
  * `zones.txt` is list of zones chosen to connect to;
  * `servers.json` is list of known servers.

The files above can be edited by human.

The following files are short living and are not expected to be edited
by human. The tool removes them after starting `openvpn`.

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
