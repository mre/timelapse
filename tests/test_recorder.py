import unittest
import sys
sys.path.append("../src")

from recorder import Recorder
import threading

"""
- Test class for the recorder class in the main directory.
  This file will contain 4 unit tests each representing and testing 
  a method found in the recorder.py file.
"""

class TestRecorder(unittest.TestCase):

    # Test init method
    def test_init_method(self):
        recorder = Recorder("./", 8)
        self.assertEquals(type(recorder._stop), threading._Event)
        self.assertEquals(recorder.interval, 8)

    # Test Case #2: get_recording_time(self)
    def test_get_recording_time(self):
        recorder = Recorder("./", 8)
        recorder.screenshot_counter = 5
        test_string = str(5 * 8) + " seconds"

        self.assertEquals(recorder.get_recording_time(), test_string)
        self.assertEquals(type(recorder.get_recording_time()), str)

    # Test Case #3: run()
    def test_run(self):
        recorder = Recorder("./", 8)
        
        # Assert the boolean is false upon initialisation.
        self.assertEquals(recorder._stop.isSet(), False)

        # Can't figure out how but a mocking solution would work well.
        # Perhaps try count how many times the screenshot() and
        # _stop.wait() methods get called and verify it. 

    # Test Case #4: screenshot()
    def test_screenshot(self):
        recorder = Recorder("./", 8)
    
        # Very simple test, just ensure that the counter got incremented.
        # Then we can be certain the other code ran previously.
        recorder.screenshot()
        self.assertEquals(recorder.screenshot_counter, 1)

if __name__ == "__main__":
    unittest.main()

