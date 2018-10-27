# Timelapse

...takes screenshots and creates a video out of them to make a timelapse.

## Requirements

* macOS (any version)
* ffmpeg (run `brew install ffmpeg`)

## Usage

First, install the project's dependencies:

```shell
pip install -r requirements.txt
```

Now run the main application from the commmand-line:

```shell
python timelapse.py
```

After that, a new icon appears in the menubar.  
By clicking on it, you start and stop the screen recording.  

Once you've finished recording, `timelapse` will create a video for you  
and print the output path to the commandline.
You can now quit timelapse.
