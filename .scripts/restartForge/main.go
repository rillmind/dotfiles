package main

import (
	"log"
	"os/exec"
)

func main() {
	disable := exec.Command("gnome-extensions", "disable", "forge@jmmaranan.com")
	enable := exec.Command("gnome-extensions", "enable", "forge@jmmaranan.com")

	err := disable.Run()
	if err != nil {
		log.Fatal("disable err: ", err)
	}

	err = enable.Run()
	if err != nil {
		log.Fatal("disable err: ", err)
	}
}
