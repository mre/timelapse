import datetime                     # Filename
import time                         # Going to sleep
from threading import Thread, Event # Encoder is a thread
import subprocess                   # System call

not_found_msg = """
The ffmpeg command was not found;
ffmpeg is used by this script to make an avi file from a set of pngs.
It is typically not installed by default distros , but it is widely available.
"""

class Encoder(Thread):
  '''Create a video file from images'''

  def __init__(self, output_dir):
    # Initialize the thread
    Thread.__init__(self)

    # Set config options
    self.output_dir = output_dir

    self.checkLibrary()
    print("Encoder started")

  def join(self):
    ''' Hard shutdown '''
    Thread.join(self)
  
  def run(self): 
		''' Render video '''
    
  def getFilename(self):
    # The id is the unique part of the filename.
    id = str(datetime.datetime.now())
    # Format the id a bit (remove whitspace and special characters)
    id = id.replace(' ', '').replace(':', '').replace('.', '')
    filename = os.path.join(self.output_dir, id) + "." + "avi"
    return filename

  def checkLibrary(self):
    try:
      subprocess.check_call(['ffmpeg'])
    except subprocess.CalledProcessError:
      print "ffmpeg command was found"
      pass # ffmpeg is found, but returns non-zero exit as expected
      # This is a quick and dirty check; it leaves some spurious output
      # for the user to puzzle over.
    except OSError:
      print not_found_msg

    # Now that we have graphed images of the dataset, we will stitch them
    # together using Mencoder to create a movie.  Each image will become
    # a single frame in the movie.
    #
    # We want to use Python to make what would normally be a command line
    # call to Mencoder.  Specifically, the command line call we want to
    # emulate is (without the initial '#'):
    # mencoder mf://*.png -mf type=png:w=800:h=600:fps=25 -ovc lavc -lavcopts vcodec=mpeg4 -oac copy -o output.avi
    # See the MPlayer and Mencoder documentation for details.
    #
    
    command = ('mencoder',
               'mf://*.png',
               '-mf',
               'type=png:w=800:h=600:fps=25',
               '-ovc',
               'lavc',
               '-lavcopts',
               'vcodec=mpeg4',
               '-oac',
               'copy',
               '-o',
               'output.avi')
    
    #os.spawnvp(os.P_WAIT, 'mencoder', command)
    
    print "\n\nabout to execute:\n%s\n\n" % ' '.join(command)
    subprocess.check_call(command)
    
    print "\n\n The movie was written to 'output.avi'"
    
    print "\n\n You may want to delete *.png now.\n\n"
    
