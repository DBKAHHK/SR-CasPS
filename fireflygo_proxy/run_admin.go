//go:build !windows && !darwin && !linux

package main

func runWithAdmin(exePath string, env []string) error {
	return nil
}
