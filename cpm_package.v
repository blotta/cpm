module main

import os
import json
import sync
import arrays
import log

struct BuildContext {
mut:
	mode string = 'default'
}

struct CpmPackage {
	name    string = 'app'
	version string

	// source_dir           string = 'src'
	source_dirs          []string
	parallel_compilation bool = true
	output               string
	c_compiler           string
	cpp_compiler         string
	include_dirs         []string
	lib_dirs             []string
	libs                 []string
	compile_flags        []string
	link_flags           []string
	modes                map[string]CpmPackage
	dependencies         map[string]CpmPackage
mut:
	ctx BuildContext @[skip]
}

fn CpmPackage.default() CpmPackage {
	proj_name := os.base(os.getwd())
	c := CpmPackage{
		name:         proj_name
		version:      '0.1.0'
		source_dirs:  ['recursive::src']
		include_dirs: ['include']
		lib_dirs:     ['lib']
	}
	return c
}

fn CpmPackage.load() !CpmPackage {
	data := os.read_file('cpm.json')!
	log.info('loaded config file')
	return json.decode(CpmPackage, data)
}

fn CpmPackage.build_cfg(args []string, cfg CpmPackage) !CpmPackage {
	mut c := cfg

	if args.len > 0 {
		c = c.clone_with_mode(args[0])!
		log.info('Applied mode "${args[0]}"')
	}

	if c.dependencies.keys().len > 0 {
		c = c.clone_with_dependencies_applied()
		log.info('Applied dependencies')
	}

	return c
}

fn (c CpmPackage) json() string {
	return json.encode_pretty(c)
}

fn (c CpmPackage) save() {
	os.write_file('cpm.json', c.json()) or { eprintln('Failed to save cpm.json: ${err}') }
}

fn (c CpmPackage) find_source_files_recursive(source_dir string) []string {
	mut src_files := []string{}
	for ext in ['.c', '.cpp'] {
		src_files << os.walk_ext(source_dir, ext, os.WalkParams{ hidden: false })
	}
	return src_files
}

fn (c CpmPackage) find_source_files(source_dir string) []string {
	mut src_files := []string{}
	for ext in ['.c', '.cpp'] {
		path := os.join_path(source_dir, '*${ext}')
		for filename in os.glob(path) or { [] } {
			src_files << os.join_path(source_dir, filename)
		}
	}
	return src_files
}

fn (c CpmPackage) output_file() string {
	mut output := c.name

	if c.output != '' {
		output = c.output
	}

	if os.user_os() == 'windows' && !output.ends_with('.exe') {
		output += '.exe'
	}

	return output
}

fn (c CpmPackage) obj_dir() string {
	obj_dir := os.join_path('.cpm', 'obj')
	return obj_dir
}

fn (c CpmPackage) clone_with_mode(mode string) !CpmPackage {
	m := c.modes[mode] or { return error('No mode named ${mode} in configuration') }

	// additive fields
	mut source_dirs := c.source_dirs.clone()
	mut compile_flags := c.compile_flags.clone()
	mut include_dirs := c.include_dirs.clone()
	mut lib_dirs := c.lib_dirs.clone()
	mut libs := c.libs.clone()
	mut link_flags := c.link_flags.clone()

	source_dirs << m.source_dirs
	compile_flags << m.compile_flags
	include_dirs << m.include_dirs
	lib_dirs << m.lib_dirs
	libs << m.libs
	link_flags << m.link_flags

	mut dependencies := c.dependencies.clone()
	for k, v in m.dependencies {
		dependencies[k] = v
	}

	pkg := CpmPackage{
		name:         if m.name != '' { m.name } else { c.name }
		version:      if m.version != '' { m.version } else { c.version }
		c_compiler:   if m.c_compiler != '' { m.c_compiler } else { c.c_compiler }
		cpp_compiler: if m.cpp_compiler != '' { m.cpp_compiler } else { c.cpp_compiler }
		output:               if m.output != '' { m.output } else { c.output }
		parallel_compilation: if m.parallel_compilation == false {
			false
		} else {
			c.parallel_compilation
		}
		source_dirs:          source_dirs
		compile_flags:        compile_flags
		include_dirs:         include_dirs
		lib_dirs:             lib_dirs
		libs:                 libs
		link_flags:           link_flags
		dependencies:         dependencies

		ctx: BuildContext{
			...c.ctx
			mode: mode
		}
	}

	return pkg
}

fn (c CpmPackage) clone_with_dependencies_applied() CpmPackage {
	mut source_dirs := c.source_dirs.clone()
	mut compile_flags := c.compile_flags.clone()
	mut include_dirs := c.include_dirs.clone()
	mut lib_dirs := c.lib_dirs.clone()
	mut libs := c.libs.clone()
	mut link_flags := c.link_flags.clone()

	for k, v in c.dependencies {
		dep_path := os.join_path('dependencies', k)

		for src in v.source_dirs {
			src_path := os.join_path(dep_path, src)
			source_dirs << src_path
		}

		for inc in v.include_dirs {
			inc_path := os.join_path(dep_path, inc)
			include_dirs << inc_path
		}

		compile_flags << v.compile_flags

		for ld in v.lib_dirs {
			ld_path := os.join_path(dep_path, ld)
			lib_dirs << ld_path
		}

		libs << v.libs

		link_flags << v.link_flags
	}

	return CpmPackage{
		...c
		source_dirs:   source_dirs
		compile_flags: compile_flags
		include_dirs:  include_dirs
		lib_dirs:      lib_dirs
		libs:          libs
		link_flags:    link_flags
	}
}

