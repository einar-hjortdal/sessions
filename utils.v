module sessions

import time

const lib = 'sessions'
const author = 'Einar-Hjortdal'

fn format_error_message(message string) string {
	return '[${lib}] ${message}'
}

fn default_string(s string, d string) string {
	if s == '' {
		return d
	}
	return s
}

fn default_time(t time.Time, d time.Time) time.Time {
	if t == time.Time{} {
		return d
	}
	return t
}
