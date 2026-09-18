class_name WebFiles
extends RefCounted
## Saves and opens level files on the user's computer from the web build, whose own file system lives
## inside the browser. Uses the File System Access API (Chrome, Edge) so a file can be picked once and
## overwritten on later saves; other browsers fall back to a download and a plain file input.

signal saved(file_name: String)
signal downloaded(file_name: String)
signal opened(file_name: String, text: String)
signal failed(message: String)

const JS := """
window.pacmazeFiles = window.pacmazeFiles || {
	handle: null,
	pending: null,
	busy: false,
	types: [{description: 'Fase do Pacmaze', accept: {'application/json': ['.json']}}],

	acceptOpened() { this.handle = this.pending; },

	async save(text, name, ask, cb) {
		if (this.busy) return;
		this.busy = true;
		try {
			if (!window.showSaveFilePicker) {
				const a = document.createElement('a');
				a.href = URL.createObjectURL(new Blob([text], {type: 'application/json'}));
				a.download = name;
				a.click();
				setTimeout(() => URL.revokeObjectURL(a.href), 1000);
				cb('downloaded', name, '');
				return;
			}
			if (ask || !this.handle) {
				this.handle = await window.showSaveFilePicker({suggestedName: name, types: this.types});
			}
			const writable = await this.handle.createWritable();
			await writable.write(text);
			await writable.close();
			cb('saved', this.handle.name, '');
		} catch (e) {
			cb(e.name === 'AbortError' ? 'cancel' : 'error', e.message, '');
		} finally {
			this.busy = false;
		}
	},

	async open(cb) {
		if (this.busy) return;
		this.busy = true;
		try {
			let file = null;
			this.pending = null;
			if (window.showOpenFilePicker) {
				const [handle] = await window.showOpenFilePicker({types: this.types});
				this.pending = handle;
				file = await handle.getFile();
			} else {
				file = await new Promise((resolve) => {
					const input = document.createElement('input');
					input.type = 'file';
					input.accept = '.json,application/json';
					input.onchange = () => resolve(input.files[0]);
					input.oncancel = () => resolve(null);
					input.click();
				});
			}
			if (file) cb('opened', file.name, await file.text());
		} catch (e) {
			cb(e.name === 'AbortError' ? 'cancel' : 'error', e.message, '');
		} finally {
			this.busy = false;
		}
	},
};
"""

var _files: JavaScriptObject
## Must stay referenced for as long as JavaScript may call it.
var _callback: JavaScriptObject


func _init() -> void:
	JavaScriptBridge.eval(JS, true)
	_files = JavaScriptBridge.get_interface("pacmazeFiles")
	_callback = JavaScriptBridge.create_callback(_on_result)


## Writes to the file picked before, unless there is none yet or `ask` is set.
func save(text: String, file_name: String, ask: bool) -> void:
	_files.save(text, file_name, ask, _callback)


func open() -> void:
	_files.open(_callback)


## Keeps the file just opened as the target of the next saves.
func accept_opened() -> void:
	_files.acceptOpened()


func _on_result(args: Array) -> void:
	var kind: String = args[0]
	match kind:
		"saved":
			saved.emit(args[1])
		"downloaded":
			downloaded.emit(args[1])
		"opened":
			opened.emit(args[1], args[2])
		"error":
			failed.emit(args[1])
