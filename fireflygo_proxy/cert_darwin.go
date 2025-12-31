//go:build darwin
// +build darwin

package main

import (
	"os/exec"
)

func installCA(absPath string) error {
	cmd := exec.Command(
		"security",
		"add-trusted-cert",
		"-d",
		"-r", "trustRoot",
		"-k", "/Library/Keychains/System.keychain",
		absPath,
	)

	if err := cmd.Run(); err != nil {
		return err
	}

	return nil
}
