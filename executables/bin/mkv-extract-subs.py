#!/bin/env python
import sys
import argparse
import os
import subprocess
import enzyme

COLUMNS = ['default', 'number', 'name', 'language']
ESCAPED_NEWLINE = " \\\n"
ZENITY_PROGRESS_CMD = (
    r"stdbuf -i0 -o0 -e0 tr '\r' '\n' | "
    r"stdbuf -i0 -o0 -e0 grep 'Progress:' | "
    r"stdbuf -i0 -e0 -o0 sed -e 's/Progress: //' -e 's/%//' -e 's/\(....\)\(..\)\(..\)/\1-\2-\3/' | "
    "zenity --progress --auto-close --percentage=0 --text='Processing file {filename}...' --title='Processing file'"
)


def main(args):
    parser = argparse.ArgumentParser()
    parser.add_argument("--select", "-s", action="store_true", help="Use zenity to select witch tracks to export")
    parser.add_argument("--notify", action="store_true", help="Use notify-send to notify when each jobe is done")
    parser.add_argument("--dry-run", "-n", action="store_true", help="Don't run the mkvextract command")
    parser.add_argument("--progress", action="store_true", help="Use zenity to draw a progress bar")
    parser.add_argument("filename", nargs="+")
    args = parser.parse_args()

    for filename in args.filename:
        with open(filename, 'rb') as f:
            mkv = enzyme.MKV(f)

        subtitle_tracks = mkv.subtitle_tracks
        if args.select:
            cmd = construct_zenity_cmd(subtitle_tracks)
            print(cmd)
            selected_numbers = [int(x) for x in subprocess.check_output(cmd, shell=True).decode().strip().split("|")]
            print(selected_numbers)
            subtitle_tracks = subtitle_track_by_number(subtitle_tracks, selected_numbers)
        if not subtitle_tracks:
            print(f"No subtitle tracks found in {filename}", file=sys.stderr)
            continue
        print(f"Will run mkvextract with the following tracks:\n{subtitle_tracks}\n")
        cmd = construct_mkvextract_cmd(filename, subtitle_tracks)
        if args.progress:
            cmd += " | " + ZENITY_PROGRESS_CMD.format(filename=filename)
        print("Command to be executed:\n" + cmd)
        if not args.dry_run:
            result = subprocess.call(cmd, shell=True)
            result = "Done" if result == 0 else "Failed"
        if args.notify:
            subprocess.call(f"notify-send 'Subtitle Extraction {result}' '{result} with {filename}'", shell=True)
    return 0


def construct_zenity_cmd(subtitle_tracks):
    column_strings = [[str(getattr(track, column)) for column in COLUMNS] for track in subtitle_tracks]
    column_strings = ESCAPED_NEWLINE.join([' '.join(f'"{s}"' for s in str_list) for str_list in column_strings])
    column_args = "".join(f"--column='{column}' " for column in COLUMNS) + ESCAPED_NEWLINE

    return f"zenity --list --checklist --title='Choose subtitle track' {column_args}{column_strings}"


def subtitle_track_by_number(subtitle_tracks, numbers):
    return [track for track in subtitle_tracks if any(track.number == number for number in numbers)]


def construct_mkvextract_cmd(filename, tracks):
    basename, _ = os.path.splitext(os.path.basename(filename))
    tracks_str = " ".join(track_argument(basename, track) for track in tracks)
    filename = shellquote(filename)
    return f"mkvextract tracks {filename} {tracks_str}"


def track_argument(basename, track):
    number = track.number - 1
    filename = subtitle_filename(basename, track)
    return shellquote(str(number) + ":" + filename)
    # return f"{number}:{filename}"


def subtitle_filename(basename, track):
    extra_text = "-" + str(track.number)
    if track.name:
        extra_text += "-" + track.name
    if track.language:
        extra_text += "-" + track.language
    return basename + extra_text + ".srt"


# https://stackoverflow.com/a/35857/3430986
# TODO: shlex.quote
def shellquote(s):
    return "'" + s.replace("'", "'\\''") + "'"


if __name__ == "__main__":
    sys.exit(main(sys.argv))
