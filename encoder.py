from threading import Thread  # Encoder is a thread
import subprocess

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
        self.input = "{}/*.png".format(input_dir)
        self.output = "{}/output.mp4".format(output_dir)

        print("Encoder started")

    def join(self, timeout=None):
        """ Hard shutdown """
        Thread.join(self)

    def run(self):
        """
        Now that we have graphed images of the dataset, we will stitch them
        together using ffmpeg to create a movie.  Each image will become
        a single frame in the movie.
        """
        command = (
            "ffmpeg", "-framerate", "30", "-pattern_type", "glob", "-i", self.input, self.output
        )

        print "\n\nabout to execute:\n%s\n\n" % ' '.join(command)
        subprocess.check_call(command)
        print "\n\n The movie was saved to `{}`".format(self.output)
