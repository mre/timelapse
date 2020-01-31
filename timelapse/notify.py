from subprocess import run


def notify(title: str, text: str) -> int:
    script = 'display notification "{}" with title "{}"'.format(text, title)
    return run(['osascript', '-e', script]).returncode
