import os      # For screenshot system call
import AppKit  # For NSImage

class Screenshot:
  ''' Creates a screenshot on Mac OS X '''

  def __init__(self, suffix="timelag_capture_"):
    self.suffix = suffix

  def capture(self):
    ''' Take a screenshot and return it to the caller '''
    try:
      screenshot = self.suffix + 'screenshort.jpg'
      os.system('screencapture -i %s' % screenshot)
      return AppKit.NSImage.alloc().initWithContentsOfFile_(screenshot)
    except:
      print("ERROR: Can't take screenshot.")
