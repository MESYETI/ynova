module ynova.interpreter;

import std.uni;
import std.array;
import std.stdio;
import std.format;
import std.algorithm;
import core.stdc.stdlib : exit;

struct Operation {
	string   stack;
	string[] tuple;
}

struct Rule {
	Operation[] conditions;
	Operation[] ops;

	// built in rules
	bool builtIn;
	void function(Interpreter) func;

	string toString() {
		string res;
		res ~= "Requires\n";

		foreach (ref op ; conditions) {
			res ~= format("    %s\n", op);
		}

		res ~= "Pushes\n";

		foreach (ref op ; ops) {
			res ~= format("    %s\n", op);
		}

		return res;
	}
}

class Interpreter {
	Rule[]             rules;
	string             code;
	size_t             i;
	char               ruleChar;
	char               stackChar;
	string[][][string] stacks;
	string[string]     subst;
	bool               runEmpty;
	size_t             rulesRun;

	this() {
		runEmpty = true;

		rules ~= Rule([Operation("", ["print", "$x"])], [], true, (Interpreter i) {
			writeln(i.subst["x"]);
		});
	}

	string ParseUntil(char[] chars) {
		string res;

		while (!chars.canFind(code[i])) {
			res ~= code[i];
			++ i;

			if (i >= code.length) {
				stderr.writefln("Expected one of %s, got EOF", chars);
				exit(1);
			}
		}

		return res;
	}

	string ParseUntil(char ch) => ParseUntil([ch]);

	Operation[] ParseOpsUntil(char ch) {
		while (code[i].isWhite()) ++ i;
		stackChar = code[i];

		Operation[] ret;

		for (; (i < code.length) && (code[i] != ch); ++ i) {
			if (code[i] == stackChar) {
				++ i;
				Operation op;
				op.stack  = ParseUntil(stackChar);
				++ i;
				op.tuple  = ParseUntil([ch, '\n']).split();
				ret      ~= op;

				if (code[i] == ch) {
					return ret;
				}
			}
			else if (code[i].isWhite()) {
				
			}
			else {
				stderr.writefln("Unexpected '%s', stack char is '%c'", code[i], stackChar);
				exit(1);
			}
		}

		return ret;
	}

	void ReadRules() {
		ruleChar = code[0];
		for (i = 0; i < code.length; ++ i) {
			if (code[i] == ruleChar) {
				Rule rule;
				++ i;
				rule.conditions = ParseOpsUntil(ruleChar);
				rules ~= rule;
			}
			else {
				if (rules.length == 0) {
					stderr.writefln("Define a rule!!!");
					exit(1);
				}
				rules[$ - 1].ops ~= ParseOpsUntil('\n');
			}
		}
	}

	string[] Substitute(string[] tuple) {
		string[] res;

		foreach (ref word ; tuple) {
			if (word[0] == '$') {
				if (word[1 .. $] !in subst) {
					stderr.writefln("Substitution '%s' doesn't exist", word);
					writeln(subst);
					exit(1);
				}

				res ~= subst[word[1 .. $]];
			}
			else {
				res ~= word;
			}
		}

		return res;
	}

	void RunRule(Rule rule) {
		subst = new string[string];

		if (rule.conditions.empty()) {
			if (runEmpty) runEmpty = false;
			else          return;
		}

		foreach (ref op ; rule.conditions) {
			if (op.stack !in stacks) {
				return;
			}

			if (stacks[op.stack].empty()) {
				return;
			}

			if (stacks[op.stack][$ - 1].length != op.tuple.length) {
				return;
			}

			foreach (i, ref word ; stacks[op.stack][$ - 1]) {
				if (op.tuple[i][0] == '$') {
					subst[op.tuple[i][1 .. $]] = word;
					continue;
				}

				if (op.tuple[i] != stacks[op.stack][$ - 1][i]) return;
			}
		}

		// now let's run the rule
		++ rulesRun;

		// pop condition tuples
		foreach (ref op ; rule.conditions) {
			stacks[op.stack] = stacks[op.stack][0 .. $ - 1];
		}

		// run rule
		foreach (ref op ; rule.ops) {
			if (op.stack !in stacks) {
				stacks[op.stack] = string[][].init;
			}

			stacks[op.stack] ~= Substitute(op.tuple);
			//writefln("Pushing %s to %s", Substitute(op.tuple), op.stack);
		}

		if (rule.builtIn) {
			rule.func(this);
		}
	}

	void Run() {
		while (true) {
			rulesRun = 0;
			foreach (ref rule ; rules) {
				RunRule(rule);
			}

			if (rulesRun == 0) {
				return;
			}
		}
	}
}
