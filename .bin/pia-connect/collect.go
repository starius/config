package main

import (
	"bytes"
	"fmt"
	"net"
	"strings"
	"time"
)

var (
	VALID_ZONES = make(map[string]bool)
)

func init() {
	for _, zones := range COUNTRY2ZONES {
		for _, zone := range zones {
			VALID_ZONES[zone] = true
		}
	}
}

func ParseZones(zonesStr string) ([]string, error) {
	zones := strings.Split(zonesStr, ",")
	for i, zone := range zones {
		zone = strings.TrimSpace(zone)
		zones[i] = zone
		if _, has := VALID_ZONES[zone]; !has {
			return nil, fmt.Errorf("unknown zone: %s", zone)
		}
	}
	return zones, nil
}

func CheckServer(server string) bool {
	// http://serverfault.com/a/470065
	addr := &net.UDPAddr{
		IP:   net.ParseIP(server),
		Port: 1194,
	}
	conn, err := net.DialUDP("udp", nil, addr)
	if err != nil {
		return false
	}
	if err := conn.SetDeadline(time.Now().Add(1 * time.Second)); err != nil {
		return false
	}
	req := []byte{0x38, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}
	if n, err := conn.Write(req); err != nil || n != len(req) {
		return false
	}
	res := make([]byte, 14)
	if n, err := conn.Read(res); err != nil || n != len(res) {
		return false
	}
	if res[0] != 0x40 {
		return false
	}
	if !bytes.Equal(res[9:], []byte{0, 0, 0, 0, 0}) {
		return false
	}
	return true
}
