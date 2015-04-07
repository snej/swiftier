#! /usr/bin/env ruby
#
# Swiftier.rb -- A quick and dirty Objective-C to Swift translator
# (in the sense of Google Translate, _not_ Xcode's "Modernize Syntax" tool, i.e. don't expect the
# output to compile! This tool just does some of the easy obvious grunt-work to save you time.)
#
# by Jens Alfke <jens@mooseyard.com> ... Github @snej
# Public domain. Do what thou wilt shall be the whole of the law.
# April 6, 2015

# Log something to the output
def NOTE(str)
  puts ">>>" + str
end

$deIndent = false

# Reads & returns the next line
def nextLine()
  line = $curLine
  if line then
    $curLine = nil
  else
    line = gets()
    line.rstrip!  if line
    if $deIndent && line.start_with?("    ") then
      line = line[4,line.length-4]
    end
  end
  return line
end

# Returns the next line but doesn't consume it (next call to peek/nextLine will return it again)
def peekLine()
  unless $curLine then
    $curLine = nextLine()
  end
  return $curLine
end

# Consumes blank lines
def skipBlankLines()
  while peekLine() == ""
    nextLine()
  end
end

# If `line` doesn't end in a semicolon, reads & discards lines up to & including the next that does.
def skipTillSemicolon(line)
  until line =~ /;\s*$/
    line = nextLine()
  end
end

def downcaseFirst!(str)
  if str.length == 1 || (str[2] == str[2].downcase) then
    str[0] = str[0].downcase
  end
end


$typeMap = {
  "void"      => "Void",
  "int"       => "Int",
  "unsigned"  => "UInt",
  "NSInteger" => "Int",
  "NSUInteger"=> "UInt",
  "SInt8"     => "Int8",
  "int8_t"    => "Int8",
  "uint8_t"   => "UInt8",
  "SInt16"    => "Int16",
  "int16_t"   => "Int16",
  "uint16_t"  => "UInt16",
  "SInt32"    => "Int32",
  "int32_t"   => "Int32",
  "uint32_t"  => "UInt32",
  "SInt64"    => "Int64",
  "int64_t"   => "Int64",
  "uint64_t"  => "UInt64",
  "BOOL"      => "Bool",
  "bool"      => "Bool",
  "char"      => "UInt8",
  "float"     => "Float",
  "double"    => "Double",
  "NSString"  => "String",
}

# Converts an Objective-C to a Swift type name
def convertType(type)
  return "NSErrorPointer"  if type == "NSError**"
  isPointer = (type.chomp!("*") != nil)
  type.rstrip!
  if type =~ /^id<(\w+)>$/ then
    type = $1
  else
    type = $typeMap.fetch(type, type)
    type += "?"  if isPointer
  end
  return type
end


# Parses an @implementation block. First line has been read already; `name` is the class name.
def parseImplementation(name)
  puts "class #{name} {"
  if peekLine() == "{" then
    nextLine()
    puts ""
    while (line = nextLine()) != "}"
      # instance variable:
      if line =~ /^\s*(\w.*)\s+(\w+)\s*;/ then
        name, type = $2, $1
        puts "private var #{name}: #{convertType(type)}"
      end
    end
  end
end


# Parses an @interface block. (Currently just skips it.)
def parseInterface(name, superclass, categoryName)
  while nextLine() != "@end" do
  end
  skipBlankLines()
end


# Parses a method header, whose first line (the one starting with +/-) is already read.
def parseMethod(isClassMethod, returnType, name, params, hasBrace)
  if name.start_with?("init") || name.start_with?("_init") then
    if name =~ /^_?initWith(\w+)$/ then
      paramName = $1
      downcaseFirst!(paramName)
      params[0] = paramName
      indent = 5
    end
    name = "init"
    returnType = "void"
    line = "init("
  else
    indent = name.length + 6
    line = isClassMethod ? "class " : ""
    line += "func #{name}("
  end
  i = 0
  while i < params.length do
    line += ", "  if i > 0
    keyword, type, paramName = params[i, 3]
    line += keyword + " "  if keyword != paramName && keyword != ""
    line += "#{paramName}: #{convertType(type)}"
    i += 3
  end
  
  # Check for more parameters on following lines:
  unless hasBrace
    while peekLine() =~ /^\s+(\w+):\s*\((.+)\)\s*(\w+)/ do
      nextLine()
      keyword, type, paramName = [$1, $2, $3]
      line += ",\n" + ' '*indent
      line += keyword + " "  if keyword != paramName
      line += paramName + ": " + convertType(type)
    end
  end
  
  line += ")"
  line += " -> #{convertType(returnType)}"  unless returnType == "void"
  line += " {"  if hasBrace
  puts line
end


# Converts a message-send statement, i.e one that starts with '[' and ends with ']', but _only_
# one that doesn't contain any square brackets. This is a subroutine of convertMessageSends.
def convert1MessageSend(expr)
  if expr =~ /^(\S+)\s+(\w+)$/ then  # no parameters
    receiver, message = $1, $2
    return receiver  if message == "alloc"        # [Foo alloc] --> Foo
    return receiver+"()"  if message == "init"    # [Foo init]  --> Foo()
    return "#{receiver}.#{message}()"             # [Foo bar] --> Foo.bar()
  end
  
  tokens = expr.split(/\s*\b(\w+):\s*/)
  return nil  unless tokens.length >= 3
  tokens.each {|token| return nil  if token.include?("[")}
  
  # Emit the receiver and the first parameter:
  receiver, keyword, param = tokens[0..2]
  if keyword.start_with?("init") then
    # Handle init and initWithXXX:
    keyword = keyword[4..keyword.length]
    if keyword.start_with?("With") then
      keyword = keyword[4..keyword.length]
      downcaseFirst!(keyword)
      # Ugly hack: If the translated expression contains a ':' it will confuse subsequent parsing,
      # so instead we'll output a '`'. These get fixed up to ':'s at the end of convertMessageSends.
      result = "#{receiver}(#{keyword}` #{param}"
    else
      result = "#{receiver}(#{param}"
    end
  else
    # Regular message:
    result = receiver + "." + keyword + "(" + param
  end
  
  # Emit any other parameters:
  i = 3
  while i < tokens.length do
    # See above comment about '`'!
    result += ", #{tokens[i]}` #{tokens[i+1]}"
    i += 2
  end
  return result + ")"
