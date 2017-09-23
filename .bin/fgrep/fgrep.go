package main

import (
	"bufio"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
)

var (
	patterns = flag.String("patterns", "", "File with patterns")
	input    = flag.String("input", "", "Input file")
)

func main() {
	flag.Parse()
	if *patterns == "" || *input == "" {
		log.Fatal("Please provide -patterns and -input")
	}
	f1, err := os.Open(*patterns)
	if err != nil {
		log.Fatalf("Openning patterns file: %v.", err)
	}
	defer f1.Close()
	var oldnew []string
	s1 := bufio.NewScanner(f1)
	for s1.Scan() {
		oldnew = append(oldnew, s1.Text(), "")
	}
	if err := s1.Err(); err != nil {
		log.Fatalf("Reading patterns file: %v.", err)
	}
	replacer := strings.NewReplacer(oldnew...)
	f2, err := os.Open(*input)
	if err != nil {
		log.Fatalf("Openning input file: %v.", err)
	}
	defer f2.Close()
	s2 := bufio.NewScanner(f2)
	for s2.Scan() {
		if t := s2.Text(); replacer.Replace(t) != t {
			fmt.Println(t)
		}
	}
	if err := s2.Err(); err != nil {
		log.Fatalf("Reading input file: %v.", err)
	}
}
