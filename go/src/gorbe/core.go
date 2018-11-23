package gorbe

import (
	πg "grumpy"
	"fmt"
)

// TODO : This function will be removed when "Kernel" module is supported.
func temporaryP(f *πg.Frame, args πg.Args, kwargs πg.KWArgs) (*πg.Object, *πg.BaseException) {
	for _, arg := range args {
		s, raised := πg.ToStr(f, arg)
		if raised != nil {
			return nil, raised
		}
		fmt.Println(s.Value())
	}

	return nil, nil
}

func InitGlobalsForRuby(f *πg.Frame) (*πg.BaseException) {
	if raised := f.Globals().SetItemString(f, "true", πg.True.ToObject()); raised != nil {
		return raised
	}
	if raised := f.Globals().SetItemString(f, "false", πg.False.ToObject()); raised != nil {
		return raised
	}
	if raised :=
		f.Globals().SetItemString(f, "p", πg.NewBuiltinFunction("puts", temporaryP).ToObject()); raised != nil {
		return raised
	}
	return nil
}