end


# Converts all Objective-C message-sends in the line into Swift syntax.
def convertMessageSends(line)
  # Keep looking for an innermost message expression (one without any nested messages), and
  # converting it to Swift syntax. Do this until there aren't any left.
  loop do
    result = line.sub(/\[\s*([^\[\]]*)\s*\]/) do |expr|
      parsed = convert1MessageSend($1)
      parsed != nil ? parsed : expr
    end
    break  if line == result
    line = result
  end
  return line.gsub("`", ":")  # Fix the temporary '`'s that got output as placeholders for ':'s
end


# Processes & converts lines until the next that ends in a ';', then adds a "}" line after it.
def addMissingCloseBrace(indent)
  done = false
  while !done do
    done = peekLine() =~ /;\s*(\/\/.*)?$/
    convertNextLine()
  end
  puts indent + "}"
end


# Processes a line.
def convertTopLevel(line)
  case line
  when /^\s*#import\s+(.*)$/
    return "import #{$1}"  if $1 =~ /<\w+\/(\w+).h>/
    return nil
  when /^@implementation\s+(\w+)/
    parseImplementation($1)
    return nil
  when /^@interface\s+(\w+)\s*:\s*(\w+)/
    parseInterface($1, $2, nil)
    return nil
  when /^@interface\s+(\w+)(?:\s*\((\w*)\))/
    parseInterface($1, nil, $2)
    return nil
  when /^@end/
    return "}"
  when /^@synthesize/
    skipTillSemicolon(line);
    return nil
  when /^[+-]/ then
    scope = (line[0] == "+") ? "class " : ""
    hasBrace = line.chomp!("{") != nil
    if m = line.match(/^[+-]\s*\(([^)]+)\)(?:\s*(\w+):\s*\(([^)]+)\)\s*(\w+))+/) then
      params = m.captures[2...m.captures.length]
      params[0,0] = "" # keyword of 1st param
      parseMethod(line[0] == "+", m[1], m[2], params, hasBrace)
      return nil
    elsif m = line.match(/[+-]\s*\(([^)]+)\)\s*(\w+)/) then
      # Special case of method with no parameters
      return "init()" if m[2] == "init"
      line = "#{scope}func #{m[2]}()"
      line += " -> #{convertType($1)}"  if $1 != "void"
      line += " {"  if hasBrace
    end
    return line
  end
  
  # General substitutions:
  line.gsub!(/(?<!%)@\"/, "\"")   # @"" -> "" (but don't convert "...%@" !)
  line.chomp!(";")
  line.gsub!(/\b__block\s+/, "")
  line.gsub!(/\bNO\b/, "false")
  line.gsub!(/\bYES\b/, "true")
  line.gsub!(/\bNSLog\b/, "println")
  line.gsub!(/\b(NS(Parameter|C)?)Assert\b/, "assert")
  
  line = convertMessageSends(line)
  
  case line
  when /^(\s+)(}?\s*(?:else\s+)?if)\s*\((.*)\)\s*({?)/ then
    # 'if' or 'else if'
    indent, keyword, condition, closeBrace = $1, $2, $3, $4
    if keyword == "if" && condition == "self" then
      # The 'if (self)...' in an initializer -- get rid of it
      $deIndent = true
      while peekLine().start_with?(indent) do
        convertNextLine()
      end
      $deIndent = false
      nextLine() # skip the "}"
      nextLine()  if peekLine() =~ /\s+return\s+self\s*;/
    else
      puts "#{indent}#{keyword} #{condition} {"
      addMissingCloseBrace(indent)  if closeBrace == ""
    end
    return nil
  when /^(\s+)(}?\s*else)\s*({?)/ then
    # 'else'
    indent, keyword, closeBrace = $1, $2, $3
    puts "#{indent}#{keyword} {"
    addMissingCloseBrace(indent)  if closeBrace == ""
    return nil
  when /^(\s+)self\s*=\s*\[\s*(.*)\s*\]/ then
    # Calling another initializer
    result = convertMessageSend($2)
    return result ? $1 + result : line
  when /^(\s+)(\w+)(?:\s|\*)+(\w+)\s*(?:\=\s*(.*))?$/ then
    # Local variable declaration
    indent, type, name, value = $1, $2, $3, $4
    return line  if type == "return"
    if value then
      return "#{indent}let #{name} = #{value}"
    else
      return "#{indent}var #{name}: #{convertType(type)}"
    end
  else
    return line
  end
end


# Reads a line, processes it, and outputs it.
def convertNextLine()
  line = nextLine()
  return false  unless line
  #NOTE "READ: #{line}"
  if match = /(.*)(\s*\/\/.*)$/.match(line) then
    line = match[1]
    comment = match[2]
  else
    comment = ""
  end
  #NOTE "$line = #{$line}   $comment = #{$comment}"
  line = convertTopLevel(line)  if line.length > 0
  puts(line + comment)  if line
  return true
end

# Top level code that just processes every line in the file.
while convertNextLine() do
end
