package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"math/rand"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/howeyc/gopass"
)

//go:generate python gen.py
//go:generate pia-connect -gen-servers
//go:generate sed -e "s/[{,]/\\0\\n/g" -e "s/}/,\\n}/g" -i servers.go
//go:generate go fmt servers.go

const (
	IPTABLES_WAIT          = 15
	WAIT_BEFORE_COLLECTION = 60
)

var (
	cacheDir0    = flag.String("cache", "~/.cache/pia-connect", "Directory to store password and server addresses.")
	countryZone  = flag.String("country", nil, "Preferred country for this launch.")
	dryRun       = flag.Bool("dry", false, "Run 'vmstat 5' instead of openvpn.")
	skipIptables = flag.Bool("skip-iptables", false, "Do not change iptables needed to accept DNS on QubesOS.")
	skipDNS      = flag.Bool("skip-dns", false, "Do not run proxy DNS server.")
	updateWait   = flag.Duration("update-wait", 10*time.Second, "Time to wait before updating servers cache.")
	genServers   = flag.Bool("gen-servers", false, "Generate servers.go from cache/servers.json.")
	updateAll    = flag.Bool("update-all-zones", false, "Update cache for all zones, not only chosen zones.")
)

func expandTilde(path string) (string, error) {
	if path[0] != '~' {
		return path, nil
	}
	if path[1] != '/' {
		return "", fmt.Errorf("path %q starts with '~' but not with '~/'", path)
	}
	usr, err := user.Current()
	if err != nil {
		return "", fmt.Errorf("user.Current: %s", err)
	}
	return filepath.Join(usr.HomeDir, path[2:]), nil
}

func makeCacheDir(path string) error {
	wantMode := os.FileMode(0700 | os.ModeDir)
	_ = os.MkdirAll(path, wantMode)
	stat, err := os.Stat(path)
	if err != nil {
		return fmt.Errorf("os.Stat(%s): %s", path, err)
	}
	if !stat.IsDir() {
		return fmt.Errorf("%s is not a directory", path)
	}
	if stat.Mode() != wantMode {
		return fmt.Errorf("%s has mode %s, want %s", path, stat.Mode(), wantMode)
	}
	return nil
}

func makeAuthTxt(cacheDir string) (string, error) {
	authFile := filepath.Join(cacheDir, "auth.txt")
	_, err := os.Stat(authFile)
	if err == nil {
		return authFile, nil
	}
	if !os.IsNotExist(err) {
		return "", fmt.Errorf("os.Stat(%s): %s", authFile, err)
	}
	fmt.Printf("Creating file %s\n", authFile)
	fmt.Println("Username and password will be stored in plaintext in the file.")
	fmt.Println("If you are uncomfortable with this, press Ctrl+C.")
	fmt.Printf("Enter username: ")
	reader := bufio.NewReader(os.Stdin)
	username, err := reader.ReadString('\n')
	if err != nil {
		return "", fmt.Errorf("username not entered: %s", err)
	}
	username = strings.TrimSpace(username)
	fmt.Printf("Enter password: ")
	password, err := gopass.GetPasswdMasked()
	if err != nil {
		return "", fmt.Errorf("password not entered: %s", err)
	}
	t := fmt.Sprintf("%s\n%s\n", username, password)
	if err := ioutil.WriteFile(authFile, []byte(t), 0600); err != nil {
		return "", fmt.Errorf("ioutil.WriteFile(%s): %s", authFile, err)
	}
	return authFile, nil
}

func printZones() {
	fmt.Println("The list of known countries and servers of PIA:")
	var line string
	for country, zones := range COUNTRY2ZONES {
		t := fmt.Sprintf("  %s: %s.", country, strings.Join(zones, ","))
		if len(line)+len(t) > 135 {
			fmt.Println(line)
			line = ""
		}
		line += t
	}
	fmt.Println(line)
}

func getZones(cacheDir string) ([]string, error) {
	zonesFile := filepath.Join(cacheDir, "zones.txt")
	zonesBytes, err := ioutil.ReadFile(zonesFile)
	if err == nil {
		zones, err := ParseZones(string(zonesBytes))
		if err != nil {
			return nil, err
		}
		return zones, nil
	}
	if _, err := os.Stat(zonesFile); !os.IsNotExist(err) {
		return nil, fmt.Errorf("file %s exists but can't be read: %s", zonesFile, err)
	}
	printZones()
	fmt.Println("North America: us-california,us-east,us-midwest,ca,ca-toronto")
	fmt.Println("Europe: italy,nl,ro,germany,fi,no,denmark,swiss,sweden")
	fmt.Println("Asia: aus,aus-melbourne,nz,kr,hk,sg,japan,in")
	fmt.Printf("Please choose zones (for instance nl,brazil): ")
	reader := bufio.NewReader(os.Stdin)
	zonesStr, err := reader.ReadString('\n')
	if err != nil {
		return nil, fmt.Errorf("zones not entered: %s", err)
	}
	zones, err := ParseZones(zonesStr)
	if err != nil {
		return nil, err
	}
	if err := ioutil.WriteFile(zonesFile, []byte(zonesStr), 0600); err != nil {
		return nil, fmt.Errorf("ioutil.WriteFile(%s): %s", zonesFile, err)
	}
	fmt.Printf("Chosen zones were saved to file %s\n", zonesFile)
	return zones, nil
}

