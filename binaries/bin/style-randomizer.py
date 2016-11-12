#!/usr/bin/env python
from subprocess import check_output, CalledProcessError
import random
import os

LOG_FILENAME = r'/tmp/random-style.log'
log_fp = None

def main():
    homedir = os.path.expanduser('~')
    picdir = os.path.join(homedir, 'Pictures/wall')
    piclist = [os.path.join(picdir, x) for x in os.listdir(picdir) if os.path.isfile(os.path.join(picdir, x))]

    random.shuffle(piclist)
    command = "feh --no-fehbg --bg-fill '" + piclist[0] + "' --bg-fill '" + piclist[1] + "'"
    os.system(command)

    i3_styles = ['archlinux', 'base16-tomorrow', 'debian', 'deep-purple', 'lime', 'tomorrow-night-80s']

    command = 'i3-style {0} -o ~/.i3/config --reload'.format(random.choice(i3_styles))
    command = os.path.join(homedir, '.npm-packages', 'bin', command)
    try:
        print(check_output(command, shell=True), file=log_fp)
    except CalledProcessError as e:
        print(e.output, file=log_fp)
        raise e

if __name__ == '__main__':
    try:
        main()
        log_fp = open(LOG_FILENAME, 'a')
    except Exception as e:
        print(e, file=log_fp)
        raise e
    finally:
        log_fp.close()
