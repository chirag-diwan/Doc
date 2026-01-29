.PHONY: build clean manifest

# Build the binary into the bin/ folder
build:
	go build -o ~/.local/bin/Doc ./cmd

manifest:
	Doc -manifest Doc 

clean:
	rm -rf bin/