func getZone2servers(cacheDir string) (map[string][]string, error) {
	m := make(map[string][]string)
	serversFile := filepath.Join(cacheDir, "servers.json")
	serversBytes, err := ioutil.ReadFile(serversFile)
	if err == nil {
		if err := json.Unmarshal(serversBytes, &m); err != nil {
			return nil, fmt.Errorf("json.Unmarshal %s: %s", serversFile, err)
		}
	}
	// Merge with servers shipped with the binary.
	for zone, servers := range SERVERS {
		set := make(map[string]bool)
		for _, s := range m[zone] {
			set[s] = true
		}
		for _, s := range servers {
			if _, has := set[s]; !has {
				m[zone] = append(m[zone], s)
				set[s] = true
			}
		}
	}
	return m, nil
}

func chooseServer(cacheDir string) (string, error) {
	zones, err := getZones(cacheDir)
	if err != nil {
		return "", err
	}
	zone := zones[rand.Intn(len(zones))]
	zone2servers, err := getZone2servers(cacheDir)
	if err != nil {
		return "", err
	}
	servers, has := zone2servers[zone]
	if !has {
		log.Printf("No servers for zone: %s.", zone)
		return "zone_is_empty", nil
	}
	server := servers[rand.Intn(len(servers))]
	return server, nil
}

func chooseServerAndCheck(cacheDir string) (string, error) {
	for i := 0; i < 10; i++ {
		server, err := chooseServer(cacheDir)
		if err != nil {
			return "", err
		}
		if server == "zone_is_empty" {
			continue
		}
		// Note that this can be used for fingerprinting.
		if CheckServer(server) {
			return server, nil
		}
		log.Printf("Server %s is not working. Retrying...", server)
		time.Sleep(1 * time.Second)
	}
	return "", fmt.Errorf("all servers tried seem to be down")
}

func makeConfig(cacheDir, authFile, server string) (string, error) {
	caFile := filepath.Join(cacheDir, "ca.rsa.4096.crt")
	if err := ioutil.WriteFile(caFile, []byte(CA), 0600); err != nil {
		return "", fmt.Errorf("ioutil.WriteFile(%s): %s", caFile, err)
	}
	crlFile := filepath.Join(cacheDir, "crl.rsa.4096.pem")
	if err := ioutil.WriteFile(crlFile, []byte(CRL), 0600); err != nil {
		return "", fmt.Errorf("ioutil.WriteFile(%s): %s", crlFile, err)
	}
	configFile := filepath.Join(cacheDir, "config.ovpn")
	config := CONFIG
	config = strings.Replace(config, "CA_FILE", caFile, -1)
	config = strings.Replace(config, "CRL_FILE", crlFile, -1)
	config = strings.Replace(config, "AUTH_FILE", authFile, -1)
	config = strings.Replace(config, "SERVER", server, -1)
	if err := ioutil.WriteFile(configFile, []byte(config), 0600); err != nil {
		return "", fmt.Errorf("ioutil.WriteFile(%s): %s", configFile, err)
	}
	return configFile, nil
}

func system(cmd string, args ...string) error {
	log.Printf("Running %s %s", cmd, strings.Join(args, " "))
	c := exec.Command(cmd, args...)
	c.Stdin = os.Stdin
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	return c.Run()
}

func systemOutput(cmd string, args ...string) ([]byte, error) {
	log.Printf("Running %s %s", cmd, strings.Join(args, " "))
	c := exec.Command(cmd, args...)
	c.Stdin = os.Stdin
	c.Stderr = os.Stderr
	return c.Output()
}

func runOpenVpn(configFile string) (*os.Process, error) {
	c := exec.Command("openvpn", "--config", configFile)
	if *dryRun {
		c = exec.Command("vmstat", "5")
	}
	c.Stdout = os.Stdout
	c.Stderr = os.Stdout
	if err := c.Start(); err != nil {
		return nil, fmt.Errorf("exec.Cmd.Start: %s", err)
	}
	return c.Process, nil
}

func fixIptables() error {
	rules, err := systemOutput("iptables-save")
	if err != nil {
		return err
	}
	if !bytes.Contains(rules, []byte("-A PREROUTING -p udp -m udp --dport 53 -j ACCEPT")) {
		err := system(
			"iptables",
			"-t", "nat",
			"-I", "PREROUTING", "1",
			"-p", "udp", "-m", "udp",
			"--dport", "53",
			"-j", "ACCEPT",
		)
		if err != nil {
			return err
		}
	}
	if !bytes.Contains(rules, []byte("-A INPUT -p udp -m udp --dport 53 -j ACCEPT")) {
		err := system(
			"iptables",
			"-I", "INPUT", "1",
			"-p", "udp", "-m", "udp",
			"--dport", "53",
			"-j", "ACCEPT",
		)
		if err != nil {
			return err
		}
	}
	return nil
}

