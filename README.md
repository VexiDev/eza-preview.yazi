# eza-preview.yazi <br>_but with easy file/directory ignoring_
### Fork of [eza-preview.yazi](https://github.com/sharklasers996/eza-preview.yazi) by [sharklasers996](https://github.com/sharklasers996)

[Yazi](https://github.com/sxyazi/yazi) plugin to preview directories using [eza](https://github.com/eza-community/eza):
- Switch between list and tree modes. 
- Easily skip files/directories when previewing in yazi using `.ezaignore` files
	- > __Note:__ eza does not support subdirectory exclude patterns ([See .ezaignore Usage](#ezaignore))


Global vs. Local `.ezaignore`:
![ezaignore.png](ezaignore_showcase.png)

List mode:
![list.png](list.png)

Tree mode:
![tree.png](tree.png)




## Requirements

- [yazi](https://github.com/sxyazi/yazi)
- [eza](https://github.com/eza-community/eza)

## Installation

### Linux/MacOS

```sh
git clone https://github.com/VexiDev/eza-preview.yazi ~/.config/yazi/plugins/eza-preview.yazi
```

## Usage

### Setup
Add `eza-preview` to previewers in `yazi.toml`:

```toml
prepend_previewers = [
	{ name = "*/", run = "eza-preview" },
]
```

Set key binding in `keymap.toml` to switch between list/tree modes and toggling the filer file:

```toml
[manager]
keymap = [
	{ on = [ "E" ], run = "plugin eza-preview",  desc = "Toggle tree/list dir preview" },
	{ on = "<S-e>", run = "plugin eza-preview toggle_ignore_command", desc = "Toggle .ezaignore filters" },
]
```

List mode is the default, if you want to have tree mode instead when starting yazi - update `yazi.lua` with:

```lua
require("eza-preview"):setup()
```

### .ezaignore
Add `.ezaignore` files to your project root directory to exclude files/directories when previewing in yazi <br>(Useful for filtering long directories when  in Tree mode).

> Adding `.ezaignore` to your `~/.config/yazi/` directory will apply a default filter to all directories when previewing in yazi. If a directory has its own `.ezaignore` file, it will override the default filter.

__Example:__ to exclude all files with the `.git` extension, add the following to your `.ezaignore` file:

```
*.git
```

To exclude the build directory, add the following to your `.ezaignore` file:
```
build/
```

To exclude all files in the `build` directory but __keep__ the `build` directory itself, add the following to your `.ezaignore` file:

```
build/*