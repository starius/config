package main

import (
	"flag"
	"log"
	"time"

	"github.com/facebookgo/inmem"
	"github.com/miekg/dns"
)

// Based on https://github.com/jackdoe/cacher/

var (
	timeout   = flag.Duration("dns-timeout", 60*time.Second, "Timeout for proxified DNS requests.")
	upstream  = flag.String("dns-upstream", "209.222.18.222:53", "Upstream DNS server.")
	listenOn  = flag.String("dns-listen", "0.0.0.0:53", "Where to run local DNS server.")
	cacheSize = flag.Int("dns-cache", 1000, "Number of records in DNS cache (0 to disable).")
)

type DNSProxy struct {
	cache  inmem.Cache
	client dns.Client
}

func (d *DNSProxy) ServeDNS(w dns.ResponseWriter, req *dns.Msg) {
	if len(req.Question) == 0 {
		log.Printf("Empty DNS request from %s.", w.RemoteAddr())
		return
	}
	key := req.Question[0] // Note that cache can deanonymize multiple Qubes VMs to each other.
	if len(req.Question) == 1 {
		// req.Question with multiple values is rare and is hard to use as a key.
		if d.cache != nil {
			if cached, has := d.cache.Get(key); has {
				clone := *cached.(*dns.Msg)
				clone.Id = req.Id
				w.WriteMsg(&clone)
				return
			}
		}
	}
	response, _, err := d.client.Exchange(req, *upstream)
	if err != nil {
		log.Printf("Error resolving %s: %s.", req.Question[0].Name, err)
		return
	}
	if len(req.Question) == 1 && len(response.Answer) > 0 {
		ttl := response.Answer[0].Header().Ttl
		expiresAt := time.Now().Add(time.Duration(ttl) * time.Second)
		if d.cache != nil {
			d.cache.Add(key, response, expiresAt)
		}
	}
	w.WriteMsg(response)
}

func RunDNS() error {
	proxy := &DNSProxy{
		client: dns.Client{
			ReadTimeout:  *timeout,
			WriteTimeout: *timeout,
		},
	}
	if *cacheSize > 0 {
		proxy.cache = inmem.NewLocked(*cacheSize)
	}
	return dns.ListenAndServe(*listenOn, "udp", proxy)
}
