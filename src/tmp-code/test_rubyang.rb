#!/usr/local/bin/ruby
#coding:utf-8
require 'rubyang'

path = '../models/yang/HW-NE40E-V800R012C10SPC300/huawei-bfd.yang'
yangtext = File.read(path)
db = Rubyang::Database.new
db.load_model Rubyang::Model::Parser.parse( yangtext )
#puts db.configure.to_xml( pretty: true )
