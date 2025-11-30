# files2md: gather code into Markdown and copy to clipboard (macOS, zsh)

files2md() {
  local exts_csv="ts"
  local minext_csv=""
  local -a ignore_patterns

  # Parse options: -ext, -min, -ignore / -x
  while [ $# -gt 0 ]; do
    case "$1" in
      -ext)
        [ -n "${2-}" ] || { echo "Usage: files2md [-ext ts,js,vue] [-min ts,js,html] [-ignore pattern[,pattern...]] <file|dir|glob> [...]" >&2; return 2; }
        exts_csv="$2"
        shift 2
        ;;
      -min)
        [ -n "${2-}" ] || { echo "Usage: files2md [-ext ts,js,vue] [-min ts,js,html] [-ignore pattern[,pattern...]] <file|dir|glob> [...]" >&2; return 2; }
        minext_csv="$2"
        shift 2
        ;;
      -ignore|-x)
        [ -n "${2-}" ] || { echo "Usage: files2md [-ext ts,js,vue] [-min ts,js,html] [-ignore pattern[,pattern...]] <file|dir|glob> [...]" >&2; return 2; }
        local ignore_csv="$2"
        ignore_csv="$(printf "%s" "$ignore_csv" | tr -d '[:space:]')"
        if [ -n "$ignore_csv" ]; then
          if [ -n "${ZSH_VERSION:-}" ]; then
            local -a tmp_ignore
            tmp_ignore=(${(s:,:)ignore_csv})
            ignore_patterns+=("${tmp_ignore[@]}")
          else
            local IFS=','
            local -a tmp_ignore
            read -r -a tmp_ignore <<< "$ignore_csv"
            ignore_patterns+=("${tmp_ignore[@]}")
          fi
        fi
        shift 2
        ;;
      --)
        shift
        break
        ;;
      -*)
        echo "Unknown option: $1" >&2
        return 2
        ;;
      *)
        break
        ;;
    esac
  done

  [ $# -gt 0 ] || { echo "Usage: files2md [-ext ts,js,vue] [-min ts,js,html] [-ignore pattern[,pattern...]] <file|dir|glob> [...]" >&2; return 2; }

  exts_csv="$(printf "%s" "$exts_csv" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
  minext_csv="$(printf "%s" "$minext_csv" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"

  local -a exts_arr minext_arr
  if [ -n "${ZSH_VERSION:-}" ]; then
    exts_arr=(${(s:,:)exts_csv}); exts_arr=(${(L)exts_arr})
    minext_arr=(${(s:,:)minext_csv}); minext_arr=(${(L)minext_arr})
  else
    local IFS=','
    read -r -a exts_arr <<< "$exts_csv"
    read -r -a minext_arr <<< "$minext_csv"
  fi
  [ ${#exts_arr[@]} -gt 0 ] || exts_arr=("ts")

  local tmp
  tmp="$(mktemp)"

  _in_list() {
    local needle="$1"; shift
    local x
    for x in "$@"; do [ "$x" = "$needle" ] && return 0; done
    return 1
  }

  _minify_html() {
    if command -v html-minifier-terser >/dev/null 2>&1; then
      html-minifier-terser \
        --collapse-whitespace \
        --remove-comments \
        --remove-attribute-quotes \
        --remove-empty-attributes \
        --case-sensitive \
        --minify-css true \
        --minify-js '{"compress":true,"mangle":false}' \
        --process-scripts 'text/html'
    else
      perl -0777 -pe 's/<!--.*?-->//gs; s/>\s+</></g'
    fi
  }

  _minify_js_like() {
    local ext="$1"
    if command -v esbuild >/dev/null 2>&1; then
      esbuild --loader="$ext" --minify-whitespace --minify-syntax
    else
      if [ "$ext" = "js" ] && command -v terser >/dev/null 2>&1; then
        terser --compress
      else
        perl -0777 -pe 's{/\*.*?\*/}{}gs; s{(^|[^:])//.*$}{$1}gm; s/\s+/ /g'
      fi
    fi
  }

  _should_ignore() {
    local file="$1"
    local pat
    for pat in "${ignore_patterns[@]}"; do
      # простая проверка "подстрока содержится в пути"
      if [ -n "$pat" ] && [[ "$file" == *"$pat"* ]]; then
        return 0
      fi
    done
    return 1
  }

  _emit() {
    local file="$1"
    local ext="${file##*.}"
    ext="$(printf "%s" "$ext" | tr '[:upper:]' '[:lower:]')"

    printf "// %s\n\n" "$file" >> "$tmp"
    printf '```\n' >> "$tmp"

    if _in_list "$ext" "${minext_arr[@]}"; then
      case "$ext" in
        html|htm) _minify_html < "$file" >> "$tmp" ;;
        js|mjs|cjs) _minify_js_like js < "$file" >> "$tmp" ;;
        ts|tsx|jsx) _minify_js_like "$ext" < "$file" >> "$tmp" ;;
        *)
          sed 's/^[[:space:]]\+//;s/[[:space:]]\+$//' "$file" | tr '\n' ' ' | tr -s ' ' >> "$tmp"
          ;;
      esac
    else
      cat -- "$file" >> "$tmp"
    fi

    printf '\n```\n\n' >> "$tmp"
  }

  _has_ext() {
    local ext="${1##*.}"
    ext="$(printf "%s" "$ext" | tr '[:upper:]' '[:lower:]')"
    local e
    for e in "${exts_arr[@]}"; do
      [ "$ext" = "$e" ] && return 0
    done
    return 1
  }

  # 1) Сначала собираем все файлы в массив
  local -a all_files
  local -a pred
  pred+=( "(" )
  local first=1 e
  for e in "${exts_arr[@]}"; do
    if [ $first -eq 1 ]; then
      pred+=( -iname "*.${e}" )
      first=0
    else
      pred+=( -o -iname "*.${e}" )
    fi
  done
  pred+=( ")" )

  while [ $# -gt 0 ]; do
    local arg="$1"
    shift
    for g in $arg; do
      if [ -f "$g" ]; then
        if _has_ext "$g"; then
          all_files+=("$g")
        fi
      elif [ -d "$g" ]; then
        while IFS= read -r -d '' f; do
          all_files+=("$f")
        done < <(find "$g" -type f "${pred[@]}" ! -path "*/node_modules/*" ! -path "*/dist/*" ! -path "*/build/*" -print0)
      fi
    done
  done

  # 2) Фильтруем игнорируемые файлы
  local -a filtered_files
  local f
  for f in "${all_files[@]}"; do
    if ! _should_ignore "$f"; then
      filtered_files+=("$f")
    fi
  done

  # 3) Эмитим только отфильтрованный список
  local count=0
  for f in "${filtered_files[@]}"; do
    _emit "$f"
    count=$((count+1))
  done

  if [ "$count" -gt 0 ]; then
    pbcopy < "$tmp"
    echo "✅ Built and copied to clipboard: $count file(s)."
  else
    echo "⚠️ Nothing matched: ${exts_arr[*]}"
  fi

  rm -f "$tmp"
}
