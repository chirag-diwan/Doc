package main

import (
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/chirag-diwan/Doc.git/internal/network"
	"github.com/neovim/go-client/nvim/plugin"
)

func main() {
	logFile, _ := os.Create("doc_log.txt")
	log.SetOutput(logFile)
	defer logFile.Close()

	plugin.Main(func(p *plugin.Plugin) error {
		p.HandleFunction(
			&plugin.FunctionOptions{
				Name: "Hello",
			},
			func(arg []string) (string, error) {
				return strings.Join(arg, " "), nil
			},
		)
		p.HandleFunction(
			&plugin.FunctionOptions{
				Name: "GetIndices",
			},
			func(args []string) (network.Indices, error) {
				if len(args) < 2 {
					return network.Indices{}, fmt.Errorf("expected 2 args (lang, callback), got %d", len(args))
				}
				lang := args[0]
				//			callbackName := args[1]
				indicesStruct, err := network.GetIndices(lang)
				if err != nil {
					return network.Indices{}, fmt.Errorf("JSON Marshal error: %v", err)
				}
				return indicesStruct, nil
			},
		)
		p.HandleFunction(
			&plugin.FunctionOptions{
				Name: "GetPath",
			},
			func(args []string) (string, error) {
				if len(args) > 1 {
					return "", fmt.Errorf("Expected 1 argument got :: %d", len(args))
				}
				data := network.GetPath(args[0])
				return data, nil
			},
		)
		return nil
	})
}
