// Sample Go file for testing

package main

type MyStruct struct {
	Value int
}

func (m *MyStruct) GetValue() int {
	return m.Value
}

func (m *MyStruct) SetValue(val int) {
	m.Value = val
}

func topLevelFunction() {
	println("top level")
}

type AnotherType struct {
	Name string
}

func (a *AnotherType) GetName() string {
	return a.Name
}

func anotherFunction() {
	println("another")
}
