# Timelapse

![timelapse logo](timelapse/resources/logo.svg)

...a little macOS app that records your screen to make a timelapse.

[![Build Status](https://travis-ci.org/mre/timelapse.svg?branch=master)](https://travis-ci.org/mre/timelapse)

## Features

- Simple
- Minimal CPU usage
- Extensible
- Follows the cursor across screens while recording

## Why use this project?

There are many alternative solutions available. Most of them fall into one of
these categories:

- Commercial applications
- Custom scripts based on Automator and AppleScript
- Freeware

This project provides an _Open-Source_ alternative that is both, easy to use and
understand. If you did something cool with the app, let us know. :)

## Requirements

- macOS (any version)
- ffmpeg (run `brew install ffmpeg`)

## Usage

1. Download the app from the [releases
   page](https://github.com/mre/timelapse/releases).
2. Start the app. If you get a warning about the app being unsigned,
   go to the `System Preferences > Security & Privacy` and allow the app from there.
3. A new icon appears in the menubar.
4. By clicking on it, you start and stop the screen recording.
5. Once you've finished recording, `timelapse` will create a video for you  
   and print the output path to the commandline.

## Development

You need Python 3.5+ for development.

First, install the project's dependencies:

```shell
pip install -r requirements.txt
```

Now run the main application from the commandline:

```shell
python timelapse
```

## License

Licensed under either of

- Apache License, Version 2.0, (LICENSE-APACHE or
  http://www.apache.org/licenses/LICENSE-2.0)
- MIT license (LICENSE-MIT or http://opensource.org/licenses/MIT)

at your option.

App icon by [gstudioimagen - www.freepik.com](https://www.freepik.com/free-photos-vectors/people).
