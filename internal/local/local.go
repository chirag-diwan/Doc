package local

import (
	"fmt"
	"os"
)

type DirTree struct {
	Files []string  `msgpack:"files"`
	Dirs  []DirTree `msgpack:"dirs"`
}

func walk(current string, root *DirTree) {
	entries, err := os.ReadDir(current)
	if err != nil {
		fmt.Print(err)
	}
	for _, entry := range entries {
		var child DirTree
		if entry.IsDir() {
			walk(fmt.Sprintf("%s/%s", current, entry.Name()), &child)
			root.Dirs = append(root.Dirs, child)
		} else {
			root.Files = append(root.Files, entry.Name())
		}
	}
}

func GetFiles(dir string) DirTree {
	_ = os.MkdirAll(dir, 0666)
	var root DirTree
	walk(dir, &root)
	return root
}

func OpenFile(path string) (string, error) {
	data, err := os.ReadFile(path)
	return string(data), err
}

func WriteFile(filename string, content string) error {
	return os.WriteFile(filename, []byte(content), 0666)
}
