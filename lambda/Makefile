.PHONY: deps clean build

deps:
	go get -u ./...

clean: 
	rm -rf ./parser/parser
	
build:
	GOOS=linux GOARCH=amd64 go build -o parser/parser ./parser