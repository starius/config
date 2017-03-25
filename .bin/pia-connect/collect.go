package main

import (
	"fmt"
	"strings"
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
