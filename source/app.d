module ynova.app;

import std.file;
import std.stdio;
import ynova.interpreter;

void main(string[] args) {
	auto interpreter = new Interpreter();
	interpreter.code = readText(args[1]);
	interpreter.ReadRules();
	interpreter.Run();
}
