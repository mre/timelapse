from subprocess import run


def notify(title, text):
    script = 'display notification "{}" with title "{}"'.format(text, title)
    return run(['osascript', '-e', script])
