//go:build !windows && !darwin && !linux

package main

func setProxy(enable bool, host string, port string) error {
	return nil
}