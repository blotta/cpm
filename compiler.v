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

fn (cc Compiler) compile_file(src string, obj string, include_dirs []string, compile_flags []string) ! {
	mut cmd := []string{}
	cmd << cc.executable

	if cc.executable == 'cl' {

		// omit cl logo
		cmd << "/nologo"

		//object flag
		cmd << "/c"

		// source file
		cmd << src

		// include dirs
		for inc in include_dirs {
			cmd << '/I'
			cmd << inc
		}

		// other flags
		for flag in compile_flags {
			for arg in flag.split_by_space() {
				cmd << arg
			}
		}

		// output
		cmd << "/Fo:${obj}"

	} else { // gcc, g++, clang, clang++
		// object flag
		cmd << '-c'

		// source file
		cmd << src

		// include dirs
		for inc in include_dirs {
			cmd << '-I'
			cmd << inc
		}

		// other flags
		for flag in compile_flags {
			for arg in flag.split_by_space() {
				cmd << arg
			}
		}

		// output
		cmd << ['-o', obj]
	}

	println('> ${cmd.join(' ')}')
	run_process_cross_plat(cmd)!
}

fn (cc Compiler) link_objs(obj_files []string, output string, lib_dirs []string, libs []string, link_flags []string) ! {
	mut cmd := []string{}
	cmd << cc.executable

	if cc.executable == 'cl' {
		// omit cl logo
		cmd << "/nologo"

		// object files
		cmd << obj_files

		// libraries to link to
		for lib in libs {
			cmd << lib
		}

		// output
		cmd << "/Fe:${output}"

		// link.exe params
		cmd << "/link"

		// library directories
		for lib_dir in lib_dirs {
			cmd << "/LIBPATH:${lib_dir}"
		}
		
		// other flags
		for flag in link_flags {
			for arg in flag.split_by_space() {
				cmd << arg
			}
		}

	} else { // gcc, g++, clang, clang++
		// object files
		cmd << obj_files

		// output
		cmd << ['-o', output]

		// library directories
		for lib_dir in lib_dirs {
			cmd << "-L"
			cmd << lib_dir
		}

		// libraries to link to
		for lib in libs {
			cmd << "-l"
			cmd << lib
		}

		// other flags
		for flag in link_flags {
			for arg in flag.split_by_space() {
				cmd << arg
			}
		}

	}

	println('> ${cmd.join(' ')}')
	run_process_cross_plat(cmd)!
}
