//go:build linux
// +build linux

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func installCA(absPath string) error {
	// Detect distro
	data, err := os.ReadFile("/etc/os-release")
	if err != nil {
		return fmt.Errorf("cannot detect distro: %v", err)
	}
	content := string(data)

	// Debian/Ubuntu/Kali
	if strings.Contains(content, "ID=debian") ||
		strings.Contains(content, "ID=ubuntu") ||
		strings.Contains(content, "ID=kali") {

		destDir := "/usr/local/share/ca-certificates"
		if err := os.MkdirAll(destDir, 0755); err != nil {
			return fmt.Errorf("failed to create cert dir: %v", err)
		}

		filename := filepath.Base(absPath)
		destPath := filepath.Join(destDir, filename)

		inputData, err := os.ReadFile(absPath)
		if err != nil {
			return fmt.Errorf("failed to read source file: %v", err)
		}
		if err := os.WriteFile(destPath, inputData, 0644); err != nil {
			return fmt.Errorf("failed to write cert file to system: %v", err)
		}

		fmt.Printf("Updating certificates for Debian/Ubuntu...\n")
		cmd := exec.Command("update-ca-certificates")
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr

		return cmd.Run()
	}

	// Arch / Manjaro
	if strings.Contains(content, "ID=arch") ||
		strings.Contains(content, "ID=manjaro") {

		cmd := exec.Command("trust", "anchor", "--store", absPath)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		return cmd.Run()
	}

	return fmt.Errorf("unsupported Linux distribution")
}
