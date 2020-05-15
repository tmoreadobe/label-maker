package controller

import (
	"github.com/xelalexv/label-maker/pkg/controller/labelmaker"
)

func init() {
	// AddToManagerFuncs is a list of functions to create controllers and add them to a manager.
	AddToManagerFuncs = append(AddToManagerFuncs, labelmaker.Add)
}
