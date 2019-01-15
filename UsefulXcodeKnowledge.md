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
follow the instructions on [this gist](https://www.youtube.com/watch?v=jGJhnIT-D2M)
