package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/elazarl/goproxy"
	zlog "github.com/rs/zerolog/log"
)

var ENV_CONFIG = make([]string, 0)

func main() {
	redirectHost := flag.String("r", "127.0.0.1:21000", "redirect target host")
	blockedStr := flag.String("b", "", "comma separated list of blocked ports")
	exePath := flag.String("e", "", "path to the executable")
	flag.Parse()

	blockedPorts := parseBlockedPorts(*blockedStr)
	port := findFreePort(blockedPorts)
	if port == "-1" {
		zlog.Error().Str("port", port).Msg("No free port available")
		return
	}

	cert, err := setupCertificate()
	if err != nil {
		zlog.Error().Err(err).Msg("Failed setup certificate")
		return
	}
	addr := ":" + port
	proxyAddr := "127.0.0.1"

	defer func() {
		if r := recover(); r != nil {
			zlog.Error().
				Interface("panic", r).
				Msg("Unexpected panic, resetting system proxy")

			setProxy(false, "", "")
		}
	}()

	setProxy(true, proxyAddr, port)

	customCaMitm := &goproxy.ConnectAction{Action: goproxy.ConnectMitm, TLSConfig: goproxy.TLSConfigFromCA(cert)}
	var customAlwaysMitm goproxy.FuncHttpsHandler = func(host string, ctx *goproxy.ProxyCtx) (*goproxy.ConnectAction, string) {
		domain := cleanHost(host)
		if matchDomain(domain, RedirectDomains) {
			return customCaMitm, host
		}
		return goproxy.OkConnect, host
	}

	proxy := goproxy.NewProxyHttpServer()
	proxy.Logger = log.New(io.Discard, "", 0)
	proxy.Tr = &http.Transport{
		Proxy:               http.ProxyFromEnvironment,
		MaxIdleConns:        1000,
		MaxIdleConnsPerHost: 100,
		IdleConnTimeout:     90 * time.Second,
		DisableCompression:  false,
	}
	proxy.CertStore = NewCertStorage()
	proxy.OnRequest().HandleConnect(customAlwaysMitm)

	proxy.OnRequest().DoFunc(func(req *http.Request, ctx *goproxy.ProxyCtx) (*http.Request, *http.Response) {
		host := req.URL.Hostname()
		path := req.URL.Path

		if matchDomain(host, AlwaysIgnoreDomains) {
			return req, nil
		}

		if matchDomain(host, RedirectDomains) {
			if matchURL(path, BlockUrls) {
				full := req.URL.String()
				zlog.Warn().Str("url", full).Msg("Blocked URL")
				return req, goproxy.NewResponse(
					req,
					goproxy.ContentTypeText,
					http.StatusNotFound,
					`{\n"message": "blocked by proxy",\n,"success": false,\n"retcode": -1\n}`,
				)
			}
			full := req.URL.String()
			if matchURL(full, ForceRedirectOnUrlContains) {

				zlog.Info().Str("Url", full).Msg("Force redirect")

				req.URL.Scheme = "http"
				req.URL.Host = *redirectHost
				return req, nil
			}

			zlog.Info().Str("Host", host).Msg("Redirect domain")
			req.URL.Scheme = "http"
			req.URL.Host = *redirectHost
			return req, nil
		}

		return req, nil
	})

	srv := &http.Server{
		Addr:              addr,
		Handler:           proxy,
		ReadTimeout:       10 * time.Second,
		ReadHeaderTimeout: 5 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    1 << 20,
	}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	if *exePath != "" && exists(*exePath) {
		go func() {
			time.Sleep(1 * time.Second)
			err := runWithAdmin(*exePath, ENV_CONFIG)
			if err != nil {
				zlog.Error().Err(err).Msg("Failed to start exe as admin")
			} else {
				zlog.Info().Str("ExePath", *exePath).Msg("Started exe as admin")
			}
		}()
	}
	go func() {
		zlog.Info().
			Str("ProxyAddress", proxyAddr).
			Str("RedirectTo", *redirectHost).
			Str("BlockedPorts", strings.Trim(strings.Join(strings.Fields(fmt.Sprint(blockedPorts)), ","), "[]")).
			Str("ExePath", *exePath).
			Msg("Proxy started")
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			zlog.Fatal().Err(err).Msg("ListenAndServe failed")
		}
	}()

	<-stop
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		zlog.Error().Err(err).Msg("Server shutdown error")
	}
	setProxy(false, "", "")
}
