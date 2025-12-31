//go:build linux
// +build linux

package main

import (
	"os"
	"os/exec"
)

func runWithAdmin(exePath string, env []string) error {
	cmd := exec.Command("pkexec", exePath)
	cmd.Env = append(os.Environ(), env...)
	return cmd.Start()
}
