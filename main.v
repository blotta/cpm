module main

import os
import cli
import log

const log_level = log.Level.debug

fn init() {
	log.set_level(.warn)

	for _, arg in os.args {
		if arg in ['--verbose', '-v'] {
			log.set_level(.info)
			break
		}
	}
}

fn main() {
	mut cfg := CpmPackage.load() or { CpmPackage.default() }

	mut cpm_args := []string{}
	mut non_cpm_args := []string{}
	mut found_double_dash := false
	for arg in os.args {
		if !found_double_dash {
			if arg == '--' {
				found_double_dash = true
				continue
			}
			cpm_args << arg
		}
		if found_double_dash {
			non_cpm_args << arg
		}
	}

	mut app := cli.Command{
		name:        'cpm'
		description: 'C Project Manager'
		flags:       [
			cli.Flag{
				flag:        .bool
				name:        'verbose'
				abbrev:      'v'
				description: 'Enable verbose output'
			},
		]
		commands:    [
			cli.Command{
				name:        'version'
				description: 'Print CPM version'
				execute:     fn (cmd cli.Command) ! {
					println('0.5.0')
					return
				}
			},
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

					cfg.build() or { log.error('${err}') }
					return
				}
			},
			cli.Command{
				name:        'run'
				usage:       '[mode] -- [run args]'
				description: 'Build and run project'
				execute:     fn [mut cfg, non_cpm_args] (cmd cli.Command) ! {
					cfg = CpmPackage.build_cfg(cmd.args, cfg)!

					cfg.build() or {
						log.error('${err}')
						return
					}

					cfg.run(non_cpm_args) or { log.error('${err}') }
					return
				}
			},
			cli.Command{
				name:        'clean'
				description: 'Clean object files and other build artifacts'
				execute:     fn [mut cfg] (cmd cli.Command) ! {
					cfg.clean() or { log.error('${err}') }
					return
				}
			},
		]
	}

	app.setup()
	app.parse(cpm_args)
}
