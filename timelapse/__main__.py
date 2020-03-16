"""
The main entrypoint of the application,
which initializes the recorder and the encoder.
"""

import os
import time
import subprocess
from pathlib import Path

from AppKit import NSObject, NSMenu, NSApplication, NSStatusBar, \
                   NSMenuItem, NSImage, NSVariableStatusItemLength, objc
from PyObjCTools import AppHelper
from Foundation import NSUserDefaults

from timelapse.encoder import Encoder # Creates timelapse video
from timelapse.recorder import Recorder # Takes screenshots
from timelapse.notify import notify # Shows notifications/alerts

NOT_FOUND_MSG = """
The ffmpeg command was not found;
ffmpeg is used by this script to make a video file from a set of pngs.
It is typically not installed by default distros , but it is widely available.
On macOS, try running `brew install ffmpeg`.
"""


def dark_mode() -> bool:
    """
    Check if the user enabled Dark Mode
    """
    return NSUserDefaults.standardUserDefaults().stringForKey_('AppleInterfaceStyle') == "Dark"


# Configuration
start_recording: bool = False  # Start recording on launch
encode: bool = True  # Create video after recording
screenshot_interval: float = 1.5  # Number of seconds between screenshots
DIR_BASE = str(Path.home())  # Base directory
dir_app: str = "timelapse"  # Output directory
dir_pictures: str = "Pictures"  # Place for pictures in filesystem
dir_movies: str = "Movies"  # Place for movies in filesystem
dir_resources: str = "./resources/"
if dark_mode():
    dir_resources += "white"
else:
    dir_resources += "black"

image_recording: str = "recording.png"  # App icon recording
image_idle: str = "idle.png"  # App icon idle
create_movies: bool = True  # Create movies from screenshots after recording
# Menu item text when recorder is running
text_recorder_running: str = "Stop recording"
# Menu item text when recorder is idle
text_recorder_idle: str = "Start recording"
# Tooltip of menu icon when not recording
tooltip_idle: str = "Timelapse screen recorder"
tooltip_running: str = "Recording | " + tooltip_idle  # Tooltip when recording


###############

class Timelapse(NSObject):
    """ Creates a timelapse video """

    def applicationDidFinishLaunching_(self, notification) -> None:
        self.check_dependencies()

        # Initialize recording
        self.recording: bool = start_recording
        self.recorder = None

        # Set correct output paths
        self.recorder_output_basedir: str = os.path.join(
            DIR_BASE, dir_pictures, dir_app)
        self.encoder_output_basedir: str = os.path.join(DIR_BASE, dir_movies)
        self.image_dir: str = self.create_dir(self.recorder_output_basedir)

        # Create a reference to the statusbar (menubar)
        self.statusbar = NSStatusBar.systemStatusBar()

        # Create item in statusbar
        self.statusitem = self.statusbar.statusItemWithLength_(
            NSVariableStatusItemLength)
        self.statusitem.setHighlightMode_(1)  # Highlight upon clicking

        # Create a simple menu and bind it to the status item
        self.menu = self.createMenu()
        self.statusitem.setMenu_(self.menu)

        # Load icons and show them in the statusbar
        self.load_icons()
        self.set_status()

    def load_icons(self) -> None:
        self.icon_recording = NSImage.alloc().initWithContentsOfFile_(
            os.path.join(dir_resources, image_recording))
        self.icon_idle = NSImage.alloc().initWithContentsOfFile_(
            os.path.join(dir_resources, image_idle))

    def set_status(self) -> None:
        """ Sets the image and menu text according to recording status """
        if self.recording:
            self.statusitem.setImage_(self.icon_recording)
            self.record_button.setTitle_(text_recorder_running)
            self.statusitem.setToolTip_(tooltip_running)
        else:
            self.statusitem.setImage_(self.icon_idle)
            self.record_button.setTitle_(text_recorder_idle)
            self.statusitem.setToolTip_(tooltip_idle)

    def createMenu(self) -> NSMenu:
        """ Status bar menu """
        menu = NSMenu.alloc().init()
        # Bind record event
        self.record_button = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            text_recorder_idle, 'startStopRecording:', '')
        menu.addItem_(self.record_button)
        # Quit event
        menuitem = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            'Quit', 'terminate:', '')
        menu.addItem_(menuitem)
        return menu

    def startStopRecording_(self, notification) -> None:
        if self.recording:
            self.recorder.join(timeout=screenshot_interval*2)
            # Create timelapse after recording?
            if encode:
                self.encoder = Encoder(
                    self.image_dir, self.encoder_output_basedir)
                self.encoder.start()
        else:
            self.recorder = Recorder(self.image_dir, screenshot_interval)
            self.recorder.start()
            notify("Timelapse started", "The recording has started")
        self.recording: bool = not self.recording
        self.set_status()

    @objc.python_method
    def create_dir(self, base_dir: str) -> str:
        """ Creates a specified directory and the path to it if necessary """
        # Create a new subdirectory
        output_dir: str = os.path.join(base_dir, self.get_sub_dir(base_dir))

        # Create path if it doesn't exist
        try:
            print(f"Output directory: {output_dir}")
            os.makedirs(output_dir)
        except OSError as e:
            notify("Timelapse error", f"Error while creating directory: {e}")
            exit()
        return output_dir

    @objc.python_method
    def get_sub_dir(self, base_dir: str) -> str:
        """ Returns the subdirectory for recording, relative to base_dir """
        subdir_suffix: str = "Session-" + \
            time.strftime("%Y-%m-%d_%H-%M-%S")
        return os.path.join(base_dir, subdir_suffix)

    def check_dependencies(self) -> None:
        try:
            subprocess.run(['ffmpeg'], check=True,
                           capture_output=True, timeout=10.0)
        except subprocess.CalledProcessError:
            print("ffmpeg command was found")
            pass  # ffmpeg is found, but returns non-zero exit as expected
            # This is a quick and dirty check; it leaves some spurious output
            # for the user to puzzle over.
        except OSError:
            print(NOT_FOUND_MSG)
            notify("Timelapse", "ERROR: ffmpeg not found")
            exit()

def main():
    app = NSApplication.sharedApplication()
    delegate = Timelapse.alloc().init()
    app.setDelegate_(delegate)
    AppHelper.runEventLoop()

if __name__ == "__main__":
    main()
