//go:build darwin
// +build darwin

package main

import (
	"fmt"
	"os/exec"
	"strings"
)

func parseNetworkServices(out string) []string {
	lines := strings.Split(out, "\n")
	var result []string

	for _, line := range lines {
		if strings.Contains(line, "(Hardware Port:") {
			start := strings.Index(line, "Hardware Port: ") + len("Hardware Port: ")
			end := strings.Index(line[start:], ",")
			if end > 0 {
				result = append(result, line[start:start+end])
			}
		}
	}
	return result
}

func contains(arr []string, v string) bool {
	for _, x := range arr {
		if x == v {
			return true
		}
	}
	return false
}

func setProxy(enable bool, host string, port string) error {
	out, err := exec.Command("networksetup", "-listnetworkserviceorder").CombinedOutput()
	if err != nil {
		return err
	}

	services := parseNetworkServices(string(out))
	active := ""

	if contains(services, "Wi-Fi") {
		active = "Wi-Fi"
	} else if contains(services, "Ethernet") {
		active = "Ethernet"
	} else {
		if len(services) == 0 {
			return fmt.Errorf("no network services found")
		}
		active = services[0]
	}

	if enable {
		exec.Command("networksetup", "-setwebproxy", active, host, port).Run()
		exec.Command("networksetup", "-setsecurewebproxy", active, host, port).Run()
		exec.Command("networksetup", "-setwebproxystate", active, "on").Run()
		exec.Command("networksetup", "-setsecurewebproxystate", active, "on").Run()
	} else {
		exec.Command("networksetup", "-setwebproxystate", active, "off").Run()
		exec.Command("networksetup", "-setsecurewebproxystate", active, "off").Run()
	}

	return nil
}
