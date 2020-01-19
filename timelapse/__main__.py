import os
import time
import subprocess
from pathlib import Path

from PyObjCTools import AppHelper
from AppKit import *

from notify import notify  # Shows notifications/alerts
from encoder import Encoder, not_found_msg  # Creates timelapse video
from recorder import Recorder  # Takes screenshots
from Foundation import NSUserDefaults


def dark_mode() -> bool:
    return NSUserDefaults.standardUserDefaults().stringForKey_('AppleInterfaceStyle') == "Dark"


# Configuration
start_recording: bool = False  # Start recording on launch
encode: bool = True  # Create video after recording
screenshot_interval: float = 1.5  # Number of seconds between screenshots
dir_base = str(Path.home())  # Base directory
dir_app: str = "timelapse"  # Output directory
dir_pictures: str = "Pictures"  # Place for pictures in filesystem
dir_movies: str = "Movies"  # Place for movies in filesystem
dir_resources: str = "./resources/"
if dark_mode():
    dir_resources += "white"
else:
    dir_resources += "black"

subdir_suffix: str = "Session-" + time.strftime("%Y%m%d")  # Name of subdirectory
image_recording: str = "record.gif"  # App icon recording
image_idle: str = "stop.gif"  # App icon idle
create_session_subdir: str = True  # New screenshot directory for each session
create_movies: bool = True  # Create movies from screenshots after recording
# Menu item text when recorder is running
text_recorder_running: str = "Stop recording"
text_recorder_idle: str = "Start recording"  # Menu item text when recorder is idle
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
            dir_base, dir_pictures, dir_app)
        self.encoder_output_basedir: str = os.path.join(dir_base, dir_movies)

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
        self.loadIcons()
        self.setStatus()

    def loadIcons(self) -> None:
        self.icon_recording = NSImage.alloc().initWithContentsOfFile_(
            os.path.join(dir_resources, image_recording))
        self.icon_idle = NSImage.alloc().initWithContentsOfFile_(
            os.path.join(dir_resources, image_idle))

    def setStatus(self) -> None:
        """ Sets the image and menu text according to recording status """
        if self.recording:
            self.statusitem.setImage_(self.icon_recording)
            self.recordButton.setTitle_(text_recorder_running)
            self.statusitem.setToolTip_(tooltip_running)
        else:
            self.statusitem.setImage_(self.icon_idle)
            self.recordButton.setTitle_(text_recorder_idle)
            self.statusitem.setToolTip_(tooltip_idle)

    def createMenu(self) -> NSMenu:
        """ Status bar menu """
        menu = NSMenu.alloc().init()
        # Bind record event
        self.recordButton = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            text_recorder_idle, 'startStopRecording:', '')
        menu.addItem_(self.recordButton)
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
            notify("Timelapse started", "The recording has started")
            self.recorder = Recorder(self.image_dir, screenshot_interval)
            self.recorder.start()
        self.recording: bool = not self.recording
        self.setStatus()

    @objc.python_method
    def create_dir(self, base_dir: str) -> str:
        """ Creates a specified directory and the path to it if necessary """
        if create_session_subdir:
            # Create a new subdirectory
            output_dir: str = os.path.join(base_dir, self.get_sub_dir(base_dir))
        else:
            # Don't create a subdirectory. Use base directory for output
            output_dir: str = base_dir
        # Create path if it doesn't exist
        try:
            print(f"Output directory: {output_dir}")
            os.makedirs(output_dir)
            notify("Timelapse is ready!",
                   "Start recording from the menubar icon.")

        except OSError as e:
            notify("Timelapse error", f"Error while creating directory: {e}")
            exit()
        return output_dir

    @objc.python_method
    def get_sub_dir(self, base_dir: str) -> str:
        """ Returns the next nonexistend subdirectory to base_dir """
        subdir_base: str = os.path.join(base_dir, subdir_suffix)
        # Check if we can use subdir without any session id
        subdir: str = subdir_base
        # Use a session id only if subdir already exists
        session_number: int = 0
        while os.path.exists(subdir):
            # We can't use subdir. Create directory with session id
            session_number += 1
            subdir: str = subdir_base + "-" + str(session_number)
        return subdir

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
            print(not_found_msg)


if __name__ == "__main__":
    app = NSApplication.sharedApplication()
    delegate = Timelapse.alloc().init()
    app.setDelegate_(delegate)
    AppHelper.runEventLoop()
