package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha256"
	_ "embed"
	"flag"
	"fmt"
	"log"
	"math/big"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/btcsuite/btcd/btcec/v2"
	"github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip04"
	"github.com/nbd-wtf/go-nostr/nip19"
	"golang.org/x/crypto/argon2"
	"golang.org/x/crypto/hkdf"
	"golang.org/x/crypto/ssh/terminal"
)

var (
	seedFile   = flag.String("seed-file", "", "File to read seed from. Must be a text file. If not set, read from standard input.")
	relaysFile = flag.String("relays-file", "", "A file with relays list, one per line. If not set, use built-in list.")
)

//go:embed relays.txt
var defaultRelays []byte

func main() {
	flag.Parse()

	// Get the list of relays.
	relaysBytes := defaultRelays
	if *relaysFile != "" {
		var err error
		relaysBytes, err = os.ReadFile(*relaysFile)
		if err != nil {
			log.Fatalf("Failed to read relays file: %v", err)
		}
	}

	var relays []string
	relaysScanner := bufio.NewScanner(bytes.NewReader(relaysBytes))
	for relaysScanner.Scan() {
		relays = append(relays, strings.TrimSpace(relaysScanner.Text()))
	}
	if err := relaysScanner.Err(); err != nil {
		log.Fatalf("Failed to parse relays file: %v", err)
	}

	// Get the seed.
	var seed []byte
	if *seedFile != "" {
		var err error
		seed, err = os.ReadFile(*seedFile)
		if err != nil {
			log.Fatalf("Failed to read seed file: %v", err)
		}
	} else {
		fmt.Print("Enter your secret seed: ")
		var err error
		seed, err = terminal.ReadPassword(int(os.Stdin.Fd()))
		fmt.Println()
		if err != nil {
			log.Fatalf("Failed to input seed: %v", err)
		}
	}
	seed = bytes.TrimSpace(seed)
	if len(seed) == 0 {
		log.Fatalf("Seed can't be an empty string!")
	}

	// Derive master private key from the seed using a memory hard function.
	t1 := time.Now()
	masterPriv := deriveMasterPriv(seed)
	log.Printf("Argon2 key derivation took %s.", time.Since(t1))

	// Derive two nostr private keys: for sender and receiver.
	senderRandomBytes := deriveKey(
		masterPriv, "nostr-private-key-sender", nostrRandomInputSize,
	)
	senderPriv := deterministicNostrPrivateKey(senderRandomBytes)
	senderPub, err := nostr.GetPublicKey(senderPriv)
	if err != nil {
		log.Fatalf("Failed to convert private nostr key to pubkey (sender): %v", err)
	}
	senderNpub, err := nip19.EncodePublicKey(senderPub)
	if err != nil {
		log.Fatalf("Failed to convert nostr pubkey to npub (sender): %v", err)
	}
	log.Printf("sender npub: %s", senderNpub)

	receiverRandomBytes := deriveKey(
		masterPriv, "nostr-private-key-receiver", nostrRandomInputSize,
	)
	receiverPriv := deterministicNostrPrivateKey(receiverRandomBytes)
	receiverPub, err := nostr.GetPublicKey(receiverPriv)
	if err != nil {
		log.Fatalf("Failed to convert private nostr key to pubkey (receiver): %v", err)
	}
	receiverNpub, err := nip19.EncodePublicKey(receiverPub)
	if err != nil {
		log.Fatalf("Failed to convert nostr pubkey to npub (receiver): %v", err)
	}
	log.Printf("receiver npub: %s", receiverNpub)

	sharedKey, err := nip04.ComputeSharedSecret(receiverPub, senderPriv)
	if err != nil {
		panic(err)
	}

	txt := make([]byte, 8*1024)

	encrypted, err := nip04.Encrypt(string(txt), sharedKey)
	if err != nil {
		panic(err)
	}

	ev := nostr.Event{
		PubKey:    senderPub,
		CreatedAt: nostr.Now(),
		Kind:      nostr.KindEncryptedDirectMessage,
		Tags: nostr.Tags{
			{
				"p", receiverPub,
			},
		},
		Content: encrypted,
	}
	ev.Sign(senderPriv)

	ctx := context.Background()

	var wg sync.WaitGroup

	for _, relay := range relays {
		wg.Add(1)
		go func() {
			defer wg.Done()

			ctx, cancel := context.WithTimeout(ctx, time.Second*10)
			defer cancel()

			relayClient, err := nostr.RelayConnect(ctx, relay)
			if err != nil {
				log.Printf("Failed to connect to relay %s: %v", relay, err)
				return
			}

			//err = relayClient.Auth(ctx, func(event *nostr.Event) error {
			//	if err := event.Sign(senderPriv); err != nil {
			//		return err
			//	}
			//	log.Println("Authenticated to relay.")

			//	return nil
			//})

			if err := relayClient.Publish(ctx, ev); err != nil {
				log.Printf("Failed to publish to relay %s: %v", relay, err)
				return
			}

			filters := []nostr.Filter{{
				Kinds:   []int{nostr.KindEncryptedDirectMessage},
				Authors: []string{senderPub},
				Limit:   1,
			}}
			sub, err := relayClient.Subscribe(ctx, filters)
			if err != nil {
				panic(err)
			}

			for ev := range sub.Events {
				fmt.Println(ev)
				return
			}
		}()
	}
	wg.Wait()
}

func deriveMasterPriv(seed []byte) []byte {
	// We don't have a salt, so derive it from seed to have something.
	h1 := sha256.Sum256(seed)
	h2 := sha256.Sum256([]byte("deriveMasterPriv"))
	salt := sha256.Sum256(append(h1[:], h2[:]...))

	const (
		time    = 1
		memory  = 64 * 1024
		threads = 4
		keyLen  = 64
	)
	return argon2.IDKey(seed, salt[:], time, memory, threads, keyLen)
}

func deriveKey(masterPriv []byte, purpose string, keyLen int) []byte {
	salt := []byte("deriveKey")
	reader := hkdf.New(sha256.New, masterPriv, salt, []byte(purpose))
	key := make([]byte, keyLen)
	n, err := reader.Read(key)
	if err != nil {
		panic(err)
	}
	if n != keyLen {
		panic("short read")
	}

	return key
}

const nostrRandomInputSize = 256/8 + 8

func deterministicNostrPrivateKey(randomBytes []byte) string {
	params := btcec.S256().Params()
	one := new(big.Int).SetInt64(1)

	if len(randomBytes) != params.BitSize/8+8 {
		panic("bad len of randomBytes")
	}

	k := new(big.Int).SetBytes(randomBytes)
	n := new(big.Int).Sub(params.N, one)
	k.Mod(k, n)
	k.Add(k, one)

	return fmt.Sprintf("%064x", k.Bytes())
}
