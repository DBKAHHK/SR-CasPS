//go:build windows
// +build windows

package main

import (
	"fmt"
	"syscall"

	"golang.org/x/sys/windows/registry"
)

func setProxy(enable bool, host string, port string) error {
	k, _, err := registry.CreateKey(
		registry.CURRENT_USER,
		`Software\Microsoft\Windows\CurrentVersion\Internet Settings`,
		registry.SET_VALUE,
	)
	if err != nil {
		return err
	}

	if enable {
		k.SetDWordValue("ProxyEnable", 1)

		addr := fmt.Sprintf("%s:%s", host, port)
		val := fmt.Sprintf("http=%s;https=%s", addr, addr)

		k.SetStringValue("ProxyServer", val)

	} else {
		k.SetDWordValue("ProxyEnable", 0)
	}

	k.Close()

	d := syscall.NewLazyDLL("wininet.dll")
	o := d.NewProc("InternetSetOptionW")
	o.Call(0, 39, 0, 0)
	o.Call(0, 37, 0, 0)

	return nil
}
