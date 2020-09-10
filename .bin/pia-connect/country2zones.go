package main

// Source: https://www.privateinternetaccess.com/pages/client-support/ubuntu-openvpn
var COUNTRY2ZONES = map[string][]string{
	"United States": []string{
		"us-california",
		"us-east",
		"us-chicago",
		"us-dal",
		"us-florida",
		"us-sea",
		"us-west",
		"us-siliconvalley",
		"us-nyc",
		"us-washingtondc",
		"us-atlanta",
		"us-lasvegas",
		"us-houston",
		"us-denver",
	},
	"United Kingdom": []string{
		"uk-london",
		"uk-southampton",
		"uk-manchester",
	},
	"Canada": []string{
		"ca-ontario",
		"ca-toronto",
		"ca-montreal",
		"ca-vancouver",
	},
	"Australia": []string{
		"au-sydney",
		"au-melbourne",
		"au-perth",
	},
	"Germany": []string{
		"de-berlin",
		"de-frankfurt",
	},
	"New Zealand": []string{
		"nz",
	},
	"Albania": []string{
		"albania",
	},
	"Netherlands": []string{
		"nl",
	},
	"Iceland": []string{
		"is",
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
	"Belgium": []string{
		"belgium",
	},
	"Austria": []string{
		"austria",
	},
	"Czech Republic": []string{
		"czech",
	},
	"Luxembourg": []string{
		"lu",
	},
	"Ireland": []string{
		"ireland",
	},
	"Italy": []string{
		"italy",
	},
	"Portugal": []string{
		"pt",
	},
	"Spain": []string{
		"spain",
	},
	"Moldova": []string{
		"md",
	},
	"Romania": []string{
		"ro",
	},
	"Bulgaria": []string{
		"bg",
	},
	"Serbia": []string{
		"rs",
	},
	"Latvia": []string{
		"lv",
	},
	"Estonia": []string{
		"ee",
	},
	"Lithuania": []string{
		"lt",
	},
	"Slovakia": []string{
		"sk",
	},
	"Hungary": []string{
		"hungary",
	},
	"Poland": []string{
		"poland",
	},
	"Greece": []string{
		"gr",
	},
	"Bosnia and Herzegovina": []string{
		"ba",
	},
	"Ukraine": []string{
		"ua",
	},
	"North Macedonia": []string{
		"mk",
	},
	"United Arab Emirates": []string{
		"ae",
	},
	"Singapore": []string{
		"sg",
	},
	"Japan": []string{
		"jp",
	},
	"Israel": []string{
		"israel",
	},
	"Mexico": []string{
		"mx",
	},
	"Brazil": []string{
		"br",
	},
	"Argentina": []string{
		"ar",
	},
	"India": []string{
		"in",
	},
	"South Africa": []string{
		"za",
	},
}
