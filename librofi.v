// librofi provides a convenient way to call rofi from V.
// Currently, only the dmenu related functionalities of rofi
// are implemented. librofi allows to create dmenus based on
// rofi and to use callback handlers to process the obtained
// result
module librofi

import os
import toml
import arrays

// Currently there is no accurate versioning. Versioning will first be applied once the
// package was published
const (
	version = '0.0.0'
)

// Callback type alias for a function that accepts a string (rofi output) and processes it
type Callback = fn (string)

// Layouts can be used to apply additional formatting to rofi entries
interface Layout {
	apply(string) string
}

// Instance represents a rofi instance and stores the desired rofi settings and callbacks
struct Instance {
mut:
	path        string     [required]
	name        string
	format      char
	message     string
	entries     []string
	callbacks   []Callback
	keybindings []string

	layout            Layout   = PlainLayout{}
	default_callback  Callback = default_callback
	success_callback  Callback = default_callback
	canceled_callback Callback = default_callback
}

// PlainLayout leaves rofi entries as they are without modifying them
pub struct PlainLayout {}

// ColumnLayout can be used to create table like output within of rofi. If used, rofi
// entries can use the specified separator to continue writing in a separate column.
pub struct ColumnLayout {
pub mut:
	width     int    [required]
	columns   int    [required]
	separator string [required]
mut:
	breakdown []int = []int{}
}

// apply for PlainLayout just returns the input string without modifying it
pub fn (layout PlainLayout) apply(entry string) string {
	return entry
}

// set_breakdown is used to specify the desired width of the separate columns
pub fn (mut layout ColumnLayout) set_breakdown(breakdown []int) {
	if breakdown.len != layout.columns {
		panic('breakdown size $breakdown.len is invalid for column size $layout.columns')
	}

	mut sum := arrays.fold(breakdown, 0, fn (r int, t int) int {
		return r + t
	})
	if sum != 100 {
		panic('breakdown need to consume 100% of the layout width')
	}

	layout.breakdown = breakdown
}

// apply for ColumnLayout modifies the input string to match the desired column
// output. It first splits the input string at the separator key and then pads
// each item to the desired column width
pub fn (layout ColumnLayout) apply(entry string) string {
	mut new_entry := ''
	mut breakdown := layout.breakdown
	mut items := entry.split(layout.separator)

	if breakdown.len == 0 {
		breakdown = []int{len: items.len, init: 100 / layout.columns}
	}

	for ctr, mut item in items {
		column_width := breakdown[ctr] * layout.width / 100

		for item.len < column_width {
			item = item + ' '
		}

		if item.len > column_width {
			item = item.substr(0, column_width - 2)
			item = item + '… '
		}

		new_entry = new_entry + item
	}

	return new_entry
}

// new_instance creates a new rofi instance. It does not start rofi right away, but allows
// to configure the desired properties of rofi first. The main task of this method is to
// look for the rofi executable, either configured via configuration file or within the
// systems PATH.
pub fn new_instance() ?Instance {
	mut rofi_path := ''
	config_file := os.join_path(os.home_dir(), '.config', 'librofi.toml')

	if os.is_readable(config_file) {
		toml_data := toml.parse_file(config_file) or { return error('Malformed librofi.toml file') }
		rofi_path = toml_data.value('config.rofi').string()
	}

	if rofi_path == '' {
		rofi_path = os.find_abs_path_of_executable('rofi') or {
			return error('rofi location was neither configured manually nor found in PATH.')
		}
	}

	return Instance{
		path: rofi_path
	}
}

// set_name set the display name of the rofi instance
pub fn (mut rofi Instance) set_name(name string) {
	rofi.name = name
}

// set_message display an additional message below the search prompt
pub fn (mut rofi Instance) set_message(message string) {
	rofi.message = message
}

// set_layout set the layout for the rofi window
pub fn (mut rofi Instance) set_layout(layout Layout) {
	rofi.layout = layout
}

// set_format set the desired output format (e.g. i for index)
pub fn (mut rofi Instance) set_format(format char) {
	if format !in [`s`, `i`, `d`, `q`, `p`, `f`, `F`] {
		error('Invalid format specified.')
	}

	rofi.format = format
}

// set_default_callback set the default callback used by librofi. This callback
// used for rofi return values that are not assigned to any other callback.
pub fn (mut rofi Instance) set_default_callback(callback Callback) {
	rofi.default_callback = callback
}

// set_success_callback set the success callback used by librofi. This callback
// is used when an item was selected by using return.
pub fn (mut rofi Instance) set_success_callback(callback Callback) {
	rofi.success_callback = callback
}

// set_canceled_callback set the canceled callback used by librofi. This callback
// is used when the user canceled the selection by any means.
pub fn (mut rofi Instance) set_canceled_callback(callback Callback) {
	rofi.canceled_callback = callback
}

// add_keybinding add a new keybinding to the rofi instance. Each keybinding
// needs to be set together with the callback handler, that should process the
// corresponding event.
pub fn (mut rofi Instance) add_keybinding(key string, callback Callback) {
	rofi.keybindings << key
	rofi.callbacks << callback
}

// add_entry add a new entry that should be displayed within the rofi window
pub fn (mut rofi Instance) add_entry(entry string) {
	rofi.entries << entry
}

// get_argument_string internally used function to prepare the argument array
// for the rofi call
fn (rofi Instance) get_argument_string() []string {
	mut args := ['-dmenu']

	if rofi.name != '' {
		args << '-p'
		args << rofi.name
	}

	if rofi.message != '' {
		args << '-mesg'
		args << rofi.message
	}

	for index, key in rofi.keybindings {
		args << '-kb-custom-' + (index + 1).str()
		args << key
	}

	return args
}

// start starts rofi with the configured configuration. After the user selected
// the desired item, the function hands over to the specified callback handler.
pub fn (rofi Instance) start() {
	args := rofi.get_argument_string()

	mut process := os.new_process(rofi.path)
	process.set_redirect_stdio()
	process.set_args(args)
	process.run()

	for entry in rofi.entries {
		line := rofi.layout.apply(entry)
		process.stdin_write(line)

		if !line.ends_with('\n') {
			process.stdin_write('\n')
		}
	}

	os.fd_close(process.stdio_fd[0])
	output := process.stdout_slurp()
	process.wait()

	match process.code {
		0 {
			rofi.success_callback(output)
		}
		1 {
			rofi.canceled_callback(output)
		}
		else {
			callback := rofi.callbacks[process.code - 10] or { default_callback }
			callback(output)
		}
	}
}

// default_callback internal function that is always used for results
// obtained by rofi, if no corresponding callback handler was set.
fn default_callback(output string) {
	println(output)
}
