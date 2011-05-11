import os					# For directory traversing
import objc					# Objective-C bindings for Python
from datetime import date	# For daily subfolders
from Foundation import * 	# For NSDefaultRunLoopMode
from AppKit import * 		# For NSApplication
from PyObjCTools import NibClassBuilder, AppHelper

# Configuration
recording = True 					# Start recording on launch
screenshot_interval = 5.0 			# Number of seconds between screenshots 
dir_base = os.path.expanduser("~") 	# Base directory
dir_app = "timelag"					# Output directory
dir_pictures = "Pictures"			# Place for pictures in filesystem
dir_movies = "Movies"				# Place for movies in filesystem
image_recording = "box_black.gif"   # App icon recording
image_idle = "box_white.gif"        # App icon idle
create_daily_subdir = True			# New screenshot directory for each session
create_movies = True				# Create movies from screenshots after recording

class Timelapse(NSObject):
  '''
  Takes a screenshot every n seconds
  '''
  def applicationDidFinishLaunching_(self, notification):
    # Set initial recording status
    self.recording = recording

    # Create a reference to the statusbar (menubar)
    self.statusbar = NSStatusBar.systemStatusBar()

    # Create item in statusbar
    self.statusitem =  self.statusbar.statusItemWithLength_(NSVariableStatusItemLength)
    self.statusitem.setToolTip_("Timelapse screen recorder")

    # Create a simple menu and bind it to the status item
    self.menu = self.createMenu()
    self.statusitem.setMenu_(self.menu)

    # Load icons and show them in the statusbar
    self.loadIcons()
    self.setStatus()

  def loadIcons(self):
    self.icon_recording = NSImage.alloc().initWithContentsOfFile_(image_recording)
    self.icon_idle = NSImage.alloc().initWithContentsOfFile_(image_idle)

  def setStatus(self):
    '''Sets the image and menu text according to recording status'''
    if self.recording:
      self.statusitem.setImage_(self.icon_recording)
      self.recordButton.setTitle_("Stop recording") 
    else:
      self.statusitem.setImage_(self.icon_idle)
      self.recordButton.setTitle_("Start recording") 
  
  def createMenu(self):  
    # Status bar menu 
    menu = NSMenu.alloc().init()
    # Bind record event
    self.recordButton = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
		'Start recording', 'startStopRecording:', '')
    menu.addItem_(self.recordButton)
    # Quit event
    menuitem = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_('Quit', 'terminate:', '')
    menu.addItem_(menuitem)
    return menu
  
  def startStopRecording_(self, notification):
    if self.recording:
      print "Stop recording"
      self.recording = False
    else:
      print "Start recording"
      self.recording = True 
    self.setStatus()

#def setPaths():
 # if create_daily_subdir:
 #   subdir = "20101225"
 # output_screenshots = os.path.join(dir_base, dir_pictures, dir_app , subdir)
 # output_movies = os.path.join(dir_base, dir_movies, dir_app, subdir)

if __name__ == "__main__":
  app = NSApplication.sharedApplication()
  delegate = Timelapse.alloc().init()
  app.setDelegate_(delegate)
  AppHelper.runEventLoop()
