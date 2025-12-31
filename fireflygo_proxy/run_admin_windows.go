//go:build windows
// +build windows

package main

import (
	"os"
	"os/exec"
)

func runWithAdmin(exePath string, env []string) error {
	cmd := exec.Command("powershell", "Start-Process", exePath, "-Verb", "runAs")
	cmd.Env = append(os.Environ(), env...)
	return cmd.Start()
}
