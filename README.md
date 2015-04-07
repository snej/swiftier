## What It Is

— A quick and dirty script that reads Objective-C source code and outputs a _rough, partial_ translation to Swift. Expect a similar level of fluency and elegance as produced by Google Translate, i.e. not much.

— A tool to save you from a whole lot of annoying search-and-replace grunt-work when converting Objective-C code to Swift.

## What It Isn't

— A pushbutton converter like Xcode's "Modernize Syntax" tool that outputs compilable code. _Not even!_

— Anything resembling a sane parser. (I've written parsers and I know the difference.) _Mais non!_ this is a nasty soup of regular expressions. It's ugly and limited, but hey, I got it running in a few hours.

— Complete. _No way!_ This is a one-day hack, and there are a lot of things it could do that it doesn't yet, or that it could do better. If I'm motivated (or if _you_ are!) then maybe someday it'll do those things.

## How To Use It

Just download the file `swiftier.rb`, make sure its executable bit is set, and feed it the contents of a `.m` file either by path or by stdin. The output will be written to stdout. For example:

    $ swiftier.rb FlappyCapybara.m >FlappyCapybara.swift

or to inspect what all your code would look like:

    $ cat *.m | swiftier.rb | mate

## License

I'm putting this in the public domain, or if you will, under the Thelemaic License: _Do what thou wilt shall be the whole of the law._ Have fun :)
