//go:build darwin
// +build darwin

package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func runWithAdmin(exePath string, env []string) error {
	escaped := strings.ReplaceAll(exePath, `"`, `\"`)
	script := fmt.Sprintf(`do shell script "%s" with administrator privileges`, escaped)

	cmd := exec.Command("osascript", "-e", script)
	cmd.Env = append(os.Environ(), env...)
	return cmd.Start()
}
