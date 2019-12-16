# Timelapse

![timelapse logo](timelapse/resources/icon.svg)

...takes screenshots and creates a video out of them to make a timelapse.

[![Build Status](https://travis-ci.org/mre/timelapse.svg?branch=master)](https://travis-ci.org/mre/timelapse)


## Goals

* Simple
* Minimal CPU usage
* Extendable

## Why use this project?

There are many alternative solutions available.
Most of them fall into one of these categories:

* Commercial applications
* Custom scripts based on Automator and AppleScript
* Freeware

This project provides an Open-Source alternative that is both,
easy to use and understand.

## Requirements

* macOS (any version)
* ffmpeg (run `brew install ffmpeg`)

## Usage

First, install the project's dependencies:

```shell
pip install -r requirements.txt
```

Now run the main application from the commandline:

```shell
python timelapse
```

After that, a new icon appears in the menubar.  
By clicking on it, you start and stop the screen recording.  

Once you've finished recording, `timelapse` will create a video for you  
and print the output path to the commandline.
You can now quit timelapse.

## License

Licensed under either of

* Apache License, Version 2.0, (LICENSE-APACHE or
  http://www.apache.org/licenses/LICENSE-2.0)
* MIT license (LICENSE-MIT or http://opensource.org/licenses/MIT)

at your option.

App icon by [gstudioimagen - www.freepik.com](https://www.freepik.com/free-photos-vectors/people).
