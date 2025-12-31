package main

import (
	"net"
	"os"
	"slices"
	"strconv"
	"strings"
)

func matchDomain(host string, list []string) bool {
	for _, d := range list {
		if strings.HasSuffix(host, d) {
			return true
		}
	}
	return false
}

func matchURL(url string, list []string) bool {
	for _, u := range list {
		if strings.HasPrefix(url, u) {
			return true
		}
	}
	return false
}

func cleanHost(h string) string {
	if idx := strings.LastIndex(h, ":"); idx != -1 {
		return h[:idx]
	}
	return h
}

func findFreePort(blocked []int) string {
	for {
		ln, err := net.Listen("tcp", ":0")
		if err != nil {
			return "-1"
		}
		port := ln.Addr().(*net.TCPAddr).Port
		ln.Close()

		if !slices.Contains(blocked, port) {
			return strconv.Itoa(port)
		}
	}
}

func parseBlockedPorts(s string) []int {
	var ports []int
	if s == "" {
		return ports
	}
	for _, p := range strings.Split(s, ",") {
		if port, err := strconv.Atoi(strings.TrimSpace(p)); err == nil {
			ports = append(ports, port)
		}
	}
	return ports
}

func exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
