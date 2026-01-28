package network

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
)

func log(err error) {
	if err != nil {
		fmt.Print(err)
		os.Exit(-1)
	}
}

func getFileName(lang string) string {
	return fmt.Sprintf("/tmp/%s_index.json", lang)
}

type Indices struct {
	Entries []struct {
		Name string `json:"name" msgpack:"name"`
		Path string `json:"path" msgpack:"path"`
		Type string `json:"type" msgpack:"type"`
	} `json:"entries" msgpack:"entries"`
}

func GetIndices(lang string) Indices {
	filepath := getFileName(lang)

	if _, err := os.Stat(filepath); os.IsExist(err) {
		data, err := os.ReadFile(filepath)
		log(err)
		var indices Indices
		log(json.NewDecoder(bytes.NewReader(data)).Decode(&indices))
		return indices
	}
	var url string
	switch strings.ToLower(lang) {
	case "js":
		url = "ttps://devdocs.io/docs/javascript/index.json"
	case "cpp":
	case "c":
	case "py":
	case "rs":
	case "lua":
	}
	resp, err := http.Get(url)
	log(err)
	defer resp.Body.Close()
	var indices Indices
	log(json.NewDecoder(resp.Body).Decode(&indices))
	return indices
}
