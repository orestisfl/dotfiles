#!/usr/bin/env python
import re
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup
from tqdm import tqdm

SUBS = ("english", "utan", "englesk")
BASE_URL = r"https://www.filminstitutet.se/"
LIST_URL = r"https://www.filminstitutet.se/sv/se-och-samtala-om-film/cinemateket-stockholm/program/?listtype=text"


def main():
    ret = 0

    for link in tqdm(list(all_links(LIST_URL))):
        r = requests.get(link)
        r.raise_for_status()

        if (subs := get_subs(r.text)) is None:
            ret = 1
            continue
        for target in SUBS:
            if target in subs:
                print(target, link)
                break

    return ret


def all_links(url):
    r = requests.get(url)
    r.raise_for_status()
    bs = BeautifulSoup(r.text, features="lxml")
    for url in bs.find_all(
        "a", attrs={"class": "article-tickets__meta-item margin-lg-b-1"}
    ):
        if href := url.get("href"):
            yield urljoin(BASE_URL, href)


def get_subs(html):
    search = re.search(
        r"text:\s*(.+)", BeautifulSoup(html, features="lxml").text.lower()
    )
    if search:
        return search.groups()[0].strip()
    return None


if __name__ == "__main__":
    import sys

    sys.exit(main())
