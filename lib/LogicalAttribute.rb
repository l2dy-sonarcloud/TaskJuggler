#
# LogicalAttribute.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'LogicalOperation'

class LogicalAttribute < LogicalOperation

  def initialize(attribute, scenario)
    @scenarioIdx = scenario
    super(attribute)
  end

  def LogicalAttribute::tjpId
    'logical'
  end

  def eval(expr)
    expr.property[@operand1, @scenarioIdx]
  end

end