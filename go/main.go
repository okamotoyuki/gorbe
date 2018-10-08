package main

import (
	mod "../build/gorbe"
	"grumpy"
	"os"
)

func main() {
	grumpy.ImportModule(grumpy.NewRootFrame(), "traceback")
	os.Exit(grumpy.RunMain(mod.Code))
}
