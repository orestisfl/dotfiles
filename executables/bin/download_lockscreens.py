#!/usr/bin/env python
import os
import json
from subprocess import Popen, PIPE, TimeoutExpired
import requests

LIMIT = 20
DIRNAME = os.path.join(os.path.expanduser("~"), ".local", "share", "lock-images")


def main():
    purge_old()

    procs = list(convert_all())
    r = 0
    for p in procs:
        try:
            r = max(r, p.wait(timeout=30))
        except TimeoutExpired:
            r = max(r, 1)
            try:
                os.remove(p.args[-1])
            except OSError:
                pass
    return r


def purge_old():
    images = sorted(listimg(), key=os.path.getctime)
    for filename in images[:-20]:
        try:
            os.remove(filename)
        except OSError as e:
            print(e)


def listimg():
    for filename in os.listdir(DIRNAME):
        filename = os.path.join(DIRNAME, filename)
        if is_image(filename):
            yield filename


def is_image(filename):
    return os.path.isfile(filename) and os.path.splitext(filename)[1] == ".png"


def convert_all():
    for img_id, img_data in extract_images(get_dict()):
        p = Popen(
            ["convert", "-resize", "1366", "JPG:-", output_filename(img_id)], stdin=PIPE
        )
        p.stdin.write(img_data)
        p.stdin.close()
        yield p


def get_dict():
    r = requests.get(
        f"http://www.reddit.com/r/earthporn.json?limit={LIMIT}",
        headers={"User-agent": "earthporn lock"},
    )
    if r.ok:
        return json.loads(r.text)
    raise ValueError(r.reason)


def extract_images(d):
    width, height = tuple(
        map(int, os.getenv("LOCK_RESOLUTION", default="1366*768").split("*"))
    )

    for thread in d["data"]["children"]:
        data = thread["data"]
        if not data["stickied"] and "preview" in data:
            src = data["preview"]["images"][0]["source"]
            if (
                abs(src["width"] / src["height"] - width / height) < 0.4
                and src["width"] >= width
            ):
                yield data["id"], requests.get(
                    src["url"].replace("amp;s", "s"), stream=True
                ).raw.read()


def output_filename(img_id):
    return os.path.join(DIRNAME, img_id + ".png")


if __name__ == "__main__":
    import sys

    if not os.path.exists(DIRNAME):
        os.mkdir(DIRNAME)

    sys.exit(main())
