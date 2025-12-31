//go:build !windows && !darwin && !linux

package main

func installCA(certPath string) error {
	return nil
}
