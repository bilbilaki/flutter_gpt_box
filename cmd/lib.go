package main

/*
#include "stdint.h"
*/
import "C"
import (
	"unsafe"
	bridge "hiddify.com/hiddify/bridge"
)

//export initNativeDartBridge
func initNativeDartBridge(api unsafe.Pointer) {
	bridge.InitDartApi(api)
}