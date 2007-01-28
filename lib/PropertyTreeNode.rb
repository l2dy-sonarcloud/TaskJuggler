#
# PropertyTreeNode.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

class PropertyTreeNode

  attr_reader :id, :name, :parent, :project, :sequenceNo, :children

  def initialize(propertySet, id, name, parent)
    @id = id
    @name = name
    @propertySet = propertySet
    @project = propertySet.project
    @sequenceNo = @propertySet.items + 1

    @parent = parent
    @children = Array.new
    if (@parent)
      @parent.addChild(self)
    end

    @attributes = Hash.new
    @scenarioAttributes = Array.new(@project.scenarioCount)
    for i in 0...@project.scenarioCount
      @scenarioAttributes[i] = Hash.new
    end
  end

  def inheritAttributes
    whitelist = %w( priority projectid rate vacation workinghours )

    # Inherit on scenario-specific values
    @propertySet.eachAttributeDefinition do |attrDef|
      next if attrDef.scenarioSpecific || !attrDef.inheritable

      if parent
        # Inherit values from parent property
        if parent.provided(attrDef)
          @attributes[attrDef.id].inherit(parent.get(attrDef))
        end
      else
        # Inherit selected values from project if top-level property
        if whitelist.index(attrDef.id)
          if @project[attrDef.id]
            puts attrDef.id
            @attributes[attrDef.id].inherit(@project[attrDef.id])
          end
        end
      end
    end

    # Inherit scenario-specific values
    @propertySet.eachAttributeDefinition do |attrDef|
      next unless attrDef.scenarioSpecific || attrDef.inheritable

      0.upto(@project.scenarioCount - 1) do |scenarioIdx|
        if parent
          # Inherit scenario specific values from parent property
          if parent.provided(attrDef.id, scenarioIdx)
            @scenarioAttributes[scenarioIdx][attrDef.id].inherit(
                parent[attrDef.id, scenarioIdx])
          end
        else
          # Inherit selected values from project if top-level property
          if whitelist.index(attrDef.id)
            if @project[attrDef.id]
              @scenarioAttributes[scenarioIdx][attrDef.id].inherit(
                  @project[attrDef.id])
            end
          end
        end
      end
    end
  end

  def inheritScenarioAttributes
    # Inherit scenario-specific values
    @propertySet.eachAttributeDefinition do |attrDef|
      next unless attrDef.scenarioSpecific || attrDef.inheritable

      # We know that parents precede their children in the list. So it's safe
      # to iterate over the list instead of recursively descend the tree.
      0.upto(@project.scenarioCount - 1) do |scenarioIdx|
        scenario = @project.scenario(scenarioIdx)
        next if scenario.parent.nil?
        parentScenarioIdx = scenario.parent['seqno']

        # We copy only provided or inherited values from parent scenario when
        # we don't have a provided or inherited value in this scenario.
        if (provided(attrDef.id, parentScenarioIdx) ||
            inherited(attrDef.id, parentScenarioIdx)) &&
           !(provided(attrDef.id, scenarioIdx) ||
             inherited(attrDef.id, scenarioIdx))
          @scenarioAttributes[scenarioIdx][attrDef.id].inherit(
              @scenarioAttributes[parentScenarioIdx][attrDef.id].value)
        end
      end
    end
  end

  # Returns a list of this node and all transient sub nodes.
  def all
    res = [ self ]
    @children.each do |c|
      res = res.concat(c.all)
    end
    res
  end

  def eachAttribute
    @attributes.each do |attr|
      yield attr
    end
  end

  def eachScenarioAttribute(scenario)
    @scenarioAttributes[scenario].each_value do |attr|
      yield attr
    end
  end

  def fullId
    res = @id
    t = self
    unless (t = t.parent).nil?
      res = t.id + "." + res
    end
  end

  def level
    t = self
    level = 0
    until (t = t.parent).nil?
      level += 1
    end
  end

  def addChild(child)
    @children.push(child)
  end

  def leaf?
    @children.empty?
  end

  def container?
    !@children.empty?
  end

  def declareAttribute(attributeType)
    attribute = attributeType.objClass.new(attributeType, self)
    if attributeType.scenarioSpecific
      for i in 0...@project.scenarioCount
        @scenarioAttributes[i][attribute.id] = attribute
      end
    else
      @attributes[attribute.id] = attribute
    end
  end

  def get(attributeId)
    case attributeId
    when 'id'
      @id
    when 'name'
      @name
    when 'seqno'
      @sequenceNo
    else
      unless @attributes.has_key?(attributeId)
        raise "Unknown attribute #{attributeId}"
      end
      @attributes[attributeId].get
    end
  end

  def set(attributeId, value)
    unless @attributes.has_key?(attributeId)
      raise "Unknown attribute #{attributeId}"
    end
    @attributes[attributeId].set(value)
  end

  def []=(attributeId, scenario, value)
    if @scenarioAttributes[scenario].has_key?(attributeId)
      @scenarioAttributes[scenario][attributeId].set(value)
    elsif @attributes.has_key?(attributeId)
      @attributes[attributeId].set(value)
    else
      raise "Unknown attribute #{attributeId}"
    end
    @scenarioAttributes[scenario][attributeId].set(value)
  end

  def [](attributeId, scenario)
    if @scenarioAttributes[scenario].has_key?(attributeId)
      @scenarioAttributes[scenario][attributeId].get
    elsif @attributes.has_key?(attributeId)
      @attributes[attributeId].get
    elsif attributeId == 'id'
      @id
    elsif attributeId == 'name'
      @name
    elsif attributeId == 'seqno'
      @sequenceNo
    else
      raise "Unknown attribute #{attributeId}"
    end
  end

  def provided(attributeId, scenarioIdx = nil)
    if scenarioIdx
      @scenarioAttributes[scenarioIdx][attributeId].provided
    else
      @attributes[attributeId].provided
    end
  end

  def to_s
    res = "#{self.class} #{fullId} \"#{@name}\"\n" +
          "  Sequence No: #{@sequenceNo}\n"

    res += "  Parent: #{@parent['id']}\n" if @parent
    @attributes.each do |key, attr|
      res += "  #{key}: " + attr.to_s + "\n"
    end
    0.upto(project.scenarioCount - 1) do |sc|
      res += "  Scenario #{project.scenario(sc).get('id')}\n"
      @scenarioAttributes[sc].each do |key, attr|
        res += "    #{key}: " + attr.to_s + "\n"
      end
    end
    res += "***\n"
  end

end
