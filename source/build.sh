#!/bin/sh

set -eu

git_top=`git rev-parse --show-toplevel` 2>&1 ||
    {
        echo "Error: Not inside a Git repository" >&2
        exit 1
    }

src_dir="$git_top/source"
dst="$git_top/install.sh"

create_file() {
    destination="$1"
    printf 'Creating %s\n' $(basename "$destination")
    mkdir -p $(dirname "$destination")
    printf "" > "$destination"
}

emit_file() {
    destination="$1"
    content_file="$2"
    printf 'Emitting '%s' to %s\n' "$content_file" $(basename "$destination")
    cat "$src_dir/$content_file" >> "$destination"
}

emit_line() {
    destination="$1"
    line="$2"
    printf 'Emitting line to %s\n' $(basename "$destination")
    printf "%s\n" "$line" >> "$destination"
}

emit_emitter() {
    destination="$1"
    emitter_name="$2"
    content_file="$3"
    heredoc_mark="$4"
    heredoc_mark_end=$(strip_sq "$heredoc_mark")

    printf 'Emitting emit_%s() to %s [%s/%s/%s]\n' "$emitter_name" $(basename "$destination") "$heredoc_mark" "$content_file" "$heredoc_mark_end"

    {
        printf 'emit_%s() {\n' "$emitter_name"
        # Built‑in‑only “cat”: read + printf inside a here‑doc
        printf '    cat <<%s\n' "$heredoc_mark"

        # emit the literal payload
        cat "$src_dir/$content_file"

        printf '\n%s\n' "$heredoc_mark_end"
        printf '}\n'
        printf '\n'
    } >> "$destination"
}

strip_sq() {
    s=$1
    case $s in
        \'*) s=${s#\'} ;;
    esac
    case $s in
        *\') s=${s%\'} ;;
    esac
    printf '%s\n' "$s"
}

create_file "$dst"
emit_file "$dst" 'base.sh'
emit_emitter "$dst" proxmox_source apt.source.proxmox EOFPROXMOX
emit_emitter "$dst" ceph_source apt.source.ceph EOFCEPH
emit_emitter "$dst" debian_source apt.source.debian EOFDEBIAN
emit_emitter "$dst" buster_conf apt.conf.buster "'EOFCONF'"
emit_emitter "$dst" buster buster.sh "'EOFBUSTER'"
emit_line "$dst" '_main "$@"'
chmod u+x "$dst"
