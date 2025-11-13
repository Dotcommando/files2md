# files2md — turn source files into a single Markdown snippet (macOS, zsh)

`files2md` collects files by extension, optionally minifies some types, and emits a Markdown-friendly block that is copied to the clipboard (`pbcopy`). Useful for pasting code bundles into chats or issues.

## Features
- Accepts files, directories, and globs.
- Filters by extensions (case-insensitive).
- Optional minification for HTML/JS/TS/JSX/TSX (with safe fallbacks).
- Skips common build dirs (`node_modules`, `dist`, `build`).
- Copies the result to the macOS clipboard.

## Requirements
- macOS with `zsh`, `find`, `perl`, and `pbcopy` (built-in on macOS).
- Node.js (for optional minifiers):  
  ```bash
  brew install node
  ```
- Optional minifiers (recommended):
  ```bash
  npm i -g html-minifier-terser esbuild terser
  ```
  - `html-minifier-terser` is used for HTML.
  - `esbuild` is preferred for JS/TS/JSX/TSX.
  - `terser` is a fallback for JS.

> If minifiers are missing, conservative Perl fallbacks are used.

## Install
Clone and add `bin` to your `PATH`:
```bash
git clone https://github.com/Dotcommando/files2md.git
cd files2md
echo 'export PATH="$PWD/bin:$PATH"' >> ~/.zshrc
exec zsh -l
```

Or source the function in your shell:
```bash
echo 'source /path/to/files2md/files2md.zsh' >> ~/.zshrc
exec zsh -l
```

## Usage
CLI:
```bash
files2md [-ext ts,js,vue] [-min ts,js,html] <file|dir|glob> [...]
```

Function (if sourced):
```bash
files2md [-ext ts,js,vue] [-min ts,js,html] <file|dir|glob> [...]
```

### Options
- `-ext`: CSV list of extensions to include. Default: `ts`.
- `-min`: CSV list of extensions to minify before emitting.

### Examples
Collect TypeScript and Vue files from `src`, minify TS:
```bash
files2md -ext ts,vue -min ts src
```

Collect JS/TS from multiple inputs (glob + dir), minify JS and HTML:
```bash
files2md -ext js,ts,html -min js,html "apps/*.{js,ts}" web/
```

Collect a single file:
```bash
files2md -ext ts path/to/file.ts
```

## Notes
- Output format per file:

<pre>
// path/to/file.ext

```
  &lt;content&gt;
```
</pre>


- The final Markdown is placed in the clipboard and a summary is printed.

## Troubleshooting
- “command not found: html-minifier-terser/esbuild/terser”  
  Install with:
  ```bash
  npm i -g html-minifier-terser esbuild terser
  ```
- Nothing copied:
  - Ensure at least one file matches the requested extensions.
  - Confirm `pbcopy` exists: `command -v pbcopy`.

## License
MIT
