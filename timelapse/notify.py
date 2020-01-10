import os


def notify(title: str, text: str) -> None:
    os.system("""
              osascript -e 'display notification "{}" with title "{}"'
              """.format(text, title))
