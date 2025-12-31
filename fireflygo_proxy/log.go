package main

import (
	"os"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

func init() {
	output := zerolog.ConsoleWriter{
		Out:        os.Stdout,
		PartsOrder: []string{"level", "message"},
	}

	log.Logger = zerolog.New(output).With().Logger()
}
