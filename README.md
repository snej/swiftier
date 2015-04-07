## What It Is

— A quick and dirty script that reads Objective-C source code and outputs a _rough, partial_ translation to Swift. Expect a similar level of fluency and elegance as produced by Google Translate, i.e. not much.

— A tool to save you from a whole lot of annoying search-and-replace grunt-work when converting Objective-C code to Swift.

## What It Isn't

— A pushbutton converter like Xcode's "Modernize Syntax" tool that outputs compilable code. _Not even!_

— Anything resembling a sane parser. (I've written parsers and I know the difference.) _Mais non!_ this is a nasty soup of regular expressions. It's ugly and limited, but hey, I got it running in a few hours.

— Complete. _No way!_ This is a one-day hack, and there are a lot of things it could do that it doesn't yet, or that it could do better. If I'm motivated (or if _you_ are!) then maybe someday it'll do those things.

## What It Converts

* `#import <Foo/Foo.h>` —> `import Foo`
* Class or category interfaces (`@interface` through `@end`) are stripped. (TBD: Use them to determine which methods are public and which correspond to properties.)
* `@implementation Foo ... @end` —> `class Foo { ... }`
* Instance variable declarations (in braces right after `@implementation`) turn into private `var`s.
* Method header lines e.g. `- (BOOL) foo:(int)bar {...}` —> `func foo(bar :Int) -> Bool { ... }`
* `init` methods are treated specially to accord with Swift's initializer rules:
    * If the method name starts with `initWith...` then the rest of the name turns into the keyword of the first parameter.
    * The `self = [super init]` boilerplate turns into an initializer call to `super` or `self`.
    * The `if (self)` boilerplate check is stripped out.
    * The `return self` at the end is stripped out.
* Local variable declarations. Those initialized with a value are defined using `let`, those with no value are `var`.
* Many common type names when used in method headers or variable declarations; like `NSUInteger` —> `UInt` and `NSString` —> `String`.
* A few common constants, like `YES` —> `true` and `NO` —> `false`.
* A few common functions, like `NSLog` —> `println` and `NSAssert` —> `assert`.
* `@"..."` —> `"..."`
* Message-send expressions in square brackets. (Limitation: Only if they fit on a single line. Those broken across multiple lines are currently left alone. Sorry!)
* Trailing semicolons — _removed!_
* Parentheses around `if` conditions — _removed!_
* Braces around single-statement `if` bodies — _added!_

Q: "Dude, you forgot `_____`. wtf! It should totally convert those too."  
A: "We're so glad you've decided to help! Pull requests welcome `^_^`"

## How To Use It

Just download the file `swiftier.rb`, make sure its executable bit is set, and feed it the contents of a `.m` file either by path or by stdin. The output will be written to stdout. For example:

    $ swiftier.rb FlappyCapybara.m >FlappyCapybara.swift

or to inspect what all your code would look like:

    $ cat *.m | swiftier.rb | mate

## License

I'm putting this in the public domain, or if you will, under the Thelemaic License: _Do what thou wilt shall be the whole of the law._ Have fun :)