func updateServersCache(cacheDir string) error {
	m, err := getZone2servers(cacheDir)
	if err != nil {
		return err
	}
	var zones []string
	if *updateAll {
		for zone := range VALID_ZONES {
			zones = append(zones, zone)
		}
	} else {
		zones, err = getZones(cacheDir)
		if err != nil {
			return err
		}
	}
	for _, zone := range zones {
		set := make(map[string]bool)
		for _, s := range m[zone] {
			set[s] = true
		}
		fresh, err := getFreshServers(zone)
		if err != nil {
			return fmt.Errorf("getFreshServers(%s): %s", zone, err)
		}
		for _, s := range fresh {
			if _, has := set[s]; !has {
				m[zone] = append(m[zone], s)
				set[s] = true
			}
		}
		time.Sleep(1 * time.Second)
	}
	serversBytes, err := json.MarshalIndent(m, "", "    ")
	if err != nil {
		return fmt.Errorf("json.MarshalIndent: %s", err)
	}
	serversFile := filepath.Join(cacheDir, "servers.json")
	if err := ioutil.WriteFile(serversFile, serversBytes, 0600); err != nil {
		return fmt.Errorf("ioutil.WriteFile(%s): %s", serversFile, err)
	}
	return nil
}

func generateServers(cacheDir string) error {
	m, err := getZone2servers(cacheDir)
	if err != nil {
		return err
	}
	var perZone []string
	for zone, servers := range m {
		perZone = append(perZone, fmt.Sprintf(`%q: %#v`, zone, servers))
	}
	sort.Strings(perZone)
	s := strings.Join(perZone, ", ")
	t := fmt.Sprintf("package main\n\nvar SERVERS = map[string][]string{%s}\n", s)
	if err := ioutil.WriteFile("servers.go", []byte(t), 0644); err != nil {
		return fmt.Errorf("ioutil.WriteFile(%s): %s", "servers.go", err)
	}
	return nil
}

func main() {
	flag.Parse()
	rand.Seed(time.Now().UTC().UnixNano())
	if *cacheDir0 == "" {
		log.Fatal("Please specify --cache.")
	}
	cacheDir, err := expandTilde(*cacheDir0)
	if err != nil {
		log.Fatalf("Failed to expand ~ to home dir: %s.", err)
	}
	if err := makeCacheDir(cacheDir); err != nil {
		log.Fatalf("Failed to make/check cache dir: %s.", err)
	}
	if *genServers {
		err := generateServers(cacheDir)
		if err != nil {
			log.Fatalf("Failed to generate servers.go: %s.", err)
		}
		return
	}
	authFile, err := makeAuthTxt(cacheDir)
	if err != nil {
		log.Fatalf("Failed to make/check auth.txt: %s.", err)
	}
	var once1, once2 sync.Once
runChild:
	server, err := chooseServerAndCheck(cacheDir)
	if err != nil {
		log.Fatalf("Failed to choose server: %s.", err)
	}
	log.Printf("Using VPN server: %s.", server)
	configFile, err := makeConfig(cacheDir, authFile, server)
	if err != nil {
		log.Fatalf("Failed to make config: %s.", err)
	}
	child, err := runOpenVpn(configFile)
	if err != nil {
		log.Fatalf("Failed to run openvpn: %s.", err)
	}
	if !*skipIptables && !*dryRun {
		once1.Do(func() {
			go func() {
				for {
					// Repeat because qubes-setup-dnat-to-ns
					// runs when new VM is connected.
					if err := fixIptables(); err != nil {
						child.Kill()
						log.Fatalf("Failed to fix iptables rules: %s.", err)
					}
					time.Sleep(IPTABLES_WAIT * time.Second)
				}
			}()
		})
	}
	log.Println("pia-connect: openvpn started.")
	if !*skipDNS {
		once2.Do(func() {
			log.Println("pia-connect: Starting DNS server.")
			go func() {
				if err := RunDNS(); err != nil {
					child.Kill()
					log.Fatalf("Failed to run DNS server: %s.", err)
				}
			}()
		})
	}
	log.Printf("pia-connect: waiting %s.\n", *updateWait)
	time.Sleep(*updateWait)
	log.Println("pia-connect: updating server addresses cache.")
	if err := updateServersCache(cacheDir); err != nil {
		log.Printf("Failed to update server addresses cache: %s.", err)
	}
	log.Println("pia-connect: updating finished. Waiting for child process.")
	if _, err := child.Wait(); err != nil {
		log.Fatalf("Wait: %s.", err)
	}
	time.Sleep(time.Second)
	goto runChild
}
