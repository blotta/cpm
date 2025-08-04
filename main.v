module main

import os
import cli

fn build_cfg(args []string, cfg CpmPackage) !CpmPackage {

	mut c := cfg

	if args.len > 0 {
		c = c.clone_with_mode(args[0])!
		println('Applied mode "${args[0]}"')
	}

	if c.dependencies.keys().len > 0 {
		c = c.clone_with_dependencies_applied()
		println('Applied dependencies')
	}

	return c
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
					cfg.save()
					return
				}
			},
			cli.Command{
				name:    'cfg'
				execute: fn [mut cfg] (cmd cli.Command) ! {
					cfg = build_cfg(cmd.args, cfg)!
					println(cfg)
					return
				}
			},
			cli.Command{
				name:    'build'
				execute: fn [mut cfg] (cmd cli.Command) ! {
					cfg = build_cfg(cmd.args, cfg)!

					cfg.build() or { eprintln(err) }
					return
				}
			},
			cli.Command{
				name:    'run'
				execute: fn [mut cfg] (cmd cli.Command) ! {
					cfg = build_cfg(cmd.args, cfg)!

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
