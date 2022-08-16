### librofi

----

*librofi* provides a convenient way to call [rofi](https://github.com/davatorium/rofi)
from *V*. It uses *rofis dmneu* mode to display user defined contents within *rofi* and
uses a callback based approach to process user selections.


### Usage

----

The following code snipped provides a small usage example:

```v
import librofi

fn callback(item string) {
	println('Selected item: ' + item)
}

fn main() {
	mut rofi := librofi.new_instance() or { panic('Something went wrong :/') }
	rofi.set_name('librofi')
	rofi.add_keybinding('CTRL+q', callback)
	rofi.add_entry('Hello World :D')
	rofi.add_entry('This is librofi!')
	rofi.start()
}
```

The example code from above creates the following *rofi* window:

![rofi window](https://tneitzel.eu/73201a92878c0aba7c3419b7403ab604/librofi-simple.png)


### Layouts

----

Layouts can be used to apply additional formatting to each line displayed by *rofi*.
Some layouts are available by default, others can be created by implementing the
`Layout` interface. The following code shows an example for the `ColumnLayout`:

```v
import librofi

fn main() {
	mut layout := librofi.ColumnLayout{ width: 94, columns: 3, separator: ';'}
	layout.set_breakdown([50, 20, 30])

	mut rofi := librofi.new_instance() or { panic(':(') }
	rofi.set_layout(layout)
	rofi.set_name('librofi')
	rofi.set_message('Example for librofis ColumnLayout\n' + layout.apply('Msg;User;Date'))
	rofi.add_entry('Hello World, this is librofi :D;qtc;2022-08-16 07:40:55')
	rofi.start()
}
```

The example code from above creates the following *rofi* window:

![rofi window](https://tneitzel.eu/73201a92878c0aba7c3419b7403ab604/librofi-column.png)
