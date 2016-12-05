#!/usr/bin/env python
# -*- coding: utf-8 -*-
import re
import requests
import bs4


def main(args):
    r = requests.get(args[1])
    soup = bs4.BeautifulSoup(r.text, "html.parser")
    ntabs_str = soup.div.div.text.strip()
    ntabs = int(re.search(r"Shared:\s*(\d*)\s* tabs", ntabs_str).groups()[0])
    links = [div.a['href'] for div in soup.find_all("div") if div.a][3:]  # 3 first are irrelevant
    if len(links) != ntabs:
        print("Onetab mention {ntabs} links but I found {actual}.".format(
            ntabs=ntabs, actual=len(links), file=sys.stderr))
    print("\n".join(links))
    return 0

if __name__ == '__main__':
    import sys
    sys.exit(main(sys.argv))
