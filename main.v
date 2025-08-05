module main

import os
import cli

fn main() {
	mut cfg := CpmPackage.load() or { CpmPackage.default() }

	mut app := cli.Command{
		name:        'cpm'
		description: 'C Project Manager'
		commands:    [
			cli.Command{
				name:        'init'
				description: 'Initialize a cpm project by creating a cpm.json file in the current directory'
				execute:     fn [cfg] (cmd cli.Command) ! {
					cfg.save()
					return
				}
			},
			cli.Command{
				name:        'cfg'
				usage:       '[mode]'
				description: 'Print the final build configuration'
				execute:     fn [mut cfg] (cmd cli.Command) ! {
					cfg = CpmPackage.build_cfg(cmd.args, cfg)!
					println(cfg.json())
					return
				}
			},
			cli.Command{
				name:        'build'
				usage:       '[mode]'
				description: 'Build the project'
				execute:     fn [mut cfg] (cmd cli.Command) ! {
					cfg = CpmPackage.build_cfg(cmd.args, cfg)!

					cfg.build() or { eprintln(err) }
					return
				}
			},
			cli.Command{
				name:        'run'
				usage:       '[mode]'
				description: 'Build and run project'
				execute:     fn [mut cfg] (cmd cli.Command) ! {
					cfg = CpmPackage.build_cfg(cmd.args, cfg)!

					cfg.build() or {
						eprintln(err)
						return
					}
					cfg.run() or { eprintln(err) }
					return
				}
			},
			cli.Command{
				name:        'clean'
				description: 'Clean object files and other build artifacts'
				execute:     fn [mut cfg] (cmd cli.Command) ! {
					cfg.clean() or { eprintln(err) }
					return
				}
			},
		]
	}

	app.setup()
	app.parse(os.args)
}
