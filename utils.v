module sessions

const lib = 'sessions'

fn format_error_message(message string) string {
	return '[${lib}] ${message}'
}
