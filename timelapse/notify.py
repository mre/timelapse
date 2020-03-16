"""
Functionality to show notifications on macOS
"""

import subprocess


def notify(title: str, text: str) -> int:
    """
    Show a macOS notification using osascript
    """
    script = 'display notification "{}" with title "{}"'.format(text, title)
    return subprocess.run(['osascript', '-e', script], check=True).returncode
