#!/usr/bin/env zsh
project_path=`dirname $(realpath $0)` # To use: sudo apt-get install realpath
google-chrome chrome://extensions
subl --project $project_path/pi6.sublime-project