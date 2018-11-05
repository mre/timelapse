# Timelapse

[![Build Status](https://travis-ci.org/mre/timelapse.svg?branch=master)](https://travis-ci.org/mre/timelapse)

...takes screenshots and creates a video out of them to make a timelapse.

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

Now run the main application from the commmand-line:

```shell
python timelapse
```

After that, a new icon appears in the menubar.  
By clicking on it, you start and stop the screen recording.  

Once you've finished recording, `timelapse` will create a video for you  
and print the output path to the commandline.
You can now quit timelapse.
