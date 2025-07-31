module main

import os
import cli
import json

struct CpmPackage {
	name       string = 'app'
	version    string = '0.1.0'
	source_dir string = 'src'
mut:
	c_compiler   string
	cpp_compiler string
	include_dirs []string
	lib_dirs []string
	libs []string
	compile_flags []string
	link_flags []string
	dependencies map[string]CpmPackage
}

fn CpmPackage.default() CpmPackage {
	proj_name := os.base(os.getwd())
	c := CpmPackage{
		name: proj_name
		include_dirs: ["include"]
		lib_dirs: ["lib"]
	}
	return c
}

fn CpmPackage.load() !CpmPackage {
	data := os.read_file('cpm.json')!
	return json.decode(CpmPackage, data)
}

fn (c CpmPackage) save() {
	os.write_file('cpm.json', json.encode_pretty(c)) or {
		eprintln('Failed to save cpm.json: ${err}')
	}
}

fn (mut c CpmPackage) build() ! {
	mut obj_files := []string{}

	c_files := find_source_files_recursive(c.source_dir, .c)
	if c_files.len > 0 {
		obj_files << c.compile_files_lang(c_files, .c, c.include_dirs, c.compile_flags)!
	}

	cpp_files := find_source_files_recursive(c.source_dir, .cpp)
	if cpp_files.len > 0 {
		obj_files << c.compile_files_lang(cpp_files, .cpp, c.include_dirs, c.compile_flags)!
	}

	c.link_files()!
}

fn (mut c CpmPackage) link_files() ! {
	obj_dir := os.join_path('.cpm', 'obj')
	obj_c_files := os.walk_ext(obj_dir, '.c.obj')
	obj_cpp_files := os.walk_ext(obj_dir, '.cpp.obj')
	// println('obj files: ${obj_c_files}, ${obj_cpp_files}')

	lang := if obj_cpp_files.len > 0 { LANG.cpp } else { LANG.c }
	cfg_compiler := if lang == .c { c.c_compiler } else { c.cpp_compiler }

	cc := match cfg_compiler {
		'' { Compiler.detect_for_lang(lang)! }
		else { Compiler.new(cfg_compiler)! }
	}
	println('${lang} linker: ${cc.executable}')

	mut obj_files := []string{}
	obj_files << obj_c_files
	obj_files << obj_cpp_files
	cc.link_objs(obj_files, c.output_file(), c.lib_dirs, c.libs, c.link_flags)!
}

fn (c CpmPackage) output_file() string {
	mut output := c.name

	if os.user_os() == 'windows' {
		output += '.exe'
	}

	return output
}

fn (c CpmPackage) obj_dir() string {
	obj_dir := os.join_path('.cpm', 'obj')
	return obj_dir
}

fn (mut c CpmPackage) compile_files_lang(src_files []string, lang LANG, include_dirs []string, compile_flags []string) ![]string {
	cfg_compiler := if lang == .c { c.c_compiler } else { c.cpp_compiler }
	cc := match cfg_compiler {
		'' { Compiler.detect_for_lang(lang)! }
		else { Compiler.new(cfg_compiler)! }
	}

	println('${lang} compiler: ${cc.executable}')
	obj_dir := os.join_path('.cpm', 'obj')
	os.mkdir_all(obj_dir) or { return error('could not create obj directory') }

	mut obj_files := []string{}
	for src_file in src_files {
		obj_file := os.base(src_file) + '.obj'
		obj_path := os.join_path(obj_dir, obj_file)
		cc.compile_file(src_file, obj_path, include_dirs, compile_flags)!
		obj_files << obj_path
	}

	// println(obj_files)
	return obj_files
}

fn (c CpmPackage) clean() ! {
	if os.exists(c.output_file()) {
		os.rm(c.output_file())!
	}

	pdbs := os.glob("*.pdb") or { 
		eprintln("failed to grab *.pdb files: $err")
		[]
	}
	for f in pdbs {
		os.rm(f)!
	}

	os.rmdir_all(c.obj_dir())!
}

fn (mut c CpmPackage) run() ! {
	if !os.exists(c.output_file()) {
		c.build()!
	}

	run_process_cross_plat([c.output_file()])!
}

fn find_source_files_recursive(source_dir string, lang LANG) []string {
	ext := match lang {
		.c { '.c' }
		.cpp { '.cpp' }
	}

	c_src := os.walk_ext(source_dir, ext, os.WalkParams{ hidden: false })
	return c_src
}

fn main() {
	mut cfg := CpmPackage.load() or { CpmPackage.default() }

	mut app := cli.Command{
		name:        'cpm'
		description: 'C Project Manager'
		commands:    [
			cli.Command{
				name:    'init'
				execute: fn [cfg] (cmd cli.Command) ! {
					println(cfg)
					cfg.save()
					return
				}
			},
			cli.Command{
				name:    'build'
				execute: fn [mut cfg] (cmd cli.Command) ! {
					cfg.build() or { eprintln(err) }
					return
				}
			},
			cli.Command{
				name:    'run'
				execute: fn [mut cfg] (cmd cli.Command) ! {
					cfg.build() or {
						eprintln(err)
						return
					}
					cfg.run() or { eprintln(err) }
					return
				}
			},
			cli.Command{
				name:    'clean'
				execute: fn [mut cfg] (cmd cli.Command) ! {
					cfg.clean() or { eprintln(err) }
					return
				}
			},
		]
	}

	app.setup()
	app.parse(os.args)
}
