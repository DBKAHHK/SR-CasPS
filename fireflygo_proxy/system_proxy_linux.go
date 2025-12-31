//go:build linux
// +build linux

package main

import "fmt"

func setProxy(enable bool, host string, port string) error {

	httpProxy1 := fmt.Sprintf("HTTP_PROXY=http://%s:%s", host, port)
	httpProxy2 := fmt.Sprintf("http_proxy=http://%s:%s", host, port)

	ENV_CONFIG = append(ENV_CONFIG, httpProxy1, httpProxy2)

	httpsProxy1 := fmt.Sprintf("HTTPS_PROXY=http://%s:%s", host, port)
	httpsProxy2 := fmt.Sprintf("https_proxy=http://%s:%s", host, port)
	ENV_CONFIG = append(ENV_CONFIG, httpsProxy1, httpsProxy2)

	if enable {
		ENV_CONFIG = make([]string, 0)
	}

	return nil
}
