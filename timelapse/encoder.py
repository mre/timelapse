from threading import Thread  # Encoder is a thread
import subprocess
from datetime import datetime
import os
import glob
import fnmatch
import shutil
from notify import notify  # Shows notifications/alerts

not_found_msg = """
The ffmpeg command was not found;
ffmpeg is used by this script to make a video file from a set of pngs.
It is typically not installed by default distros , but it is widely available.
On macOS, try running `brew install ffmpeg`.
"""


class Encoder(Thread):
    """Create a video file from images"""

    def __init__(self, input_dir, output_dir):
        # Initialize the thread
        Thread.__init__(self)

        # Set config options
        self.input = f"{input_dir}/%d.png"
        timestamp = datetime.now().strftime("%Y-%m-%d-%H-%M-%S")
        self.output = f"{output_dir}/timelapse-{timestamp}.mov"

        print("Encoder started")

    def join(self, timeout=None):
        """ Hard shutdown """
        Thread.join(self)

    def run(self):
        """
        Now that we have screenshots of the user's desktop, we will stitch them
        together using `ffmpeg` to create a movie.  Each image will become
        a single frame in the movie.
        """
        # Call ffmpeg with settings compatible with QuickTime.
        # https://superuser.com/a/820137
        command = ["ffmpeg", "-y",
                   "-framerate", "30",
                   "-i", self.input,
                   "-vf", "format=yuv420p",
                   '-vcodec', 'h264',
                   self.output]
        try:
            notify("Timelapse", f"Creating timelapse. This might take a while")
            print(' '.join(command))
            try:
                subprocess.run(command, capture_output=True, check=True)
            except subprocess.CalledProcessError as e:
                notify("Timelapse Error: ffmpeg", e.stderr.decode('utf-8'))
            else:
                notify("Timelapse", f"Movie saved to `{self.output}`")

        except Exception as e:
            notify("Timelapse Error", e)
