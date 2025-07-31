module main

import os

enum LANG {
	c
	cpp
}

struct Compiler {
	executable string
	language   LANG
}

fn Compiler.detect_for_lang(lang LANG) !Compiler {
	c_compilers := ['gcc', 'clang', 'cl']
	cpp_compilers := ['g++', 'clang++', 'cl']

	if lang == .c {
		for c in c_compilers {
			_ := os.find_abs_path_of_executable(c) or { continue }
			return Compiler.new(c)
		}
	} else if lang == .cpp {
		for c in cpp_compilers {
			_ := os.find_abs_path_of_executable(c) or { continue }
			return Compiler.new(c)
		}
	}

	return error('No compiler found for language ${lang}')
}

fn Compiler.new(cc string) !Compiler {
	c := match cc {
		'gcc' {
			Compiler{
				executable: cc
				language:   LANG.c
			}
		}
		'clang' {
			Compiler{
				executable: cc
				language:   LANG.c
			}
		}
		'g++' {
			Compiler{
				executable: cc
				language:   LANG.cpp
			}
		}
		'clang++' {
			Compiler{
				executable: cc
				language:   LANG.cpp
			}
		}
		'cl' {
			Compiler{
				executable: cc
				language:   LANG.cpp
			}
		}
		else {
			return error('Compiler ${cc} not supported')
		}
	}
	return c
}

fn (cc Compiler) compile_file(src string, obj string) ! {
	println('> ${cc.executable} -c ${src} -o ${obj}')

	run_process_cross_plat([cc.executable, '-c', src, '-o', obj])!
}

fn (cc Compiler) link_objs(obj_files []string, output string) ! {
	mut cmd := []string{}
	cmd << cc.executable
	cmd << obj_files
	cmd << ['-o', output]

	println('> ${cmd.join(' ')}')
	run_process_cross_plat(cmd)!
}
