#!/usr/bin/env python3
import os
import sys


def main():
    os.execvp(
        "kubectl",
        ["kubectl"]
        + getenv_arg("--context", "KUBECTL_CONTEXT")
        + getenv_arg("--namespace", "KUBECTL_NAMESPACE")
        + sys.argv[1:],
    )


def getenv_arg(arg, key):
    if value := os.getenv(key):
        return [arg, value]
    return []


if __name__ == "__main__":
    main()
