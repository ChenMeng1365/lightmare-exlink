#!/usr/local/bin/ruby
#coding:utf-8

['yaml', 'fileutils','./conf'].each{|mod|require mod}
索引 = YAML.load File.read("#{$config}/path.yaml")

raise("Please input feature name!") unless ARGV[0]

feature, conftest, steps, modules = DATA.read.split("__END__")

索引['pytest-bdd'].each do|key, path|
  !File.exist?(path) and `mkdir -p #{path}`
  key == 'feature'   and File.write("#{path}/#{ARGV[0]}.feature", feature)
  key == 'steps'     and (
    File.exist?("#{path}/__init__.py") ? raise("File #{path}/__init__.py already exists!") : File.write("#{path}/__init__.py", modules)
    File.exist?("#{path}/conftest.py") ? raise("File #{path}/conftest.py already exists!") : File.write("#{path}/conftest.py", conftest)
    File.exist?("#{path}/#{ARGV[0]}_test.py") ? raise("File #{path}/#{ARGV[0]}_test.py already exists!") : File.write("#{path}/#{ARGV[0]}_test.py", steps.gsub("<<FEATURE_NAME>>","<<#{ARGV[0]}>>"))
  )
end

puts "WRAN:你需要手动移动.tmp/tests到项目文件中,移动前请检查测试文件内容."

__END__
Feature:   <<MODULE_NAME>><<FUNCTION>>
  As an    <<MODULE>><<COMPONENT>>
  I        <<SOME_ACTION>>
  So I can <<GET_SOME_ABILITY>>

  Scenario: <<NAME>>
    Given   <<PRECONDITIONS>>
    AND     <<DITTO>>
    When    <<ACTIONS>>
    AND     <<DITTO>>
    Then    <<POSTSEQUENCES>>
    AND     <<DITTO>>
    BUT     <<NOT_SOMETHING>>
__END__
#coding:utf-8
import pytest
from pytest_bdd import scenarios, given, when, then, parsers

@pytest.fixture()
def init():
    '''  '''
__END__
#coding:utf-8
import pytest
from pytest_bdd import scenarios, given, when, then, parsers
import sys
sys.path.append('.')

scenarios('../features/<<FEATURE_NAME>>.feature')
from <<MODULE_PATH>> import *

@given("<<GIVEN_CLAUSE>>")
def action_<<NUM>>(init):
    '''  '''

@when("<<WHEN_CLAUSE>>")
def action_<<NUM>>(init):
    '''  '''

@then("<<THEN_CLAUSE>>")
def action_<<NUM>>(init):
    '''  '''
__END__