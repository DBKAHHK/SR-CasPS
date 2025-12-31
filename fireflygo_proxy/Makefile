build:
	@echo Building windows binary...
	set GOOS=windows&& set GOARCH=amd64&& set CGO_ENABLED=0&& go build -trimpath -ldflags="-s -w" .
	@echo Done!

build_ico:
	@echo Building application icon...
	magick logo.jpg -define icon:auto-resize=256,128,64,48,32,16 ./logo.ico
	@echo Done!

set_logo:
	@echo Embedding application icon...
	go-winres simply --icon ./logo.ico
	@echo Done!