//go:build windows
// +build windows

package main

import (
	"os/exec"
)

func installCA(absPath string) error {
	cmd := exec.Command("certutil", "-addstore", "-user", "root", absPath)
	if err := cmd.Run(); err != nil {
		return err
	}

	return nil
}
