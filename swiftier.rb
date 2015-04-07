#! /usr/bin/env ruby
#
# Swiftier.rb -- A quick and dirty Objective-C to Swift translator
# (in the sense of Google Translate, _not_ Xcode's "Modernize Syntax" tool, i.e. don't expect the
# output to compile! This tool just does some of the easy obvious grunt-work to save you time.)
#
# by Jens Alfke <jens@mooseyard.com> ... Github @snej
# Public domain. Do what thou wilt shall be the whole of the law.
# April 6, 2015

def NOTE(str)
  puts ">>>" + str
end

def nextLine()
  line = $curLine
  if line then
    $curLine = nil
  else
    line = gets()
    line.rstrip!  if line
  end
  return line
end

def peekLine()
  unless $curLine then
    $curLine = gets()
    $curLine.rstrip!  if $curLine
  end
  return $curLine
end

def skipBlankLines()
  while peekLine() == ""
    nextLine()
  end
end


def skipTillSemicolon(line)
  until line =~ /;\s*$/
    line = nextLine()
  end
end


$typeMap = {
  "void" => "Void",
  "int" => "Int",
  "NSInteger" => "Int",
  "unsigned" => "UInt",
  "NSUInteger" => "UInt",
  "uint8_t" => "UInt8",
  "uint32_t" => "UInt32",
  "int32_t" => "Int32",
  "BOOL" => "Bool",
  "bool" => "Bool",
  "float" => "Float",
  "double" => "Double",
  "NSString" => "String",
}

def convertType(type)
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


def parseImplementation(name)
  puts "class #{name} {"
  if peekLine() == "{" then
    nextLine()
    puts ""
    while (line = nextLine()) != "}"
      # instance variable:
      if line =~ /^\s*(\w.*)\s+(\w+)\s*;/ then
        name, type = [$2, $1.chomp("*")]
        puts "private var #{name}: #{convertType(type)}"
      end
    end
  end
end


def parseInterface(name, superclass, categoryName)
  while nextLine() != "@end" do
  end
  skipBlankLines()
end


def parseMethod(isClassMethod, returnType, name, params, hasBrace)
  if name.start_with?("init") || name.start_with?("_init") then
    if name =~ /^_?initWith(\w+)$/ then
      paramName = $1
      paramName[0] = paramName[0].downcase
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
    line += keyword + "  "  if keyword != paramName && keyword != ""
    line += "#{paramName}: #{convertType(type)}"
    i += 3
  end
  
  # Check for more parameters on following lines:
  unless hasBrace
    while peekLine() =~ /^\s+(\w+):\s*\((.+)\)\s*(\w+)/ do
      nextLine()
      keyword, type, paramName = [$1, $2, $3]
      line += ",\n" + ' '*indent
      line += keyword + "  "  if keyword != paramName
      line += paramName + ": " + convertType(type)
    end
  end
  
  line += ")"
  line += " -> #{convertType(returnType)}"  unless returnType == "void"
  line += " {"  if hasBrace
  puts line
end


def parseMessageSend(expr)
  if expr =~ /^(\w+)\s+(\w+)$/ then  # no parameters
    receiver, message = $1, $2
    return "#{receiver}.#{message}()"
  end
  
  tokens = expr.split(/\s*\b(\w+):\s*/)
  return nil  unless tokens.length >= 3
  tokens.each {|token| return nil  if token.include?("[")}
  result = tokens[0] + "." + tokens[1] + "(" + tokens[2]
  i = 3
  while i < tokens.length do
    result += ", #{tokens[i]}: #{tokens[i+1]}"
    i += 2
  end
  result += ")"
  return result
end


def addMissingCloseBrace(indent)
  done = false
  while !done do
    done = peekLine() =~ /;\s*(\/\/.*)?$/
    convertNextLine()
  end
  puts indent + "}"
end


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
  
  case line
  when /^(\s+)(}?\s*(?:else\s+)?if\s*)\((.*)\)\s*({?)/ then
    # 'if' or 'else if'
    indent, keyword, condition, closeBrace = $1, $2, $3, $4
    puts "#{indent}#{keyword}#{condition} {"
    addMissingCloseBrace(indent)  if closeBrace == ""
    return nil
  when /^(\s+)(}?\s*else)\s*({?)/ then
    # 'else'
    indent, keyword, closeBrace = $1, $2, $3
    puts "#{indent}#{keyword} {"
    addMissingCloseBrace(indent)  if closeBrace == ""
    return nil
  when /^(\s+)\[\s*(.*)\s*\]$/ then
    # Message-send
    result = parseMessageSend($2)
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

while line = nextLine()
  while convertNextLine() do
  end
end
