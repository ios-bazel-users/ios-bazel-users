Useful Xcode Knowdledge
=======================

Xcconfig
--------

Xcode uses files that end in `.xcconfig` for storing configuration about various compiler settings.
While most of the variables in these `xcconfig` files are pretty self-explanatory, their meaning is 
specified in files with extension `.xcspec` that are stored in the `Xcode.app` bundle. You can find
these files by running the following:

```
$ find /Applications/Xcode.app -name \*.xcspec
```

Xcode Index Files
-----------------

Xcode stores index files for code completion and general navigation. A good explanation of how this works
is in [this video](https://www.youtube.com/watch?v=jGJhnIT-D2M). If you need to dump the index files, 
follow the instructions on [this gist](https://gist.github.com/kastiglione/fd9516db3cc93c9bdbeb5665f7d49985).

Xcodebuild flags
----------------

* `-UseSanitizedBuildSystemEnvironment=YES` – Makes `xcodebuild` behave like the IDE.
* `-IDEBuildOperationTimingLogLevel=3` – Enable extensive per-task timings.
* `-IDEBuildOperationDependenciesLogLevel=3` – Enable old build system logging for "implicit dependencies"
* `-IDEShowPrebuildLogs=YES` – Show logs from the "prebuild" step.
* `-ShowBuildOperationDuration=YES` – Enable timings on build operations.

All of these can be set permanently using:
```
defaults write com.apple.dt.Xcode $OPTION [-bool|-int|-string] $VALUE
```
See `man defaults`
