#!/bin/sh
# Local protocol fixture. Never contacts a website, installs tools, or reads credentials.
case "$1" in
  -v)
    for argument in "$@"; do
      if [ "$argument" = 'a:0' ]; then
        printf '%s\n' '{"streams":[{"codec_type":"audio"}],"format":{"duration":"10.5"}}'
        exit 0
      fi
    done
    printf '%s\n' '{"streams":[{"codec_type":"video","width":1280,"height":720}],"format":{"duration":"10.5"}}'
    exit 0 ;;
esac
previous=''
destination=''
metadata=false
audio=false
last=''
for argument in "$@"; do
  if [ "$argument" = '--dump-single-json' ]; then metadata=true; fi
  if [ "$argument" = '--extract-audio' ]; then audio=true; fi
  if [ "$previous" = '--paths' ]; then destination="$argument"; fi
  previous="$argument"
  last="$argument"
done
if "$metadata"; then
  case "$last" in *slow-inspect*) sleep 0.3 ;; esac
  printf '%s\n' '{"id":"fixture","title":"Test video","duration":10.5,"uploader":"Test creator","formats":[{"height":720,"vcodec":"avc1","acodec":"mp4a"},{"height":360,"vcodec":"avc1"}]}'
  exit 0
fi
if [ -z "$destination" ]; then exit 2; fi
case "$last" in
  *fail-download*) sleep 0.3; printf 'fixture download failure\n' >&2; exit 3 ;;
  *slow-download*) sleep 0.3 ;;
esac
if "$audio"; then
  printf '%s\n' 'LATTICE_PARTS:{"parts":[],"single":"a"}'
  printf '%s\n' 'LATTICE_PROGRESS:40%|40|100|1000|1|NA|NA|downloading|"a"'
  printf '%s\n' 'LATTICE_PROGRESS:75%|75|100|1000|1|NA|NA|downloading|"a"'
  printf '%s\n' 'LATTICE_PROGRESS:100%|100|100|1000|0|NA|NA|finished|"a"'
  printf 'fixture bytes' > "$destination/Test video.m4a"
  printf 'LATTICE_FILE:%s/Test video.m4a\n' "$destination"
  exit 0
fi
printf '%s\n' 'LATTICE_PARTS:{"parts":[{"format_id":"v"},{"format_id":"a"}],"single":"v+a"}'
printf '%s\n' 'LATTICE_PROGRESS:20%|20|100|1000|1|NA|NA|downloading|"v"'
printf '%s\n' 'LATTICE_PROGRESS:15%|30|200|1000|1|NA|NA|downloading|"v"'
printf '%s\n' 'LATTICE_PROGRESS:100%|200|200|1000|0|NA|NA|finished|"v"'
printf '%s\n' 'LATTICE_PROGRESS:0%|0|100|1000|1|NA|NA|downloading|"a"'
printf '%s\n' 'LATTICE_PROGRESS:50%|50|100|1000|1|NA|NA|downloading|"a"'
printf '%s\n' 'LATTICE_PROGRESS:100%|100|100|1000|0|NA|NA|finished|"a"'
printf 'fixture bytes' > "$destination/Test video.mp4"
printf 'LATTICE_FILE:%s/Test video.mp4\n' "$destination"
