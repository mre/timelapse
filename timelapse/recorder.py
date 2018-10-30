import os  # Taking screenshot
import datetime  # Filename
from threading import Thread, Event  # Recorder is a thread


class Recorder(Thread):
    """
    Takes a screenshot every 'interval' seconds and saves it into output_dir or a subdirectory thereof.
    """

    def __init__(self, output_dir, interval=4):
        # Initialize the thread
        Thread.__init__(self)

        # Provide a way to stop the recorder
        self._stop = Event()

        # Set config options
        self.output_dir = output_dir
        self.interval = interval
        self.format = "png"

        # Number of screenshots taken
        self.screenshot_counter = 0
        print("Recorder started")

    def join(self, timeout=None):
        """ Stop recording """
        self._stop.set()
        print("Recorder stopped. Total recording time: " + self.get_recording_time() + ".")
        Thread.join(self)

    def run(self):
        """ Periodically take a screenshots of the screen """
        while not self._stop.isSet():
            self.screenshot()
            self._stop.wait(self.interval)

    def get_recording_time(self):
        return str(self.screenshot_counter * self.interval) + " seconds"

    def get_filename(self):
        """ Call screencapture for mac screenshot """
        # The id is the unique part of the filename.
        id = str(datetime.datetime.now())
        # Format the id a bit (remove whitspace and special characters)
        id = id.replace(' ', '').replace(':', '').replace('.', '')
        filename = os.path.join(self.output_dir, id) + "." + self.format
        return filename

    def screenshot(self):
        """ This method uses Mac OSX screencapture from the commandline """
        filename = self.get_filename()
        print("Taking screenshot [" + filename + "]")
        os.system("screencapture -S -o -x -t" + self.format + " " + filename)
        self.screenshot_counter += 1
