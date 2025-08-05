# CPM (C Project Manager)

CPM is a convenience tool for building small C/C++ projects.

This is a tool meant to directly manipulate the compiler's command line arguments
and streamline the compilation and execution of small or new projects. You still have to know and provide all the arguments for the compiler, but CPM may prevent you from having to write a custom build script or Makefile.

## Features

* Recursivelly and automatically compile C/C++ files
* Incremental parallel compilation
* Custom build modes (DEBUG/RELEASE/YOUR OWN)
* Simple and modular dependency system


## Usage

By executing `cpm build` in the project directory, it will try to find a C/C++ compiler
and build the source files located in the `src` directory. Without a `cpm.json` file, CPM will use the following default configuration:

```json
{
	"name":	"<directory name>",
	"version":	"0.1.0",
	"source_dir":	"src",
	"parallel_compilation":	true,
	"output":	"",
	"c_compiler":	"",
	"cpp_compiler":	"",
	"include_dirs":	["include"],
	"lib_dirs":	["lib"],
	"libs":	[],
	"compile_flags": [],
	"link_flags": [],
	"modes": {
	},
	"dependencies":	{
	}
}
```

These are all the possible configurations variables this file can have and this is what is generated when running `cpm init` in the project directory.

### Compiler Support

Currently, the supported C compilers are `gcc`, `clang`, `cl`. The supported C++ compilers are `g++`, `clang++`, `cl`. If not specified in the configuration file, CPM will look for each of them in the mentioned order on the system path.

### Modes

Modes are mean't for customizing the compilation mode, such as "debug" or "release". 

```json
{
	"name":	"myapp",
	"version":	"0.1.0",
	"source_dir":	"src",
	"parallel_compilation":	true,
	"output":	"",
	"c_compiler":	"",
	"cpp_compiler":	"",
	"include_dirs":	["include"],
	"lib_dirs":	["lib"],
	"libs":	[],
	"compile_flags": [],
	"link_flags": [],
	"modes": {
		"mydebug": {
            "name": "myapp-debug",
			"compile_flags": ["-g", "-DDEBUG"]
		}
	},
	"dependencies":	{
	}
}
```

When running `cpm build mydebug`, the top level configuration will essentially become the following:


```json
{
	"name":	"myapp-debug",
	"version":	"0.1.0",
	"source_dir":	"src",
	"parallel_compilation":	true,
	"output":	"",
	"c_compiler":	"",
	"cpp_compiler":	"",
	"include_dirs":	["include"],
	"lib_dirs":	["lib"],
	"libs":	[],
	"compile_flags": ["-g", "-DDEBUG"],
	"link_flags": [],
	"modes": {
	},
	"dependencies":	{
	}
}
```

### Dependencies

CPM will look in the `dependencies` directory for the keys specified. The following configuration will expect a directory `dependencies/mydep` with the `include` and `lib` directories and will use the `mydep` lib on the build.

```json
{
	"name":	"myapp",
	"version":	"0.1.0",
	"source_dir":	"src",
	"parallel_compilation":	true,
	"output":	"",
	"c_compiler":	"",
	"cpp_compiler":	"",
	"include_dirs":	["include"],
	"lib_dirs":	["lib"],
	"libs":	[],
	"compile_flags": [],
	"link_flags": [],
	"modes": {
	},
	"dependencies":	{
        "mydep": {
			"include_dirs": [ "include" ],
			"lib_dirs": ["lib"],
            "lib": ["mydep"]
        }
	}
}
```

The configuration above will essentially turn the top level configuration into the following:

```json
{
	"name":	"myapp",
	"version":	"0.1.0",
	"source_dir":	"src",
	"parallel_compilation":	true,
	"output":	"",
	"c_compiler":	"",
	"cpp_compiler":	"",
	"include_dirs":	["include", "dependencies/mydep/include"],
	"lib_dirs":	["lib", "dependencies/mydep/lib"],
	"libs":	["mydep"],
	"compile_flags": [],
	"link_flags": [],
	"modes": {
	},
	"dependencies":	{
	}
}
```