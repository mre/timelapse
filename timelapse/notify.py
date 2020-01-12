import os


def notify(title: str, text: str) -> int:
    os.system("""
              osascript -e 'display notification "{}" with title "{}"'
              """.format(text, title))
