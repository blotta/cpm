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
