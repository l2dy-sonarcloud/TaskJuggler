#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TaskJuggler.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'drb'
require 'Project'
require 'MessageHandler'
require 'Log'

# The TaskJuggler class models the object that provides access to the
# fundamental features of the TaskJuggler software. It can read project
# files, schedule them and generate the reports.
class TaskJuggler

  attr_reader :messageHandler
  attr_accessor :maxCpuCores, :warnTsDeltas

  # Create a new TaskJuggler object. _console_ is a boolean that determines
  # whether or not messsages can be written to $stderr.
  def initialize(console)
    @project = nil
    @parser = nil
    @messageHandler = MessageHandler.new(console)
    @maxCpuCores = 1
    @warnTsDeltas = false
  end

  # Read in the files passed as file names in _files_, parse them and
  # construct a Project object. In case of success true is returned.
  # Otherwise false.
  def parse(files, keepParser = false)
    Log.enter('parser', 'Parsing files ...')
    master = true
    @project = nil

    @parser = ProjectFileParser.new(@messageHandler)
    files.each do |file|
      begin
        @parser.open(file, master)
      rescue TjException
        Log.exit('parser')
        return false
      end
      if master
        @project = @parser.parse('project')
        master = false
      else
        @parser.setGlobalMacros
        @parser.parse('properties')
      end
      @parser.close
    end

    # For the report server mode we may need to keep the parser. Otherwise,
    # destroy it.
    @parser = nil unless keepParser

    Log.exit('parser')
    @messageHandler.errors == 0
  end

  # Parse a file and add the content to the existing project. _fileName_ is
  # the name of the file. _rule_ is the TextParser::Rule to start with.
  def parseFile(fileName, rule)
    @parser.open(fileName, false)
    @parser.setGlobalMacros
    return nil if (res = @parser.parse(rule)).nil?
    # Make sure that _rule_ described the full content of the file. There
    # should be no more content left.
    @parser.checkForEnd
    @parser.close
    res
  end

  # Schedule all scenarios in the project. Return true if no error was
  # detected, false otherwise.
  def schedule
    Log.enter('scheduler', 'Scheduling project ...')
    #puts @project.to_s
    @project.warnTsDeltas = @warnTsDeltas
    res = @project.schedule
    Log.exit('scheduler')
    res
  end

  # Generate all specified reports. The project must have be scheduled before
  # this method can be called. It returns true if no error occured, false
  # otherwise.
  def generateReports(outputDir)
    @project.outputDir = outputDir
    Log.enter('reports', 'Generating reports ...')
    res = @project.generateReports(@maxCpuCores)
    Log.exit('reports')
    res
  end

  # Generate the report with the ID _reportId_. If _regExpMode_ is true,
  # _reportId_ is interpreted as a Regular Expression and all reports with
  # matching IDs are generated.
  def generateReport(reportId, regExpMode)
    begin
      Log.enter('generateReport', 'Generating report #{reportId} ...')
      @project.generateReport(reportId, regExpMode)
    rescue TjException
      Log.exit('generateReport')
      return false
    end
    Log.exit('generateReport')
    true
  end

  # Generate the report with the ID _reportId_. If _regExpMode_ is true,
  # _reportId_ is interpreted as a Regular Expression and all reports with
  # matching IDs are listed.
  def listReports(reportId, regExpMode)
    begin
      Log.enter('listReports', 'Generating report list for #{reportId} ...')
      @project.listReports(reportId, regExpMode)
    rescue TjException
      Log.exit('listReports')
      return false
    end
    Log.exit('listReports')
    true
  end

  # Check the content of the file _fileName_ and interpret it as a time sheet.
  # If the sheet is syntaxtically correct and matches the loaded project, true
  # is returned. Otherwise false.
  def checkTimeSheet(fileName)
    begin
      Log.enter('checkTimeSheet', 'Parsing #{fileName} ...')
      # Make sure we don't use data from old time sheets or Journal entries.
      @project.timeSheets.clear
      @project['journal'] = Journal.new
      return false unless (ts = parseFile(fileName, 'timeSheet'))
      return false unless @project.checkTimeSheets
      queryAttrs = { 'project' => @project,
                     'property' => ts.resource,
                     'scopeProperty' => nil,
                     'scenarioIdx' => @project['trackingScenarioIdx'],
                     'start' => ts.interval.start,
                     'end' => ts.interval.end,
                     'timeFormat' => '%Y-%m-%d' }
      query = Query.new(queryAttrs)
      rti = ts.resource.query_journal(query)
      rti.lineWidth = 72
      rti.indent = 2
      rti.titleIndent = 0
      rti.listIndent = 2
      rti.parIndent = 2
      rti.preIndent = 4
      puts rti.to_s
    rescue TjException
      Log.exit('checkTimeSheet')
      return false
    end
    Log.exit('checkTimeSheet')
    true
  end

  # Check the content of the file _fileName_ and interpret it as a status
  # sheet.  If the sheet is syntaxtically correct and matches the loaded
  # project, true is returned. Otherwise false.
  def checkStatusSheet(fileName)
    begin
      Log.enter('checkStatusSheet', 'Parsing #{fileName} ...')
      return false unless (ss = parseFile(fileName, 'statusSheet'))
      queryAttrs = { 'project' => @project,
                     'property' => ss[0],
                     'scopeProperty' => nil,
                     'scenarioIdx' => @project['trackingScenarioIdx'],
                     'timeFormat' => '%Y-%m-%d',
                     'start' => ss[1],
                     'end' => ss[2],
                     'timeFormat' => '%Y-%m-%d' }
      query = Query.new(queryAttrs)
      rti = ss[0].query_dashboard(query)
      rti.lineWidth = 72
      rti.indent = 2
      rti.titleIndent = 0
      rti.listIndent = 2
      rti.parIndent = 2
      rti.preIndent = 4
      puts rti.to_s
    rescue TjException
      Log.exit('checkStatusSheet')
      return false
    end
    Log.exit('checkStatusSheet')
    true
  end

  # Return the ID of the project or nil if no project has been loaded yet.
  def projectId
    return nil if @project.nil?
    @project['projectid']
  end

  # Return the number of errors that had been reported during processing.
  def errors
    @project.messageHandler.errors
  end

end

