package main

// Source: https://www.privateinternetaccess.com/pages/client-support/ubuntu-openvpn
var COUNTRY2ZONES = map[string][]string{
	"United States": []string{
		"us-california",
		"us-east",
		"us-midwest",
		"us-chicago",
		"us-texas",
		"us-florida",
		"us-seattle",
		"us-west",
		"us-siliconvalley",
		"us-newyorkcity",
		"us-atlanta",
	},
	"United Kingdom": []string{
		"uk-london",
		"uk-southampton",
		"uk-manchester",
	},
	"Canada": []string{
		"ca-toronto",
		"ca",
		"ca-vancouver",
	},
	"Australia": []string{
		"aus",
		"aus-melbourne",
	},
	"New Zealand": []string{
		"nz",
	},
	"Netherlands": []string{
		"nl",
	},
	"Sweden": []string{
		"sweden",
	},
	"Norway": []string{
		"no",
	},
	"Denmark": []string{
		"denmark",
	},
	"Finland": []string{
		"fi",
	},
	"Switzerland": []string{
		"swiss",
	},
	"France": []string{
		"france",
	},
	"Germany": []string{
		"germany",
	},
	"Belgium": []string{
		"belgium",
	},
	"Austria": []string{
		"austria",
	},
	"Ireland": []string{
		"ireland",
	},
	"Italy": []string{
		"italy",
	},
	"Spain": []string{
		"spain",
	},
	"Romania": []string{
		"ro",
	},
	"Turkey": []string{
		"turkey",
	},
	"South Korea": []string{
		"kr",
	},
	"Hong Kong": []string{
		"hk",
	},
	"Singapore": []string{
		"sg",
	},
	"Japan": []string{
		"japan",
	},
	"Israel": []string{
		"israel",
	},
	"Mexico": []string{
		"mexico",
	},
	"Brazil": []string{
		"brazil",
	},
	"India": []string{
		"in",
	},
}
