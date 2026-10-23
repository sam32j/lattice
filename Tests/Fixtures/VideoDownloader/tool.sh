#!/bin/sh
# Local protocol fixture. Never contacts a website, installs tools, or reads credentials.
case "$1" in
  -v)
    printf '%s\n' '{"streams":[{"codec_type":"video","width":1280,"height":720}],"format":{"duration":"10.5"}}'
    exit 0 ;;
esac
previous=''
destination=''
for argument in "$@"; do
  if [ "$argument" = '--dump-single-json' ]; then
    printf '%s\n' '{"id":"fixture","title":"Test video","duration":10.5,"uploader":"Test creator","formats":[{"height":720,"vcodec":"avc1"},{"height":360,"vcodec":"avc1"}]}'
    exit 0
  fi
  if [ "$previous" = '--paths' ]; then destination="$argument"; fi
  previous="$argument"
done
if [ -z "$destination" ]; then exit 2; fi
printf 'fixture bytes' > "$destination/Test video.mp4"
printf 'LATTICE_PROGRESS:50%%\nLATTICE_FILE:%s/Test video.mp4\n' "$destination"
