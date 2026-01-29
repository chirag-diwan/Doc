package network

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
)

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

func GetIndices(lang string) (Indices, error) {
	filepath := getFileName(lang)
	if _, err := os.Stat(filepath); err == nil {
		data, err := os.ReadFile(filepath)
		if err != nil {
			return Indices{}, fmt.Errorf("failed to read cached file: %w", err)
		}
		var indices Indices
		if err := json.NewDecoder(bytes.NewReader(data)).Decode(&indices); err != nil {
			return Indices{}, fmt.Errorf("failed to decode cached JSON: %w", err)
		}
		log.Printf("Loaded indices from cache: %s", filepath)
		return indices, nil
	}

	var url string
	switch strings.ToLower(lang) {
	case "js":
		url = "https://documents.devdocs.io/javascript/index.json"
	case "cpp":
		url = "https://documents.devdocs.io/cpp/index.json"
	case "c":
		url = "https://documents.devdocs.io/c/index.json"
	case "py":
		url = "https://documents.devdocs.io/python~3.12/index.json"
	case "rs":
		url = "https://documents.devdocs.io/rust/index.json"
	case "lua":
		url = "https://documents.devdocs.io/lua/index.json"
	default:
		return Indices{}, fmt.Errorf("unsupported language: %s", lang)
	}

	resp, err := http.Get(url)
	if err != nil {
		return Indices{}, fmt.Errorf("HTTP GET failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return Indices{}, fmt.Errorf("HTTP status not OK: %d %s", resp.StatusCode, resp.Status)
	}

	var indices Indices
	if err := json.NewDecoder(resp.Body).Decode(&indices); err != nil {
		return Indices{}, fmt.Errorf("failed to decode JSON from response: %w", err)
	}

	jsonBytes, err := json.Marshal(indices)
	if err != nil {
		log.Printf("Warning: failed to marshal for caching: %v", err)
	} else {
		if err := os.WriteFile(filepath, jsonBytes, 0644); err != nil {
			log.Printf("Warning: failed to write cache file %s: %v", filepath, err)
		} else {
			log.Printf("Cached indices to: %s", filepath)
		}
	}
	return indices, nil
}

func GetPath(path string) string {
	var url string
	switch path {
	case "js":
		url = fmt.Sprintf("https://documents.devdocs.io/javascript/%s", path)
	case "cpp":
		url = fmt.Sprintf("https://documents.devdocs.io/javascript/%s", path)
	case "c":
		url = fmt.Sprintf("https://documents.devdocs.io/javascript/%s", path)
	case "py":
		url = fmt.Sprintf("https://documents.devdocs.io/javascript/%s", path)
	case "rs":
		url = fmt.Sprintf("https://documents.devdocs.io/javascript/%s", path)
	case "lua":
		url = fmt.Sprintf("https://documents.devdocs.io/javascript/%s", path)
	}
	resp, err := http.Get(url)
	if err != nil {
		return fmt.Sprintf("%v", err)
	}
	defer resp.Body.Close()

	var data string
	err = json.NewDecoder(resp.Body).Decode(&data)
	if err != nil {
		return fmt.Sprintf("%v", err)
	}
	return data
}
