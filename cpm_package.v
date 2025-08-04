module main

import os
import json
import sync
import arrays

struct CpmPackage {
	name       string = 'app'
	version    string = '0.1.0'
	source_dir string = 'src'
	parallel_compilation bool = true
mut:
	c_compiler    string
	cpp_compiler  string
	include_dirs  []string
	lib_dirs      []string
	libs          []string
	compile_flags []string
	link_flags    []string
	dependencies  map[string]CpmPackage
}

fn CpmPackage.default() CpmPackage {
	proj_name := os.base(os.getwd())
	c := CpmPackage{
		name:         proj_name
		include_dirs: ['include']
		lib_dirs:     ['lib']
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

fn (c CpmPackage) find_source_files_recursive(source_dir string, lang LANG) []string {
	ext := match lang {
		.c { '.c' }
		.cpp { '.cpp' }
	}

	src_files := os.walk_ext(source_dir, ext, os.WalkParams{ hidden: false })
	return src_files
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

fn (mut c CpmPackage) build() ! {
	mut obj_files := []string{}

	c_files := c.find_source_files_recursive(c.source_dir, .c)
	if c_files.len > 0 {
		obj_files << c.compile_files_lang(c_files, .c, c.include_dirs, c.compile_flags, c.parallel_compilation)!
	}

	cpp_files := c.find_source_files_recursive(c.source_dir, .cpp)
	if cpp_files.len > 0 {
		obj_files << c.compile_files_lang(cpp_files, .cpp, c.include_dirs, c.compile_flags, c.parallel_compilation)!
	}

	c.link_files()!
}

fn (mut c CpmPackage) compile_files_lang(src_files []string, lang LANG, include_dirs []string, compile_flags []string, parallel_compilation bool) ![]string {
	cfg_compiler := if lang == .c { c.c_compiler } else { c.cpp_compiler }
	cc := match cfg_compiler {
		'' { Compiler.detect_for_lang(lang)! }
		else { Compiler.new(cfg_compiler)! }
	}

	println('${lang} compiler: ${cc.executable}')
	obj_dir := os.join_path('.cpm', 'obj')
	os.mkdir_all(obj_dir) or { return error('could not create obj directory') }

	mut obj_files := []string{}
	mut wg := sync.new_waitgroup()
	mut err_chan := chan IError{cap: src_files.len}
	defer {
		err_chan.close()
	}
	for src_file in src_files {
		// obj_file := os.base(src_file) + '.obj'
		obj_file := src_file + '.obj'
		obj_path := os.join_path(obj_dir, obj_file)
		os.mkdir_all(os.dir(obj_path)) or { return error('could not create mirror obj directory')}
		obj_files << obj_path

		if os.exists(obj_path) {
			src_mtime := os.file_last_mod_unix(src_file)
			obj_mtime := os.file_last_mod_unix(obj_path)
			if obj_mtime > src_mtime {
				println('Up-to-date ${src_file}')
				continue
			}
		}
		if parallel_compilation {
			wg.add(1)
			go fn(cc Compiler, src_file string, obj_path string, include_dirs []string, compile_flags []string, mut wg sync.WaitGroup, err_chan chan IError) ! {
				defer {
					wg.done()
				}
				cc.compile_file(src_file, obj_path, include_dirs, compile_flags) or {
					err_chan <- err
				}
			}(cc, src_file, obj_path, include_dirs, compile_flags, mut wg, err_chan)
		} else {
			cc.compile_file(src_file, obj_path, include_dirs, compile_flags)!
		}
	}

	wg.wait()

	if err_chan.len > 0 {
		return <-err_chan
	}

	return obj_files
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

	if obj_files.len == 0 {
		println('No object files to link')
		return
	}

	// check if there are updated object files
	if os.exists(c.output_file()) {
		mtimes := obj_files.map(os.file_last_mod_unix(it))
		max_obj_mtime := arrays.max(mtimes)!
		output_mtime := os.file_last_mod_unix(c.output_file())
		if output_mtime > max_obj_mtime {
			println('Up-to-date ${c.output_file()}')
			return
		}
	}

	cc.link_objs(obj_files, c.output_file(), c.lib_dirs, c.libs, c.link_flags)!
}


fn (c CpmPackage) clean() ! {
	if os.exists(c.output_file()) {
		println(c.output_file())
		os.rm(c.output_file())!
	}

	files := os.ls(".") or {[]}
	for f in files {
		if os.file_ext(f) == ".pdb" {
			println(f)
			os.rm(f)!
		}
	}

	if os.exists(c.obj_dir()) {
		println(c.obj_dir())
		os.rmdir_all(c.obj_dir())!
	}
}

fn (mut c CpmPackage) run() ! {
	if !os.exists(c.output_file()) {
		c.build()!
	}

	run_process_cross_plat([c.output_file()])!
}

