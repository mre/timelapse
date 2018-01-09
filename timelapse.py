import os  # For directory traversing
import objc  # Objective-C bindings for Python
import threading  # For recorder and renderer
import time  # To create subdirectories
from recorder import Recorder  # Takes screenshots
from encoder import Encoder  # Creates timelapse video
from datetime import date  # For session subfolders
from Foundation import *  # For NSDefaultRunLoopMode
from AppKit import *  # For NSApplication
from PyObjCTools import NibClassBuilder, AppHelper

# Configuration
start_recording = False  # Start recording on launch
encode = True  # Create video after recording
screenshot_interval = 1.5  # Number of seconds between screenshots
dir_base = os.path.expanduser("~")  # Base directory
dir_app = "timelapse"  # Output directory
dir_pictures = "Pictures"  # Place for pictures in filesystem
dir_movies = "Movies"  # Place for movies in filesystem
dir_resources = "resources"
subdir_suffix = "Session-" + time.strftime("%Y%m%d")  # Name of subdirectory
image_recording = "record.gif"  # App icon recording
image_idle = "stop.gif"  # App icon idle
create_session_subdir = True  # New screenshot directory for each session
create_movies = True  # Create movies from screenshots after recording
text_recorder_running = "Stop recording"  # Menu item text when recorder is running
text_recorder_idle = "Start recording"  # Menu item text when recorder is idle
tooltip_idle = "Timelapse screen recorder"  # Tooltip of menu icon when not recording
tooltip_running = "Recording | " + tooltip_idle  # Tooltip when recording


###############

class Timelapse(NSObject):
    ''' Creates a timelapse video '''

    def applicationDidFinishLaunching_(self, notification):
        # Initialize recording
        self.recording = start_recording

        # Set correct output paths
        self.recorder_output_basedir = os.path.join(dir_base, dir_pictures, dir_app)
        self.encoder_output_basedir = os.path.join(dir_base, dir_movies)

        # Create a reference to the statusbar (menubar)
        self.statusbar = NSStatusBar.systemStatusBar()

        # Create item in statusbar
        self.statusitem = self.statusbar.statusItemWithLength_(NSVariableStatusItemLength)
        self.statusitem.setHighlightMode_(1)  # Highlight upon clicking

        # Create a simple menu and bind it to the status item
        self.menu = self.createMenu()
        self.statusitem.setMenu_(self.menu)

        # Load icons and show them in the statusbar
        self.loadIcons()
        self.setStatus()

    def loadIcons(self):
        self.icon_recording = NSImage.alloc().initWithContentsOfFile_(os.path.join(dir_resources, image_recording))
        self.icon_idle = NSImage.alloc().initWithContentsOfFile_(os.path.join(dir_resources, image_idle))

    def setStatus(self):
        ''' Sets the image and menu text according to recording status '''
        if self.recording:
            self.statusitem.setImage_(self.icon_recording)
            self.recordButton.setTitle_(text_recorder_running)
            self.statusitem.setToolTip_(tooltip_running)
        else:
            self.statusitem.setImage_(self.icon_idle)
            self.recordButton.setTitle_(text_recorder_idle)
            self.statusitem.setToolTip_(tooltip_idle)

    def createMenu(self):
        ''' Status bar menu '''
        menu = NSMenu.alloc().init()
        # Bind record event
        self.recordButton = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            text_recorder_idle, 'startStopRecording:', '')
        menu.addItem_(self.recordButton)
        # Quit event
        menuitem = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_('Quit', 'terminate:', '')
        menu.addItem_(menuitem)
        return menu

    def startStopRecording_(self, notification):
        if self.recording:
            self.recorder.join()
            # Create timelapse after recording?
            if encode:
                self.encoder = Encoder(self.encoder_output_basedir)
                self.encoder.start()
        else:
            output_dir = self.createDir(self.recorder_output_basedir)
            self.recorder = Recorder(output_dir, screenshot_interval)
            self.recorder.start()
        self.recording = not self.recording
        self.setStatus()

    def createDir(self, base_dir):
        ''' Creates a specified directory and the path to it if necessary '''
        if create_session_subdir:
            # Create a new subdirectory
            output_dir = os.path.join(base_dir, self.getSubDir(base_dir))
        else:
            # Don't create a subdirectory. Use base directory for output
            output_dir = base_dir
        # Create path if it doesn't exist
        try:
            print(output_dir)
            os.makedirs(output_dir)
        except OSError:
            print("oops")
            exit()
        return output_dir

    def getSubDir(self, base_dir):
        ''' Returns the next nonexistend subdirectory to base_dir '''
        subdir_base = os.path.join(base_dir, subdir_suffix)
        # Check if we can use subdir without any session id
        subdir = subdir_base
        # Use a session id only if subdir already exists
        session_number = 0
        while os.path.exists(subdir):
            # We can't use subdir. Create directory with session id
            session_number += 1
            subdir = subdir_base + "-" + str(session_number)
        return subdir


if __name__ == "__main__":
    app = NSApplication.sharedApplication()
    delegate = Timelapse.alloc().init()
    app.setDelegate_(delegate)
    AppHelper.runEventLoop()
