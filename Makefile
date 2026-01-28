.PHONY: build clean

# Build the binary into the bin/ folder
build:
	go build -o bin/server ./cmd/server

clean:
	rm -rf bin/
