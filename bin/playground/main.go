package main

import (
	mod "./hello"
	"grumpy"
	"os"
)

func main() {
	grumpy.ImportModule(grumpy.NewRootFrame(), "traceback")
	os.Exit(grumpy.RunMain(mod.Code))
}
