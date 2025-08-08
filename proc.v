module main

import os

fn run_process_cross_plat(cmd []string) ! {
	mut rcmd := []string{}

	println('> ${cmd.join(' ')}')

	if os.user_os() == 'windows' {
		cmd_shell := os.getenv_opt('COMSPEC') or { 'C:\\Windows\\System32\\cmd.exe' }
		rcmd << [cmd_shell, '/c']
		rcmd << cmd
	} else {
		sh := os.getenv_opt('SHELL') or { '/bin/sh' }
		rcmd << [sh, '-c']
		rcmd << [cmd.join(' ')]
	}

	mut p := os.new_process(rcmd[0])

	if rcmd.len > 1 {
		p.set_args(rcmd[1..])
	}

	p.use_stdio_ctl = false

	p.wait()

	if p.code != 0 {
		return error_with_code('proc error', p.code)
	}
}