fn (c CpmPackage) build() ! {
	mut include_dirs := []string{}
	mut compile_flags := []string{}

	include_dirs << c.include_dirs
	compile_flags << c.compile_flags

	mut src_paths := []string{}
	for s in c.source_dirs {
		if s.starts_with('recursive::') {
			cpm_path := s.split('::')
			dir := if cpm_path.len > 1 { cpm_path[1] } else { '.' }
			src_paths << c.find_source_files_recursive(dir)
		} else {
			src_paths << c.find_source_files(s)
		}
	}
	if src_paths.len > 0 {
		c.compile_files(src_paths, include_dirs, compile_flags, c.parallel_compilation)!
	}

	c.link_files()!
}

fn (c CpmPackage) compile_files(src_files []string, include_dirs []string, compile_flags []string, parallel_compilation bool) ![]string {
	cc, ccpp := c.determine_compilers_for_source_files(src_files)!

	if cc != none {
		log.info('C compiler: ${cc.executable}')
	}
	if ccpp != none {
		log.info('C++ compiler: ${ccpp.executable}')
	}

	// return []
	obj_dir := c.obj_dir()
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
		os.mkdir_all(os.dir(obj_path)) or { return error('could not create mirror obj directory') }
		obj_files << obj_path

		lang := match os.file_ext(src_file) {
			'.c' { LANG.c }
			'.cpp' { LANG.cpp }
			else { return error('invalid file extention "${src_file}"') }
		}

		comp := match lang {
			.c { cc or { return error('no C compiler determined') } }
			.cpp { ccpp or { return error('no C++ compiler determined') } }
		}

		if os.exists(obj_path) {
			src_mtime := os.file_last_mod_unix(src_file)
			obj_mtime := os.file_last_mod_unix(obj_path)
			if obj_mtime > src_mtime {
				log.info('Up-to-date ${src_file}')
				continue
			}
		}
		if parallel_compilation {
			wg.add(1)
			go fn (comp Compiler, src_file string, obj_path string, include_dirs []string, compile_flags []string, mut wg sync.WaitGroup, err_chan chan IError) ! {
				defer {
					wg.done()
				}
				comp.compile_file(src_file, obj_path, include_dirs, compile_flags) or {
					err_chan <- err
				}
			}(comp, src_file, obj_path, include_dirs, compile_flags, mut wg, err_chan)
		} else {
			comp.compile_file(src_file, obj_path, include_dirs, compile_flags)!
		}
	}

	wg.wait()

	if err_chan.len > 0 {
		return <-err_chan
	}

	return obj_files
}

fn (c CpmPackage) determine_compilers_for_source_files(src_files []string) !(?Compiler, ?Compiler) {
	mut cc := ?Compiler(none)

	if src_files.any(it.ends_with('.c')) {
		cc = match c.c_compiler {
			'' { Compiler.detect_for_lang(.c)! }
			else { Compiler.new(c.c_compiler)! }
		}
	}

	mut ccpp := ?Compiler(none)

	if src_files.any(it.ends_with('.cpp')) {
		ccpp = match c.cpp_compiler {
			'' { Compiler.detect_for_lang(.cpp)! }
			else { Compiler.new(c.cpp_compiler)! }
		}
	}

	return cc, ccpp
}

fn (c CpmPackage) link_files() ! {
	obj_dir := os.join_path('.cpm', 'obj')
	obj_c_files := os.walk_ext(obj_dir, '.c.obj')
	obj_cpp_files := os.walk_ext(obj_dir, '.cpp.obj')

	mut obj_files := []string{}
	obj_files << obj_c_files
	obj_files << obj_cpp_files

	if obj_files.len == 0 {
		log.info('No object files to link')
		return
	}

	lang := if obj_cpp_files.len > 0 { LANG.cpp } else { LANG.c }
	cfg_compiler := if lang == .c { c.c_compiler } else { c.cpp_compiler }

	cc := match cfg_compiler {
		'' { Compiler.detect_for_lang(lang)! }
		else { Compiler.new(cfg_compiler)! }
	}
	log.info('Linker: ${cc.executable}')

	// check if there are updated object files
	if os.exists(c.output_file()) {
		mtimes := obj_files.map(os.file_last_mod_unix(it))
		max_obj_mtime := arrays.max(mtimes)!
		output_mtime := os.file_last_mod_unix(c.output_file())
		if output_mtime > max_obj_mtime {
			log.info('Up-to-date ${c.output_file()}')
			return
		}
	}

	mut lib_dirs := []string{}
	mut libs := []string{}
	mut link_flags := []string{}

	lib_dirs << c.lib_dirs
	libs << c.libs
	link_flags << c.link_flags

	output := c.output_file()
	if os.dir(output) != '.' {
		os.mkdir_all(os.dir(output)) or { return error('could not create output directory') }
	}

	cc.link_objs(obj_files, c.output_file(), lib_dirs, libs, link_flags)!
}

fn (c CpmPackage) clean() ! {
	if os.exists(c.output_file()) {
		println(c.output_file())
		os.rm(c.output_file())!
	}

	files := os.ls('.') or { [] }
	for f in files {
		if os.file_ext(f) == '.pdb' {
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

	cmd := [c.output_file()]
	run_process_cross_plat(cmd)!
}
