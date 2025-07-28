module main

import os
import json
// import time

struct CpmFlags {
	include_flags []string
	lib_flags     []string
	libs         []string
}

// struct CpmPackage {
// 	// name         string
// 	// version      string
// 	include_dirs ?[]string
// 	lib_dirs     ?[]string
// 	libs         ?[]string
// }

struct CpmConfig {
	// CpmPackage
	name    string
	version string
	// entry        string
	output       string
	dependencies map[string]CpmConfig

	include_dirs ?[]string
	lib_dirs     ?[]string
	libs         ?[]string
}

fn load_config() !CpmConfig {
	data := os.read_file('cpm.json')!
	println("config read")
	return json.decode(CpmConfig, data)
}

fn save_config(cfg CpmConfig) {
	os.write_file('cpm.json', json.encode_pretty(cfg)) or {
		eprintln('Failed to save cpm.json: ${err}')
	}
}

fn file_mtime(path string) i64 {
	info := os.stat(path) or { return 0 }
	return info.mtime
}

fn merge_pacakge(a CpmConfig, b CpmConfig) CpmConfig {
	c := CpmConfig{
		include_dirs: if dirs := b.include_dirs { dirs } else { a.include_dirs }
		lib_dirs: if dirs := b.lib_dirs { dirs } else { a.lib_dirs }
		libs: if libs := b.libs { libs } else { a.libs }
	}
	return c
}

fn load_package(dep string) CpmConfig {
	cfg:= load_config() or {panic("no config")}
	dep_dir := os.join_path('cpm_modules', dep)
	mut pkg := CpmConfig{
		include_dirs: ["include"]
		lib_dirs: ["lib"]
		libs: [dep]
	}

	pkg_file := os.join_path(dep_dir, 'cpm-package.json')
	if os.exists(pkg_file) {
		pkg_data := os.read_file(pkg_file) or { panic("Error reading file: ${pkg_file}") }
		pkg = json.decode(CpmConfig, pkg_data) or { panic("Error parsing file: ${pkg_file}")}
	}


	if cfg_pkg := cfg.dependencies[dep] {
		pkg = merge_pacakge(pkg, cfg_pkg)
	}

	return pkg
}

fn cmd_test() {
	pkg := load_all_flags()

	println(pkg)
}

fn cmd_init() {
	cfg := CpmConfig{
		name:    os.base(os.getwd())
		version: '0.1.0'
		// entry:        'main.c'
		output:       'app.exe'
		dependencies: map[string]CpmConfig{}
	}
	save_config(cfg)
	println('Created cpm.json')
}

fn load_all_flags() CpmFlags {
	cfg := load_config() or {
		panic("Config not found")
	}

	mut include_flags := []string{}
	mut lib_flags := []string{}
	mut libs := []string{}

	// this project's flags
	if inc_dirs := cfg.include_dirs {
		for i in inc_dirs {
			include_flags << "-I${i}"
		}
	}

	mut deps := []string{}
	// dependencies flags
	dirs := os.ls("cpm_modules") or {[]}
	for dep in dirs {
		deps << dep
		// println("dep: ${dep}")

		dep_dir := os.join_path("cpm_modules", dep)
		// println("dep_dir: ${dep_dir}")

		pkg := load_package(dep)
		// println("pkg: ${pkg}")

		if inc_dirs := pkg.include_dirs {
			for dir in inc_dirs {
				inc_path := os.join_path(dep_dir, dir)
				include_flags << "-I.\\${inc_path}"
			}
		}

		if lib_dirs := pkg.lib_dirs {
			for dir in lib_dirs {
				lib_path := os.join_path(dep_dir, dir)
				lib_flags << "-L.\\${lib_path}"
			}
		}

		if pkg_libs := pkg.libs {
			for lib in pkg_libs {
				libs << "-l${lib}"
			}
		}
	}

	return CpmFlags{
		include_flags: include_flags
		lib_flags: lib_flags
		libs: libs
	}
}

fn cmd_build() {
	cfg := load_config() or {
		eprintln("Run 'cpm init' first.")
		return
	}

	flags := load_all_flags()

	os.mkdir_all('.cpm_build') or {}

	// find all .c files
	files := os.ls('.') or { [] }
	mut c_files := []string{}
	for f in files {
		if f.ends_with('.c') {
			c_files << f
		}
	}

	mut object_files := []string{}
	for c_file in c_files {
		obj_file := '.cpm_build/${os.file_name(c_file).replace('.c', '.o')}'
		c_mtime := file_mtime(c_file)
		o_mtime := file_mtime(obj_file)

		// compile only if .o is missing or source changed
		if o_mtime < c_mtime {
			println('Compiling ${c_file} -> ${obj_file}')
			compile_cmd := 'gcc -c ${c_file} ${flags.include_flags.join(' ')} -o ${obj_file}'
			os.system(compile_cmd)
		} else {
			println('Up-to-date ${c_file}')
		}
		object_files << obj_file
	}

	// Link step
	link_cmd := 'gcc ${object_files.join(' ')} ${flags.lib_flags.join(' ')} ${flags.libs.join(' ')} -o ${cfg.output}'
	println('Linking: ${link_cmd}')
	os.system(link_cmd)
}

fn cmd_run() {
	cfg := load_config() or {
		eprintln("Run 'cpm init' first.")
		return
	}
	println('Running .\\${cfg.output}')
	os.system('.\\${cfg.output}')
}

fn cmd_help() {
	println('Usage: cpm <command>')
	println('  init		initialize project in the current directory')
	println('  install	install packages')
	println('  run		run project')
}


fn main() {
	args := os.args
	if args.len < 2 {
		cmd_help()
		return
	}

	match args[1] {
		'help' {
			cmd_help()
		}
		'build' {
			cmd_build()
		}
		'run' {
			cmd_build()
			cmd_run()
		}
		'init' {
			cmd_init()
		}
		'test' {
			cmd_test()
		}
		else {
			eprintln('Unknown command: ${args[1]}')
		}
	}
}
